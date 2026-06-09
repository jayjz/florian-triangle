--!strict
-- GhostShipGenerator.lua (ReplicatedStorage/Modules)
-- Procedural ghost ship spawning with rich interiors for horror and loot.

local Utils = require(script.Parent.Utils)
local CollectionService = Utils.GetService("CollectionService")
local ShipController = require(script.Parent.ShipController)
local ExtractionManager = require(script.Parent.ExtractionManager)

local GhostShipGenerator = {}
GhostShipGenerator.__index = GhostShipGenerator

local activeShips: {Model} = {}
local globalMaid = Utils.CreateMaid()

local CONFIG = {
	MaxShips = 8,
	SpawnRadius = 350,
}

local function createInterior(shipModel: Model)
	local interior = Instance.new("Model")
	interior.Name = "Interior"

	-- Safe isolation: Place interior very high up
	local interiorBasePos = shipModel.PrimaryPart.Position + Vector3.new(0, 5000, 0)

	-- Floor
	local floor = Instance.new("Part")
	floor.Size = Vector3.new(60, 2, 80)
	floor.Position = interiorBasePos
	floor.Anchored = true
	floor.Material = Enum.Material.Wood
	floor.Color = Color3.fromRGB(30, 20, 10)
	floor.Parent = interior
	
	-- Walls (to keep player inside)
	local wallTemplate = Instance.new("Part")
	wallTemplate.Size = Vector3.new(60, 20, 2)
	wallTemplate.Anchored = true
	wallTemplate.Transparency = 1 -- Invisible barriers
	
	local w1 = wallTemplate:Clone(); w1.Position = interiorBasePos + Vector3.new(0, 10, 40); w1.Parent = interior
	local w2 = wallTemplate:Clone(); w2.Position = interiorBasePos + Vector3.new(0, 10, -40); w2.Parent = interior
	local w3 = wallTemplate:Clone(); w3.Size = Vector3.new(2, 20, 80); w3.Position = interiorBasePos + Vector3.new(30, 10, 0); w3.Parent = interior
	local w4 = wallTemplate:Clone(); w4.Size = Vector3.new(2, 20, 80); w4.Position = interiorBasePos + Vector3.new(-30, 10, 0); w4.Parent = interior

	-- Loot chests
	for i = 1, math.random(3, 5) do
		local chest = Instance.new("Model")
		chest.Name = "LootChest"
		local part = Instance.new("Part")
		part.Size = Vector3.new(4, 3, 6)
		part.Position = interiorBasePos + Vector3.new(math.random(-25, 25), 3, math.random(-35, 35))
		part.Anchored = true
		part.Material = Enum.Material.Wood
		part.Color = Color3.fromRGB(120, 80, 50)
		part.Parent = chest
		chest.PrimaryPart = part
		chest.Parent = interior
		
		CollectionService:AddTag(chest, "LootChest")
		ExtractionManager.RegisterChest(chest, 15, math.random(100, 300))
	end

	-- Exit Prompt
	local exitPart = Instance.new("Part")
	exitPart.Size = Vector3.new(6, 8, 6)
	exitPart.Position = interiorBasePos + Vector3.new(0, 4, 35)
	exitPart.Transparency = 0.5
	exitPart.Color = Color3.new(0, 1, 1)
	exitPart.Material = Enum.Material.Neon
	exitPart.Anchored = true
	exitPart.CanCollide = false
	exitPart.Parent = interior
	
	local exitPrompt = Instance.new("ProximityPrompt")
	exitPrompt.ActionText = "Return to Ship"
	exitPrompt.ObjectText = "Glowing Hatch"
	exitPrompt.Parent = exitPart
	
	exitPrompt.Triggered:Connect(function(player)
		local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if root then
			ShipController.SetSailing(player, true)
			root.CFrame = shipModel.PrimaryPart.CFrame + Vector3.new(0, 12, 0)
		end
	end)

	interior.Parent = shipModel
end

function GhostShipGenerator.CreateTestShip(pos: Vector3): {Model: Model}
	local ship = Instance.new("Model")
	ship.Name = "GhostShip"

	local hull = Instance.new("Part")
	hull.Size = Vector3.new(55, 15, 130)
	hull.Position = pos
	hull.Color = Color3.fromRGB(40, 40, 45)
	hull.Material = Enum.Material.Wood
	hull.Anchored = true
	hull.Parent = ship
	ship.PrimaryPart = hull

	local boardingPrompt = Instance.new("ProximityPrompt")
	boardingPrompt.ActionText = "Board Ghost Ship"
	boardingPrompt.ObjectText = "Haunted Vessel"
	boardingPrompt.HoldDuration = 0.5
	boardingPrompt.Parent = hull
	
	boardingPrompt.Triggered:Connect(function(player)
		local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
		local interior = ship:FindFirstChild("Interior")
		local floor = interior and interior:FindFirstChild("Part") :: BasePart?
		
		if root and floor then
			-- Disable sailing while scavenging inside
			ShipController.SetSailing(player, false)
			root.CFrame = floor.CFrame + Vector3.new(0, 8, 0)
		end
	end)

	CollectionService:AddTag(ship, "GhostShip")

	createInterior(ship)
	ship.Parent = workspace

	table.insert(activeShips, ship)
	return {Model = ship}
end

function GhostShipGenerator.CullDistantShips(center: Vector3)
	for i = #activeShips, 1, -1 do
		local ship = activeShips[i]
		if ship.PrimaryPart and (ship.PrimaryPart.Position - center).Magnitude > 700 then
			ship:Destroy()
			table.remove(activeShips, i)
		end
	end
end

function GhostShipGenerator.Initialize()
	print("[GhostShipGenerator] Initialized with rich procedural interiors")
end

function GhostShipGenerator.Destroy()
	globalMaid:Cleanup()
	for _, ship in activeShips do
		if ship then ship:Destroy() end
	end
	table.clear(activeShips)
end

return GhostShipGenerator
