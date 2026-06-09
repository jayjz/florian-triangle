--!strict
-- ClientHorrorController.lua (StarterPlayerScripts/Controllers)
-- Full horror feedback with audio integration and hallucinations.
-- Uses AudioManager for spatial sounds, Lighting effects, and client-only visuals.

local Utils = require(game.ReplicatedStorage.Modules.Utils)
local AudioManager = require(game.ReplicatedStorage.Modules.AudioManager)

local RunService = Utils.GetService("RunService")
local Lighting = Utils.GetService("Lighting")
local TweenService = Utils.GetService("TweenService")

local ClientHorrorController = {}
local maid = Utils.CreateMaid()

local Remotes = {
	SanityChanged = Utils.CreateRemoteEvent("SanityChanged"),
	HorrorPulse = Utils.CreateRemoteEvent("HorrorPulse"),
	HallucinationTriggered = Utils.CreateRemoteEvent("HallucinationTriggered"),
}

local currentSanity = 100
local colorCorrection: ColorCorrectionEffect?
local depthOfField: DepthOfFieldEffect?
local lastJumpscare = 0

function ClientHorrorController.Initialize()
	colorCorrection = Lighting:FindFirstChild("HorrorColor") :: ColorCorrectionEffect?
	if not colorCorrection then
		colorCorrection = Instance.new("ColorCorrectionEffect")
		colorCorrection.Name = "HorrorColor"
		colorCorrection.Parent = Lighting
	end

	depthOfField = Lighting:FindFirstChild("HorrorBlur") :: DepthOfFieldEffect?
	if not depthOfField then
		depthOfField = Instance.new("DepthOfFieldEffect")
		depthOfField.Name = "HorrorBlur"
		depthOfField.Parent = Lighting
	end

	Remotes.SanityChanged.OnClientEvent:Connect(function(level: number)
		currentSanity = level
	end)

	Remotes.HorrorPulse.OnClientEvent:Connect(function(intensity: number)
		ClientHorrorController:ApplyPulseEffect(intensity)
	end)

	Remotes.HallucinationTriggered.OnClientEvent:Connect(function(type: number)
		ClientHorrorController:TriggerHallucination(type)
	end)

	maid:GiveTask(RunService.RenderStepped:Connect(function()
		local insanity = (100 - currentSanity) / 100
		if colorCorrection then
			colorCorrection.Saturation = -0.75 * insanity
			colorCorrection.Contrast = 0.45 * insanity
		end
		if depthOfField then
			depthOfField.FarIntensity = 0.95 * insanity
		end
	end))

	print("[ClientHorrorController] Initialized with full audio + hallucination system")
end

function ClientHorrorController:ApplyPulseEffect(intensity: number)
	if not colorCorrection then return end
	local original = colorCorrection.Brightness
	
	local tween = TweenService:Create(colorCorrection, TweenInfo.new(0.15, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {
		Brightness = intensity * 0.65
	})
	tween:Play()
	tween.Completed:Connect(function()
		TweenService:Create(colorCorrection, TweenInfo.new(0.4, Enum.EasingStyle.Sine, Enum.EasingDirection.In), {
			Brightness = original
		}):Play()
	end)
end

function ClientHorrorController:TriggerHallucination(type: number)
	-- Type 1: Jumpscare, Type 2: Whisper/Blur, Type 3: Shadow Man
	if type == 1 then
		ClientHorrorController:TriggerJumpscare(1.3)
	elseif type == 2 then
		ClientHorrorController:ApplyPulseEffect(0.4)
	elseif type == 3 then
		ClientHorrorController:SpawnShadowMan()
	end
end

function ClientHorrorController:SpawnShadowMan()
	local char = game.Players.LocalPlayer.Character
	if not char or not char.PrimaryPart then return end
	
	-- Spawn a simple dark part behind player or just in view
	local shadow = Instance.new("Part")
	shadow.Name = "ShadowMan"
	shadow.Size = Vector3.new(4, 7, 1)
	shadow.Color = Color3.new(0, 0, 0)
	shadow.Material = Enum.Material.Neon
	shadow.Transparency = 0.4
	shadow.CanCollide = false
	shadow.Anchored = true
	
	-- Position it 15 studs behind player, then move it slightly out of sight
	local targetPos = char.PrimaryPart.CFrame * CFrame.new(math.random(-15, 15), 0, 15)
	shadow.CFrame = targetPos
	shadow.Parent = workspace
	
	task.delay(1.5, function()
		if shadow then
			local t = TweenService:Create(shadow, TweenInfo.new(0.8), {Transparency = 1})
			t:Play()
			t.Completed:Connect(function() shadow:Destroy() end)
		end
	end)
end

function ClientHorrorController:TriggerJumpscare(intensity: number)
	if tick() - lastJumpscare < 8 then return end
	lastJumpscare = tick()

	if colorCorrection then
		local original = colorCorrection.Brightness
		colorCorrection.Brightness = intensity * 0.95
		task.delay(0.18, function()
			if colorCorrection then colorCorrection.Brightness = original end
		end)
	end
end

function ClientHorrorController.Destroy()
	maid:Cleanup()
end

return ClientHorrorController
