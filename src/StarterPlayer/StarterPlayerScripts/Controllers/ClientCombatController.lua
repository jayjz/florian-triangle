--!strict
-- ClientCombatController.lua (LocalScript)
-- Handles client-side visual rendering of combat effects for zero-latency feel.
-- Listens to EntityRangedAttack RemoteEvent and tweens projectiles locally using RunService.RenderStepped.
-- Never trusts server visuals. Pure client rendering for smooth horror experience on mobile.
-- Uses object pooling for projectiles to avoid GC spikes.
-- Author: Fog Sea Architect - 2026-06-06

local Utils = require(game.ReplicatedStorage.Modules.Utils)
local Players = Utils.GetService("Players")
local RunService = Utils.GetService("RunService")
local TweenService = Utils.GetService("TweenService")

local localPlayer = Players.LocalPlayer
local RangedAttackRemote = Utils.CreateRemoteEvent("EntityRangedAttack")

local projectilePool: {Part} = {}
local activeProjectiles: { {Part: Part, StartTime: number, Origin: Vector3, Target: Vector3} } = {}

local CONFIG = {
	ProjectileSpeed = 65,
	Lifetime = 2.0,
	PoolSize = 8,
}

-- Create pooled projectile
local function getProjectile(): Part
	if #projectilePool > 0 then
		return table.remove(projectilePool) :: Part
	end
	local p = Instance.new("Part")
	p.Size = Vector3.new(1.2, 1.2, 3.5)
	p.Color = Color3.fromRGB(190, 30, 30)
	p.Material = Enum.Material.Neon
	p.Anchored = true
	p.CanCollide = false
	p.Transparency = 0.2
	return p
end

local function returnProjectile(p: Part)
	p.Parent = nil
	table.insert(projectilePool, p)
end

-- Render loop for smooth client-side projectiles (RenderStepped = buttery smooth on mobile)
local connection
local function startRenderLoop()
	if connection then return end
	connection = RunService.RenderStepped:Connect(function(dt: number)
		local now = tick()
		for i = #activeProjectiles, 1, -1 do
			local proj = activeProjectiles[i]
			local t = (now - proj.StartTime) / CONFIG.Lifetime
			if t > 1 then
				returnProjectile(proj.Part)
				table.remove(activeProjectiles, i)
			else
				local pos = proj.Origin:Lerp(proj.Target, t * 1.8) -- overshoot for speed feel
				proj.Part.Position = pos
				proj.Part.CFrame = CFrame.lookAt(pos, proj.Target)
			end
		end
	end)
end

RangedAttackRemote.OnClientEvent:Connect(function(origin: Vector3, target: Vector3)
	local projectile = getProjectile()
	projectile.Parent = workspace
	
	table.insert(activeProjectiles, {
		Part = projectile,
		StartTime = tick(),
		Origin = origin,
		Target = target,
	})
	
	startRenderLoop()
	
	-- Auto cleanup
	task.delay(CONFIG.Lifetime + 0.5, function()
		if projectile.Parent then
			returnProjectile(projectile)
		end
	end)
end)

print("ClientCombatController initialized - Smooth client-side projectile rendering active")
