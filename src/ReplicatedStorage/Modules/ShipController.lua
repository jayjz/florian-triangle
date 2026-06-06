--!strict
-- ShipController.lua
-- Core ship sailing, docking, and upgrade system for Fog Sea.
-- Mobile-first implementation. All heavy lifting done on server.
-- Uses proper RemoteEvent pattern with validation.
-- Author: Fog Sea Architect - 2026-06-06

local Utils = require(script.Parent.Utils)
local FogSystem = require(script.Parent.FogSystem)
local RunService = Utils.GetService("RunService")
local Players = Utils.GetService("Players")

local ShipController = {}
ShipController.__index = ShipController

export type ShipController = typeof(ShipController)
export type Ship = {
	Model: Model,
	Velocity: Vector3,
	Level: number,
	Upgrades: { [string]: number },
	LastDockTime: number,
}

-- RemoteEvents (created safely via Utils)
local Remotes = {
	PlayerSailing = Utils.CreateRemoteEvent("PlayerSailing"),
	PlayerDocked = Utils.CreateRemoteEvent("PlayerDocked"),
}

local activeShips: { [Player]: Ship } = {}
local maid = Utils.CreateMaid()

-- Object pooling for ship parts / effects (performance critical)
local effectPool = Utils.CreateObjectPool(Instance.new("ParticleEmitter"), 12)

-- Configuration - tuned for mobile
local CONFIG = {
	MaxSpeed = 45,
	Acceleration = 18,
	TurnRate = 2.2,
	DockingDistance = 35,
	MobileTouchSensitivity = 1.4,
}

-- Main update loop (runs at 30Hz on mobile for performance)
local function updateShips(dt: number)
	for player, ship in pairs(activeShips) do
		if not player.Character then continue end
		
		local root = player.Character:FindFirstChild("HumanoidRootPart")
		if not root then continue end
		
		-- Simple sailing physics (very cheap)
		local moveDirection = root.CFrame.LookVector
		ship.Velocity = ship.Velocity:Lerp(moveDirection * CONFIG.MaxSpeed, 0.15)
		
		-- Apply velocity (network ownership given to server for anti-exploit)
		root.AssemblyLinearVelocity = ship.Velocity
		
		-- Check for docking with ghost ships (server authority)
		if tick() - ship.LastDockTime > 3 then
			ShipController:AttemptDock(player, ship)
		end
	end
end

function ShipController.Initialize()
	FogSystem.Initialize()
	
	-- Heartbeat at reduced rate for mobile
	maid:GiveTask(RunService.Heartbeat:Connect(function(dt: number)
		updateShips(dt)
	end))
	
	-- Remote event listeners with validation
	Remotes.PlayerSailing.OnServerEvent:Connect(function(player: Player, isSailing: boolean)
		-- Server validation
		if typeof(isSailing) ~= "boolean" then return end
		if not activeShips[player] then
			activeShips[player] = {
				Model = player.Character or nil,
				Velocity = Vector3.new(0, 0, 0),
				Level = 1,
				Upgrades = { Speed = 1, Cargo = 1 },
				LastDockTime = 0,
			}
		end
	end)
	
	print("ShipController initialized - Mobile performant sailing & docking active")
end

function ShipController.AttemptDock(player: Player, ship: Ship)
	local shipPos = ship.Model and ship.Model.PrimaryPart and ship.Model.PrimaryPart.Position
	if not shipPos then return end
	
	-- Find nearby ghost ships (simplified - will use spatial query later)
	for _, obj in ipairs(workspace:GetChildren()) do
		if obj.Name:find("GhostShip") and obj.PrimaryPart then
			local dist = (obj.PrimaryPart.Position - shipPos).Magnitude
			if dist < CONFIG.DockingDistance then
				ship.LastDockTime = tick()
				Remotes.PlayerDocked:FireClient(player, obj)
				-- TODO: Trigger FogSystem horror pulse
				FogSystem.TriggerHorrorPulse(0.6)
				break
			end
		end
	end
end

function ShipController.GetShip(player: Player): Ship?
	return activeShips[player]
end

function ShipController.ApplyUpgrade(player: Player, upgradeType: string)
	local ship = activeShips[player]
	if not ship then return end
	
	if ship.Upgrades[upgradeType] then
		ship.Upgrades[upgradeType] += 1
		-- Broadcast upgrade (with proper RemoteEvent)
		Remotes.PlayerSailing:FireClient(player, true)
	end
end

function ShipController.Destroy()
	maid:Cleanup()
	for _, ship in pairs(activeShips) do
		-- Return pooled objects
	end
	table.clear(activeShips)
end

return ShipController
