--!strict
-- ClientUIController.lua (StarterPlayerScripts/Controllers)
-- Client-only UI and HUD controller for Fog Sea.
-- Handles sanity bar, weight HUD, feedback popups, and tag-based visuals.
-- Pure client visuals. No server logic. Mobile-optimized with throttling and pooling.

local Utils = require(game.ReplicatedStorage.Modules.Utils)
local Players = Utils.GetService("Players")
local RunService = Utils.GetService("RunService")
local TweenService = Utils.GetService("TweenService")
local CollectionService = Utils.GetService("CollectionService")

local localPlayer = Players.LocalPlayer
local playerGui = localPlayer:WaitForChild("PlayerGui")

local ClientUIController = {}
local maid = Utils.CreateMaid()

-- Remotes
local WeightUpdated = Utils.CreateRemoteEvent("WeightUpdated")
local PickupEffect = Utils.CreateRemoteEvent("PickupEffect")
local SanityChanged = Utils.CreateRemoteEvent("SanityChanged")

-- UI Container
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "FogSeaHUD"
screenGui.ResetOnSpawn = false
screenGui.Parent = playerGui

-- Sanity Bar
local sanityFrame = Instance.new("Frame")
sanityFrame.Size = UDim2.new(0.38, 0, 0.028, 0)
sanityFrame.Position = UDim2.new(0.5, 0, 0.035, 0)
sanityFrame.AnchorPoint = Vector2.new(0.5, 0)
sanityFrame.BackgroundColor3 = Color3.fromRGB(20, 20, 25)
sanityFrame.BorderSizePixel = 0
sanityFrame.Parent = screenGui

local sanityBar = Instance.new("Frame")
sanityBar.Size = UDim2.new(1, 0, 1, 0)
sanityBar.BackgroundColor3 = Color3.fromRGB(0, 220, 100)
sanityBar.BorderSizePixel = 0
sanityBar.Parent = sanityFrame

local sanityText = Instance.new("TextLabel")
sanityText.Size = UDim2.new(1, 0, 1, 0)
sanityText.BackgroundTransparency = 1
sanityText.TextColor3 = Color3.new(1, 1, 1)
sanityText.Font = Enum.Font.GothamBold
sanityText.TextScaled = true
sanityText.Parent = sanityFrame

-- Weight HUD
local weightFrame = Instance.new("Frame")
weightFrame.Size = UDim2.new(0.26, 0, 0.09, 0)
weightFrame.Position = UDim2.new(0.02, 0, 0.88, 0)
weightFrame.BackgroundColor3 = Color3.fromRGB(10, 10, 15)
weightFrame.BorderSizePixel = 2
weightFrame.BorderColor3 = Color3.fromRGB(80, 80, 90)
weightFrame.Parent = screenGui

local weightText = Instance.new("TextLabel")
weightText.Size = UDim2.new(1, 0, 0.55, 0)
weightText.BackgroundTransparency = 1
weightText.TextColor3 = Color3.fromRGB(255, 215, 0)
weightText.Font = Enum.Font.Gotham
weightText.TextScaled = true
weightText.Parent = weightFrame

local weightBar = Instance.new("Frame")
weightBar.Size = UDim2.new(0, 0, 0.32, 0)
weightBar.Position = UDim2.new(0.05, 0, 0.6, 0)
weightBar.BackgroundColor3 = Color3.fromRGB(0, 180, 80)
weightBar.Parent = weightFrame

-- Feedback Pool (floating +X G loot text)
local feedbackPool: {TextLabel} = {}
local currentSanity = 100
local currentWeight = 0
local MAX_WEIGHT = 80

local function getFeedbackLabel(): TextLabel
    if #feedbackPool > 0 then
        return table.remove(feedbackPool) :: TextLabel
    end
    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(0, 160, 0, 45)
    label.BackgroundTransparency = 0.3
    label.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
    label.TextScaled = true
    label.Font = Enum.Font.GothamBold
    label.TextColor3 = Color3.fromRGB(0, 255, 120)
    label.Parent = screenGui
    return label
end

local function recycleFeedback(label: TextLabel)
    label.Parent = nil
    table.insert(feedbackPool, label)
end

-- Tag Handlers with Debounce
local lastTagTime: {[Model]: number} = {}

local function onLootChestAdded(chest: Model)
    if lastTagTime[chest] and tick() - lastTagTime[chest] < 1.2 then return end
    lastTagTime[chest] = tick()

    local highlight = Instance.new("Highlight")
    highlight.FillColor = Color3.fromRGB(0, 255, 140)
    highlight.OutlineColor = Color3.fromRGB(100, 255, 200)
    highlight.FillTransparency = 0.65
    highlight.OutlineTransparency = 0.15
    highlight.Adornee = chest
    highlight.Parent = chest
    maid:GiveTask(highlight)
end

local function onGhostShipAdded(ship: Model)
    if lastTagTime[ship] and tick() - lastTagTime[ship] < 2 then return end
    lastTagTime[ship] = tick()

    local highlight = Instance.new("Highlight")
    highlight.FillColor = Color3.fromRGB(255, 90, 0)
    highlight.OutlineColor = Color3.fromRGB(255, 180, 60)
    highlight.FillTransparency = 0.6
    highlight.OutlineTransparency = 0.1
    highlight.Adornee = ship
    highlight.Parent = ship
    maid:GiveTask(highlight)
end

-- RenderStepped HUD (throttled, smooth, mobile-friendly)
maid:GiveTask(RunService.RenderStepped:Connect(function(dt: number)
    local sanityTarget = currentSanity / 100
    sanityBar.Size = UDim2.new(Utils.Lerp(sanityBar.Size.X.Scale, sanityTarget, 8 * dt), 0, 1, 0)

    local weightRatio = math.clamp(currentWeight / MAX_WEIGHT, 0, 1)
    weightBar.Size = UDim2.new(weightRatio, 0, 0.32, 0)

    if weightRatio > 0.75 then
        weightBar.BackgroundColor3 = Color3.fromRGB(200, 30, 30)
        weightText.TextColor3 = Color3.fromRGB(255, 60, 60)
    elseif weightRatio > 0.45 then
        weightBar.BackgroundColor3 = Color3.fromRGB(255, 160, 40)
        weightText.TextColor3 = Color3.fromRGB(255, 200, 60)
    else
        weightBar.BackgroundColor3 = Color3.fromRGB(0, 180, 80)
        weightText.TextColor3 = Color3.fromRGB(255, 215, 0)
    end

    sanityText.Text = `SANITY: {math.floor(currentSanity)}%`
    weightText.Text = `WEIGHT: {math.floor(currentWeight)}/{MAX_WEIGHT}kg`
end))

-- Remote Handlers
maid:GiveTask(WeightUpdated.OnClientEvent:Connect(function(newWeight: number, valueGained: number?)
    currentWeight = newWeight

    if valueGained then
        local fb = getFeedbackLabel()
        fb.Text = `+{valueGained}G`
        fb.Position = UDim2.new(0.5, math.random(-90, 90), 0.45, 0)

        local tween = TweenService:Create(fb, TweenInfo.new(1.6, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {
            Position = fb.Position + UDim2.new(0, 0, -0.28, 0),
            TextTransparency = 1
        })
        tween:Play()
        tween.Completed:Connect(function()
            recycleFeedback(fb)
        end)
    end
end))

maid:GiveTask(SanityChanged.OnClientEvent:Connect(function(s: number)
    currentSanity = math.clamp(s, 0, 100)
end))

maid:GiveTask(PickupEffect.OnClientEvent:Connect(function(status: string)
    if status == "OverEncumbered" then
        weightText.TextColor3 = Color3.new(1, 0, 0)
        task.delay(1.2, function()
            weightText.TextColor3 = Color3.fromRGB(255, 215, 0)
        end)
    end
end))

-- Tag Consumers
maid:GiveTask(CollectionService:GetInstanceAddedSignal("LootChest"):Connect(onLootChestAdded))
maid:GiveTask(CollectionService:GetInstanceAddedSignal("GhostShip"):Connect(onGhostShipAdded))

-- Initialize existing tags
for _, obj in CollectionService:GetTagged("LootChest") do
    onLootChestAdded(obj)
end
for _, obj in CollectionService:GetTagged("GhostShip") do
    onGhostShipAdded(obj)
end

-- Pre-warm feedback pool
for _ = 1, 10 do
    table.insert(feedbackPool, getFeedbackLabel())
end

function ClientUIController.Initialize()
    print("[ClientUIController] Fully initialized - HUD and tag consumers active")
end

function ClientUIController.Destroy()
    maid:Cleanup()
    screenGui:Destroy()
    for _, label in feedbackPool do
        if label then label:Destroy() end
    end
    table.clear(feedbackPool)
    table.clear(lastTagTime)
end

return ClientUIController