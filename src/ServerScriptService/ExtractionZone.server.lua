--!strict
-- ExtractionZone.server.lua (ServerScriptService)
-- Creates and manages the visible extraction zone for Fog Sea.
-- Players must bring loot to this zone to extract and progress toward the win condition.

local EXTRACTION_POSITION = Vector3.new(0, 8, 0)
local EXTRACTION_RADIUS = 28

-- Create the physical zone
local zonePart = Instance.new("Part")
zonePart.Name = "ExtractionZone"
zonePart.Size = Vector3.new(42, 3, 42)
zonePart.Position = EXTRACTION_POSITION
zonePart.Anchored = true
zonePart.CanCollide = false
zonePart.Transparency = 0.65
zonePart.Color = Color3.fromRGB(0, 255, 140)
zonePart.Material = Enum.Material.Neon
zonePart.Parent = workspace

-- Add a simple glowing Billboard label
local billboard = Instance.new("BillboardGui")
billboard.Size = UDim2.new(0, 220, 0, 60)
billboard.StudsOffset = Vector3.new(0, 10, 0)
billboard.AlwaysOnTop = true
billboard.Parent = zonePart

local label = Instance.new("TextLabel")
label.Size = UDim2.new(1, 0, 1, 0)
label.BackgroundTransparency = 1
label.Text = "EXTRACTION ZONE"
label.TextColor3 = Color3.fromRGB(0, 255, 140)
label.TextScaled = true
label.Font = Enum.Font.GothamBold
label.Parent = billboard

print("[ExtractionZone] Extraction zone active at", EXTRACTION_POSITION)