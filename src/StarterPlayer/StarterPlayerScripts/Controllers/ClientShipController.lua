--!strict
-- ClientShipController.lua (StarterPlayerScripts/Controllers)
-- Consumes CollectionService tags for GhostShip and LootChest.
-- Client-only visuals (Highlights for verification and atmosphere).
-- Debounced to prevent spam. Pure visuals — no server logic.

local CollectionService = game:GetService("CollectionService")
local Utils = require(game.ReplicatedStorage.Modules.Utils)

local ClientShipController = {}
local maid = Utils.CreateMaid()

-- Debounce to prevent spam on rapid tag additions
local lastDetection: {[Model]: number} = {}

local function createHighlight(model: Model, fillColor: Color3, outlineColor: Color3)
    local highlight = Instance.new("Highlight")
    highlight.Name = "ClientHighlight"
    highlight.FillColor = fillColor
    highlight.OutlineColor = outlineColor
    highlight.FillTransparency = 0.65
    highlight.OutlineTransparency = 0.15
    highlight.Adornee = model
    highlight.Parent = model

    maid:GiveTask(highlight)
    return highlight
end

local function onGhostShipAdded(ship: Model)
    if lastDetection[ship] and tick() - lastDetection[ship] < 1.8 then
        return
    end
    lastDetection[ship] = tick()

    createHighlight(ship, Color3.fromRGB(255, 90, 40), Color3.fromRGB(255, 180, 80))
end

local function onLootChestAdded(chest: Model)
    if lastDetection[chest] and tick() - lastDetection[chest] < 1.2 then
        return
    end
    lastDetection[chest] = tick()

    createHighlight(chest, Color3.fromRGB(0, 220, 120), Color3.fromRGB(120, 255, 200))
end

function ClientShipController.Initialize()
    -- Listen for new tagged instances
    maid:GiveTask(CollectionService:GetInstanceAddedSignal("GhostShip"):Connect(onGhostShipAdded))
    maid:GiveTask(CollectionService:GetInstanceAddedSignal("LootChest"):Connect(onLootChestAdded))

    -- Handle any pre-existing tagged objects (e.g. from previous test scenarios)
    for _, obj in ipairs(CollectionService:GetTagged("GhostShip")) do
        onGhostShipAdded(obj)
    end
    for _, obj in ipairs(CollectionService:GetTagged("LootChest")) do
        onLootChestAdded(obj)
    end

    print("[ClientShipController] Initialized - Tag consumers active")
end

function ClientShipController.Destroy()
    maid:Cleanup()
    table.clear(lastDetection)
end

return ClientShipController