--!strict
-- ExtractionManager.lua (ReplicatedStorage/Modules)
-- Production loot + weight + quota system for Fog Sea.

local Utils = require(script.Parent.Utils)
local GhostShipGenerator = require(script.Parent.GhostShipGenerator)
local ServerStorage = Utils.GetService("ServerStorage")
local CollectionService = Utils.GetService("CollectionService")
local RunService = Utils.GetService("RunService")
local Players = Utils.GetService("Players")

local ExtractionManager = {}
ExtractionManager.__index = ExtractionManager

export type LootChest = {
    Model: Model,
    Weight: number,
    Value: number,
    Ship: any,
    Prompt: ProximityPrompt?,
    Maid: any,
}

local activeChests: { [Model]: LootChest } = {}
local playerWeight: { [Player]: number } = {}
local globalMaid = Utils.CreateMaid()

local WeightUpdateRemote = Utils.CreateRemoteEvent("WeightUpdated")
local PickupEffectRemote = Utils.CreateRemoteEvent("PickupEffect")
local ExtractionSuccessRemote = Utils.CreateRemoteEvent("ExtractionSuccess")

local CONFIG = {
    MaxChestsPerShip = 4,
    BaseWeight = 15,
    MaxCarryWeight = 80,
    SpeedPenaltyMultiplier = 0.65,
    JumpPenaltyMultiplier = 0.7,
}

local chestPool: {Model} = {}
local chestTemplate: Model? = nil

-- ==================== CHEST CREATION ====================

local function getChestTemplate(): Model?
    if not chestTemplate then
        local assets = ServerStorage:FindFirstChild("Assets")
        chestTemplate = assets and assets:FindFirstChild("LootChestRig")
    end
    return chestTemplate
end

local function createChestModel(): Model
    if #chestPool > 0 then
        local model = table.remove(chestPool) :: Model
        model.Parent = workspace
        return model
    end

    local template = getChestTemplate()
    if template then
        return template:Clone()
    end

    -- Fallback placeholder (should rarely be used)
    local model = Instance.new("Model")
    model.Name = "LootChest"
    local part = Instance.new("Part")
    part.Name = "Root"
    part.Size = Vector3.new(4, 3, 6)
    part.Color = Color3.fromRGB(139, 69, 19)
    part.Material = Enum.Material.Wood
    part.Parent = model
    model.PrimaryPart = part
    return model
end

local function returnToPool(model: Model)
    if model then
        model.Parent = nil
        table.insert(chestPool, model)
    end
end

local function createLootChest(ship: any): LootChest?
    local shipModel = ship.Model
    if not shipModel or not shipModel.PrimaryPart then return nil end

    local chestModel = createChestModel()
    local root = chestModel.PrimaryPart :: Part

    local offset = Vector3.new(math.random(-12, 12), 3, math.random(-12, 12))
    root.Position = shipModel.PrimaryPart.Position + offset
    root.Orientation = Vector3.new(0, math.random(0, 360), 0)

    local prompt = Instance.new("ProximityPrompt")
    prompt.ActionText = "Pick Up Loot"
    prompt.ObjectText = "Treasure Chest"
    prompt.MaxActivationDistance = 12
    prompt.RequiresLineOfSight = true
    prompt.Parent = root

    local chestMaid = Utils.CreateMaid()
    local chest: LootChest = {
        Model = chestModel,
        Weight = CONFIG.BaseWeight + math.random(10, 40),
        Value = math.random(120, 450),
        Ship = ship,
        Prompt = prompt,
        Maid = chestMaid,
    }

    activeChests[chestModel] = chest

    chestMaid:GiveTask(prompt.Triggered:Connect(function(player: Player)
        ExtractionManager.HandlePickup(player, chestModel)
    end))

    CollectionService:AddTag(chestModel, "LootChest")
    return chest
end

-- ==================== PICKUP & EXTRACTION ====================

function ExtractionManager.HandlePickup(player: Player, chestModel: Model)
    local chest = activeChests[chestModel]
    if not chest then return end

    local currentWeight = playerWeight[player] or 0
    if currentWeight + chest.Weight > CONFIG.MaxCarryWeight then
        PickupEffectRemote:FireClient(player, "OverEncumbered")
        return
    end

    local char = player.Character
    local root = char and char:FindFirstChild("HumanoidRootPart") :: Part?
    if not root or (root.Position - chest.Model.PrimaryPart.Position).Magnitude > 15 then
        return
    end

    playerWeight[player] = currentWeight + chest.Weight
    WeightUpdateRemote:FireClient(player, playerWeight[player], chest.Value)
    PickupEffectRemote:FireClient(player, "Success", chest.Value)

    ExtractionManager.ApplyPenalties(player)

    if chest.Maid then chest.Maid:Cleanup() end
    returnToPool(chest.Model)
    activeChests[chestModel] = nil
end

function ExtractionManager.ExtractAtZone(player: Player, zonePosition: Vector3, radius: number): boolean
    local char = player.Character
    local root = char and char:FindFirstChild("HumanoidRootPart") :: Part?
    if not root then return false end

    if (root.Position - zonePosition).Magnitude > radius then return false end

    local carried = playerWeight[player] or 0
    if carried <= 0 then return false end

    if _G.RoundManager and typeof(_G.RoundManager.AddExtracted) == "function" then
        _G.RoundManager.AddExtracted(carried)
    end

    playerWeight[player] = 0
    ExtractionSuccessRemote:FireClient(player, carried)
    ExtractionManager.ApplyPenalties(player)

    print(`[Extraction] {player.Name} successfully extracted {carried} loot!`)
    return true
end

function ExtractionManager.ApplyPenalties(player: Player)
    local char = player.Character
    if not char then return end
    local hum = char:FindFirstChildOfClass("Humanoid")
    if not hum then return end

    local w = playerWeight[player] or 0
    local ratio = math.min(w / CONFIG.MaxCarryWeight, 1)

    hum.WalkSpeed = 16 * (1 - ratio * CONFIG.SpeedPenaltyMultiplier)
    hum.JumpPower = 50 * (1 - ratio * CONFIG.JumpPenaltyMultiplier)
end

-- ==================== LIFECYCLE ====================

function ExtractionManager.Initialize()
    globalMaid:GiveTask(RunService.Heartbeat:Connect(function()
        local ships = GhostShipGenerator.GetActiveShips()
        for _, ship in ships do
            local count = 0
            for _, c in activeChests do if c.Ship == ship then count += 1 end end
            if count < CONFIG.MaxChestsPerShip and math.random() < 0.035 then
                createLootChest(ship)
            end
        end
    end))

    globalMaid:GiveTask(Players.PlayerRemoving:Connect(function(p)
        playerWeight[p] = nil
    end))

    print("[ExtractionManager] Initialized with real LootChestRig + quota support")
end

function ExtractionManager.Destroy()
    globalMaid:Cleanup()
    for _, c in activeChests do
        if c.Maid then c.Maid:Cleanup() end
        if c.Model then c.Model:Destroy() end
    end
    table.clear(activeChests)
    table.clear(playerWeight)
    table.clear(chestPool)
end

function ExtractionManager.CreateTestChest(ship: any)
    return createLootChest(ship)
end

return ExtractionManager