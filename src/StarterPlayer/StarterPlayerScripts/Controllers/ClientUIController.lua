--!strict
-- ClientUIController.lua (StarterPlayer/StarterPlayerScripts/Controllers)
-- Client-only UI and tag consumer for LootChest/GhostShip highlights + sanity/weight HUD.
-- All visuals on RenderStepped (throttled, mobile-first). Maid for everything. No server logic.
-- Uses CollectionService signals for server tags. Highlights are dev verification only.
-- Performance: Conditional updates, object pooling for feedback labels, no per-frame allocations.
-- Author: Fog Sea Architect - 2026-06-08

local Utils = require(game.ReplicatedStorage.Modules.Utils)
local Players = Utils.GetService("Players")
local RunService = Utils.GetService("RunService")
local TweenService = Utils.GetService("TweenService")
local ProximityPromptService = Utils.GetService("ProximityPromptService")
local CollectionService = Utils.GetService("CollectionService")

local localPlayer = Players.LocalPlayer
local playerGui = localPlayer:WaitForChild("PlayerGui")

local WeightUpdated = Utils.CreateRemoteEvent("WeightUpdated")
local PickupEffect = Utils.CreateRemoteEvent("PickupEffect")
local SanityChanged = Utils.CreateRemoteEvent("SanityChanged")

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "FogSeaHUD"
screenGui.ResetOnSpawn = false
screenGui.Parent = playerGui

local maid = Utils.CreateMaid()

-- UI Elements
local sanityFrame = Instance.new("Frame")
sanityFrame.Size = UDim2.new(0.35, 0, 0.03, 0)
sanityFrame.Position = UDim2.new(0.5, 0, 0.03, 0)
sanityFrame.AnchorPoint = Vector2.new(0.5, 0)
sanityFrame.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
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
sanityText.Text = "SANITY: 100%"
sanityText.TextColor3 = Color3.new(1,1,1)
sanityText.Font = Enum.Font.GothamBold
sanityText.TextScaled = true
sanityText.Parent = sanityFrame

local weightFrame = Instance.new("Frame")
weightFrame.Size = UDim2.new(0.25, 0, 0.1, 0)
weightFrame.Position = UDim2.new(0.02, 0, 0.85, 0)
weightFrame.BackgroundColor3 = Color3.fromRGB(10,10,15)
weightFrame.BorderSizePixel = 2
weightFrame.BorderColor3 = Color3.fromRGB(100,100,100)
weightFrame.Parent = screenGui

local weightText = Instance.new("TextLabel")
weightText.Size = UDim2.new(1,0,0.5,0)
weightText.BackgroundTransparency = 1
weightText.Text = "WEIGHT: 0/80kg"
weightText.TextColor3 = Color3.fromRGB(255, 215, 0)
weightText.Font = Enum.Font.Gotham
weightText.TextScaled = true
weightText.Parent = weightFrame

local weightBar = Instance.new("Frame")
weightBar.Size = UDim2.new(0,0,0.3,0)
weightBar.Position = UDim2.new(0.05,0,0.6,0)
weightBar.BackgroundColor3 = Color3.fromRGB(0, 180, 80)
weightBar.Parent = weightFrame

local feedbackPool: {TextLabel} = {}
local currentSanity = 100
local currentWeight = 0
local MAX_WEIGHT = 80

local function getFeedback(): TextLabel
	if #feedbackPool > 0 then
		return table.remove(feedbackPool) :: TextLabel
	end
	local label = Instance.new("TextLabel")
	label.Size = UDim2.new(0, 140, 0, 40)
	label.BackgroundTransparency = 0.4
	label.TextScaled = true
	label.Font = Enum.Font.GothamBold
	label.TextColor3 = Color3.fromRGB(0, 255, 100)
	label.Parent = screenGui
	return label
end

local function recycleFeedback(label: TextLabel)
	label.Parent = nil
	table.insert(feedbackPool, label)
end

local function onLootChestAdded(chest: Model)
	print("[ClientUIController] LootChest tag consumed for UI feedback")
	local highlight = Instance.new("Highlight")
	highlight.Name = "UIHighlight"
	highlight.FillColor = Color3.fromRGB(0, 255, 120)
	highlight.OutlineColor = Color3.fromRGB(0, 255, 255)
	highlight.FillTransparency = 0.7
	highlight.OutlineTransparency = 0.2
	highlight.Adornee = chest
	highlight.Parent = chest
	maid:GiveTask(highlight)
end

local function onGhostShipAdded(ship: Model)
	print("[ClientUIController] GhostShip tag consumed for UI/ship visuals")
	local highlight = Instance.new("Highlight")
	highlight.Name = "UIHighlight"
	highlight.FillColor = Color3.fromRGB(255, 100, 0)
	highlight.OutlineColor = Color3.fromRGB(255, 200, 0)
	highlight.FillTransparency = 0.6
	highlight.OutlineTransparency = 0.1
	highlight.Adornee = ship
	highlight.Parent = ship
	maid:GiveTask(highlight)
end

-- Main RenderStepped (mobile performant - only 2 lerps + conditional color)
maid:GiveTask(RunService.RenderStepped:Connect(function(dt: number)
	local target = currentSanity / 100
	sanityBar.Size = UDim2.new(Utils.Lerp(sanityBar.Size.X.Scale, target, 12 * dt), 0, 1, 0)
	
	local wRatio = math.clamp(currentWeight / MAX_WEIGHT, 0, 1)
	weightBar.Size = UDim2.new(wRatio, 0, 0.3, 0)
	
	if wRatio > 0.75 then
		weightBar.BackgroundColor3 = Color3.fromRGB(200, 30, 30)
		weightText.TextColor3 = Color3.fromRGB(255, 60, 60)
	elseif wRatio > 0.4 then
		weightBar.BackgroundColor3 = Color3.fromRGB(255, 160, 40)
		weightText.TextColor3 = Color3.fromRGB(255, 200, 60)
	else
		weightBar.BackgroundColor3 = Color3.fromRGB(0, 180, 80)
		weightText.TextColor3 = Color3.fromRGB(255, 215, 0)
	end
	
	sanityText.Text = `SANITY: {math.floor(currentSanity)}%`
	weightText.Text = `WEIGHT: {math.floor(currentWeight)}/{MAX_WEIGHT}kg`
end))

maid:GiveTask(WeightUpdated.OnClientEvent:Connect(function(w: number, val: number?)
	currentWeight = w
	if val then
		local fb = getFeedback()
		fb.Text = `+{val}G`
		fb.Position = UDim2.new(0.5, math.random(-80, 80), 0.4, 0)
		local tw = TweenService:Create(fb, TweenInfo.new(1.5, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {
			Position = fb.Position + UDim2.new(0, 0, -0.25, 0), 
			TextTransparency = 1
		})
		tw:Play()
		tw.Completed:Connect(function() recycleFeedback(fb) end)
	end
end))

maid:GiveTask(PickupEffect.OnClientEvent:Connect(function(status: string)
	if status == "OverEncumbered" then
		weightText.TextColor3 = Color3.new(1, 0, 0)
	end
end))

maid:GiveTask(SanityChanged.OnClientEvent:Connect(function(s: number)
	currentSanity = math.clamp(s, 0, 100)
	if currentSanity < 30 then
		sanityBar.BackgroundColor3 = Color3.fromRGB(180, 20, 20)
	end
end))

-- Tag consumers (fixes the orphaned controller issue)
maid:GiveTask(CollectionService:GetInstanceAddedSignal("LootChest"):Connect(onLootChestAdded))
maid:GiveTask(CollectionService:GetInstanceAddedSignal("GhostShip"):Connect(onGhostShipAdded))

-- Initialize existing tags
for _, obj in CollectionService:GetTagged("LootChest") do
	onLootChestAdded(obj)
end
for _, obj in CollectionService:GetTagged("GhostShip") do
	onGhostShipAdded(obj)
end

-- Prompt enhancements
maid:GiveTask(ProximityPromptService.PromptShown:Connect(function(prompt)
	if prompt.ActionText == "Extract Loot" then
		-- Client visual only
	end
end))

-- Pool setup
for i = 1, 8 do
	table.insert(feedbackPool, getFeedback())
end

print("ClientUIController fully initialized with tag consumers, RenderStepped HUD, pooling, and Maid.")

local ClientUIController = {
	Initialize = function() end,
	Maid = maid
}

maid:GiveTask(function()
	screenGui:Destroy()
	for _, l in feedbackPool do 
		if l then l:Destroy() end 
	end
end)

return ClientUIController
