--!strict
-- ShipController.lua (ReplicatedStorage/Modules)
-- Player ship movement with weight-based speed penalties and boarding state management.

local Utils = require(script.Parent.Utils)
local AudioManager = require(script.Parent.AudioManager)
local HorrorEvents = require(script.Parent.HorrorEvents)

local RunService = Utils.GetService("RunService")

local ShipController = {}
ShipController.__index = ShipController

local Remotes = {
	PlayerMoveInput = Utils.CreateRemoteEvent("PlayerMoveInput"),
	PlayerDocked = Utils.CreateRemoteEvent("PlayerDocked"),
}

type ShipState = {
	Velocity: Vector3,
	TargetVelocity: Vector3,
	Weight: number,
	LastInputTime: number,
	SailingEnabled: boolean,
	LastBoardTime: number,
}

local activeShips: {[Player]: ShipState} = {}
local maid = Utils.CreateMaid()

local CONFIG = {
	MaxSpeed = 58,
	BaseWeightPenalty = 0.78,
	InputRateLimit = 0, -- Unlimited — client does change detection (~2-10 packets/sec), process immediately for zero artificial latency
	MaxInputMagnitude = 1.2,
	BoardingSanityDamage = 12,
	BoardingHorrorPulse = 0.8,
	BoardingDebounce = 1.5,
	SailingInputDebounce = 0.2,
	VelocityLerpAlpha = 0.22, -- Heartbeat velocity smoothing (60Hz). 0.22 → 99% convergence in ~18 frames (~0.3s), responsive but not twitchy
	IdleFriction = 0.92, -- Velocity decay when no recent input (per Heartbeat). 0.92^60 ≈ 0.007 → stops in ~1 sec after releasing keys
	InputTimeout = 0.15, -- Seconds after last input before idle friction kicks in. Allows brief input gaps (packet loss, frame drops) without triggering friction
}

local function getOrCreateShip(player: Player): ShipState
	local ship = activeShips[player]
	if not ship then
		ship = {
			Velocity = Vector3.new(),
			TargetVelocity = Vector3.new(),
			Weight = 0,
			LastInputTime = 0,
			SailingEnabled = false, -- Default to Humanoid movement (lobby/on-foot). Opt-in to ShipController sailing.
			LastBoardTime = 0,
		}
		activeShips[player] = ship
	end
	return ship
end

local function isInputAllowed(player: Player): boolean
	local ship = activeShips[player]
	if not ship then return false end
	if not ship.SailingEnabled then return false end
	return (os.clock() - (ship.LastInputTime or 0)) > CONFIG.InputRateLimit
end

function ShipController.Initialize()
	maid:GiveTask(RunService.Heartbeat:Connect(function(dt: number)
		local now = os.clock()
		for player, ship in activeShips do
			-- Only control AssemblyLinearVelocity when actively sailing.
			-- When SailingEnabled == false, let Roblox Humanoid handle movement
			-- (lobby, ghost ship interiors). This prevents tug-of-war between
			-- Humanoid controller (WalkSpeed 16) and ShipController (58 studs/sec).
			if not ship.SailingEnabled then continue end
			if not player.Character then continue end
			local root = player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
			if root then
				-- Velocity smoothing: Lerp current Velocity toward TargetVelocity every frame.
				-- TargetVelocity is set INSTANTLY by input packets (client change detection:
				-- ~2-10 packets/sec, direction changes only, zero artificial latency).
				-- Heartbeat interpolation (60Hz) makes movement smooth REGARDLESS of input rate.
				-- This decouples network input rate from movement feel — critical for
				-- change-detection input (was: input spam 60Hz → Lerp in input handler,
				-- smooth but wasteful; now: input on change → Lerp in Heartbeat, smooth + efficient).
				ship.Velocity = ship.Velocity:Lerp(ship.TargetVelocity, CONFIG.VelocityLerpAlpha)

				-- Idle friction: decay velocity to zero when no recent input.
				-- Without this: player releases keys → stop packet sent → TargetVelocity = 0
				-- → Velocity Lerps 22% toward 0 → stuck at 78% speed forever (no more input
				-- packets → no more Lerp steps → velocity frozen). WITH friction: after
				-- InputTimeout (0.15s) with no input packets, apply exponential decay
				-- (0.92 per frame → stops in ~1 sec). Ship coasts to a natural stop,
				-- like water drag / anchor drop. Feels good, prevents drift bug.
				-- InputTimeout = 0.15s allows brief input gaps (packet loss, frame drops)
				-- without triggering friction — input resumes → friction stops, smooth.
				if now - ship.LastInputTime > CONFIG.InputTimeout then
					ship.Velocity *= CONFIG.IdleFriction
					ship.TargetVelocity *= CONFIG.IdleFriction
					-- Snap to zero when velocity is negligible — prevents infinite
					-- asymptotic decay (0.92^n never actually reaches 0), saves CPU
					-- (stopped ship = zero ALV writes = less physics work), prevents
					-- micro-drift (ship creeping at 0.001 studs/sec forever).
					if ship.Velocity.Magnitude < 0.1 then
						ship.Velocity = Vector3.new()
						ship.TargetVelocity = Vector3.new()
					end
				end

				local penalty = 1 - (ship.Weight / 80) * CONFIG.BaseWeightPenalty
				-- Preserve Y velocity for gravity/jump/fall physics.
				-- ShipController owns HORIZONTAL (X/Z) sailing movement,
				-- physics engine owns VERTICAL (Y) gravity/jump/fall.
				-- Without Y preservation: gravity cancelled → float instead of fall,
				-- jump impulse cancelled → can't jump. With Y preservation:
				-- walk off ship deck → FALL with gravity, jump works naturally.
				local sv = ship.Velocity * math.clamp(penalty, 0.2, 1.0)
				local av = root.AssemblyLinearVelocity
				root.AssemblyLinearVelocity = Vector3.new(sv.X, av.Y, sv.Z)
			end
		end
	end))

	Remotes.PlayerMoveInput.OnServerEvent:Connect(function(player: Player, moveDir: Vector3?)
		if typeof(moveDir) ~= "Vector3" then return end
		if not isInputAllowed(player) then return end
		if moveDir.Magnitude > CONFIG.MaxInputMagnitude then return end

		local ship = getOrCreateShip(player)

		-- Set TargetVelocity INSTANTLY — no Lerp here.
		-- Velocity smoothing happens in Heartbeat (60Hz): ship.Velocity:Lerp(ship.TargetVelocity, 0.22)
		-- This decouples network input rate from movement feel — critical for change-detection
		-- input (client sends ~2-10 packets/sec, direction changes only). Old system: Lerp in
		-- input handler (0.38 alpha) + input spam 60Hz = smooth but wasteful (47.5/60 packets
		-- dropped, 80ms artificial latency). New system: input on change + Heartbeat Lerp =
		-- smooth + efficient + zero artificial latency.
		-- moveDir = Vector3.zero is VALID — that's the STOP packet (keys released).
		-- Client change detection sends stop packets: moveDir goes from non-zero → zero
		-- → (moveDir - lastMoveDir).Magnitude > 0.01 → FireServer(Vector3.zero)
		-- → TargetVelocity = 0 → Heartbeat Lerps Velocity toward 0 → idle friction
		-- kicks in after 0.15s → ship coasts to stop in ~1 sec. Feels natural.
		if moveDir.Magnitude > 0 then
			ship.TargetVelocity = moveDir.Unit * CONFIG.MaxSpeed
		else
			ship.TargetVelocity = Vector3.new()
		end
		ship.LastInputTime = os.clock()
	end)

	-- Re-apply Humanoid movement settings on character respawn.
	-- When a player respawns, their new Humanoid defaults to WalkSpeed 16 /
	-- AutoRotate true. If SailingEnabled was true before death, re-disable
	-- Humanoid movement on the new character, otherwise Humanoid +
	-- ShipController fight → tug-of-war / yanking bug.
	-- Also restore NetworkOwnership + HumanoidState (anti-yanking fix).
	local Players = Utils.GetService("Players")
	maid:GiveTask(Players.PlayerAdded:Connect(function(player: Player)
		-- CharacterAdded is NOT stored in maid — it dies naturally with the
		-- Player instance when they leave. We DO clean up activeShips[player]
		-- in the global PlayerRemoving handler below to break the retain cycle:
		-- activeShips[player] → strong ref to Player → would leak after leave.
		player.CharacterAdded:Connect(function(character: Model)
			task.wait() -- Wait one frame for Humanoid to exist
			local ship = activeShips[player]
			local humanoid = character:FindFirstChildOfClass("Humanoid") :: Humanoid?
			local root = character:FindFirstChild("HumanoidRootPart") :: BasePart?
			if not humanoid or not root then return end

			if ship and ship.SailingEnabled then
				-- Sailing mode respawn: disable Humanoid, server owns physics.
				humanoid.WalkSpeed = 0
				humanoid.AutoRotate = false
				humanoid.UseJumpPower = true
				humanoid.JumpPower = 0
				humanoid.JumpHeight = 0
				pcall(function() root:SetNetworkOwner(nil) end)
				pcall(function() humanoid:ChangeState(Enum.HumanoidStateType.Physics) end)
			else
				-- On-foot respawn: ensure client owns physics for responsive Humanoid.
				-- Character defaults to client-owned, but be explicit for consistency
				-- (handles edge case: player dies while sailing → respawns in lobby,
				-- ShipState may still exist with SailingEnabled=true briefly).
				pcall(function() root:SetNetworkOwner(player) end)
				pcall(function() humanoid:ChangeState(Enum.HumanoidStateType.Running) end)
			end
			-- else: SailingEnabled = false or no ship state → leave Humanoid
			-- at defaults (WalkSpeed 16, AutoRotate true) for on-foot movement.
			-- NetworkOwnership + State explicitly restored above.
		end)
	end))

	-- Clean up ShipState when players leave — prevents Player instance leak
	-- via activeShips table key. Without this: activeShips[player] keeps
	-- Player alive after leave → CharacterAdded closure keeps Player alive →
	-- memory leak accumulates over multiple sessions on persistent servers.
	maid:GiveTask(Players.PlayerRemoving:Connect(function(player: Player)
		activeShips[player] = nil
	end))

	print("[ShipController] Initialized - Secure sailing active")
end

function ShipController.UpdatePlayerWeight(player: Player, newWeight: number)
	local ship = activeShips[player]
	if ship then
		ship.Weight = math.clamp(newWeight, 0, 80)
	end
end

-- SetSailing: Toggle player ship movement on/off.
-- enabled = false → freeze velocity, reject move input, RESTORE Humanoid movement
--                  (player is on foot: lobby, ghost ship interior)
-- enabled = true  → restore sailing, DISABLE Humanoid movement
--                  (player is sailing: ShipController owns AssemblyLinearVelocity)
-- Note: Prefer BoardGhostShip/ExitGhostShip for full boarding flow with FX.
-- SetSailing is kept exported as a low-level primitive.
function ShipController.SetSailing(player: Player, enabled: boolean)
	if typeof(player) ~= "Instance" or not player:IsA("Player") then return end
	local ship = getOrCreateShip(player)
	ship.SailingEnabled = enabled

	-- Velocity reset: Always zero ship velocity on sailing state change.
	-- Prevents stale velocity launch bug: if player walked in lobby (Humanoid,
	-- SailingEnabled=false), ShipState.Velocity gets polluted by input.
	-- Without this reset, SetSailing(true) at round start → instant launch
	-- in last-walked direction. Same for ExitGhostShip → launch with
	-- pre-boarding velocity. Always start sailing from zero velocity.
	-- Reset BOTH Velocity and TargetVelocity — TargetVelocity is set by input
	-- packets (client change detection), Velocity is lerped toward TargetVelocity
	-- in Heartbeat. Zeroing both prevents instant launch + drift.
	ship.Velocity = Vector3.new()
	ship.TargetVelocity = Vector3.new()

	-- Client input gating: Set Player attribute so ClientShipController
	-- can skip firing PlayerMoveInput when not sailing. Stops input spam
	-- (60 Hz RenderStepped → server) during lobby/on-foot, prevents
	-- ShipState velocity pollution, reduces bandwidth.
	player:SetAttribute("SailingEnabled", enabled)

	-- Input debounce: Block move input for SailingInputDebounce seconds
	-- after enabling sailing. Safety net against stale/residual input
	-- causing instant launch. isInputAllowed() checks LastInputTime.
	if enabled then
		ship.LastInputTime = os.clock() + CONFIG.SailingInputDebounce
	end

	-- Toggle Humanoid movement controller to prevent tug-of-war with
	-- AssemblyLinearVelocity. When sailing: Humanoid OFF, ShipController ON.
	-- When on foot: Humanoid ON, ShipController OFF.
	local character = player.Character
	if character then
		local root = character:FindFirstChild("HumanoidRootPart") :: BasePart?
		local humanoid = character:FindFirstChildOfClass("Humanoid") :: Humanoid?
		if humanoid then
			if enabled then
				-- Sailing mode: disable Humanoid movement, ShipController owns physics.
				-- WalkSpeed = 0 / AutoRotate = false prevents Humanoid from fighting
				-- ShipController's AssemblyLinearVelocity (tug-of-war bug).
				-- JumpPower = 0 / JumpHeight = 0 disables jumping while sailing —
				-- consistent with WalkSpeed/AutoRotate toggle: sailing mode =
				-- ShipController owns 100% of physics, Humanoid owns 0%.
				-- Prevents accidental falls off ship deck, simpler state machine.
				-- Set UseJumpPower = true to ensure JumpPower (not JumpHeight)
				-- is respected — Roblox defaults to JumpHeight mode in some rigs.
				humanoid.WalkSpeed = 0
				humanoid.AutoRotate = false
				humanoid.UseJumpPower = true
				humanoid.JumpPower = 0
				humanoid.JumpHeight = 0

				-- NETWORK OWNERSHIP FIX (yanking/rubberbanding bug):
				-- Player characters are network-owned by the client by default in Roblox.
				-- When ShipController (server) writes AssemblyLinearVelocity every Heartbeat,
				-- the client ALSO simulates physics for that same part and overwrites ALV —
				-- classic tug-of-war → yanking/rubberbanding.
				-- Fix: Give server authority over character physics during sailing.
				-- SetNetworkOwner(nil) → server owns physics, authoritative movement.
				if root then
					local ok = pcall(function()
						root:SetNetworkOwner(nil)
					end)
					if not ok then
						warn("[ShipController] SetNetworkOwner(nil) failed for", player.Name)
					end
				end

				-- Kick Humanoid state machine into pure physics mode — belt-and-suspenders
				-- against state machine interference with ShipController ALV writes.
				-- Physics state = Humanoid stops all locomotion/standing logic, zero interference.
				local ok = pcall(function()
					humanoid:ChangeState(Enum.HumanoidStateType.Physics)
				end)
				if not ok then
					warn("[ShipController] Humanoid:ChangeState(Physics) failed for", player.Name)
				end
			else
				-- On-foot mode: restore Humanoid movement, ShipController hands off.
				-- Reset AssemblyLinearVelocity so Humanoid starts from clean state
				-- (no residual drift/slide from sailing velocity).
				if root then
					root.AssemblyLinearVelocity = Vector3.zero
					root.AssemblyAngularVelocity = Vector3.zero

					-- Restore client network ownership for normal Humanoid movement.
					-- Player characters default to client-owned for input responsiveness.
					-- Give ownership back when sailing ends (lobby, ghost ship interior).
					local ok = pcall(function()
						root:SetNetworkOwner(player)
					end)
					if not ok then
						warn("[ShipController] SetNetworkOwner(player) failed for", player.Name)
					end
				end
				humanoid.WalkSpeed = 16
				humanoid.AutoRotate = true
				humanoid.UseJumpPower = true
				humanoid.JumpPower = 50
				humanoid.JumpHeight = 7.2

				-- Restore Humanoid to normal running state for on-foot movement.
				local ok = pcall(function()
					humanoid:ChangeState(Enum.HumanoidStateType.Running)
				end)
				if not ok then
					warn("[ShipController] Humanoid:ChangeState(Running) failed for", player.Name)
				end
			end
		end
	end
end

-- BoardGhostShip: Full boarding sequence with horror feedback.
-- Freezes sailing, teleports player to interior, triggers sanity damage,
-- horror pulse, boarding audio, and fires PlayerDocked RemoteEvent for client FX.
-- Returns true on success, false if player/character invalid.
function ShipController.BoardGhostShip(player: Player, ghostModel: Model, interiorCFrame: CFrame): boolean
	if typeof(player) ~= "Instance" or not player:IsA("Player") then return false end
	if typeof(ghostModel) ~= "Instance" or not ghostModel:IsA("Model") then return false end
	if typeof(interiorCFrame) ~= "CFrame" then return false end

	local character = player.Character
	if not character then return false end
	local root = character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root then return false end

	-- Boarding exploit guard: prevent double-board / ProximityPrompt spam.
	-- SailingEnabled check blocks re-entry while already docked.
	-- Debounce blocks rapid spam during state transitions (HoldDuration = 0
	-- on ProximityPrompt = instant trigger, player mashing E).
	local ship = getOrCreateShip(player)
	if not ship.SailingEnabled then return false end
	local now = os.clock()
	if now - (ship.LastBoardTime or 0) < CONFIG.BoardingDebounce then return false end
	ship.LastBoardTime = now

	-- Freeze ship movement
	ShipController.SetSailing(player, false)

	-- Teleport to interior
	root.CFrame = interiorCFrame

	-- Horror feedback chain (all guarded)
	if typeof(AudioManager.PlayBoardingSound) == "function" then
		local ok = pcall(AudioManager.PlayBoardingSound, ghostModel)
		if not ok then warn("[ShipController] PlayBoardingSound failed") end
	end

	if typeof(HorrorEvents.TriggerSanityDamage) == "function" then
		local ok = pcall(HorrorEvents.TriggerSanityDamage, player, CONFIG.BoardingSanityDamage)
		if not ok then warn("[ShipController] TriggerSanityDamage failed") end
	end

	if typeof(HorrorEvents.TriggerHorrorPulse) == "function" then
		local ok = pcall(HorrorEvents.TriggerHorrorPulse, CONFIG.BoardingHorrorPulse)
		if not ok then warn("[ShipController] TriggerHorrorPulse failed") end
	end

	-- Fire client boarding FX event
	local ok = pcall(function()
		Remotes.PlayerDocked:FireClient(player, ghostModel)
	end)
	if not ok then
		warn("[ShipController] PlayerDocked FireClient failed")
	end

	return true
end

-- ExitGhostShip: Restore sailing and teleport player back to exterior.
-- Returns true on success, false if player/character invalid.
function ShipController.ExitGhostShip(player: Player, returnCFrame: CFrame): boolean
	if typeof(player) ~= "Instance" or not player:IsA("Player") then return false end
	if typeof(returnCFrame) ~= "CFrame" then return false end

	local character = player.Character
	if not character then return false end
	local root = character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root then return false end

	-- Restore sailing
	ShipController.SetSailing(player, true)

	-- Teleport to exterior
	root.CFrame = returnCFrame

	return true
end

function ShipController.Destroy()
	maid:Cleanup()
	table.clear(activeShips)
end

return ShipController
