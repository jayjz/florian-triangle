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
	InputRateLimit = 0.08,
	MaxInputMagnitude = 1.2,
	BoardingSanityDamage = 12,
	BoardingHorrorPulse = 0.8,
	BoardingDebounce = 1.5,
}

local function getOrCreateShip(player: Player): ShipState
	local ship = activeShips[player]
	if not ship then
		ship = {
			Velocity = Vector3.new(),
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
	if not ship then return true end
	if ship.SailingEnabled == false then return false end
	return (os.clock() - (ship.LastInputTime or 0)) > CONFIG.InputRateLimit
end

function ShipController.Initialize()
	maid:GiveTask(RunService.Heartbeat:Connect(function(dt: number)
		for player, ship in activeShips do
			-- Only control AssemblyLinearVelocity when actively sailing.
			-- When SailingEnabled == false, let Roblox Humanoid handle movement
			-- (lobby, ghost ship interiors). This prevents tug-of-war between
			-- Humanoid controller (WalkSpeed 16) and ShipController (58 studs/sec).
			if not ship.SailingEnabled then continue end
			if not player.Character then continue end
			local root = player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
			if root then
				local penalty = 1 - (ship.Weight / 80) * CONFIG.BaseWeightPenalty
				root.AssemblyLinearVelocity = ship.Velocity * math.clamp(penalty, 0.2, 1.0)
			end
		end
	end))

	Remotes.PlayerMoveInput.OnServerEvent:Connect(function(player: Player, moveDir: Vector3?)
		if typeof(moveDir) ~= "Vector3" then return end
		if not isInputAllowed(player) then return end
		if moveDir.Magnitude > CONFIG.MaxInputMagnitude then return end

		local ship = getOrCreateShip(player)

		local targetVelocity = Vector3.new()
		if moveDir.Magnitude > 0 then
			targetVelocity = moveDir.Unit * CONFIG.MaxSpeed
		end
		ship.Velocity = ship.Velocity:Lerp(targetVelocity, 0.38)
		ship.LastInputTime = os.clock()
	end)

	-- Re-apply Humanoid movement settings on character respawn.
	-- When a player respawns, their new Humanoid defaults to WalkSpeed 16 /
	-- AutoRotate true. If SailingEnabled was true before death, re-disable
	-- Humanoid movement on the new character, otherwise Humanoid +
	-- ShipController fight → tug-of-war / yanking bug.
	local Players = Utils.GetService("Players")
	maid:GiveTask(Players.PlayerAdded:Connect(function(player: Player)
		-- CharacterAdded is NOT stored in maid — it dies naturally with the
		-- Player instance when they leave. We DO clean up activeShips[player]
		-- in the global PlayerRemoving handler below to break the retain cycle:
		-- activeShips[player] → strong ref to Player → would leak after leave.
		player.CharacterAdded:Connect(function(character: Model)
			task.wait() -- Wait one frame for Humanoid to exist
			local ship = activeShips[player]
			if ship and ship.SailingEnabled then
				local humanoid = character:FindFirstChildOfClass("Humanoid") :: Humanoid?
				if humanoid then
					humanoid.WalkSpeed = 0
					humanoid.AutoRotate = false
				end
			end
			-- else: SailingEnabled = false or no ship state → leave Humanoid
			-- at defaults (WalkSpeed 16, AutoRotate true) for on-foot movement
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

	-- Toggle Humanoid movement controller to prevent tug-of-war with
	-- AssemblyLinearVelocity. When sailing: Humanoid OFF, ShipController ON.
	-- When on foot: Humanoid ON, ShipController OFF.
	local character = player.Character
	if character then
		local humanoid = character:FindFirstChildOfClass("Humanoid") :: Humanoid?
		if humanoid then
			if enabled then
				-- Sailing mode: disable Humanoid movement, ShipController owns physics
				humanoid.WalkSpeed = 0
				humanoid.AutoRotate = false
			else
				-- On-foot mode: restore Humanoid movement, ShipController hands off
				-- Reset AssemblyLinearVelocity so Humanoid starts from clean state
				local root = character:FindFirstChild("HumanoidRootPart") :: BasePart?
				if root then
					root.AssemblyLinearVelocity = Vector3.zero
					root.AssemblyAngularVelocity = Vector3.zero
				end
				humanoid.WalkSpeed = 16
				humanoid.AutoRotate = true
			end
		end
	end

	if not enabled then
		ship.Velocity = Vector3.new()
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
