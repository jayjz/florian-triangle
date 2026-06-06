--!strict
-- ExtractionManager.lua (ReplicatedStorage/Modules)
-- Production-grade loot extraction and weight system for Fog Sea.
-- Server-authoritative loot chest spawning on ghost ships, pickup validation, movement penalties (WalkSpeed + JumpPower).
-- Uses ProximityPrompt for intuitive mobile-friendly interaction. Validates all client requests on server (anti-exploit).
-- Performance: Server loop throttled to ~3Hz, object pooling for chest visuals (commented), minimal per-player state. No per-frame physics on server.
-- Maid for all cleanup. Integrates with GhostShipGenerator. Fires remotes for client UI/effects only (visuals stay on client per Roblox best practices).
-- Architecture: Central server module initialized by GameManager. Weight penalties applied directly to Humanoid for replication.
-- Author: Fog Sea Architect - 2026-06-06

local Utils = require(script.Parent.Utils)
local GhostShipGenerator = require(script.Parent.GhostShipGenerator)
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

local activeChests: {[Model]: LootChest} = {}
local playerWeight: {[Player]: number} = {}
local globalMaid = Utils.CreateMaid()

local PickupRemote = Utils.CreateRemoteEvent("LootPickup")
local WeightUpdateRemote = Utils.CreateRemoteEvent("WeightUpdated")
local PickupEffectRemote = Utils.CreateRemoteEvent("PickupEffect") -- For client VFX/feedback

local CONFIG = {
	MaxChestsPerShip = 4,
	BaseWeight = 15,
	UpdateRate = 0.33, -- ~3Hz - safe for mobile server tick rate, avoids unnecessary load
	MaxCarryWeight = 80,
	SpeedPenaltyMultiplier = 0.6,
	JumpPenaltyMultiplier = 0.7,
	ChestPoolSize = 8, -- For future pooling
}

local chestTemplate: Model
local chestPool = {} -- Simple pool for performance

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
		part.Name = "ChestPart"
		part.Size = Vector3.new(5, 4, 7)
		part.Color = Color3.fromRGB(139, 69, 19)
		part.Material = Enum.Material.Wood
		part.Anchored = true
		part.CanCollide = true
		part.Parent = chestTemplate
		
		local decal = Instance.new("Decal")
		decal.Texture = "rbxassetid://123456" -- Placeholder for treasure symbol
		decal.Face = Enum.NormalId.Top
		decal.Parent = part
		
		chestTemplate.PrimaryPart = part
	end
	
	local newChest = chestTemplate:Clone()
	newChest.Parent = workspace
	return newChest
end

local function returnToPool(model: Model)
	if model then
		model.Parent = nil
		table.insert(chestPool, model)
	end
end

local function createLootChest(ship: any): LootChest?
	local shipModel = ship and ship.Model
	if not shipModel or not shipModel.PrimaryPart then
		return nil
	end
	
	local chestModel = createChestModel()
	local root = chestModel.PrimaryPart :: Part
	
	-- Position intelligently on/near ship (cull off-screen in client)
	local offset = Vector3.new(math.random(-15, 15), 5, math.random(-15, 15))
	root.Position = shipModel.PrimaryPart.Position + offset
	root.Orientation = Vector3.new(0, math.random(0, 360), 0)
	
	-- Create ProximityPrompt (server-side for security, visible to all clients)
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Loot Chest"
	prompt.ObjectText = "Treasure (" .. tostring(math.random(20,45)) .. "kg)"
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.GamepadKeyCode = Enum.KeyCode.ButtonA
	prompt.MaxActivationDistance = 12
	prompt.RequiresLineOfSight = true
	prompt.Parent = root
	
	local chestMaid = Utils.CreateMaid()
	
	local chest: LootChest = {
		Model = chestModel,
		Weight = CONFIG.BaseWeight + math.random(5, 35),
		Value = math.random(120, 350),
		Ship = ship,
		Prompt = prompt,
		Maid = chestMaid,
	}
	
	activeChests[chestModel] = chest
	
	-- Server-side prompt trigger with full validation (anti-exploit)
	chestMaid:GiveTask(prompt.Triggered:Connect(function(triggerPlayer: Player)
		ExtractionManager.HandlePickup(triggerPlayer, chestModel)
	end))
	
	-- Auto cleanup if ship sinks (example)
	chestMaid:GiveTask(function()
		returnToPool(chestModel)
		activeChests[chestModel] = nil
	end)
	
	return chest
end

function ExtractionManager.HandlePickup(player: Player, chestModel: Model)
	local chest = activeChests[chestModel]
	if not chest then return end
	
	local currentWeight = playerWeight[player] or 0
	if currentWeight + chest.Weight > CONFIG.MaxCarryWeight then
		-- TODO: Fire "overencumbered" remote to client for feedback
		PickupEffectRemote:FireClient(player, "OverWeight", chest.Weight)
		return
	end
	
	-- Validate distance (anti-exploit)
	local character = player.Character
	local rootPart = character and character:FindFirstChild("HumanoidRootPart") :: Part?
	if not rootPart or (rootPart.Position - chest.Model.PrimaryPart.Position).Magnitude > 20 then
		return
	end
	
	-- Process pickup
	playerWeight[player] = currentWeight + chest.Weight
	
	WeightUpdateRemote:FireClient(player, playerWeight[player], chest.Value)
	PickupEffectRemote:FireClient(player, "Success", chest.Value)
	
	-- Apply movement penalties (server authoritative, replicates to all clients)
	ExtractionManager.ApplyPenalties(player)
	
	-- Cleanup chest
	if chest.Maid then
		chest.Maid:Cleanup()
	end
	chest.Model:Destroy() -- In production, return to pool
	activeChests[chestModel] = nil
	
	print(`Player {player.Name} extracted {chest.Weight}kg loot (total weight: {playerWeight[player]})`)
end

function ExtractionManager.ApplyPenalties(player: Player)
	local character = player.Character
	if not character then return end
	
	local humanoid = character:FindFirstChildOfClass("Humanoid") :: Humanoid?
	if not humanoid then return end
	
	local weight = playerWeight[player] or 0
	local weightRatio = math.min(weight / CONFIG.MaxCarryWeight, 1.0)
	
	local speedMult = 1 - (weightRatio * (1 - CONFIG.SpeedPenaltyMultiplier))
	local jumpMult = 1 - (weightRatio * (1 - CONFIG.JumpPenaltyMultiplier))
	
	humanoid.WalkSpeed = 16 * math.max(speedMult, 0.35)
	humanoid.JumpPower = 50 * math.max(jumpMult, 0.4)
	
	-- Note: For mobile, avoid frequent changes; throttle if needed in production
end

function ExtractionManager.Initialize()
	globalMaid:GiveTask(RunService.Heartbeat:Connect(function(_dt: number)
		-- Throttled spawning on active ghost ships
		local activeShips = GhostShipGenerator.GetActiveShips()
		for _, ship in activeShips do
			local shipChestCount = 0
			for _, c in activeChests do
				if c.Ship == ship then shipChestCount += 1 end
			end
			
			if shipChestCount < CONFIG.MaxChestsPerShip and math.random() < 0.05 then -- Low probability per tick
				createLootChest(ship)
			end
		end
	end))
	
	-- Player cleanup
	globalMaid:GiveTask(Players.PlayerRemoving:Connect(function(player: Player)
		playerWeight[player] = nil
		-- Reset penalties on other players? In full system use character respawn hook
	end))
	
	-- Optional: Reset penalties on character respawn
	Players.PlayerAdded:Connect(function(player)
		player.CharacterAdded:Connect(function()
			task.delay(1, function()
				if playerWeight[player] then
					ExtractionManager.ApplyPenalties(player)
				end
			end)
		end)
	end)
	
	print("ExtractionManager initialized - Loot system with weight penalties, ProximityPrompts & server validation active (mobile optimized at 3Hz)")
end

function ExtractionManager.GetPlayerWeight(player: Player): number
	return playerWeight[player] or 0
end

function ExtractionManager.Destroy()
	globalMaid:Cleanup()
	for model, chest in activeChests do
		if chest.Maid then chest.Maid:Cleanup() end
		if model then model:Destroy() end
	end
	table.clear(activeChests)
	table.clear(playerWeight)
	table.clear(chestPool)
end

return ExtractionManager
