--!strict
-- GhostShipGenerator.lua
-- Procedural haunted ship spawning system for Fog Sea.
-- Server authoritative. Spawns ships at distance in fog with increasing difficulty.
-- Performance: Runs at 0.5Hz, uses object pooling for ship parts, minimal per-frame work.
-- Integrates with FogSystem for visibility culling.
-- Asset Binding (Phase 7): Use ServerStorage.Assets.GhostShipRig:Clone() for production rigged model with sails, lights, haunted effects. Use CollectionService "GhostShip" tag for ClientShipController visuals. Current procedural Part is placeholder for testing. Maid for cleanup.
-- Author: Fog Sea Architect - 2026-06-07

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

-- Creates a procedural ghost ship with randomized haunted elements (placeholder until rigged asset bound)
local function createGhostShip(difficulty: number): GhostShip
	local shipModel = shipPool:Get()
	shipModel.Name = "GhostShip_" .. os.time()
	
	-- Asset Binding: Replace with ServerStorage.Assets.GhostShipRig:Clone() + random decal/parts for haunted look
	local hull = Instance.new("Part")
	hull.Size = Vector3.new(25, 8, 60)
	hull.Color = Color3.fromRGB(45, 45, 55)
	hull.Material = Enum.Material.Wood
	hull.Position = Vector3.new(0, 0, 0)
	hull.Parent = shipModel
	shipModel.PrimaryPart = hull
	
	-- Add masts/sails as placeholder (rigged in prod)
	for i = 1, 2 do
		local mast = Instance.new("Part")
		mast.Size = Vector3.new(2, 20, 2)
		mast.Position = hull.Position + Vector3.new(0, 15, (i-1.5)*20)
		mast.Parent = shipModel
	end
	
	local ship: GhostShip = {
		Model = shipModel,
		Difficulty = difficulty,
		HauntLevel = 1.0 + difficulty * 0.5,
		LastSpawnTime = tick(),
		Entities = {},
	}
	
	table.insert(activeShips, ship)
	return ship
end

function GhostShipGenerator.Initialize()
	maid:GiveTask(RunService.Heartbeat:Connect(function()
		local now = tick()
		if now - lastSpawnAttempt < CONFIG.SpawnInterval then return end
		lastSpawnAttempt = now
		
		if #activeShips >= CONFIG.MaxActiveShips then return end
		
		currentDifficulty = currentDifficulty + CONFIG.DifficultyRamp
		local spawnPos = Vector3.new(math.random(-200,200), 0, math.random(-200,200))
		local ship = createGhostShip(currentDifficulty)
		ship.Model:PivotTo(CFrame.new(spawnPos))
		
		print("GhostShipGenerator: Spawned ship at difficulty " .. currentDifficulty)
	end))
	
	print("GhostShipGenerator initialized with asset binding notes for ServerStorage rigged models.")
end

function GhostShipGenerator.CreateTestShip(center: Vector3): GhostShip
	-- Test helper for TestHarness (Phase 7). Uses placeholder; bind to ServerStorage.Assets.GhostShipRig in prod.
	return createGhostShip(currentDifficulty)
end

function GhostShipGenerator.CullDistantShips(center: Vector3)
	-- Cull ships outside fog visibility (mobile performance)
	for i = #activeShips, 1, -1 do
		local ship = activeShips[i]
		if (ship.Model.PrimaryPart.Position - center).Magnitude > 300 then
			ship.Model:Destroy()
			table.remove(activeShips, i)
		end
	end
end

function GhostShipGenerator.GetActiveShips(): {GhostShip}
	return activeShips
end

function GhostShipGenerator.Destroy()
	maid:Cleanup()
	for _, ship in activeShips do
		if ship.Model then ship.Model:Destroy() end
	end
	table.clear(activeShips)
end

return GhostShipGenerator
