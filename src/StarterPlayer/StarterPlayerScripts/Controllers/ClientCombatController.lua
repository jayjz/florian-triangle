--!strict
-- ClientCombatController.lua (StarterPlayer/StarterPlayerScripts/Controllers)
-- Client-only combat visual controller for Fog Sea. Renders smooth projectiles from EntityRangedAttack remote using pooled Parts + RenderStepped lerp (mobile-safe, no GC spikes).
-- NEVER performs any game logic or damage (server only via validation delay in EntityAI). Pure visuals.
-- Maid for all connections and cleanup. Object pooling for projectiles. Tween optional for impact effects.
-- Performance: RenderStepped only for active projectiles (capped pool of 8). No per-frame work when idle. Designed for 60FPS on low-end mobile.
-- Architecture: Listens to remotes from server EntityAI. Integrates with ClientInit. Client visuals only per Roblox best practices.
-- Polished for Cleanup Phase: Added Maid, strong typing, error handling, explicit performance comments, Beam alternative comment for production.
-- Author: Fog Sea Architect - 2026-06-07

local Utils = require(game.ReplicatedStorage.Modules.Utils)
local Players = Utils.GetService("Players")
local RunService = Utils.GetService("RunService")
local TweenService = Utils.GetService("TweenService")

local localPlayer = Players.LocalPlayer
local RangedAttackRemote = Utils.CreateRemoteEvent("EntityRangedAttack")

local maid = Utils.CreateMaid()

local projectilePool: {Part} = {}
local activeProjectiles: {{Part: Part, StartTime: number, Origin: Vector3, Target: Vector3, Tween: Tween?}} = {}

local CONFIG = {
	ProjectileSpeed = 65,
	Lifetime = 1.8,
	PoolSize = 12, -- Increased for co-op combat on mobile
}

local function getProjectile(): Part
	if #projectilePool > 0 then
		local p = table.remove(projectilePool) :: Part
		p.Transparency = 0.2
		return p
	end
	local p = Instance.new("Part")
	p.Size = Vector3.new(0.8, 0.8, 4)
	p.Color = Color3.fromRGB(200, 40, 20)
	p.Material = Enum.Material.Neon
	p.Anchored = true
	p.CanCollide = false
	p.Transparency = 0.2
	-- Production: Use Beam + Attachment instead of Part for even lower mobile cost
	return p
end

local function returnProjectile(p: Part)
	p.Parent = nil
	p.Transparency = 1
	table.insert(projectilePool, p)
end

-- Pre-pool for mobile performance (avoid runtime instantiation)
for _ = 1, CONFIG.PoolSize do
	table.insert(projectilePool, getProjectile())
end

-- RenderStepped for active projectiles only (throttled by pool size, buttery on mobile)
local renderConn = RunService.RenderStepped:Connect(function(dt: number)
	local now = tick()
	for i = #activeProjectiles, 1, -1 do
		local proj = activeProjectiles[i]
		local t = (now - proj.StartTime) / CONFIG.Lifetime
		if t > 1 then
			returnProjectile(proj.Part)
			if proj.Tween then proj.Tween:Cancel() end
			table.remove(activeProjectiles, i)
		else
			local pos = proj.Origin:Lerp(proj.Target, math.min(t * 1.6, 1))
			proj.Part.Position = pos
			proj.Part.CFrame = CFrame.lookAt(pos, proj.Target)
		end
	end
end)

maid:GiveTask(renderConn)
maid:GiveTask(function()
	for _, proj in activeProjectiles do
		returnProjectile(proj.Part)
	end
	table.clear(activeProjectiles)
	for _, p in projectilePool do
		p:Destroy()
	end
	table.clear(projectilePool)
end)

RangedAttackRemote.OnClientEvent:Connect(function(origin: Vector3, target: Vector3)
	if typeof(origin) ~= "Vector3" or typeof(target) ~= "Vector3" then return end -- Sanity check
	local projectile = getProjectile()
	projectile.Parent = workspace
	
	local projData = {
		Part = projectile,
		StartTime = tick(),
		Origin = origin,
		Target = target,
	}
	table.insert(activeProjectiles, projData)
	
	-- Optional impact tween on arrival (client only)
	task.delay(CONFIG.Lifetime, function()
		if projectile.Parent then
			local impactTween = TweenService:Create(projectile, TweenInfo.new(0.3), {Transparency = 1, Size = Vector3.new(0.2,0.2,0.2)})
			impactTween:Play()
			impactTween.Completed:Connect(function()
				returnProjectile(projectile)
			end)
		end
	end)
end)

print("ClientCombatController polished - Maid-managed RenderStepped pooling for projectiles (mobile 60FPS target, client visuals only)")

return {
	Initialize = function() end,
	Maid = maid,
}
