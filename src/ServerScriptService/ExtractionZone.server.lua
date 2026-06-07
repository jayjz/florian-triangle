--!strict
-- ExtractionZone.server.lua (ServerScriptService)
-- Creates and manages the visible Extraction Zone for Fog Sea.
-- One Piece themed: "The Cursed Beacon" — pay the toll to escape the Florian Triangle.

local RunService = game:GetService("RunService")
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")

local EXTRACTION_POSITION = Vector3.new(0, 8, 0)
local EXTRACTION_RADIUS = 28

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
            local success = ExtractionManager.ExtractAtZone(player, EXTRACTION_POSITION, EXTRACTION_RADIUS)
            if success then
                prompt.ActionText = "TOLL PAID — PROGRESS MADE"
                task.delay(3, function()
                    if prompt and prompt.Parent then
                        prompt.ActionText = "Extract Loot (Pay Toll)"
                    end
                end)
            end
        end
    end)
end

local function startGlowEffect()
    local pulse = 1
    maid:GiveTask(RunService.Heartbeat:Connect(function(dt: number)
        if not zonePart then return end
        local current = zonePart.Transparency
        if current <= 0.4 then pulse = -1 elseif current >= 0.8 then pulse = 1 end
        zonePart.Transparency += pulse * dt * 0.8
    end))
end

local maid = Utils.CreateMaid() -- Assume Utils is required if needed, or use local maid

function ExtractionZone.Initialize()
    createExtractionZone()
    setupProximityPrompt()
    startGlowEffect()
    print("[ExtractionZone] Fully initialized - One Piece themed extraction goal active")
end

function ExtractionZone.Destroy()
    if zonePart then zonePart:Destroy() end
end

return ExtractionZone