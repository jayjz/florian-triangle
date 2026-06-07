--!strict
-- FogSystem.lua (ReplicatedStorage/Modules)
-- FULL GAMEPLAY-READY Smothering Mist: Closing Circle (Fortnite-style) + Green Ocean Horror.
-- Server = Truth (phase + safe radius). Client renders visuals + culling.

local Utils = require(script.Parent.Utils)
local RunService = Utils.GetService("RunService")
local Players = Utils.GetService("Players")

local FogSystem = {}
FogSystem.__index = FogSystem

local CONFIG = {
	InitialRadius = 400,           -- Large starting ocean play area
	MinRadius = 80,                -- Final deadly zone
	ShrinkTime = 300,              -- 5 minutes to full close (adjust for match length)
	BaseDensity = 0.35,
	MaxDensity = 2.2,
	Color = Color3.fromRGB(35, 85, 55), -- Creepy green
	UpdateRate = 1 / 15,
}

local maid = Utils.CreateMaid()
local initialized = false
local currentHorrorLevel = 0.0
local globalFogPhase = 0.0
local currentSafeRadius = CONFIG.InitialRadius
local startTime = 0

function FogSystem.SetHorrorLevel(level: number)
	currentHorrorLevel = Utils.Clamp(level or 0.0, 0.0, 1.0)
end

function FogSystem.Initialize()
	if initialized then return end
	initialized = true
	startTime = tick()

	-- Throttled server loop
	maid:GiveTask(RunService.Heartbeat:Connect(function(dt: number)
		local now = tick()
		if now - (FogSystem.lastUpdate or 0) < CONFIG.UpdateRate then return end
		FogSystem.lastUpdate = now
		FogSystem.Update(dt or 0.0667)
	end))

	print("[FogSystem] Initialized - Closing Green Smothering Mist Circle Active")
end

function FogSystem.Update(dt: number)
	local elapsed = tick() - startTime
	local progress = math.clamp(elapsed / CONFIG.ShrinkTime, 0, 1)

	-- Closing circle (linear + horror acceleration)
	currentSafeRadius = CONFIG.InitialRadius - (CONFIG.InitialRadius - CONFIG.MinRadius) * progress
	currentSafeRadius = currentSafeRadius * (1 - currentHorrorLevel * 0.3) -- Horror speeds shrink

	-- Global phase (0-1+ for mist intensity)
	globalFogPhase = math.clamp(currentHorrorLevel * (0.7 + 0.4 * math.sin(tick() * 1.1)), 0, 1.4)
end

function FogSystem.GetVisibilityDistance(): number
	return currentSafeRadius * (1.0 - math.clamp(globalFogPhase * 0.6, 0, 0.95))
end

function FogSystem.GetGlobalFogPhase(): number
	return globalFogPhase
end

function FogSystem.GetSafeRadius(): number
	return currentSafeRadius
end

function FogSystem.IsInSafeZone(position: Vector3): boolean
	local center = Vector3.new(0, 50, 0) -- Adjust to map center
	return (position - center).Magnitude <= currentSafeRadius
end

function FogSystem.TriggerHorrorPulse(intensity: number)
	local safe = Utils.Clamp(intensity or 0, 0, 2)
	currentHorrorLevel = Utils.Clamp(currentHorrorLevel + safe * 0.5, 0, 1.0)
end

function FogSystem.Destroy()
	maid:Cleanup()
	initialized = false
end

return FogSystem