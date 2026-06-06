--!strict
-- ClientShipController.lua
-- Consumes server-applied CollectionService tags for GhostShip.
-- Client visuals only (Highlight for Studio verification). Maid cleanup. No server state.
-- Performance: Signal based, no loops. Instant highlight on tag add. Mobile safe.
-- Integrates with server tagging from TestHarness/GhostShipGenerator.

local CollectionService = game:GetService("CollectionService")
local Utils = require(game.ReplicatedStorage.Modules.Utils)

local ClientShipController = {}
local maid = Utils.CreateMaid()

local function onGhostShipAdded(ship: Model)
	print("[ClientShipController] GhostShip detected:", ship:GetFullName())
	local highlight = Instance.new("Highlight")
	highlight.Name = "ClientVerificationHighlight"
	highlight.FillColor = Color3.fromRGB(255, 80, 0)
	highlight.OutlineColor = Color3.fromRGB(255, 160, 0)
	highlight.FillTransparency = 0.6
	highlight.OutlineTransparency = 0.2
	highlight.Adornee = ship
	highlight.Parent = ship
	maid:GiveTask(highlight)
	maid:GiveTask(function()
		if highlight then highlight:Destroy() end
	end)
end

local function onLootChestAdded(chest: Model)
	print("[ClientShipController] LootChest detected:", chest:GetFullName())
	local highlight = Instance.new("Highlight")
	highlight.Name = "ClientVerificationHighlight"
	highlight.FillColor = Color3.fromRGB(0, 200, 100)
	highlight.OutlineColor = Color3.fromRGB(100, 255, 200)
	highlight.FillTransparency = 0.7
	highlight.OutlineTransparency = 0.1
	highlight.Adornee = chest
	highlight.Parent = chest
	maid:GiveTask(highlight)
end

function ClientShipController.Initialize()
	-- Consume tags added by server (TestHarness, generators)
	maid:GiveTask(CollectionService:GetInstanceAddedSignal("GhostShip"):Connect(onGhostShipAdded))
	maid:GiveTask(CollectionService:GetInstanceAddedSignal("LootChest"):Connect(onLootChestAdded))
	
	-- Handle any pre-existing tagged instances
	for _, obj in ipairs(CollectionService:GetTagged("GhostShip")) do
		onGhostShipAdded(obj)
	end
	for _, obj in ipairs(CollectionService:GetTagged("LootChest")) do
		onLootChestAdded(obj)
	end
	
	print("ClientShipController initialized - Tag consumers active with Highlight visuals for verification.")
end

function ClientShipController.Destroy()
	maid:Cleanup()
end

return ClientShipController
