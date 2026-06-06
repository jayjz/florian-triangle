--!strict
-- GameManager.lua
-- Central server orchestrator for Fog Sea (Florian Triangle).
-- Ties together ShipController, GhostShipGenerator, EntityAI, HorrorEvents, ExtractionManager, TestHarness.
-- Handles player loading, main game loop at 5Hz, entity spawning, extraction loop coordination.
-- All critical state server-authoritative. Uses RemoteEvents ONLY for client visuals/UI sync.
-- Performance: 5Hz main loop, culling, pooling. Explicit SetNetworkOwner(nil) on all AI (from Phase 4).
-- This is the single source of truth for game state.
-- Asset readiness notes (Phase 6): TODO - Bind ServerStorage.Assets.GhostShipRig, AI rigs, chest models with animations. Use tags for client-side visual controllers. Update spawning in subsystems to use rigged versions.
-- Author: Fog Sea Architect - 2026-06-07

local Utils = require(script.Parent.Parent.ReplicatedStorage.Modules.Utils)
local ShipController = require(script.Parent.Parent.ReplicatedStorage.Modules.ShipController)
local GhostShipGenerator = require(script.Parent.Parent.ReplicatedStorage.Modules.GhostShipGenerator)
local EntityAI = require(script.Parent.Parent.ReplicatedStorage.Modules.EntityAI)
local HorrorEvents = require(script.Parent.Parent.ReplicatedStorage.Modules.HorrorEvents)
local ExtractionManager = require(script.Parent.Parent.ReplicatedStorage.Modules.ExtractionManager)
local TestHarness = require(script.Parent.TestHarness) -- Phase 6 testing harness
local Players = Utils.GetService("Players")
local RunService = Utils.GetService("RunService")

local GameManager = {}
GameManager.__index = GameManager

local maid = Utils.CreateMaid()
local playerPositions: {[Player]: Vector3} = {}
local lastUpdate = 0
local UPDATE_RATE = 0.2 -- 5Hz - optimal balance for mobile server performance and responsiveness

local function onPlayerAdded(player: Player)
	player.CharacterAdded:Connect(function(character)
		task.wait(1.5) -- Allow full loading before applying systems
		ShipController.InitializeForPlayer(player)
		-- Extraction penalties will be applied on first pickup
	end)
	
	print(`Player {player.Name} joined Fog Sea - ship, AI, extraction systems ready`)
end

local function onPlayerRemoving(player: Player)
	playerPositions[player] = nil
end

function GameManager.Initialize()
	-- Initialize ALL systems in correct dependency order
	ShipController.Initialize()
	GhostShipGenerator.Initialize()
	EntityAI.Initialize()
	HorrorEvents.Initialize()
	ExtractionManager.Initialize()  -- Loot + weight system integrated into core loop
	TestHarness.Initialize() -- Phase 6: Testing harness for rapid verification
	
	-- Player management
	Players.PlayerAdded:Connect(onPlayerAdded)
	Players.PlayerRemoving:Connect(onPlayerRemoving)
	
	for _, player in Players:GetPlayers() do
		onPlayerAdded(player)
	end
	
	-- Main throttled server game loop (critical for mobile replication performance)
	maid:GiveTask(RunService.Heartbeat:Connect(function(dt: number)
		local now = tick()
		if now - lastUpdate < UPDATE_RATE then return end
		lastUpdate = now
		
		-- Update player positions for AI targeting (culling done in subsystems)
		for _, player in Players:GetPlayers() do
			local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: Part?
			if root then
				playerPositions[player] = root.Position
			end
		end
		
		-- Delegate updates to subsystems (keeps this loop lightweight)
		EntityAI.UpdateAll(playerPositions, dt)
		GhostShipGenerator.CullDistantShips(Vector3.new(0, 0, 0)) -- Replace with dynamic center in prod
		-- ExtractionManager has its own internal spawn loop at 3Hz for chests
		
		-- Horror pressure increases with carried weight (synergy example)
		-- Full implementation would query ExtractionManager.GetPlayerWeight()
	end))
	
	print("=== GameManager fully initialized with Extraction Loop + TestHarness (Phase 6) ===")
end

function GameManager.Destroy()
	maid:Cleanup()
	EntityAI.Destroy()
	HorrorEvents.Destroy()
	GhostShipGenerator.Destroy()
	ExtractionManager.Destroy()
	TestHarness.Destroy()
end

-- Auto start
GameManager.Initialize()

return GameManager
