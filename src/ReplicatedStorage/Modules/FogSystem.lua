--!strict
-- FogSystem.lua (ReplicatedStorage/Modules)
-- Green "Smothering Mist" for Florian Triangle ocean horror.
-- Server Atmosphere management + Lighting reset (fixes "lighting fucked" loops).
-- HorrorLevel from HorrorEvents/GameManager drives thickening + closing pressure feel.
-- Client effects still in ClientHorrorController.

local Utils = require(script.Parent.Utils)
local RunService = Utils.GetService("RunService")
local Lighting = Utils.GetService("Lighting")

local FogSystem = {}
FogSystem.__index = FogSystem

local CONFIG = {
	Density = 0.35,           -- Lower start = visible at game start
	Color = Color3.fromRGB(35, 85, 55),   -- Creepy green mist (One Piece Florian vibe)
	FadeSpeed = 0.85,
	VisibilityRange = 140,    -- Bigger ocean playspace
	UpdateRate = 1 / 15,
}

local atmosphere: Atmosphere? = nil
local maid = Utils.CreateMaid()
local lastUpdate = 0
local initialized = false
local currentHorrorLevel = 0.0

function FogSystem.SetHorrorLevel(level: number)
	currentHorrorLevel = Utils.Clamp(level or 0.0, 0.0, 1.0)
end

function FogSystem.Initialize()
	if initialized then return end
	initialized = true

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
end

return FogSystem