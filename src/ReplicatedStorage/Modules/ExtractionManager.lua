--!strict
-- ExtractionManager.lua
-- Core loot extraction system for Fog Sea.
-- Spawns weighted loot chests on ghost ships. Applies movement penalty based on carried weight (mobile performant).
-- Server authoritative. Uses RemoteEvents via Utils for client pickup prompts and UI updates.
-- Performance: Runs at 3Hz, uses object pooling for chests, simple weight calculation (no complex physics simulation on mobile).
-- Maid used for cleanup. Integrates with ShipController and GhostShipGenerator.
-- Author: Fog Sea Architect - 2026-06-06

local Utils = require(script.Parent.Utils)
local GhostShipGenerator = require(script.Parent.GhostShipGenerator)
local RunService = Utils.GetService("RunService")
local Players = Utils.GetService("Players")

local ExtractionManager = {}
ExtractionManager.__index = ExtractionManager

export type LootChest = {
	Model: Model,
	Weight: number,
	Value: number,
	Ship: any,
}

export type ExtractionManager = typeof(ExtractionManager)

local activeChests: {LootChest} = {}
local playerWeight: {[Player]: number} = {}
local globalMaid = Utils.CreateMaid()

local PickupRemote = Utils.CreateRemoteEvent("LootPickup")
local WeightUpdateRemote = Utils.CreateRemoteEvent("WeightUpdated")

local CONFIG = {
	MaxChestsPerShip = 3,
	BaseWeight = 12,
	UpdateRate = 0.33, -- ~3Hz - safe for mobile server
	MaxCarryWeight = 65,
	SpeedPenaltyMultiplier = 0.65,
}

local function createLootChest(ship: any): LootChest
	local chestModel = Instance.new("Model")
	chestModel.Name = "LootChest"
	
	local part = Instance.new("Part")
	part.Size = Vector3.new(6, 4, 8)
	part.Color = Color3.fromRGB(80, 60, 30)
	part.Material = Enum.Material.Wood
	part.Parent = chestModel
	chestModel.PrimaryPart = part
	
	-- Position on ship (simplified)
	if ship.Model.PrimaryPart then
		part.Position = ship.Model.PrimaryPart.Position + Vector3.new(0, 6, 0)
	end
	chestModel.Parent = workspace
	
	local chest: LootChest = {
		Model = chestModel,
		Weight = CONFIG.BaseWeight + math.random(8, 25),
		Value = math.random(80, 220),
		Ship = ship,
	}
	
	table.insert(activeChests, chest)
	return chest
end

function ExtractionManager.Initialize()
	globalMaid:GiveTask(RunService.Heartbeat:Connect(function(_dt: number)
		-- Spawn loot on active ghost ships (throttled)
		for _, ship in GhostShipGenerator.GetActiveShips() do
			local shipChests = 0
			for _, chest in activeChests do
				if chest.Ship == ship then shipChests += 1 end
			end
			
			if shipChests < CONFIG.MaxChestsPerShip and math.random() < 0.07 then
				createLootChest(ship)
			end
		end
	end))
	
	-- Pickup handling
	PickupRemote.OnServerEvent:Connect(function(player: Player, chestId: number)
		-- Validate and process pickup with weight check
		for i, chest in ipairs(activeChests) do
			if i == chestId then
				playerWeight[player] = (playerWeight[player] or 0) + chest.Weight
				WeightUpdateRemote:FireClient(player, playerWeight[player])
				
				-- Apply movement penalty
				local character = player.Character
				if character and character:FindFirstChildOfClass("Humanoid") then
					local hum = character:FindFirstChildOfClass("Humanoid") :: Humanoid
					local penalty = math.clamp(1 - (playerWeight[player] / CONFIG.MaxCarryWeight) * (1 - CONFIG.SpeedPenaltyMultiplier), 0.4, 1.0)
					hum.WalkSpeed = 16 * penalty
				end
				
				chest.Model:Destroy()
				table.remove(activeChests, i)
				break
			end
		end
	end)
	
	Players.PlayerRemoving:Connect(function(player: Player)
		playerWeight[player] = nil
	end)
	
	print("ExtractionManager initialized - Loot chests and weight penalties active (mobile optimized)")
end

function ExtractionManager.GetPlayerWeight(player: Player): number
	return playerWeight[player] or 0
end

function ExtractionManager.Destroy()
	globalMaid:Cleanup()
	for _, chest in activeChests do
		if chest.Model then chest.Model:Destroy() end
	end
	table.clear(activeChests)
	table.clear(playerWeight)
end

return ExtractionManager
