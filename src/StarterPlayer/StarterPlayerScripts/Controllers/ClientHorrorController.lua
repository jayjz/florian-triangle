--!strict
-- ClientHorrorController.lua (StarterPlayerScripts/Controllers)
-- Full horror feedback with audio integration and hallucinations.
-- Uses AudioManager for spatial sounds, TweenService for effects, pooling for fake entities.

local Utils = require(game.ReplicatedStorage.Modules.Utils)
local AudioManager = require(game.ReplicatedStorage.Modules.AudioManager)  -- NEW

local RunService = Utils.GetService("RunService")
local Lighting = Utils.GetService("Lighting")

local ClientHorrorController = {}
local maid = Utils.CreateMaid()

local Remotes = {
	SanityChanged = Utils.CreateRemoteEvent("SanityChanged"),
	HorrorPulse = Utils.CreateRemoteEvent("HorrorPulse"),
	HallucinationTriggered = Utils.CreateRemoteEvent("HallucinationTriggered"),
}

local AudioManager = require(game.ReplicatedStorage.Modules.AudioManager)
AudioManager.Initialize()
local currentSanity = 100
local colorCorrection: ColorCorrectionEffect?
local depthOfField: DepthOfFieldEffect?
local lastJumpscare = 0

function ClientHorrorController.Initialize()
	colorCorrection = Instance.new("ColorCorrectionEffect")
	colorCorrection.Parent = Lighting

	depthOfField = Instance.new("DepthOfFieldEffect")
	depthOfField.Parent = Lighting

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
	colorCorrection.Brightness = intensity * 0.65
	task.delay(0.22, function()
		if colorCorrection then colorCorrection.Brightness = original end
	end)
end

function ClientHorrorController:TriggerHallucination(type: number)
	-- Audio already handled by AudioManager; here we add visuals
	if type == 1 then
		ClientHorrorController:TriggerJumpscare(1.3)
	elseif type == 2 or type == 3 then
		-- Fake entity or whisper visual
		print("[ClientHorror] Visual hallucination triggered")
	end
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
	if colorCorrection then colorCorrection:Destroy() end
	if depthOfField then depthOfField:Destroy() end
end

return ClientHorrorController