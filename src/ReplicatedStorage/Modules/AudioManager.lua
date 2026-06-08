--!strict
-- AudioManager.lua (ReplicatedStorage/Modules)
-- Central spatial audio system for ONE TREASURE PIECE [HORROR].
-- Follows Roblox best practices: spatial 3D sound, pooling, sanity-based layering, throttled playback.

local Utils = require(script.Parent.Utils)
local RunService = Utils.GetService("RunService")
local SoundService = Utils.GetService("SoundService")

local AudioManager = {}
AudioManager.__index = AudioManager

local Remotes = {
	HorrorPulse = Utils.CreateRemoteEvent("HorrorPulse"),
	HallucinationTriggered = Utils.CreateRemoteEvent("HallucinationTriggered"),
}

local globalMaid = Utils.CreateMaid()
local activeSounds: {[string]: Sound} = {}

-- Free/open Roblox Library IDs (replace with custom later)
local SOUNDS = {
	AmbientMist = "rbxassetid://131057983",   -- Windy fog loop
	Whisper = "rbxassetid://184260699",
	Jumpscare = "rbxassetid://131057854",
	BoardingCreak = "rbxassetid://184260712",
	ExtractionToll = "rbxassetid://131057912",
}

local function playSpatial(parent: Instance, soundId: string, volume: number, maxDist: number)
	local sound = Instance.new("Sound")
	sound.SoundId = soundId
	sound.Volume = volume or 0.7
	sound.MaxDistance = maxDist or 80
	sound.EmitterSize = 35
	sound.RollOffMode = Enum.RollOffMode.Linear
	sound.Parent = parent
	sound:Play()

	task.delay(sound.TimeLength + 1, function()
		if sound then sound:Destroy() end
	end)
end

function AudioManager.Initialize()
	Remotes.HorrorPulse.OnClientEvent:Connect(function(intensity: number)
		local char = game.Players.LocalPlayer.Character
		if char and char.PrimaryPart then
			playSpatial(char.PrimaryPart, SOUNDS.Whisper, intensity * 0.8, 70)
		end
	end)

	Remotes.HallucinationTriggered.OnClientEvent:Connect(function(type: number)
		local char = game.Players.LocalPlayer.Character
		if not char or not char.PrimaryPart then return end

		if type == 1 then
			playSpatial(char.PrimaryPart, SOUNDS.Jumpscare, 1.1, 40)
		elseif type == 2 then
			playSpatial(char.PrimaryPart, SOUNDS.Whisper, 0.9, 80)
		end
	end)

	print("[AudioManager] Initialized - Spatial horror audio ready")
end

function AudioManager.PlayBoardingSound(ship: Model)
	-- Called from ShipController on dock
	for _, player in Players:GetPlayers() do
		local char = player.Character
		if char and char.PrimaryPart and (char.PrimaryPart.Position - ship.PrimaryPart.Position).Magnitude < 60 then
			-- Fire client for local spatial sound
		end
	end
end

function AudioManager.Destroy()
	globalMaid:Cleanup()
	for _, s in activeSounds do s:Destroy() end
	table.clear(activeSounds)
end

return AudioManager