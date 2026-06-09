--!strict
-- ClientMistController.lua (StarterPlayerScripts/Controllers)
-- Playable Green Smothering Mist - Horror atmosphere without blinding darkness.
-- Works with your current Lighting (Brightness ~0.65-0.75) and Atmosphere (Density 0.14 base).

local Utils = require(game.ReplicatedStorage.Modules.Utils)
local FogSystem = require(game.ReplicatedStorage.Modules.FogSystem)
local RunService = Utils.GetService("RunService")
local Lighting = Utils.GetService("Lighting")

local ClientMistController = {}
local maid = Utils.CreateMaid()

local MIST_CONFIG = {
	ParticleCount = 40,               -- Mobile friendly
	WallHeight = 140,
	WallThickness = 28,
	UpdateRate = 1 / 15,              -- ~15Hz visual updates
	Color = Color3.fromRGB(40, 90, 60), -- Matches your Atmosphere Color
	Transparency = 0.55,              -- Higher base transparency
	BaseDensity = 0.09,               -- Gentle ramp on top of your 0.14
	MaxDensityMultiplier = 0.75,      -- Don't go full black
	MinBrightness = 0.58,             -- Keeps ocean/terrain visible
	AmbientTarget = Color3.fromRGB(22, 38, 32), -- Subtle green tint
}

local mistFolder: Folder? = nil
local mistWalls: {Part} = {}
local lastUpdate = 0
local centerPosition = Vector3.new(0, 60, 0)

local originalAmbient = Lighting.Ambient
local originalBrightness = Lighting.Brightness

local function createMistWall(index: number): Part
	local wall = Instance.new("Part")
	wall.Name = `MistWall_{index}`
	wall.Anchored = true
	wall.CanCollide = false
	wall.Transparency = MIST_CONFIG.Transparency
	wall.Color = MIST_CONFIG.Color
	wall.Material = Enum.Material.ForceField
	wall.Parent = mistFolder
	
	-- Particle effect for volumetric mist
	local emitter = Instance.new("ParticleEmitter")
	emitter.Texture = "rbxassetid://243098098" -- Soft mist particle
	emitter.Color = ColorSequence.new(MIST_CONFIG.Color)
	emitter.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.6),
		NumberSequenceKeypoint.new(1, 1.0)
	})
	emitter.Size = NumberSequence.new(8, 14)
	emitter.Lifetime = NumberRange.new(4, 7)
	emitter.Rate = 18
	emitter.Speed = NumberRange.new(2, 5)
	emitter.SpreadAngle = Vector2.new(25, 25)
	emitter.Parent = wall
	
	return wall
end

function ClientMistController.UpdateMistWalls()
	local now = tick()
	if now - lastUpdate < MIST_CONFIG.UpdateRate then return end
	lastUpdate = now
	
	local radius = FogSystem.GetSafeRadius()
	local phase = FogSystem.GetGlobalFogPhase() -- 0.0 → 1.0 as circle closes
	
	-- Create walls if needed
	if #mistWalls == 0 then
		for i = 1, 24 do
			table.insert(mistWalls, createMistWall(i))
		end
	end
	
	-- Update circular wall positions + properties
	for i, wall in ipairs(mistWalls) do
		local angle = (i / #mistWalls) * (2 * math.pi)
		local x = centerPosition.X + radius * math.cos(angle)
		local z = centerPosition.Z + radius * math.sin(angle)
		
		wall.CFrame = CFrame.new(x, centerPosition.Y, z) * CFrame.Angles(0, angle + math.pi/2, 0)
		
		local thickness = MIST_CONFIG.WallThickness * (1 + phase * 0.7)
		wall.Size = Vector3.new(thickness, MIST_CONFIG.WallHeight * (0.85 + phase * 0.4), 12)
		
		-- Gentle transparency ramp
		wall.Transparency = math.clamp(MIST_CONFIG.Transparency - (phase * 0.28), 0.32, 0.68)
	end
	
	-- Atmosphere + Lighting ramp (gentle, respects your base settings)
	if Lighting:FindFirstChild("Atmosphere") then
		local atm = Lighting.Atmosphere :: Atmosphere
		atm.Density = MIST_CONFIG.BaseDensity + (phase * MIST_CONFIG.MaxDensityMultiplier)
		atm.Decay = atm.Decay:Lerp(Color3.fromRGB(70, 95, 75), phase * 0.4) -- Subtle decay boost
	end
	
	-- Brightness & Ambient control
	Lighting.Brightness = math.max(MIST_CONFIG.MinBrightness, originalBrightness - (phase * 0.65))
	Lighting.Ambient = originalAmbient:Lerp(MIST_CONFIG.AmbientTarget, math.clamp(phase * 0.75, 0, 0.85))
end

function ClientMistController.Initialize()
	if mistFolder then return end
	
	mistFolder = Instance.new("Folder")
	mistFolder.Name = "SmotheringMist"
	mistFolder.Parent = workspace
	
	-- Start update loop
	maid:GiveTask(RunService.Heartbeat:Connect(ClientMistController.UpdateMistWalls))
	
	print("[ClientMistController] Closing Green Smothering Mist initialized (playable visibility)")
end

function ClientMistController.Destroy()
	Lighting.Ambient = originalAmbient
	Lighting.Brightness = originalBrightness
	
	maid:Cleanup()
	
	if mistFolder then
		mistFolder:Destroy()
		mistFolder = nil
	end
	
	table.clear(mistWalls)
end

return ClientMistController