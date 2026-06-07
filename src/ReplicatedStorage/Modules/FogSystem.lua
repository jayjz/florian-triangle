--!strict
-- FogSystem.lua (ReplicatedStorage/Modules)
-- Manages server-side Atmosphere for volumetric fog.
-- Horror intensity is pushed from HorrorEvents/GameManager via SetHorrorLevel().
-- Client visuals (ColorCorrection, DepthOfField, etc.) live in ClientHorrorController.

local Utils = require(script.Parent.Utils)
local RunService = Utils.GetService("RunService")
local Lighting = Utils.GetService("Lighting")

local FogSystem = {}
FogSystem.__index = FogSystem

export type FogSystem = typeof(FogSystem)

local CONFIG = {
    Density = 0.7,
    Color = Color3.fromRGB(50, 55, 65),
    FadeSpeed = 0.8,
    VisibilityRange = 80,
    UpdateRate = 1 / 15, -- 15Hz is plenty for fog (was 30Hz)
}

local atmosphere: Atmosphere? = nil
local maid = Utils.CreateMaid()
local lastUpdate = 0
local initialized = false

-- Current horror level is SET by external systems (HorrorEvents / GameManager)
local currentHorrorLevel = 0.0

function FogSystem.SetHorrorLevel(level: number)
    currentHorrorLevel = Utils.Clamp(level or 0.0, 0.0, 1.0)
end

function FogSystem.Initialize()
    if initialized then return end
    initialized = true

    if not atmosphere then
        atmosphere = Instance.new("Atmosphere")
        atmosphere.Density = CONFIG.Density
        atmosphere.Offset = 0.25
        atmosphere.Color = CONFIG.Color
        atmosphere.Decay = Color3.fromRGB(80, 90, 100)
        atmosphere.Glare = 0.1
        atmosphere.Haze = 2.5
        atmosphere.Parent = Lighting
    end

    -- Throttled update loop (15Hz)
    maid:GiveTask(RunService.Heartbeat:Connect(function(dt: number)
        local now = tick()
        if now - lastUpdate < CONFIG.UpdateRate then return end
        lastUpdate = now
        FogSystem.Update(dt or 0.033)
    end))

    print("[FogSystem] Initialized - 15Hz throttled, horrorLevel pushed from game state")
end

function FogSystem.Update(dt: number)
    if not atmosphere then return end

    local horrorLevel = currentHorrorLevel

    local targetDensity = CONFIG.Density + (horrorLevel * 0.6)
    targetDensity = Utils.Clamp(targetDensity, 0.1, 2.0)

    local fade = CONFIG.FadeSpeed * (dt or 1/30) * 60
    fade = Utils.Clamp(fade, 0.0, 1.0)

    local newDensity = Utils.Lerp(
        atmosphere.Density or CONFIG.Density,
        targetDensity,
        fade
    )

    atmosphere.Density = Utils.Clamp(newDensity, 0.1, 2.0)
end

function FogSystem.GetVisibilityDistance(): number
    if not atmosphere then
        return CONFIG.VisibilityRange
    end
    local density = atmosphere.Density or CONFIG.Density
    return CONFIG.VisibilityRange * (1.0 - math.clamp(density * 0.4, 0.0, 0.85))
end

function FogSystem.TriggerHorrorPulse(intensity: number)
    if not atmosphere then return end
    local safeIntensity = Utils.Clamp(intensity or 0, 0, 2)
    currentHorrorLevel = Utils.Clamp(currentHorrorLevel + safeIntensity * 0.4, 0.0, 1.0)
    atmosphere.Density = Utils.Clamp((atmosphere.Density or CONFIG.Density) + safeIntensity * 0.4, 0.4, 1.8)
end

function FogSystem.Destroy()
    maid:Cleanup()
    if atmosphere then
        atmosphere:Destroy()
        atmosphere = nil
    end
    initialized = false
    currentHorrorLevel = 0.0
end

return FogSystem