--!strict
-- FogSystem.lua (ReplicatedStorage/Modules)
-- Production-grade closing green Smothering Mist circle for ONE TREASURE PIECE [HORROR].
-- Server = single source of truth for safe radius. Client visuals tuned for performance + atmosphere.
-- References:
-- https://create.roblox.com/docs/environment/lighting/atmosphere
-- https://create.roblox.com/docs/reference/engine/classes/TweenService
-- https://create.roblox.com/docs/reference/engine/classes/RunService

local Utils = require(script.Parent.Utils)
local TweenService = Utils.GetService("TweenService")
local RunService = Utils.GetService("RunService")
local Lighting = Utils.GetService("Lighting")

local FogSystem = {}
FogSystem.__index = FogSystem

local CONFIG = {
    InitialRadius = 450,      -- Large starting play area
    MinRadius = 60,           -- Final deadly zone
    ShrinkTime = 420,         -- ~7 minutes total (slow early, accelerates slightly)
    CenterPosition = Vector3.new(0, 50, 0),
    
    -- Atmosphere tuning (prevents instant pitch black)
    BaseDensity = 0.25,       -- Gentle start
    MaxDensity = 1.8,         -- Heavy at end, but not blinding
    FogColor = Color3.fromRGB(35, 85, 55), -- Creepy green
    DecayStartDelay = 60,     -- First minute is almost static
}

local currentSafeRadius = CONFIG.InitialRadius
local shrinkTween: Tween? = nil
local radiusValue: NumberValue? = nil
local initialized = false
local maid = Utils.CreateMaid()

-- Server truth: Start the closing circle (called from RoundManager.StartRound())
function FogSystem.StartClosingCircle()
    if shrinkTween then
        shrinkTween:Cancel()
    end

    -- Create tween target if missing
    if not radiusValue then
        radiusValue = Instance.new("NumberValue")
        radiusValue.Name = "FogRadius"
        radiusValue.Value = CONFIG.InitialRadius
        radiusValue.Parent = game.ReplicatedStorage
        maid:GiveTask(radiusValue)
    end

    radiusValue.Value = CONFIG.InitialRadius

    local tweenInfo = TweenInfo.new(
        CONFIG.ShrinkTime,
        Enum.EasingStyle.Sine,      -- Smooth, natural feel
        Enum.EasingDirection.Out,
        0, false, 0
    )

    shrinkTween = TweenService:Create(radiusValue, tweenInfo, {Value = CONFIG.MinRadius})
    shrinkTween:Play()

    print("[FogSystem] Closing circle started - Mist is now active (slow ramp)")
end

function FogSystem.Initialize()
    if initialized then return end
    initialized = true

    -- Heartbeat to sync current radius from tween
    maid:GiveTask(RunService.Heartbeat:Connect(function()
        if radiusValue then
            currentSafeRadius = radiusValue.Value
        end
    end))

    -- Optional: Gentle initial atmosphere setup
    local atmosphere = Lighting:FindFirstChild("Atmosphere") or Instance.new("Atmosphere")
    atmosphere.Density = CONFIG.BaseDensity
    atmosphere.Color = CONFIG.FogColor
    atmosphere.Parent = Lighting

    print("[FogSystem] Initialized - Closing Green Smothering Mist ready")
end

function FogSystem.GetSafeRadius(): number
    return currentSafeRadius
end

function FogSystem.IsInSafeZone(position: Vector3): boolean
    return (position - CONFIG.CenterPosition).Magnitude <= currentSafeRadius
end

-- Normalized 0-1 progress for client visuals / sanity
function FogSystem.GetGlobalFogPhase(): number
    local progress = (CONFIG.InitialRadius - currentSafeRadius) / (CONFIG.InitialRadius - CONFIG.MinRadius)
    return math.clamp(progress, 0, 1)
end

-- Sanity drain: ZERO inside safe zone, ramps with distance outside
function FogSystem.GetSanityDrainMultiplier(position: Vector3): number
    if FogSystem.IsInSafeZone(position) then
        return 0.0
    end
    local distanceOutside = (position - CONFIG.CenterPosition).Magnitude - currentSafeRadius
    -- Gentle ramp so it doesn't feel punishing too early
    return 1.0 + (distanceOutside * 0.008)
end

-- Cleanup
function FogSystem.Destroy()
    if shrinkTween then
        shrinkTween:Cancel()
    end
    maid:Cleanup()
    if radiusValue then
        radiusValue:Destroy()
        radiusValue = nil
    end
end

return FogSystem