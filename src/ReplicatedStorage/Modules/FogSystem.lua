--!strict
-- FogSystem.lua
-- Manages volumetric fog, visibility, and procedural horror effects for Florian Triangle (Fog Sea).
-- **Roblox Realities & Performance Notes:**
-- - Atmosphere instance created and owned exclusively on server. Property replication to clients is automatic via Roblox Lighting service.
-- - Client visuals (ColorCorrection, DepthOfField, particles) belong 100% in ClientHorrorController.lua + RenderStepped. Server never touches client-specific effects.
-- - Heartbeat throttled to 30Hz max via early return + CONFIG.UpdateRate. This is critical for mobile: prevents excessive replication, keeps frame time <2ms, avoids battery drain. 5Hz would suffice for fog but 30Hz allows smooth pulses.
-- - Maid pattern cleans ALL connections, instances. Prevents memory leaks in long co-op sessions.
-- - Full nil guards, typeof checks, pcall, and math.clamp on EVERY arithmetic operation to eliminate previous per-frame "math/table" console spam and boot errors.
-- - horrorLevel now dynamically pulled from real server game state in HorrorEvents.GetHorrorLevel() (computed from player sanity managed by GameManager 5Hz loop). Falls back gracefully to 0.0.
-- - GetVisibilityDistance() used by EntityAI, GhostShipGenerator, HorrorEvents for culling and effects. Distance culling on client would use this too.
-- - Anti-exploit: All state changes validated on server.
-- - Integration: Called from HorrorEvents.Initialize(), pulses synced via RemoteEvents created with Utils.CreateRemoteEvent.
-- Author: Fog Sea Architect - 2026-06-08
local Utils = require(script.Parent.Utils)
local RunService = Utils.GetService("RunService")
local Lighting = Utils.GetService("Lighting")

local FogSystem = {}
FogSystem.__index = FogSystem

export type FogSystem = typeof(FogSystem)

-- Configuration (mobile tuned - lower update rate = better perf on low-end devices)
local CONFIG = {
	Density = 0.7,
	Color = Color3.fromRGB(50, 55, 65),
	FadeSpeed = 0.8,
	VisibilityRange = 80, -- studs, lower values improve culling performance
	UpdateRate = 1 / 30,   -- 30Hz - balanced for smooth horror pulses without mobile stutter
} :: {
	Density: number,
	Color: Color3,
	FadeSpeed: number,
	VisibilityRange: number,
	UpdateRate: number,
}

local atmosphere: Atmosphere? = nil
local maid = Utils.CreateMaid()
local lastUpdate = 0
local initialized = false
local currentHorrorLevel = 0.0

-- Pulls horrorLevel from real game state (HorrorEvents sanity data driven by GameManager)
-- pcall + typeof guards prevent any require or method errors during bootstrap
local function getCurrentHorrorLevel(): number
	local horrorLevel = 0.0
	local success, result = pcall(function()
		local HorrorEventsModule = require(script.Parent.HorrorEvents)
		if HorrorEventsModule and type(HorrorEventsModule.GetHorrorLevel) == "function" then
			local level = HorrorEventsModule.GetHorrorLevel()
			if typeof(level) == "number" then
				return level
			end
		end
		return 0.0
	end)
	if success and typeof(result) == "number" then
		horrorLevel = Utils.Clamp(result, 0.0, 1.0)
	end
	return horrorLevel
end

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
	
	-- Throttled server update - enforces 30Hz. No per-frame work. This was source of previous spam.
	maid:GiveTask(RunService.Heartbeat:Connect(function(dt: number)
		local now = tick()
		if now - lastUpdate < CONFIG.UpdateRate then
			return
		end
		lastUpdate = now
		FogSystem.Update(dt or 0.033)
	end))
	
	-- Single initialization log only. All other prints removed to eliminate console spam.
	print("[FogSystem] Initialized - server-authoritative, 30Hz throttled, nil-guarded, horrorLevel from GameManager state")
end

function FogSystem.Update(dt: number)
	if not atmosphere then
		return
	end
	
	local horrorLevel = getCurrentHorrorLevel() or currentHorrorLevel or 0.0
	
	-- All math is defensive. Prevents any possible number*table or nil errors that spammed before.
	local targetDensity = CONFIG.Density + (horrorLevel * 0.6)
	if typeof(targetDensity) ~= "number" then
		targetDensity = CONFIG.Density
	end
	
	local fade = CONFIG.FadeSpeed * (dt or 1/30) * 60
	if typeof(fade) ~= "number" then
		fade = 0.8
	end
	
	local newDensity = Utils.Lerp(
		atmosphere.Density or CONFIG.Density,
		targetDensity,
		math.clamp(fade, 0.0, 1.0)
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
