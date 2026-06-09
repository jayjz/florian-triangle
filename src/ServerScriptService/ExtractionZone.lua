--!strict
-- ExtractionZone.server.lua (ServerScriptService)
-- Creates and manages the visible Extraction Zone (Cursed Beacon).

local ExtractionManager = require(game.ReplicatedStorage.Modules.ExtractionManager)
local RoundManager = require(script.Parent.RoundManager)

local EXTRACTION_POSITION = Vector3.new(0, 95, 0)
local EXTRACTION_RADIUS = 28

local ExtractionZone = {}
local zonePart: Part
local billboard: BillboardGui
local label: TextLabel

local function createExtractionZone()
    zonePart = Instance.new("Part")
    zonePart.Name = "ExtractionZone"
    zonePart.Size = Vector3.new(42, 3, 42)
    zonePart.Position = EXTRACTION_POSITION
    zonePart.Anchored = true
    zonePart.CanCollide = false
    zonePart.Transparency = 0.65
    zonePart.Color = Color3.fromRGB(0, 255, 140)
    zonePart.Material = Enum.Material.Neon
    zonePart.Parent = workspace

    billboard = Instance.new("BillboardGui")
    billboard.Size = UDim2.new(0, 280, 0, 70)
    billboard.StudsOffset = Vector3.new(0, 12, 0)
    billboard.AlwaysOnTop = true
    billboard.Parent = zonePart

    label = Instance.new("TextLabel")
    label.Size = UDim2.new(1, 0, 1, 0)
    label.BackgroundTransparency = 1
    label.Text = "CURSED BEACON\nPAY THE TOLL TO ESCAPE"
    label.TextColor3 = Color3.fromRGB(0, 255, 140)
    label.TextScaled = true
    label.Font = Enum.Font.GothamBold
    label.TextStrokeTransparency = 0.7
    label.Parent = billboard

    print("[ExtractionZone] Cursed Beacon created at", EXTRACTION_POSITION)
end

local function setupProximityPrompt()
    local prompt = Instance.new("ProximityPrompt")
    prompt.ActionText = "Extract Loot (Pay Toll)"
    prompt.ObjectText = "Cursed Beacon"
    prompt.MaxActivationDistance = EXTRACTION_RADIUS + 8
    prompt.RequiresLineOfSight = false
    prompt.Parent = zonePart

    prompt.Triggered:Connect(function(player: Player)
        if typeof(ExtractionManager.ExtractAtZone) == "function" then
            local value = ExtractionManager.ExtractAtZone(player, EXTRACTION_POSITION, EXTRACTION_RADIUS)
			if value > 0 then
				RoundManager.AddExtracted(value)
			end
        end
    end)
end

function ExtractionZone.Initialize()
    createExtractionZone()
    setupProximityPrompt()
    print("[ExtractionZone] Fully initialized")
end

function ExtractionZone.Destroy()
    if zonePart then
        zonePart:Destroy()
    end
end

return ExtractionZone
