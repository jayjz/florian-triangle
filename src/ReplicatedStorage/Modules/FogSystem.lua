--!strict
-- FogSystem.lua (ReplicatedStorage/Modules)
<<<<<<< HEAD
-- Green "Smothering Mist" for Florian Triangle ocean horror.
-- Server Atmosphere management + Lighting reset (fixes "lighting fucked" loops).
-- HorrorLevel from HorrorEvents/GameManager drives thickening + closing pressure feel.
-- Client effects still in ClientHorrorController.
=======
-- Smothering Mist Server Architecture (Priority 0 refactor).
-- Server = Truth: Calculates GlobalFogPhase based on horrorLevel + time. NO graphics rendering on server (no Atmosphere instance).
-- Client = Perception: Clients will read GlobalFogPhase via remote or replicated value to render mist (moved from server in this fix).
-- Removed all Instance.new("Atmosphere"), atmosphere var, Density updates. Keeps 15Hz throttled loop for phase calculation only.
-- Fixes previous review: No server visuals. No API mismatches. Maid, strict typing, performance comments preserved.
-- GetVisibilityDistance now uses GlobalFogPhase for AI/culling.
-- Author: Fog Sea Architect - 2026-06-08
>>>>>>> 9e2c2a5f16f22fffc394f3d6c56ea9d2b19eea95

local Utils = require(script.Parent.Utils)
local RunService = Utils.GetService("RunService")

local FogSystem = {}
FogSystem.__index = FogSystem

local CONFIG = {
<<<<<<< HEAD
	Density = 0.35,           -- Lower start = visible at game start
	Color = Color3.fromRGB(35, 85, 55),   -- Creepy green mist (One Piece Florian vibe)
	FadeSpeed = 0.85,
	VisibilityRange = 140,    -- Bigger ocean playspace
	UpdateRate = 1 / 15,
=======
    VisibilityRange = 80,
    UpdateRate = 1 / 15, -- 15Hz for phase calculation (mobile friendly, no visuals)
>>>>>>> 9e2c2a5f16f22fffc394f3d6c56ea9d2b19eea95
}

local maid = Utils.CreateMaid()
local lastUpdate = 0
local initialized = false
local currentHorrorLevel = 0.0
local GlobalFogPhase = 0.0 -- Server truth for Smothering Mist intensity over time

function FogSystem.SetHorrorLevel(level: number)
	currentHorrorLevel = Utils.Clamp(level or 0.0, 0.0, 1.0)
end

function FogSystem.Initialize()
	if initialized then return end
	initialized = true

<<<<<<< HEAD
	-- === CRITICAL LIGHTING RESET (fixes most "no fog" + lighting broken issues) ===
	Lighting.Ambient = Color3.fromRGB(30, 40, 45)
	Lighting.Brightness = 0.6
	Lighting.ClockTime = 2.5          -- Dark eerie ocean night
	Lighting.FogEnd = 400
	Lighting.FogColor = CONFIG.Color
	Lighting.EnvironmentDiffuseScale = 0.4
	Lighting.EnvironmentSpecularScale = 0.2

	-- Ensure Sky exists (Atmosphere REQUIRES Sky in Lighting)
	if not Lighting:FindFirstChildOfClass("Sky") then
		local sky = Instance.new("Sky")
		sky.Parent = Lighting
	end

	if not atmosphere then
		atmosphere = Instance.new("Atmosphere")
		atmosphere.Density = CONFIG.Density
		atmosphere.Offset = 0.28
		atmosphere.Color = CONFIG.Color
		atmosphere.Decay = Color3.fromRGB(25, 65, 45)
		atmosphere.Glare = 0.12
		atmosphere.Haze = 2.8          -- Strong misty feel
		atmosphere.Parent = Lighting
	end

	-- Throttled update
	maid:GiveTask(RunService.Heartbeat:Connect(function(dt: number)
		local now = tick()
		if now - lastUpdate < CONFIG.UpdateRate then return end
		lastUpdate = now
		FogSystem.Update(dt or 0.033)
	end))

	print("[FogSystem] Initialized - Green Smothering Mist (Ocean Horror Ready)")
end

function FogSystem.Update(dt: number)
	if not atmosphere then return end
	local targetDensity = CONFIG.Density + (currentHorrorLevel * 0.75)  -- Stronger ramp
	targetDensity = Utils.Clamp(targetDensity, 0.15, 2.2)

	local fade = CONFIG.FadeSpeed * (dt or 1/30) * 60
	local newDensity = Utils.Lerp(atmosphere.Density or CONFIG.Density, targetDensity, fade)
	atmosphere.Density = Utils.Clamp(newDensity, 0.15, 2.2)
end

function FogSystem.GetVisibilityDistance(): number
	if not atmosphere then return CONFIG.VisibilityRange end
	local density = atmosphere.Density or CONFIG.Density
	return CONFIG.VisibilityRange * (1.0 - math.clamp(density * 0.45, 0.0, 0.9))
end

function FogSystem.TriggerHorrorPulse(intensity: number)
	if not atmosphere then return end
	local safe = Utils.Clamp(intensity or 0, 0, 2)
	currentHorrorLevel = Utils.Clamp(currentHorrorLevel + safe * 0.45, 0.0, 1.0)
	atmosphere.Density = Utils.Clamp((atmosphere.Density or CONFIG.Density) + safe * 0.5, 0.4, 2.0)
end

function FogSystem.Destroy()
	maid:Cleanup()
	if atmosphere then
		atmosphere:Destroy()
		atmosphere = nil
	end
	initialized = false
	currentHorrorLevel = 0.0
=======
    -- 15Hz Heartbeat for phase calculation only (no visuals, per refactor)
    maid:GiveTask(RunService.Heartbeat:Connect(function(dt: number)
        local now = tick()
        if now - lastUpdate < CONFIG.UpdateRate then return end
        lastUpdate = now
        FogSystem.Update(dt or 0.0667)
    end))

    print("[FogSystem] Initialized - Smothering Mist Server Architecture (phase only, no Atmosphere on server)")
end

function FogSystem.Update(dt: number)
    -- Calculate GlobalFogPhase based on currentHorrorLevel and time (sinusoidal variation for natural mist pulsing)
    -- This is the server truth. Clients perceive via remotes.
    GlobalFogPhase = currentHorrorLevel * (0.6 + 0.4 * math.sin(tick() * 1.2))
    GlobalFogPhase = Utils.Clamp(GlobalFogPhase, 0.0, 1.2)
end

function FogSystem.GetVisibilityDistance(): number
    -- Uses GlobalFogPhase (server truth) instead of Atmosphere density
    return CONFIG.VisibilityRange * (1.0 - math.clamp(GlobalFogPhase * 0.55, 0.0, 0.9))
end

function FogSystem.TriggerHorrorPulse(intensity: number)
    local safeIntensity = Utils.Clamp(intensity or 0, 0, 2)
    currentHorrorLevel = Utils.Clamp(currentHorrorLevel + safeIntensity * 0.5, 0.0, 1.0)
    -- Update phase immediately for responsive mist
    GlobalFogPhase = currentHorrorLevel * (0.6 + 0.4 * math.sin(tick() * 1.2))
    GlobalFogPhase = Utils.Clamp(GlobalFogPhase, 0.0, 1.2)
end

function FogSystem.GetGlobalFogPhase(): number
    return GlobalFogPhase
end

function FogSystem.Destroy()
    maid:Cleanup()
    initialized = false
    currentHorrorLevel = 0.0
    GlobalFogPhase = 0.0
>>>>>>> 9e2c2a5f16f22fffc394f3d6c56ea9d2b19eea95
end

return FogSystem
