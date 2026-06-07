--!strict
-- ClientShipController.lua (StarterPlayerScripts/Controllers)
-- Consumes CollectionService tags for GhostShip and LootChest.
-- Client-only visuals (Highlights). No server logic.
-- Added debounce to prevent spam.

local CollectionService = game:GetService("CollectionService")
local Utils = require(game.ReplicatedStorage.Modules.Utils)

local ClientShipController = {}
local maid = Utils.CreateMaid()

-- Simple debounce table to stop spam
local lastDetection: {[Model]: number} = {}

local function createHighlight(model: Model, fillColor: Color3, outlineColor: Color3)
    local highlight = Instance.new("Highlight")
    highlight.Name = "ClientVerificationHighlight"
    highlight.FillColor = fillColor
    highlight.OutlineColor = outlineColor
    highlight.FillTransparency = 0.6
    highlight.OutlineTransparency = 0.2
    highlight.Adornee = model
    highlight.Parent = model

    maid:GiveTask(highlight)
    return highlight
end

local function onGhostShipAdded(ship: Model)
    if lastDetection[ship] and tick() - lastDetection[ship] < 2 then return end
    lastDetection[ship] = tick()

    print("[ClientShipController] GhostShip detected:", ship:GetFullName())
    createHighlight(ship, Color3.fromRGB(255, 80, 0), Color3.fromRGB(255, 160, 0))
end

local function onLootChestAdded(chest: Model)
    if lastDetection[chest] and tick() - lastDetection[chest] < 1.5 then return end
    lastDetection[chest] = tick()

    print("[ClientShipController] LootChest detected:", chest:GetFullName())
    createHighlight(chest, Color3.fromRGB(0, 200, 100), Color3.fromRGB(100, 255, 200))
end

function ClientShipController.Initialize()
    -- Listen for new tags
    maid:GiveTask(CollectionService:GetInstanceAddedSignal("GhostShip"):Connect(onGhostShipAdded))
    maid:GiveTask(CollectionService:GetInstanceAddedSignal("LootChest"):Connect(onLootChestAdded))

    -- Handle already tagged objects at startup
    for _, obj in ipairs(CollectionService:GetTagged("GhostShip")) do
        onGhostShipAdded(obj)
    end

    for _, obj in ipairs(CollectionService:GetTagged("LootChest")) do
        onLootChestAdded(obj)
    end

    print("ClientShipController initialized - Tag consumers active.")
end

function ClientShipController.Destroy()
    maid:Cleanup()
    table.clear(lastDetection)
end

return ClientShipController