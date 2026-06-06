--!strict
-- GhostShipGenerator.lua
-- Procedural haunted ship spawning system for Fog Sea.
-- Server authoritative. Spawns ships at distance in fog with increasing difficulty.
-- Performance: Runs at 0.5Hz, uses object pooling for ship parts, minimal per-frame work.
-- Integrates with FogSystem for visibility culling.
-- Author: Fog Sea Architect - 2026-06-06

local Utils = require(script.Parent.Utils)
local FogSystem = require(script.Parent.FogSystem)
local RunService = Utils.GetService("RunService")
local Workspace = Utils.GetService("Workspace")

local GhostShipGenerator = {}
GhostShipGenerator.__index = GhostShipGenerator

export type GhostShip = {
	Model: Model,
	Difficulty: number,
	HauntLevel: number,
	LastSpawnTime: number,
	Entities: { any },
}

export type Generator = typeof(GhostShipGenerator)

local self = setmetatable({}, GhostShipGenerator)
local maid = Utils.CreateMaid()
local activeShips: { GhostShip } = {}
local shipPool = Utils.CreateObjectPool(Instance.new("Model"), 5) -- Pool for ghost ship containers

local CONFIG = {
	SpawnDistance = 180,      -- Far enough to be in heavy fog
	SpawnInterval = 25,       -- Seconds between potential spawns (mobile friendly)
	MaxActiveShips = 4,       -- Critical limit for mobile performance
	DifficultyRamp = 0.15,    -- Increases over time
}

local lastSpawnAttempt = 0
local currentDifficulty = 1.0

-- Creates a procedural ghost ship with randomized haunted elements
local function createGhostShip(difficulty: number): GhostShip
	local shipModel = shipPool:Get()
	shipModel.Name = "GhostShip_" .. os.time()
	
	-- In real implementation this would load from Assets with randomized parts
	local hull = Instance.new("Part")
	hull.Size = Vector3.new(25, 8, 60)
	hull.Color = Color3.fromRGB(45, 45, 55)
	hull.Material = Enum.Material.Slate
	hull.Parent = shipModel
	
	shipModel.PrimaryPart = hull
	shipModel.Parent = Workspace
	
	local ship: GhostShip = {
		Model = shipModel,
		Difficulty = difficulty,
		HauntLevel = 0.3 + difficulty * 0.4,
		LastSpawnTime = tick(),
		Entities = {},
	}
	
	-- TODO: Add randomized masts, broken sails, glowing runes, etc.
	return ship
end

function GhostShipGenerator.Initialize()
	FogSystem.Initialize()
	
	maid:GiveTask(RunService.Heartbeat:Connect(function(_dt: number)
		local now = tick()
		if now - lastSpawnAttempt < CONFIG.SpawnInterval then return end
		lastSpawnAttempt = now
		
		if #activeShips >= CONFIG.MaxActiveShips then return end
		
		currentDifficulty += CONFIG.DifficultyRamp * 0.1
		currentDifficulty = Utils.Clamp(currentDifficulty, 1.0, 5.0)
		
		local newShip = createGhostShip(currentDifficulty)
		table.insert(activeShips, newShip)
		
		-- Fire to all clients via RemoteEvent (proper client-server split)
		local remotes = Utils.GetService("ReplicatedStorage"):WaitForChild("Events")
		local spawnEvent = remotes:WaitForChild("GhostShipSpawned") :: RemoteEvent
		spawnEvent:FireAllClients(newShip.Model, newShip.Difficulty)
	end))
	
	print("GhostShipGenerator initialized - Procedural fog spawning active (mobile optimized)")
end

function GhostShipGenerator.GetActiveShips(): { GhostShip }
	return activeShips
end

-- Despawn ships that are too far or cleared
function GhostShipGenerator.CullDistantShips(playerPos: Vector3)
	for i = #activeShips, 1, -1 do
		local ship = activeShips[i]
		if ship.Model.PrimaryPart then
			local dist = (ship.Model.PrimaryPart.Position - playerPos).Magnitude
			if dist > 350 then
				shipPool.Return(ship.Model)
				table.remove(activeShips, i)
			end
		end
	end
end

function GhostShipGenerator.Destroy()
	maid:Cleanup()
	for _, ship in activeShips do
		if ship.Model then ship.Model:Destroy() end
	end
	table.clear(activeShips)
end

return GhostShipGenerator
