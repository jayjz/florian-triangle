--!strict
-- ShipController.lua (ReplicatedStorage/Modules)
-- Fixed: os.clock(), guarded calls to HorrorEvents/AudioManager, improved docking.

local Utils = require(script.Parent.Utils)
local FogSystem = require(script.Parent.FogSystem)
local AudioManager = require(script.Parent.AudioManager)
local HorrorEvents = require(script.Parent.HorrorEvents)

local RunService = Utils.GetService("RunService")
local Players = Utils.GetService("Players")
local CollectionService = Utils.GetService("CollectionService")

local ShipController = {}
ShipController.__index = ShipController

local Remotes = {
	PlayerMoveInput = Utils.CreateRemoteEvent("PlayerMoveInput"),
	PlayerDocked = Utils.CreateRemoteEvent("PlayerDocked"),
}

local activeShips: {[Player]: {Velocity: Vector3, LastDockTime: number, Weight: number, LastInputTime: number}} = {}
local maid = Utils.CreateMaid()

local CONFIG = {
	MaxSpeed = 58,
	Acceleration = 34,
	TurnRate = 4.0,
	DockingDistance = 32,
	BaseWeightPenalty = 0.78,
	InputRateLimit = 0.08,
	MaxInputMagnitude = 1.2,
}

local function isInputAllowed(player: Player): boolean
	local ship = activeShips[player]
	if not ship then return true end
	return (os.clock() - (ship.LastInputTime or 0)) > CONFIG.InputRateLimit
end

function ShipController.Initialize()
	maid:GiveTask(RunService.Heartbeat:Connect(function(dt: number)
		for player, ship in activeShips do
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

		if not activeShips[player] then
			activeShips[player] = {Velocity = Vector3.new(), LastDockTime = 0, Weight = 0, LastInputTime = 0}
		end

		local ship = activeShips[player]
		local targetVelocity = Vector3.new()
		if moveDir.Magnitude > 0 then
			targetVelocity = moveDir.Unit * CONFIG.MaxSpeed
		end
		ship.Velocity = ship.Velocity:Lerp(targetVelocity, 0.38)
		ship.LastInputTime = os.clock()
	end)

	print("[ShipController] Initialized - Secure sailing active")
end

function ShipController.UpdatePlayerWeight(player: Player, newWeight: number)
	local ship = activeShips[player]
	if ship then
		ship.Weight = math.clamp(newWeight, 0, 80)
	end
end

function ShipController.AttemptDock(player: Player)
	local ship = activeShips[player]
	if not ship or (os.clock() - ship.LastDockTime) < 2.2 then return end

	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root then return end

	for _, ghost in CollectionService:GetTagged("GhostShip") do
		local primary = ghost.PrimaryPart
		if primary and (primary.Position - root.Position).Magnitude < CONFIG.DockingDistance then
			ship.LastDockTime = os.clock()

			Remotes.PlayerDocked:FireClient(player, ghost)
			
			-- Guarded calls (prevents nil errors)
			if typeof(AudioManager.PlayBoardingSound) == "function" then
				AudioManager.PlayBoardingSound(ghost)
			end
			if typeof(HorrorEvents.TriggerSanityDamage) == "function" then
				HorrorEvents.TriggerSanityDamage(player, 12)
			end
			if typeof(HorrorEvents.TriggerHorrorPulse) == "function" then
				HorrorEvents.TriggerHorrorPulse(0.8)
			end

			return true
		end
	end
	return false
end

function ShipController.Destroy()
	maid:Cleanup()
	table.clear(activeShips)
end

return ShipController