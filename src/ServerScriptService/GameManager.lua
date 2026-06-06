--!strict
-- GameManager.lua
-- Central server orchestrator for Fog Sea (Florian Triangle).
-- Ties together ShipController, GhostShipGenerator, EntityAI, HorrorEvents, ExtractionManager, TestHarness.
-- Handles player loading, main game loop at 5Hz, entity spawning, extraction loop coordination.
-- All critical state server-authoritative. Uses RemoteEvents ONLY for client visuals/UI sync.
-- Performance: 5Hz main loop, culling, pooling. Explicit SetNetworkOwner(nil) on all AI.
-- This is the single source of truth for game state.
-- Asset readiness notes (Phase 6): TODO - Bind ServerStorage.Assets.GhostShipRig, AI rigs, chest models with animations.

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
        if type(ShipController.InitializeForPlayer) == "function" then
            ShipController.InitializeForPlayer(player)
        end
    end)
    print(`Player {player.Name} joined Fog Sea - ship, AI, extraction systems ready`)
end

local function onPlayerRemoving(player: Player)
    playerPositions[player] = nil
end

function GameManager.Initialize()
    -- Safely initialize ALL systems in correct dependency order (Bulletproof logic)
    local systems = {
        {name = "ShipController", sys = ShipController},
        {name = "GhostShipGenerator", sys = GhostShipGenerator},
        {name = "EntityAI", sys = EntityAI},
        {name = "HorrorEvents", sys = HorrorEvents},
        {name = "ExtractionManager", sys = ExtractionManager},
        {name = "TestHarness", sys = TestHarness}
    }

    for _, data in ipairs(systems) do
        if type(data.sys) == "table" and type(data.sys.Initialize) == "function" then
            data.sys.Initialize()
        else
            warn(`[GameManager] {data.name} is missing an Initialize() method. Skipping.`)
        end
    end
    
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
        
        -- Delegate updates to subsystems safely
        if type(EntityAI.UpdateAll) == "function" then
            EntityAI.UpdateAll(playerPositions, dt)
        end
        
        if type(GhostShipGenerator.CullDistantShips) == "function" then
            GhostShipGenerator.CullDistantShips(Vector3.new(0, 0, 0)) -- Replace with dynamic center in prod
        end
    end))
    
    print("=== GameManager fully initialized (Bulletproofed) ===")
end

function GameManager.Destroy()
    maid:Cleanup()
    if type(EntityAI.Destroy) == "function" then EntityAI.Destroy() end
    if type(HorrorEvents.Destroy) == "function" then HorrorEvents.Destroy() end
    if type(GhostShipGenerator.Destroy) == "function" then GhostShipGenerator.Destroy() end
    if type(ExtractionManager.Destroy) == "function" then ExtractionManager.Destroy() end
    if type(TestHarness.Destroy) == "function" then TestHarness.Destroy() end
end

-- NOTE: Removed the auto-start `GameManager.Initialize()` from the bottom. 
-- ServerMain.server.lua is now the sole bootstrapper, preventing double-initialization.

return GameManager