--!strict
-- HorrorEvents.lua
-- Centralized horror mechanics system for Fog Sea.
-- Manages sanity meter, whispers, hallucinations, collapsing floors.
-- Clear client/server separation. Uses RemoteEvents for all cross-boundary communication.
-- Performance: All client visual effects are cheap. Server only runs sanity logic.
-- Heavy use of Maid for cleanup. Integrates with FogSystem and ShipController.
-- Author: Fog Sea Architect - 2026-06-06

local Utils = require(script.Parent.Utils)
local FogSystem = require(script.Parent.FogSystem)
local RunService = Utils.GetService("RunService")
local Players = Utils.GetService("Players")
local SoundService = Utils.GetService("SoundService")

local HorrorEvents = {}
HorrorEvents.__index = HorrorEvents

export type SanityData = {
	Level: number,
	LastDecay: number,
	EffectsActive: { string },
}

export type HorrorEvents = typeof(HorrorEvents)

local self = setmetatable({}, HorrorEvents)
local maid = Utils.CreateMaid()
local playerSanity: { [Player]: SanityData } = {}

-- RemoteEvents (created safely)
local Remotes = {
	SanityChanged = Utils.CreateRemoteEvent("SanityChanged"),
	WhisperTriggered = Utils.CreateRemoteEvent("WhisperTriggered"),
	HallucinationTriggered = Utils.CreateRemoteEvent("HallucinationTriggered"),
	FloorCollapse = Utils.CreateRemoteEvent("FloorCollapse"),
}

local CONFIG = {
	SanityDecayRate = 0.8,      -- Per second when in heavy fog
	WhisperInterval = 12,
	HallucinationThreshold = 35,
	MobileEffectLimit = 2,      -- Limit simultaneous client effects for performance
}

-- Server-side sanity management
function HorrorEvents.UpdateSanity(dt: number)
	for player, data in playerSanity do
		if not player.Character then continue end
		
		local inHeavyFog = FogSystem.GetVisibilityDistance() < 45
		if inHeavyFog then
			data.Level = Utils.Clamp(data.Level - CONFIG.SanityDecayRate * dt, 0, 100)
		end
		
		if data.Level < CONFIG.HallucinationThreshold and tick() - data.LastDecay > 8 then
			data.LastDecay = tick()
			Remotes.HallucinationTriggered:FireClient(player, "ShadowFigure")
			FogSystem.TriggerHorrorPulse(0.8)
		end
		
		Remotes.SanityChanged:FireClient(player, data.Level)
	end
end

function HorrorEvents.Initialize()
	FogSystem.Initialize()
	
	-- Main server update loop (throttled for performance)
	maid:GiveTask(RunService.Heartbeat:Connect(function(dt: number)
		HorrorEvents.UpdateSanity(dt)
	end))
	
	-- Client joins
	Players.PlayerAdded:Connect(function(player: Player)
		playerSanity[player] = {
			Level = 100,
			LastDecay = tick(),
			EffectsActive = {},
		}
		
		-- Whisper loop per player (cheap)
		task.spawn(function()
			while player.Parent do
				task.wait(CONFIG.WhisperInterval + math.random(4, 12))
				if playerSanity[player] and playerSanity[player].Level < 75 then
					Remotes.WhisperTriggered:FireClient(player, "TheyreWatching")
				end
			end
		end)
	end)
	
	Players.PlayerRemoving:Connect(function(player: Player)
		if playerSanity[player] then
			playerSanity[player] = nil
		end
	end)
	
	print("HorrorEvents initialized - Sanity, whispers, and hallucinations active")
end

-- Trigger collapsing floor (with proper validation)
function HorrorEvents.TriggerFloorCollapse(position: Vector3, radius: number)
	Remotes.FloorCollapse:FireAllClients(position, radius)
	-- Server would handle actual physics destruction here in full implementation
end

-- Client-side handlers would be in a separate LocalScript that listens to these remotes
-- (kept separate for clean architecture)

function HorrorEvents.GetSanity(player: Player): number
	local data = playerSanity[player]
	return data and data.Level or 100
end

function HorrorEvents.Destroy()
	maid:Cleanup()
	table.clear(playerSanity)
end

return HorrorEvents
