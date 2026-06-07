--!strict
-- ClientCombatController.lua (StarterPlayerScripts/Controllers)
-- Client-only combat visual system for Fog Sea.
-- Renders smooth, pooled projectiles from server EntityAI ranged attacks.
-- Pure visuals — no game logic, no damage, no server communication.

local Utils = require(game.ReplicatedStorage.Modules.Utils)
local RunService = Utils.GetService("RunService")
local TweenService = Utils.GetService("TweenService")
local Workspace = Utils.GetService("Workspace")

local ClientCombatController = {}
local maid = Utils.CreateMaid()

local RangedAttackRemote = Utils.CreateRemoteEvent("EntityRangedAttack")

local projectilePool: {Part} = {}
local activeProjectiles: {{ 
    Part: Part, 
    StartTime: number, 
    Origin: Vector3, 
    Target: Vector3 
}} = {}

local CONFIG = {
    ProjectileSpeed = 65,
    Lifetime = 1.8,
    PoolSize = 12,           -- Good balance for co-op on mobile
    ImpactTweenTime = 0.25,
}

-- ==================== PROJECTILE POOLING ====================

local function createProjectile(): Part
    local p = Instance.new("Part")
    p.Name = "RangedProjectile"
    p.Size = Vector3.new(0.8, 0.8, 4.5)
    p.Color = Color3.fromRGB(200, 40, 20)
    p.Material = Enum.Material.Neon
    p.Anchored = true
    p.CanCollide = false
    p.Transparency = 0.2
    p.CastShadow = false
    return p
end

local function getProjectile(): Part
    if #projectilePool > 0 then
        local p = table.remove(projectilePool) :: Part
        p.Transparency = 0.2
        p.Size = Vector3.new(0.8, 0.8, 4.5)
        return p
    end
    return createProjectile()
end

local function returnProjectile(p: Part)
    if not p then return end
    p.Parent = nil
    p.Transparency = 1
    table.insert(projectilePool, p)
end

-- Pre-warm pool for mobile performance
for _ = 1, CONFIG.PoolSize do
    table.insert(projectilePool, createProjectile())
end

-- ==================== RENDER LOOP (Efficient) ====================

local function updateProjectiles(dt: number)
    local now = tick()
    for i = #activeProjectiles, 1, -1 do
        local proj = activeProjectiles[i]
        local elapsed = now - proj.StartTime
        local t = elapsed / CONFIG.Lifetime

        if t >= 1 then
            returnProjectile(proj.Part)
            table.remove(activeProjectiles, i)
        else
            local pos = proj.Origin:Lerp(proj.Target, math.min(t * 1.65, 1))
            proj.Part.Position = pos
            proj.Part.CFrame = CFrame.lookAt(pos, proj.Target)
        end
    end
end

maid:GiveTask(RunService.RenderStepped:Connect(updateProjectiles))

-- ==================== REMOTE HANDLING ====================

RangedAttackRemote.OnClientEvent:Connect(function(origin: Vector3, target: Vector3)
    if typeof(origin) ~= "Vector3" or typeof(target) ~= "Vector3" then
        return
    end

    local projectile = getProjectile()
    projectile.Parent = Workspace

    table.insert(activeProjectiles, {
        Part = projectile,
        StartTime = tick(),
        Origin = origin,
        Target = target,
    })

    -- Impact effect
    task.delay(CONFIG.Lifetime, function()
        if projectile.Parent then
            local impactTween = TweenService:Create(
                projectile,
                TweenInfo.new(CONFIG.ImpactTweenTime, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
                { Transparency = 1, Size = Vector3.new(0.3, 0.3, 0.3) }
            )
            impactTween:Play()
            impactTween.Completed:Connect(function()
                returnProjectile(projectile)
            end)
        end
    end)
end)

-- ==================== LIFECYCLE ====================

function ClientCombatController.Initialize()
    print("[ClientCombatController] Initialized - Pooled projectile visuals ready (mobile optimized)")
end

function ClientCombatController.Destroy()
    maid:Cleanup()

    for _, proj in activeProjectiles do
        returnProjectile(proj.Part)
    end
    table.clear(activeProjectiles)

    for _, p in projectilePool do
        p:Destroy()
    end
    table.clear(projectilePool)
end

return ClientCombatController