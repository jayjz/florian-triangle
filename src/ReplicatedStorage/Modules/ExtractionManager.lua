--!strict
-- ExtractionManager.lua (ReplicatedStorage/Modules)
-- Production extraction + weight + quota system for Fog Sea.
-- One Piece themed: Players must bring loot to the Cursed Beacon to pay the toll and escape the Florian Triangle.
-- Fixed: No _G. Uses required RoundManager directly. Function is ExtractAtZone (API match). Surgical fix per Priority 0. Conflict resolved by clean rewrite.

local Utils = require(script.Parent.Utils)
local GhostShipGenerator = require(script.Parent.GhostShipGenerator)
local CollectionService = Utils.GetService("CollectionService")
local RunService = Utils.GetService("RunService")
local Players = Utils.GetService("Players")
local RoundManager = require(game.ServerScriptService.RoundManager)

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
    UpdateRate = 0.33,
    MaxCarryWeight = 80,
    SpeedPenaltyMultiplier = 0.65,
    JumpPenaltyMultiplier = 0.7,
}

local chestPool: {Model} = {}
local chestTemplate: Model?

local function createChestModel(): Model
    if #chestPool > 0 then
        local model = table.remove(chestPool) :: Model
        model.Parent = workspace
        return model
    end

    if not chestTemplate then
        chestTemplate = Instance.new("Model")
        chestTemplate.Name = "LootChest"
        local part = Instance.new("Part")
        part.Name = "Root"
        part.Size = Vector3.new(4, 3, 6)
        part.Color = Color3.fromRGB(139, 69, 19)
        part.Material = Enum.Material.Wood
        part.Anchored = false
        part.CanCollide = true
        part.Parent = chestTemplate
        chestTemplate.PrimaryPart = part
    end

    local newModel = chestTemplate:Clone()
    CollectionService:AddTag(newModel, "LootChest")
    newModel.Parent = workspace
    return newModel
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

    return chest
end

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

    local dist = (root.Position - zonePosition).Magnitude
    if dist > radius then return false end

    local carried = playerWeight[player] or 0
    if carried <= 0 then return false end

    -- Bank the loot toward quota (fixed: direct call, no _G.RoundManager)
    RoundManager.AddExtracted(carried)

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

function ExtractionManager.GetPlayerWeight(player: Player): number
    return playerWeight[player] or 0
end

function ExtractionManager.Initialize()
    globalMaid:GiveTask(RunService.Heartbeat:Connect(function()
        local ships = GhostShipGenerator.GetActiveShips()
        for _, ship in ships do
            local count = 0
            for _, c in activeChests do
                if c.Ship == ship then count += 1 end
            end
            if count < CONFIG.MaxChestsPerShip and math.random() < 0.035 then
                createLootChest(ship)
            end
        end
    end))

    globalMaid:GiveTask(Players.PlayerRemoving:Connect(function(p)
        playerWeight[p] = nil
    end))

    print("[ExtractionManager] Initialized with quota-integrated extraction (API fixed, no _G)")
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
