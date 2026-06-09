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

	print("[ClientHorrorController] Initialized - Terrifying atmosphere active")
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
	-- 1=Jumpscare, 2=Whispers/Blur, 3=Shadow Man (Umibozu), 4=Gaslight UI
	if type == 1 then
		ClientHorrorController:TriggerJumpscare(1.3)
	elseif type == 2 then
		ClientHorrorController:ApplyPulseEffect(0.4)
		-- AudioManager handles whispers
	elseif type == 3 then
		ClientHorrorController:SpawnShadowMan()
	elseif type == 4 then
		ClientHorrorController:GaslightUI()
	end
end

function ClientHorrorController:SpawnShadowMan()
	local char = game.Players.LocalPlayer.Character
	if not char or not char.PrimaryPart then return end
	
	-- Umibozu-style silhouette
	local shadow = Instance.new("Part")
	shadow.Name = "UmibozuShadow"
	shadow.Size = Vector3.new(12, 25, 2)
	shadow.Color = Color3.new(0, 0, 0)
	shadow.Material = Enum.Material.Neon
	shadow.Transparency = 0.35
	shadow.CanCollide = false
	shadow.Anchored = true
	
	-- Spawn in fog, slightly behind or beside player
	local angle = math.random() * math.pi * 2
	local offset = Vector3.new(math.cos(angle), 0, math.sin(angle)) * 45
	shadow.Position = char.PrimaryPart.Position + offset
	shadow.CFrame = CFrame.lookAt(shadow.Position, char.PrimaryPart.Position)
	shadow.Parent = workspace
	
	task.delay(2.2, function()
		if shadow then
			local t = TweenService:Create(shadow, TweenInfo.new(1.2), {Transparency = 1, Size = shadow.Size * 1.5})
			t:Play()
			t.Completed:Connect(function() shadow:Destroy() end)
		end
	end)
end

function ClientHorrorController:GaslightUI()
	-- Flicker sanity UI or show fake values
	local playerGui = game.Players.LocalPlayer:FindFirstChild("PlayerGui")
	local hud = playerGui and playerGui:FindFirstChild("FogSeaHUD")
	if not hud then return end
	
	local originalSanity = currentSanity
	currentSanity = math.random(5, 25) -- Fake extreme drop
	
	task.delay(3.5, function()
		currentSanity = originalSanity
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
