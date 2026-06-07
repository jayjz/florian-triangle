--!strict
-- FogSystem.lua (ReplicatedStorage/Modules)
-- Smothering Mist Server Architecture (Priority 0 refactor).
-- Server = Truth: Calculates GlobalFogPhase based on horrorLevel + time. NO graphics rendering on server (no Atmosphere instance).
-- Client = Perception: Clients will read GlobalFogPhase via remote or replicated value to render mist (moved from server in this fix).
-- Removed all Instance.new("Atmosphere"), atmosphere var, Density updates. Keeps 15Hz throttled loop for phase calculation only.
-- Fixes previous review: No server visuals. No API mismatches. Maid, strict typing, performance comments preserved.
-- GetVisibilityDistance now uses GlobalFogPhase for AI/culling.
-- Author: Fog Sea Architect - 2026-06-08

local Utils = require(script.Parent.Utils)
local RunService = Utils.GetService("RunService")

local FogSystem = {}
FogSystem.__index = FogSystem

export type FogSystem = typeof(FogSystem)

local CONFIG = {
    VisibilityRange = 80,
    UpdateRate = 1 / 15, -- 15Hz for phase calculation (mobile friendly, no visuals)
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
end

return FogSystem
