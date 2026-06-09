--!strict
-- ClientUIController.lua (StarterPlayerScripts/Controllers)
-- Full HUD + Lobby Ready Button for ONE TREASURE PIECE [HORROR].
-- Mobile-optimized, pooled feedback, dynamic weight/sanity, and lobby integration.

local Utils = require(game.ReplicatedStorage.Modules.Utils)
local Players = Utils.GetService("Players")
local RunService = Utils.GetService("RunService")
local TweenService = Utils.GetService("TweenService")
local CollectionService = Utils.GetService("CollectionService")
local UserInputService = Utils.GetService("UserInputService")

local localPlayer = Players.LocalPlayer
local playerGui = localPlayer:WaitForChild("PlayerGui")

local ClientUIController = {}
local maid = Utils.CreateMaid()

-- Remotes
local WeightUpdated = Utils.CreateRemoteEvent("WeightUpdated")
local PickupEffect = Utils.CreateRemoteEvent("PickupEffect")
local SanityChanged = Utils.CreateRemoteEvent("SanityChanged")
local ExtractionSuccess = Utils.CreateRemoteEvent("ExtractionSuccess")
local LobbyReady = Utils.CreateRemoteEvent("LobbyReady")
local LobbyCountdown = Utils.CreateRemoteEvent("LobbyCountdown")

-- ScreenGui
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "FogSeaHUD"
screenGui.ResetOnSpawn = false
screenGui.Parent = playerGui

-- Sanity Bar
local sanityFrame = Instance.new("Frame")
sanityFrame.Size = UDim2.new(0.4, 0, 0.03, 0)
sanityFrame.Position = UDim2.new(0.5, 0, 0.03, 0)
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
weightFrame.Size = UDim2.new(0.28, 0, 0.1, 0)
weightFrame.Position = UDim2.new(0.02, 0, 0.86, 0)
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

-- Lobby Ready Button
local readyButton = Instance.new("TextButton")
readyButton.Size = UDim2.new(0.25, 0, 0.08, 0)
readyButton.Position = UDim2.new(0.5, 0, 0.85, 0)
readyButton.AnchorPoint = Vector2.new(0.5, 0)
readyButton.BackgroundColor3 = Color3.fromRGB(0, 180, 80)
readyButton.Text = "READY (Foosha Village)"
readyButton.TextColor3 = Color3.new(1, 1, 1)
readyButton.Font = Enum.Font.GothamBold
readyButton.TextScaled = true
readyButton.Parent = screenGui

local isReady = false

-- Feedback Pool
local feedbackPool: {TextLabel} = {}
local currentSanity = 100
local currentWeight = 0
local MAX_WEIGHT = 80
local lastTagTime: {[Model]: number} = {}

local function getFeedbackLabel(): TextLabel
	if #feedbackPool > 0 then
		return table.remove(feedbackPool) :: TextLabel
	end
	local label = Instance.new("TextLabel")
	label.Size = UDim2.new(0, 160, 0, 45)
	label.BackgroundTransparency = 0.35
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

-- Tag Handlers
local function onGhostShipAdded(ship: Model)
	if lastTagTime[ship] and tick() - lastTagTime[ship] < 1.8 then return end
	lastTagTime[ship] = tick()
	local highlight = Instance.new("Highlight")
	highlight.FillColor = Color3.fromRGB(255, 90, 40)
	highlight.OutlineColor = Color3.fromRGB(255, 180, 80)
	highlight.FillTransparency = 0.65
	highlight.OutlineTransparency = 0.15
	highlight.Adornee = ship
	highlight.Parent = ship
	maid:GiveTask(highlight)
end

local function onLootChestAdded(chest: Model)
	if lastTagTime[chest] and tick() - lastTagTime[chest] < 1.2 then return end
	lastTagTime[chest] = tick()
	local highlight = Instance.new("Highlight")
	highlight.FillColor = Color3.fromRGB(0, 220, 120)
	highlight.OutlineColor = Color3.fromRGB(120, 255, 200)
	highlight.FillTransparency = 0.65
	highlight.OutlineTransparency = 0.15
	highlight.Adornee = chest
	highlight.Parent = chest
	maid:GiveTask(highlight)
end

-- RenderStepped HUD
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

-- Lobby Ready Button Logic
readyButton.MouseButton1Click:Connect(function()
	isReady = not isReady
	readyButton.BackgroundColor3 = isReady and Color3.fromRGB(0, 100, 0) or Color3.fromRGB(0, 180, 80)
	readyButton.Text = isReady and "READY (Waiting...)" or "READY (Foosha Village)"
	LobbyReady:FireServer(isReady)
end)

-- Remote Handlers
maid:GiveTask(LobbyCountdown.OnClientEvent:Connect(function(seconds: number)
	if seconds > 0 then
		readyButton.Text = `STARTING IN {seconds}...`
		readyButton.BackgroundColor3 = Color3.fromRGB(200, 100, 0)
	else
		readyButton.Text = "DEPLOYING!"
		readyButton.BackgroundColor3 = Color3.fromRGB(255, 0, 0)
	end
end))

maid:GiveTask(WeightUpdated.OnClientEvent:Connect(function(newWeight: number, valueGained: number?)
	currentWeight = newWeight or 0
	if valueGained and valueGained > 0 then
		local fb = getFeedbackLabel()
		fb.Text = `+{valueGained}G`
		fb.TextColor3 = Color3.fromRGB(0, 255, 120)
		fb.Position = UDim2.new(0.5, math.random(-90, 90), 0.45, 0)
		local tween = TweenService:Create(fb, TweenInfo.new(1.6, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {
			Position = fb.Position + UDim2.new(0, 0, -0.28, 0),
			TextTransparency = 1
		})
		tween:Play()
		tween.Completed:Connect(function() recycleFeedback(fb) end)
	end
end))

maid:GiveTask(SanityChanged.OnClientEvent:Connect(function(s: number)
	currentSanity = math.clamp(s or 100, 0, 100)
end))

maid:GiveTask(PickupEffect.OnClientEvent:Connect(function(status: string)
	if status == "OverEncumbered" then
		weightText.TextColor3 = Color3.new(1, 0, 0)
		task.delay(1.2, function()
			weightText.TextColor3 = Color3.fromRGB(255, 215, 0)
		end)
	end
end))

maid:GiveTask(ExtractionSuccess.OnClientEvent:Connect(function(amount: number)
	if not amount or amount <= 0 then return end
	local fb = getFeedbackLabel()
	fb.Text = `TOLL PAID: +{amount}G`
	fb.TextColor3 = Color3.fromRGB(0, 255, 255)
	fb.Position = UDim2.new(0.5, 0, 0.4, 0)
	local tween = TweenService:Create(fb, TweenInfo.new(2.5, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {
		Position = fb.Position + UDim2.new(0, 0, -0.4, 0),
		TextTransparency = 1
	})
	tween:Play()
	tween.Completed:Connect(function() recycleFeedback(fb) end)
end))

-- Tag Consumers
maid:GiveTask(CollectionService:GetInstanceAddedSignal("LootChest"):Connect(onLootChestAdded))
maid:GiveTask(CollectionService:GetInstanceAddedSignal("GhostShip"):Connect(onGhostShipAdded))

-- Pre-warm pool
for _ = 1, 12 do
	table.insert(feedbackPool, getFeedbackLabel())
end

function ClientUIController.Initialize()
	print("[ClientUIController] Fully initialized - HUD + Lobby Ready Button active")
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
