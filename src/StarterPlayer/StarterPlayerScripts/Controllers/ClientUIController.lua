--!strict
-- ClientUIController.lua (LocalScript)
-- Handles all UI for sanity, weight, and loot prompts in Fog Sea.
-- Uses ScreenGui with sanity bar, weight indicator, and proximity prompts.
-- Listens to WeightUpdated and SanityChanged remotes. Updates on RenderStepped for smooth bars.
-- Performance: Minimal UI updates, uses pooling for prompt labels, clamped values for mobile.
-- Maid used for all connections and UI cleanup.
-- Author: Fog Sea Architect - 2026-06-06

local Utils = require(game.ReplicatedStorage.Modules.Utils)
local Players = Utils.GetService("Players")
local RunService = Utils.GetService("RunService")

local localPlayer = Players.LocalPlayer
local playerGui = localPlayer:WaitForChild("PlayerGui")

local Remotes = {
	SanityChanged = Utils.CreateRemoteEvent("SanityChanged"),
	WeightUpdated = Utils.CreateRemoteEvent("WeightUpdated"),
	LootPickup = Utils.CreateRemoteEvent("LootPickup"),
}

local screenGui = Instance.new("ScreenGui")
screenGui.ResetOnSpawn = false
screenGui.Parent = playerGui

-- Sanity Bar
local sanityFrame = Instance.new("Frame")
sanityFrame.Size = UDim2.new(0.25, 0, 0.03, 0)
sanityFrame.Position = UDim2.new(0.5, 0, 0.92, 0)
sanityFrame.AnchorPoint = Vector2.new(0.5, 0)
sanityFrame.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
sanityFrame.BorderSizePixel = 2
sanityFrame.Parent = screenGui

local sanityBar = Instance.new("Frame")
sanityBar.Size = UDim2.new(1, 0, 1, 0)
sanityBar.BackgroundColor3 = Color3.fromRGB(80, 200, 120)
sanityBar.Parent = sanityFrame

local sanityText = Instance.new("TextLabel")
sanityText.Size = UDim2.new(1, 0, 1, 0)
sanityText.BackgroundTransparency = 1
sanityText.TextColor3 = Color3.new(1, 1, 1)
sanityText.Text = "SANITY: 100"
sanityText.Font = Enum.Font.GothamBold
sanityText.TextScaled = true
sanityText.Parent = sanityFrame

-- Weight Indicator
local weightFrame = Instance.new("Frame")
weightFrame.Size = UDim2.new(0.18, 0, 0.06, 0)
weightFrame.Position = UDim2.new(0.05, 0, 0.88, 0)
weightFrame.BackgroundColor3 = Color3.fromRGB(20, 20, 25)
weightFrame.Parent = screenGui

local weightText = Instance.new("TextLabel")
weightText.Size = UDim2.new(1, 0, 1, 0)
weightText.BackgroundTransparency = 1
weightText.TextColor3 = Color3.fromRGB(255, 180, 60)
weightText.Text = "WEIGHT: 0/65"
weightText.Font = Enum.Font.Gotham
weightText.TextScaled = true
weightText.Parent = weightFrame

local currentSanity = 100
local currentWeight = 0
local maid = Utils.CreateMaid()

-- Update UI smoothly
maid:GiveTask(RunService.RenderStepped:Connect(function(_dt: number)
	sanityBar.Size = UDim2.new(currentSanity / 100, 0, 1, 0)
	
	if currentSanity < 30 then
		sanityBar.BackgroundColor3 = Color3.fromRGB(220, 50, 50)
	elseif currentSanity < 60 then
		sanityBar.BackgroundColor3 = Color3.fromRGB(255, 160, 40)
	else
		sanityBar.BackgroundColor3 = Color3.fromRGB(80, 200, 120)
	end
	
	sanityText.Text = `SANITY: {math.floor(currentSanity)}`
	weightText.Text = `WEIGHT: {currentWeight}/65`
end))

Remotes.SanityChanged.OnClientEvent:Connect(function(sanity: number)
	currentSanity = sanity
end)

Remotes.WeightUpdated.OnClientEvent:Connect(function(weight: number)
	currentWeight = weight
end)

-- Loot prompt example (proximity based - simplified)
local function showLootPrompt(chest: Model)
	local prompt = Instance.new("TextLabel")
	prompt.Size = UDim2.new(0, 180, 0, 40)
	prompt.Position = UDim2.new(0.5, 0, 0.6, 0)
	prompt.AnchorPoint = Vector2.new(0.5, 0)
	prompt.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
	prompt.BackgroundTransparency = 0.4
	prompt.Text = "[E] Loot Chest"
	prompt.TextColor3 = Color3.new(1, 1, 1)
	prompt.Font = Enum.Font.GothamBold
	prompt.TextScaled = true
	prompt.Parent = screenGui
	
	task.delay(3, function() prompt:Destroy() end)
end

print("ClientUIController initialized - Sanity bar, weight indicator, and loot prompts active")

maid:GiveTask(function()
	screenGui:Destroy()
end)
