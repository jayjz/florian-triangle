--!strict
-- ClientMistController.lua (StarterPlayerScripts/Controllers)
-- Closing Green Smothering Mist Circle - Fortnite-style visual horror.
-- Uses FogSystem server truth (GetSafeRadius + GetGlobalFogPhase) to drive
-- dynamic particle walls / dome that shrink and thicken over time.
-- Mobile 60FPS friendly, Maid cleanup, debounced updates.

local Utils = require(game.ReplicatedStorage.Modules.Utils)
local RunService = Utils.GetService("RunService")
local FogSystem = require(game.ReplicatedStorage.Modules.FogSystem)
local Lighting = Utils.GetService("Lighting")

local ClientMistController = {}
local maid = Utils.CreateMaid()

local MIST_CONFIG = {
	ParticleCount = 45,           -- Performance tuned for mobile
	WallHeight = 120,
	WallThickness = 25,
	UpdateRate = 1 / 12,          -- 12Hz visual updates
	Color = Color3.fromRGB(35, 85, 55),
	Transparency = 0.35,
}

local mistFolder: Folder? = nil
local mistWalls: {Part} = {}
local lastUpdate = 0
local centerPosition = Vector3.new(0, 60, 0)  -- Map center - adjust in Studio if needed

function ClientMistController.Initialize()
	if mistFolder then return end

	mistFolder = Instance.new("Folder")
	mistFolder.Name = "SmotheringMist"
	mistFolder.Parent = workspace

	-- Create initial circular wall segments
	for i = 1, MIST_CONFIG.ParticleCount do
		local wall = Instance.new("Part")
		wall.Name = "MistWall"
		wall.Anchored = true
		wall.CanCollide = false
		wall.Transparency = MIST_CONFIG.Transparency
		wall.Color = MIST_CONFIG.Color
		wall.Material = Enum.Material.ForceField  -- Ethereal mist look
		wall.Size = Vector3.new(MIST_CONFIG.WallThickness, MIST_CONFIG.WallHeight, 8)
		wall.Parent = mistFolder

		-- Add subtle particle emitter for volumetric feel
		local emitter = Instance.new("ParticleEmitter")
		emitter.Texture = "rbxassetid://243098098"  -- Soft mist particle
		emitter.Color = ColorSequence.new(MIST_CONFIG.Color)
		emitter.Transparency = NumberSequence.new(0.6, 1)
		emitter.Size = NumberSequence.new(4, 8)
		emitter.Lifetime = NumberRange.new(2, 4)
		emitter.Rate = 8
		emitter.Speed = NumberRange.new(1, 3)
		emitter.Parent = wall

		table.insert(mistWalls, wall)
	end

	maid:GiveTask(RunService.Heartbeat:Connect(function(dt: number)
		local now = tick()
		if now - lastUpdate < MIST_CONFIG.UpdateRate then return end
		lastUpdate = now
		ClientMistController:UpdateMistWalls()
	end))

	print("[ClientMistController] Closing Green Smothering Mist initialized")
end

function ClientMistController:UpdateMistWalls()
	local radius = FogSystem.GetSafeRadius()
	local phase = FogSystem.GetGlobalFogPhase()

	for i, wall in ipairs(mistWalls) do
		local angle = (i / #mistWalls) * (math.pi * 2)
		local x = centerPosition.X + math.cos(angle) * radius
		local z = centerPosition.Z + math.sin(angle) * radius

		wall.Position = Vector3.new(x, centerPosition.Y, z)
		wall.Orientation = Vector3.new(0, math.deg(angle) + 90, 0)

		-- Dynamic thickness & opacity based on phase
		local thickness = MIST_CONFIG.WallThickness * (1 + phase * 0.6)
		wall.Size = Vector3.new(thickness, MIST_CONFIG.WallHeight * (0.8 + phase * 0.4), 8)
		wall.Transparency = math.clamp(MIST_CONFIG.Transparency - phase * 0.25, 0.1, 0.65)
	end

	-- Global atmosphere boost from client side
	if Lighting:FindFirstChild("Atmosphere") then
		local atm = Lighting.Atmosphere :: Atmosphere
		atm.Density = 0.4 + phase * 1.1
	end
end

function ClientMistController.Destroy()
	maid:Cleanup()
	if mistFolder then
		mistFolder:Destroy()
		mistFolder = nil
	end
	table.clear(mistWalls)
end

return ClientMistController
