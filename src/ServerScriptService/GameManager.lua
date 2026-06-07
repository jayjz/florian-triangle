--!strict
-- GameManager.lua (ServerScriptService)
-- Central server orchestrator for Fog Sea (Florian Triangle).
-- Production version with horror integration and extraction zone coordination.
-- This is the single source of truth for game state.

local Utils = require(script.Parent.Parent.ReplicatedStorage.Modules.Utils)
local ShipController = require(script.Parent.Parent.ReplicatedStorage.Modules.ShipController)
local GhostShipGenerator = require(script.Parent.Parent.ReplicatedStorage.Modules.GhostShipGenerator)
local EntityAI = require(script.Parent.Parent.ReplicatedStorage.Modules.EntityAI)
local HorrorEvents = require(script.Parent.Parent.ReplicatedStorage.Modules.HorrorEvents)
local ExtractionManager = require(script.Parent.Parent.ReplicatedStorage.Modules.ExtractionManager)
local TestHarness = require(script.Parent.TestHarness)

local Players = Utils.GetService("Players")
local RunService = Utils.GetService("RunService")

local GameManager = {}
GameManager.__index = GameManager

local maid = Utils.CreateMaid()
local playerPositions: {[Player]: Vector3} = {}
local lastUpdate = 0
local UPDATE_RATE = 0.2 -- 5Hz

-- Extraction Zone Settings (can be moved to a config later)
local EXTRACTION_ZONE_POSITION = Vector3.new(0, 8, 0)
local EXTRACTION_ZONE_RADIUS = 28

-- ============================================================
-- PLAYER MANAGEMENT
-- ============================================================

local function onPlayerAdded(player: Player)
    player.CharacterAdded:Connect(function(character)
        task.wait(1.5)
        if typeof(ShipController.InitializeForPlayer) == "function" then
            ShipController.InitializeForPlayer(player)
        end
    end)
    print(`[GameManager] Player {player.Name} joined`)
end

local function onPlayerRemoving(player: Player)
    playerPositions[player] = nil
end

-- ============================================================
-- INITIALIZATION
-- ============================================================

function GameManager.Initialize()
    print("=== [GameManager] Initializing all systems ===")

    local systems = {
        { name = "ShipController",      sys = ShipController },
        { name = "GhostShipGenerator",  sys = GhostShipGenerator },
        { name = "HorrorEvents",        sys = HorrorEvents },
        { name = "ExtractionManager",   sys = ExtractionManager },
        { name = "TestHarness",         sys = TestHarness },
        { name = "EntityAI",            sys = EntityAI },
    }

    for _, data in ipairs(systems) do
        if typeof(data.sys) == "table" and typeof(data.sys.Initialize) == "function" then
            local success, err = pcall(data.sys.Initialize)
            if not success then
                warn(`[GameManager] Failed to initialize {data.name}: {err}`)
            end
        else
            warn(`[GameManager] {data.name} is missing Initialize() method.`)
        end
    end

    Players.PlayerAdded:Connect(onPlayerAdded)
    Players.PlayerRemoving:Connect(onPlayerRemoving)

    for _, player in Players:GetPlayers() do
        onPlayerAdded(player)
    end

    -- ============================================================
    -- MAIN GAME LOOP (5Hz)
    -- ============================================================

    maid:GiveTask(RunService.Heartbeat:Connect(function(dt: number)
        local now = tick()
        if now - lastUpdate < UPDATE_RATE then return end
        lastUpdate = now

        -- Update player positions
        for _, player in Players:GetPlayers() do
            local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: Part?
            if root then
                playerPositions[player] = root.Position
            end
        end

        -- Core Systems
        if typeof(EntityAI.UpdateAll) == "function" then
            EntityAI.UpdateAll(playerPositions, dt)
        end

        if typeof(GhostShipGenerator.CullDistantShips) == "function" then
            GhostShipGenerator.CullDistantShips(Vector3.new(0, 50, 0))
        end

        -- Horror → Fog Integration
        if typeof(HorrorEvents.GetHorrorLevel) == "function" then
            local horrorLevel = HorrorEvents.GetHorrorLevel()
            if typeof(FogSystem) == "table" and typeof(FogSystem.SetHorrorLevel) == "function" then
                FogSystem.SetHorrorLevel(horrorLevel)
            end
        end

        -- Extraction Zone Check (Win Condition)
        if typeof(ExtractionManager.ExtractAtZone) == "function" then
            for _, player in Players:GetPlayers() do
                ExtractionManager.ExtractAtZone(player, EXTRACTION_ZONE_POSITION, EXTRACTION_ZONE_RADIUS)
            end
        end
    end))

    print("=== [GameManager] Fully initialized (Production) ===")
end

-- ============================================================
-- CLEANUP
-- ============================================================

function GameManager.Destroy()
    maid:Cleanup()

    if typeof(EntityAI.Destroy) == "function" then EntityAI.Destroy() end
    if typeof(HorrorEvents.Destroy) == "function" then HorrorEvents.Destroy() end
    if typeof(GhostShipGenerator.Destroy) == "function" then GhostShipGenerator.Destroy() end
    if typeof(ExtractionManager.Destroy) == "function" then ExtractionManager.Destroy() end
    if typeof(TestHarness.Destroy) == "function" then TestHarness.Destroy() end
end

return GameManager