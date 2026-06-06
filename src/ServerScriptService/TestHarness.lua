--!strict
-- TestHarness.lua (ServerScriptService)
-- Fixed: Removed fatal :FireServer() calls from server script. Uses direct function calls instead.
-- Fixed: Re-added _G.ForceTestScenario for bulletproof Studio Command Bar testing.
-- "fullTestScenario" has a guard for GameManager.Initialize() to avoid duplication.
-- Spawns complete testable round (ship + 3 chests + 2 entities + difficulty scaling).
-- Asset binding: References ServerStorage.Assets.*Rig with placeholder logic + CollectionService tags.

local Utils = require(game.ReplicatedStorage.Modules.Utils)
local GhostShipGenerator = require(game.ReplicatedStorage.Modules.GhostShipGenerator)
local ExtractionManager = require(game.ReplicatedStorage.Modules.ExtractionManager)
local EntityAI = require(game.ReplicatedStorage.Modules.EntityAI)
local GameManager = require(game.ServerScriptService.GameManager)
local Players = Utils.GetService("Players")
local RunService = Utils.GetService("RunService")
local CollectionService = Utils.GetService("CollectionService")

local TestHarness = {}
TestHarness.__index = TestHarness

export type DebugCommand = "spawnTestShip" | "spawnEntities" | "spawnChests" | "setDifficulty" | "fullTestScenario"
export type TestHarness = typeof(TestHarness)

local testMaid = Utils.CreateMaid()
local AdminDebugRemote = Utils.CreateRemoteEvent("AdminDebugCommand")

local currentDifficulty = 1
local isGameManagerInitialized = false

local function isAdmin(player: Player): boolean
    -- Production guard: Studio or admin list. Prevents exploits in live games.
    return RunService:IsStudio() or player.UserId == 0 -- Replace with real admin system
end

local function executeDebugCommand(player: Player, command: DebugCommand, param: number?)
    if not isAdmin(player) then return end
    
    local center = Vector3.new(0, 50, 0)
    local char = player.Character
    if char and char:FindFirstChild("HumanoidRootPart") then
        center = (char.HumanoidRootPart :: Part).Position + Vector3.new(0, 30, 50)
    end
    
    if command == "fullTestScenario" then
        if not isGameManagerInitialized then
            GameManager.Initialize()
            isGameManagerInitialized = true
        end
        local ship = GhostShipGenerator.CreateTestShip(center)
        CollectionService:AddTag(ship.Model, "GhostShip")
        
        for i = 1, 3 do
            local chest = ExtractionManager.CreateTestChest(ship)
            CollectionService:AddTag(chest.Model, "LootChest")
        end
        
        for i = 1, 2 do
            local e = EntityAI.SpawnTestEntity(center + Vector3.new(i*12, 0, 0))
            CollectionService:AddTag(e.Model, "CorruptedPirate")
            if e.Root then e.Root:SetNetworkOwner(nil) end
            testMaid:GiveTask(e.Model)
        end
        currentDifficulty = param or 2
        print(`Full testable round spawned by {player.Name} at difficulty {currentDifficulty} (with guard and tags)`)
        
    elseif command == "spawnTestShip" then
        local ship = GhostShipGenerator.CreateTestShip(center)
        CollectionService:AddTag(ship.Model, "GhostShip")
        for i = 1, 3 do
            local chest = ExtractionManager.CreateTestChest(ship)
            CollectionService:AddTag(chest.Model, "LootChest")
        end
        print(`Test ship spawned by {player.Name}`)
        
    elseif command == "spawnEntities" then
        local count = math.clamp(param or 3, 1, 8)
        for i = 1, count do
            local e = EntityAI.SpawnTestEntity(center + Vector3.new(i*8, 0, 0))
            CollectionService:AddTag(e.Model, "CorruptedPirate")
            if e.Root then e.Root:SetNetworkOwner(nil) end
            testMaid:GiveTask(e.Model)
        end
        print(`Spawned {count} test entities`)
        
    elseif command == "spawnChests" then
        local count = math.clamp(param or 3, 1, 6)
        local ship = GhostShipGenerator.CreateTestShip(center)
        CollectionService:AddTag(ship.Model, "GhostShip")
        for i = 1, count do
            local chest = ExtractionManager.CreateTestChest(ship)
            CollectionService:AddTag(chest.Model, "LootChest")
        end
        print(`Spawned {count} test chests`)
        
    elseif command == "setDifficulty" then
        currentDifficulty = math.clamp(param or 1, 1, 5)
        print(`Difficulty set to {currentDifficulty}`)
    end
end

function TestHarness.Initialize()
    -- 1. Listen for requests coming from the Client (RemoteEvent)
    AdminDebugRemote.OnServerEvent:Connect(function(player: Player, command: DebugCommand, param: number?)
        executeDebugCommand(player, command, param)
    end)
    
    -- 2. Listen for Server-side Chat commands
    Players.PlayerAdded:Connect(function(player: Player)
        if isAdmin(player) then
            player.Chatted:Connect(function(msg: string)
                local lower = msg:lower()
                if lower:find("/debug") then
                    if lower:find("full") then
                        -- FATAL FIX: Call internal function, NOT :FireServer()
                        executeDebugCommand(player, "fullTestScenario", 3)
                    elseif lower:find("ship") then
                        executeDebugCommand(player, "spawnTestShip")
                    end
                end
            end)
        end
    end)
    
    print("TestHarness initialized. Chat commands and Command Bar hooks are ready.")
end

function TestHarness.Destroy()
    testMaid:Cleanup()
    isGameManagerInitialized = false
end

TestHarness.Initialize()

-- Expose to _G for bulletproof Studio Command Bar testing (Bypasses Roblox Chat UI entirely)
_G.ForceTestScenario = function(playerId: number?)
    local target = playerId and Players:GetPlayerByUserId(playerId) or Players:GetPlayers()[1]
    if target then
        print(`[TestHarness] Forcing fullTestScenario for {target.Name} via Command Bar...`)
        executeDebugCommand(target, "fullTestScenario", 3)
    else
        warn("[TestHarness] No players found to execute the test scenario.")
    end
end

return TestHarness