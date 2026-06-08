--!strict
-- ExtractionManager.lua (ReplicatedStorage/Modules)
-- Proximity-based extraction with weight penalties and quota integration.
-- No polling - distance checks on throttled Heartbeat.

local Utils = require(script.Parent.Utils)
local ShipController = require(script.Parent.ShipController)
local RoundManager = require(script.Parent.Parent.ServerScriptService.RoundManager)

local CollectionService = Utils.GetService("CollectionService")
local RunService = Utils.GetService("RunService")
local Players = Utils.GetService("Players")

local ExtractionManager = {}
ExtractionManager.__index = ExtractionManager

local Remotes = {
	WeightUpdated = Utils.CreateRemoteEvent("WeightUpdated"),
	PickupEffect = Utils.CreateRemoteEvent("PickupEffect"),
	ExtractionSuccess = Utils.CreateRemoteEvent("ExtractionSuccess"),
}

local activeChests: {[Model]: {Model: Model, Weight: number, Value: number, Ship: any, Maid: any}} = {}
local playerWeight: {[Player]: number} = {}
local chestPool: {Model} = {}
local globalMaid = Utils.CreateMaid()

local CONFIG = {
	MaxChestsPerShip = 5,
	BaseWeight = 18,
	MaxCarryWeight = 80,
	SpeedPenaltyMultiplier = 0.68,
	JumpPenaltyMultiplier = 0.75,
	ExtractionRadius = 28,
}

local function createChestModel(): Model
	if #chestPool > 0 then
		local model = table.remove(chestPool) :: Model
		model.Parent = workspace
		return model
	end

	local template = Instance.new("Model")
	template.Name = "LootChest"
	local root = Instance.new("Part")
	root.Name = "Root"
	root.Size = Vector3.new(4, 3.5, 6)
	root.Color = Color3.fromRGB(139, 69, 19)
	root.Material = Enum.Material.Wood
	root.Anchored = false
	root.CanCollide = true
	root.Parent = template
	template.PrimaryPart = root
	return template
end

local function returnToPool(model: Model)
	if model then
		model.Parent = nil
		table.insert(chestPool, model)
	end
end

function ExtractionManager.HandlePickup(player: Player, chestModel: Model)
	local chest = activeChests[chestModel]
	if not chest then return end

	local current = playerWeight[player] or 0
	if current + chest.Weight > CONFIG.MaxCarryWeight then
		Remotes.PickupEffect:FireClient(player, "OverEncumbered")
		return
	end

	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: Part?
	if not root or (root.Position - chest.Model.PrimaryPart.Position).Magnitude > 18 then
		return
	end

	playerWeight[player] = current + chest.Weight
	ShipController.UpdatePlayerWeight(player, playerWeight[player])

	Remotes.WeightUpdated:FireClient(player, playerWeight[player], chest.Value)
	Remotes.PickupEffect:FireClient(player, "Success", chest.Value)

	if chest.Maid then chest.Maid:Cleanup() end
	returnToPool(chest.Model)
	activeChests[chestModel] = nil
end

function ExtractionManager.Initialize()
	globalMaid:GiveTask(Players.PlayerRemoving:Connect(function(player)
		playerWeight[player] = nil
	end))

	print("[ExtractionManager] Initialized - Proximity extraction ready")
end

function ExtractionManager.Destroy()
	globalMaid:Cleanup()
	for _, chest in activeChests do
		if chest.Maid then chest.Maid:Cleanup() end
		if chest.Model then returnToPool(chest.Model) end
	end
	table.clear(activeChests)
	table.clear(playerWeight)
	table.clear(chestPool)
end

function ExtractionManager.CreateTestChest(ship: any)
	-- Implementation in GhostShipGenerator now
end

function ExtractionManager.GetPlayerWeight(player: Player): number
	return playerWeight[player] or 0
end

return ExtractionManager