--!strict
-- ShipController.lua (ReplicatedStorage/Modules)
-- Client-authoritative sailing with weight penalties, smooth physics, and docking for imported assets.

local Utils = require(script.Parent.Utils)
local FogSystem = require(script.Parent.FogSystem)
local RunService = Utils.GetService("RunService")
local Players = Utils.GetService("Players")
local CollectionService = Utils.GetService("CollectionService")

local ShipController = {}
ShipController.__index = ShipController

local Remotes = {
	PlayerMoveInput = Utils.CreateRemoteEvent("PlayerMoveInput"),
	PlayerDocked = Utils.CreateRemoteEvent("PlayerDocked"),
}

local activeShips: {[Player]: {Velocity: Vector3, LastDockTime: number, Weight: number}} = {}
local maid = Utils.CreateMaid()

local CONFIG = {
	MaxSpeed = 55,
	Acceleration = 30,
	TurnRate = 3.5,
	DockingDistance = 32,
	BaseWeightPenalty = 0.48,
	UpdateRate = 1 / 30,
}

function ShipController.Initialize()
	maid:GiveTask(RunService.Heartbeat:Connect(function(dt: number)
		for player, ship in activeShips do
			if not player.Character then continue end
			local root = player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
			if root then
				local penalty = 1 - (ship.Weight / 80) * CONFIG.BaseWeightPenalty
				root.AssemblyLinearVelocity = ship.Velocity * math.clamp(penalty, 0.35, 1.0)
			end
		end
	end))

	Remotes.PlayerMoveInput.OnServerEvent:Connect(function(player: Player, moveDir: Vector3?)
		if typeof(moveDir) ~= "Vector3" then return end
		if not activeShips[player] then
			activeShips[player] = {Velocity = Vector3.new(), LastDockTime = 0, Weight = 0}
		end
		local ship = activeShips[player]
		ship.Velocity = ship.Velocity:Lerp(moveDir * CONFIG.MaxSpeed, 0.32)
	end))

	print("[ShipController] Initialized - Tuned client-authoritative sailing")
end

function ShipController.UpdatePlayerWeight(player: Player, newWeight: number)
	local ship = activeShips[player]
	if ship then ship.Weight = math.clamp(newWeight, 0, 80) end
end

function ShipController.AttemptDock(player: Player)
	local ship = activeShips[player]
	if not ship or tick() - ship.LastDockTime < 2 then return end

	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root then return end

	for _, ghost in CollectionService:GetTagged("GhostShip") do
		local primary = ghost.PrimaryPart
		if primary and (primary.Position - root.Position).Magnitude < CONFIG.DockingDistance then
			ship.LastDockTime = tick()
			Remotes.PlayerDocked:FireClient(player, ghost)
			FogSystem.TriggerHorrorPulse(0.8)
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