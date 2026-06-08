--!strict
-- GhostShipGenerator.lua (ReplicatedStorage/Modules)
-- Procedural ghost ship spawning with rich interiors for horror and loot.

local Utils = require(script.Parent.Utils)
local CollectionService = Utils.GetService("CollectionService")

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

	-- Floor
	local floor = Instance.new("Part")
	floor.Size = Vector3.new(45, 2, 65)
	floor.Position = shipModel.PrimaryPart.Position + Vector3.new(0, 5, 0)
	floor.Anchored = true
	floor.Material = Enum.Material.Wood
	floor.Parent = interior

	-- Loot chests
	for i = 1, 5 do
		local chest = Instance.new("Model")
		chest.Name = "LootChest"
		local part = Instance.new("Part")
		part.Size = Vector3.new(4, 3, 6)
		part.Position = floor.Position + Vector3.new(math.random(-18, 18), 6, math.random(-25, 25))
		part.Parent = chest
		chest.PrimaryPart = part
		chest.Parent = interior
		CollectionService:AddTag(chest, "LootChest")
	end

	-- Horror props
	local prop = Instance.new("Part")
	prop.Transparency = 0.7
	prop.Color = Color3.fromRGB(40, 40, 50)
	prop.Size = Vector3.new(8, 12, 8)
	prop.Position = floor.Position + Vector3.new(0, 12, 0)
	prop.Parent = interior
	CollectionService:AddTag(prop, "HorrorProp")

	interior.Parent = shipModel
end

function GhostShipGenerator.CreateTestShip(pos: Vector3): {Model: Model}
	local ship = Instance.new("Model")
	ship.Name = "GhostShip"

	local hull = Instance.new("Part")
	hull.Size = Vector3.new(55, 15, 130)
	hull.Position = pos
	hull.Color = Color3.fromRGB(70, 70, 85)
	hull.Material = Enum.Material.Wood
	hull.Anchored = false
	hull.Parent = ship
	ship.PrimaryPart = hull

	CollectionService:AddTag(ship, "GhostShip")

	createInterior(ship)

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