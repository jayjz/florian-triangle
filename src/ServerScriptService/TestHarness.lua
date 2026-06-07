--!strict
-- TestHarness.lua (ServerScriptService)
-- Refactored & Hardened for reliable Studio testing.
-- Features: DRY spawning helpers, proper Maid cleanup, defensive guards, chat + _G command bar support.

local Utils = require(game.ReplicatedStorage.Modules.Utils)
local GhostShipGenerator = require(game.ReplicatedStorage.Modules.GhostShipGenerator)
local ExtractionManager = require(game.ReplicatedStorage.Modules.ExtractionManager)
local EntityAI = require(game.ReplicatedStorage.Modules.EntityAI)

local Players = Utils.GetService("Players")
local RunService = Utils.GetService("RunService")
local CollectionService = Utils.GetService("CollectionService")

local TestHarness = {}
TestHarness.__index = TestHarness

export type DebugCommand = "spawnTestShip" | "spawnEntities" | "spawnChests" | "setDifficulty" | "fullTestScenario"

local testMaid = Utils.CreateMaid()
local AdminDebugRemote = Utils.CreateRemoteEvent("AdminDebugCommand")
local currentDifficulty = 1

-- ============================================================
-- INTERNAL SPAWNING HELPERS (DRY + Defensive)
-- ============================================================

local function tag(model: Model?, tagName: string)
    if model then
        CollectionService:AddTag(model, tagName)
    end
end

local function spawnShip(pos: Vector3): Model?
    local shipData = GhostShipGenerator.CreateTestShip(pos)
    if not shipData or not shipData.Model then
        warn("[TestHarness] Failed to create test ship")
        return nil
    end

    tag(shipData.Model, "GhostShip")
    testMaid:GiveTask(shipData.Model) -- Track for cleanup
    return shipData.Model
end

local function spawnChest(shipModel: Model?)
    if not shipModel then return end

    local chestData = ExtractionManager.CreateTestChest(shipModel)
    if chestData and chestData.Model then
        tag(chestData.Model, "LootChest")
        testMaid:GiveTask(chestData.Model)
    end
end

local function spawnEnemy(pos: Vector3)
    local entity = EntityAI.SpawnTestEntity(pos)
    if not entity or not entity.Model then
        warn("[TestHarness] Failed to create test entity")
        return
    end

    tag(entity.Model, "CorruptedPirate")
    if entity.Root then
        entity.Root:SetNetworkOwner(nil)
    end
    testMaid:GiveTask(entity.Model)
end

-- ============================================================
-- ADMIN & COMMAND HANDLING
-- ============================================================

local function isAdmin(player: Player): boolean
    return RunService:IsStudio() or player.UserId == 0
end

local function executeDebugCommand(player: Player, command: DebugCommand, param: number?)
    if not isAdmin(player) then return end

    local center = Vector3.new(0, 50, 0)
    local char = player.Character
    if char and char:FindFirstChild("HumanoidRootPart") then
        center = (char.HumanoidRootPart :: Part).Position + Vector3.new(0, 30, 50)
    end

    if command == "fullTestScenario" then
        local shipModel = spawnShip(center)
        if shipModel then
            for _ = 1, 3 do
                spawnChest(shipModel)
            end
            for i = 1, 2 do
                spawnEnemy(center + Vector3.new(i * 12, 0, 0))
            end
        end
        currentDifficulty = param or 2
        print(`[TestHarness] Full scenario spawned at difficulty {currentDifficulty}`)

    elseif command == "spawnTestShip" then
        local shipModel = spawnShip(center)
        if shipModel then
            for _ = 1, 3 do
                spawnChest(shipModel)
            end
        end
        print("[TestHarness] Test ship + chests spawned")

    elseif command == "spawnEntities" then
        local count = math.clamp(param or 3, 1, 8)
        for i = 1, count do
            spawnEnemy(center + Vector3.new(i * 8, 0, 0))
        end
        print(`[TestHarness] Spawned {count} test entities`)

    elseif command == "spawnChests" then
        local count = math.clamp(param or 3, 1, 6)
        local shipModel = spawnShip(center)
        if shipModel then
            for _ = 1, count do
                spawnChest(shipModel)
            end
        end
        print(`[TestHarness] Spawned {count} chests on test ship`)

    elseif command == "setDifficulty" then
        currentDifficulty = math.clamp(param or 1, 1, 5)
        print(`[TestHarness] Difficulty set to {currentDifficulty}`)
    end
end

-- ============================================================
-- INITIALIZATION
-- ============================================================

function TestHarness.Initialize()
    AdminDebugRemote.OnServerEvent:Connect(function(player: Player, command: DebugCommand, param: number?)
        executeDebugCommand(player, command, param)
    end)

    Players.PlayerAdded:Connect(function(player: Player)
        if isAdmin(player) then
            player.Chatted:Connect(function(msg: string)
                local lower = msg:lower()
                if lower:find("/debug") then
                    if lower:find("full") then
                        executeDebugCommand(player, "fullTestScenario", 3)
                    elseif lower:find("ship") then
                        executeDebugCommand(player, "spawnTestShip")
                    end
                end
            end)
        end
    end)

    print("[TestHarness] Initialized. Use /debug full or _G.ForceTestScenario() in Command Bar.")
end

function TestHarness.Destroy()
    testMaid:Cleanup()
end

-- ============================================================
-- GLOBAL COMMAND BAR HOOK
-- ============================================================

_G.ForceTestScenario = function(playerId: number?)
    local target = playerId and Players:GetPlayerByUserId(playerId) or Players:GetPlayers()[1]
    if target then
        print(`[TestHarness] Forcing fullTestScenario via Command Bar for {target.Name}`)
        executeDebugCommand(target, "fullTestScenario", 3)
    else
        warn("[TestHarness] No players available to run test scenario.")
    end
end

return TestHarness