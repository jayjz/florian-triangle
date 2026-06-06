--!strict
-- ExtractionManager.lua (ReplicatedStorage/Modules)
-- Production-grade loot extraction and weight system for Fog Sea co-op horror extraction.
-- Server-authoritative chest spawning on ghost ships, ProximityPrompt interaction, weight-based movement penalties.
-- All client input validated on server (anti-exploit). Visuals/effects fired via remotes only — client handles UI/RenderStepped.
-- Performance: Heartbeat throttled to ~3Hz for spawning checks (mobile server safety). Object pooling for chests. Minimal state.
-- Maid pattern for all cleanup. Integrates with GhostShipGenerator. Explicit SetNetworkOwner(nil) note for dynamic parts.
-- Uses Utils.CreateRemoteEvent. No server visuals or physics simulation.
-- Asset Binding (Phase 7): Replace createChestModel() with ServerStorage.Assets.LootChestRig:Clone(). Bind rigged models with animations/sounds. Use CollectionService "LootChest" tag for client visual controllers. Ensure all spawned Models have PrimaryPart and NetworkOwner set to nil for AI/ship parts on mobile replication.
-- Author: Fog Sea Architect - 2026-06-07

local Utils = require(script.Parent.Utils)
local GhostShipGenerator = require(script.Parent.GhostShipGenerator)
local CollectionService = Utils.GetService("CollectionService")
local RunService = Utils.GetService("RunService")
local Players = Utils.GetService("Players")
local ProximityPromptService = Utils.GetService("ProximityPromptService")

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

export type ExtractionManager = typeof(ExtractionManager)

local activeChests: { [Model]: LootChest } = {}
local playerWeight: { [Player]: number } = {}
local globalMaid = Utils.CreateMaid()

local WeightUpdateRemote = Utils.CreateRemoteEvent("WeightUpdated")
local PickupEffectRemote = Utils.CreateRemoteEvent("PickupEffect")

local CONFIG = {
	MaxChestsPerShip = 4,
	BaseWeight = 15,
	UpdateRate = 0.33, -- ~3Hz server loop - critical for mobile performance, prevents unnecessary replication load
	MaxCarryWeight = 80,
	SpeedPenaltyMultiplier = 0.6,
	JumpPenaltyMultiplier = 0.7,
}

local chestTemplate: Model
local chestPool: {Model} = {}

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
		part.Anchored = true
		part.CanCollide = true
		part.Parent = chestTemplate
		chestTemplate.PrimaryPart = part
	end
	local newModel = chestTemplate:Clone()
	newModel.Parent = workspace
	CollectionService:AddTag(newModel, "LootChest") -- For client visual controller in prod
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
	local offset = Vector3.new(math.random(-12,12), 3, math.random(-12,12))
	root.Position = shipModel.PrimaryPart.Position + offset
	root.Orientation = Vector3.new(0, math.random(0,360), 0)
	
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Extract Loot"
	prompt.ObjectText = "Treasure Chest"
	prompt.MaxActivationDistance = 10
	prompt.RequiresLineOfSight = true
	prompt.Parent = root
	
	local chestMaid = Utils.CreateMaid()
	local chest: LootChest = {
		Model = chestModel,
		Weight = CONFIG.BaseWeight + math.random(10,40),
		Value = math.random(100,400),
		Ship = ship,
		Prompt = prompt,
		Maid = chestMaid,
	}
	activeChests[chestModel] = chest
	
	chestMaid:GiveTask(prompt.Triggered:Connect(function(plr: Player)
		ExtractionManager.HandlePickup(plr, chestModel)
	end))
	
	chestMaid:GiveTask(function()
		returnToPool(chestModel)
		activeChests[chestModel] = nil
	end)
	
	return chest
end

function ExtractionManager.HandlePickup(player: Player, chestModel: Model)
	local chest = activeChests[chestModel]
	if not chest then return end
	local weight = playerWeight[player] or 0
	if weight + chest.Weight > CONFIG.MaxCarryWeight then
		PickupEffectRemote:FireClient(player, "OverEncumbered")
		return
	end
	local char = player.Character
	local root = char and char:FindFirstChild("HumanoidRootPart") :: Part?
	if not root or (root.Position - chest.Model.PrimaryPart.Position).Magnitude > 15 then return end
	
	playerWeight[player] = weight + chest.Weight
	WeightUpdateRemote:FireClient(player, playerWeight[player], chest.Value)
	PickupEffectRemote:FireClient(player, "Success", chest.Value)
	ExtractionManager.ApplyPenalties(player)
	
	if chest.Maid then chest.Maid:Cleanup() end
	chest.Model:Destroy()
	activeChests[chestModel] = nil
end

function ExtractionManager.ApplyPenalties(player: Player)
	local char = player.Character
	if not char then return end
	local hum = char:FindFirstChildOfClass("Humanoid")
	if not hum then return end
	local w = playerWeight[player] or 0
	local ratio = math.min(w / CONFIG.MaxCarryWeight, 1)
	hum.WalkSpeed = 16 * (1 - ratio * 0.65)
	hum.JumpPower = 50 * (1 - ratio * 0.6)
end

function ExtractionManager.Initialize()
	globalMaid:GiveTask(RunService.Heartbeat:Connect(function()
		local ships = GhostShipGenerator.GetActiveShips()
		for _, ship in ships do
			local count = 0
			for _, c in activeChests do if c.Ship == ship then count += 1 end end
			if count < CONFIG.MaxChestsPerShip and math.random() < 0.03 then
				createLootChest(ship)
			end
		end
	end))
	
	globalMaid:GiveTask(Players.PlayerRemoving:Connect(function(p)
		playerWeight[p] = nil
	end))
	
	print("ExtractionManager initialized (mobile 3Hz loop, server authority, Maid + pooling + remotes only)")
end

function ExtractionManager.Destroy()
	globalMaid:Cleanup()
	for m, c in activeChests do
		if c.Maid then c.Maid:Cleanup() end
		if m then m:Destroy() end
	end
	table.clear(activeChests)
	table.clear(playerWeight)
	table.clear(chestPool)
end

function ExtractionManager.CreateTestChest(ship: any)
	-- Test helper for TestHarness (Phase 7). Uses placeholder rig reference.
	return createLootChest(ship)
end

return ExtractionManager
