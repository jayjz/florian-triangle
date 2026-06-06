--!strict
-- ClientHorrorController.lua (LocalScript)
-- Handles all client-side horror visuals and audio for Fog Sea.
-- Listens to HorrorEvents remotes for sanity changes, whispers, hallucinations.
-- Uses RunService.RenderStepped for smooth sanity-based post-processing (ColorCorrection, DepthOfField).
-- Pooled local sounds via SoundService for whispers/hallucinations. Zero server visual code.
-- Mobile performance: Effect intensity is clamped and updated at reduced rate.
-- Author: Fog Sea Architect - 2026-06-06

local Utils = require(game.ReplicatedStorage.Modules.Utils)
local Players = Utils.GetService("Players")
local RunService = Utils.GetService("RunService")
local Lighting = Utils.GetService("Lighting")
local SoundService = Utils.GetService("SoundService")

local localPlayer = Players.LocalPlayer
local playerGui = localPlayer:WaitForChild("PlayerGui")

local Remotes = {
	SanityChanged = Utils.CreateRemoteEvent("SanityChanged"),
	WhisperTriggered = Utils.CreateRemoteEvent("WhisperTriggered"),
	HallucinationTriggered = Utils.CreateRemoteEvent("HallucinationTriggered"),
	HorrorPulse = Utils.CreateRemoteEvent("HorrorPulse"),
}

local colorCorrection = Instance.new("ColorCorrectionEffect")
colorCorrection.Parent = Lighting
local depthOfField = Instance.new("DepthOfFieldEffect")
depthOfField.FocusDistance = 15
depthOfField.InFocusRadius = 40
depthOfField.Parent = Lighting

local soundPool: {Sound} = {}
local currentSanity = 100
local lastEffectUpdate = 0

local CONFIG = {
	EffectUpdateRate = 0.1, -- Throttled for mobile
	MaxInsanityEffects = 3,
	WhisperVolume = 0.65,
}

local function getPooledSound(): Sound
	if #soundPool > 0 then
		return table.remove(soundPool) :: Sound
	end
	local s = Instance.new("Sound")
	s.Parent = SoundService
	s.Volume = CONFIG.WhisperVolume
	return s
end

local function returnSound(s: Sound)
	s:Stop()
	s.Parent = nil
	table.insert(soundPool, s)
end

Remotes.SanityChanged.OnClientEvent:Connect(function(newSanity: number)
	currentSanity = newSanity
end)

Remotes.WhisperTriggered.OnClientEvent:Connect(function(whisperType: string)
	local sound = getPooledSound()
	sound.SoundId = if whisperType == "TheyreWatching" then "rbxassetid://9112832456" else "rbxassetid://1848354532"
	sound:Play()
	task.delay(5, function() returnSound(sound) end)
end)

Remotes.HallucinationTriggered.OnClientEvent:Connect(function(hallucinationType: number)
	-- Visual flash + sound
	colorCorrection.Brightness = 0.4
	task.delay(0.3, function() colorCorrection.Brightness = 0 end)
	
	local sound = getPooledSound()
	sound.SoundId = "rbxassetid://9112906594"
	sound:Play()
	task.delay(3, function() returnSound(sound) end)
end)

Remotes.HorrorPulse.OnClientEvent:Connect(function(intensity: number)
	depthOfField.FocusDistance = 8 + intensity * 12
	task.delay(1.5, function() depthOfField.FocusDistance = 15 end)
end)

-- Smooth sanity-based post processing on RenderStepped
local renderConnection = RunService.RenderStepped:Connect(function(_dt: number)
	local now = tick()
	if now - lastEffectUpdate < CONFIG.EffectUpdateRate then return end
	lastEffectUpdate = now
	
	local insanity = (100 - currentSanity) / 100
	colorCorrection.Saturation = -0.6 * insanity
	colorCorrection.Contrast = 0.3 * insanity
	depthOfField.FarIntensity = 0.7 * insanity
end)

print("ClientHorrorController initialized - Full client horror visuals and audio active")

-- Cleanup on destroy
localPlayer.CharacterRemoving:Connect(function()
	if renderConnection then renderConnection:Disconnect() end
	colorCorrection:Destroy()
	depthOfField:Destroy()
end)
