--!strict
-- FogSystem.lua
-- Manages volumetric fog, visibility, and procedural horror effects for Florian Triangle.
-- Heavily optimized for mobile. Uses Atmosphere + ParticleEmitters + clever scripting.
-- Performance target: < 2ms per frame on low-end devices.
-- Author: Fog Sea Architect - 2026-06-06

local Utils = require(script.Parent.Utils)
local RunService = Utils.GetService("RunService")
local Lighting = Utils.GetService("Lighting")

local FogSystem = {}
FogSystem.__index = FogSystem

export type FogSystem = typeof(FogSystem)

-- Configuration (tunable for performance vs visual fidelity)
local CONFIG = {
	Density = 0.7,
	Color = Color3.fromRGB(50, 55, 65),
	FadeSpeed = 0.8,
	VisibilityRange = 80, -- studs. Lower = better performance
	UpdateRate = 1 / 30,   -- 30Hz updates (mobile friendly)
}

local self = setmetatable({}, FogSystem)
local maid = Utils.CreateMaid()
local lastUpdate = 0

-- Main Atmosphere object (most performant way to do dense fog on Roblox)
local atmosphere: Atmosphere

function FogSystem.Initialize()
	if atmosphere then return end
	
	atmosphere = Instance.new("Atmosphere")
	atmosphere.Density = CONFIG.Density
	atmosphere.Offset = 0.25
	atmosphere.Color = CONFIG.Color
	atmosphere.Decay = Color3.fromRGB(80, 90, 100)
	atmosphere.Glare = 0.1
	atmosphere.Haze = 2.5
	atmosphere.Parent = Lighting
	
	-- Connection for dynamic fog based on horror level
	maid:GiveTask(RunService.Heartbeat:Connect(function(dt: number)
		local now = tick()
		if now - lastUpdate < CONFIG.UpdateRate then return end
		lastUpdate = now
		
		FogSystem:Update(dt)
	end))
	
	print("FogSystem initialized - Mobile optimized volumetric fog active")
end

function FogSystem.Update(dt: number)
	-- Procedural intensity based on "horror level" (to be expanded)
	local horrorLevel = 0.3 -- placeholder, will be driven by game state
	
	atmosphere.Density = Utils.Lerp(
		atmosphere.Density, 
		CONFIG.Density + horrorLevel * 0.6, 
		CONFIG.FadeSpeed * dt * 60
	)
	
	-- TODO: Add distance-based fog culling and particle management
	-- Note: Avoid updating too many properties per frame on mobile
end

-- Dynamic visibility control for ghost ships and effects
function FogSystem.GetVisibilityDistance(): number
	return CONFIG.VisibilityRange * (1 - atmosphere.Density * 0.4)
end

-- Horror pulse effect (used when player is in danger)
function FogSystem.TriggerHorrorPulse(intensity: number)
	-- Will drive particle systems and sound later
	atmosphere.Density = math.clamp(atmosphere.Density + intensity * 0.4, 0.4, 1.8)
end

function FogSystem.Destroy()
	maid:Cleanup()
	if atmosphere then
		atmosphere:Destroy()
		atmosphere = nil
	end
end

return FogSystem
