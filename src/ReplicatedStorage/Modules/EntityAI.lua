--!strict
-- EntityAI.lua (ReplicatedStorage/Modules)
-- Production server-authoritative corrupted pirate AI for Fog Sea horror.
-- Combines state machine, proper pathfinding, ranged attacks with client visuals, fog culling, and Maid cleanup.

local Utils = require(script.Parent.Utils)
local FogSystem = require(script.Parent.FogSystem)
local HorrorEvents = require(script.Parent.HorrorEvents)
local CollectionService = Utils.GetService("CollectionService")
local RunService = Utils.GetService("RunService")
local PathfindingService = Utils.GetService("PathfindingService")
local Workspace = Utils.GetService("Workspace")
local Players = Utils.GetService("Players")

local EntityAI = {}
EntityAI.__index = EntityAI

export type EntityState = "Idle" | "Chasing" | "Attacking" | "Fleeing" | "Stunned"

export type Entity = {
    Model: Model,
    Humanoid: Humanoid,
    Root: BasePart,
    Target: Player?,
    Health: number,
    State: EntityState,
    LastPathfind: number,
    LastLOSCheck: number,
    LastAttack: number,
    Maid: any,
    CurrentPath: {Vector3}?,
}

local activeEntities: {Entity} = {}
local globalMaid = Utils.CreateMaid()

local RangedAttackRemote = Utils.CreateRemoteEvent("EntityRangedAttack")

local CONFIG = {
    PathfindInterval = 0.6,
    LOSInterval = 0.35,
    AttackCooldown = 1.6,
    MeleeRange = 9,
    RangedRange = 28,
    ChaseSpeed = 21,
    SanityDrainRadius = 32,
    RangedDamage = 14,
    RangedValidationDelay = 0.4,
}

-- ==================== ENTITY CREATION ====================

function EntityAI.Create(template: Model, spawnPosition: Vector3): Entity
    local maid = Utils.CreateMaid()
    local model = template:Clone()
    model:PivotTo(CFrame.new(spawnPosition))
    model.Parent = Workspace

    local root = model:FindFirstChild("HumanoidRootPart") :: BasePart? or model:FindFirstChildWhichIsA("BasePart")
    if not root then error("Entity template missing root part") end

    -- Critical: Server owns physics to prevent exploits and mobile stuttering
    root:SetNetworkOwner(nil)

    local humanoid = model:FindFirstChildOfClass("Humanoid") or Instance.new("Humanoid", model)

    local entity: Entity = {
        Model = model,
        Humanoid = humanoid,
        Root = root,
        Target = nil,
        Health = 125,
        State = "Idle",
        LastPathfind = 0,
        LastLOSCheck = 0,
        LastAttack = 0,
        Maid = maid,
        CurrentPath = nil,
    }

    CollectionService:AddTag(model, "CorruptedPirate")

    maid:GiveTask(model)
    maid:GiveTask(function()
        for i, e in ipairs(activeEntities) do
            if e == entity then
                table.remove(activeEntities, i)
                break
            end
        end
    end)

    table.insert(activeEntities, entity)
    return entity
end

-- ==================== HELPER FUNCTIONS ====================

local function hasLineOfSight(entity: Entity, targetPos: Vector3): boolean
    if tick() - entity.LastLOSCheck < CONFIG.LOSInterval then
        return false
    end
    entity.LastLOSCheck = tick()

    if (targetPos - entity.Root.Position).Magnitude > FogSystem.GetVisibilityDistance() * 1.3 then
        return false
    end

    local params = RaycastParams.new()
    params.FilterDescendantsInstances = {entity.Model}
    params.FilterType = Enum.RaycastFilterType.Exclude

    local result = Workspace:Raycast(entity.Root.Position, targetPos - entity.Root.Position, params)
    return result == nil
end

function EntityAI:ComputePath(targetPos: Vector3)
    local path = PathfindingService:CreatePath({
        AgentRadius = 3.5,
        AgentHeight = 6,
        AgentCanJump = true,
        WaypointSpacing = 10,
    })

    path:ComputeAsync(self.Root.Position, targetPos)

    if path.Status == Enum.PathStatus.Success then
        local waypoints = path:GetWaypoints()
        self.CurrentPath = {}
        for _, wp in waypoints do
            if wp.Action ~= Enum.PathWaypointAction.Jump then
                table.insert(self.CurrentPath, wp.Position)
            end
        end
    end
end

function EntityAI:PerformAttack(attackType: "Melee" | "Ranged", targetPos: Vector3)
    local now = tick()
    if now - self.LastAttack < CONFIG.AttackCooldown then return end
    self.LastAttack = now

    if attackType == "Ranged" then
        RangedAttackRemote:FireAllClients(self.Root.Position, targetPos)

        task.delay(CONFIG.RangedValidationDelay, function()
            if not self.Target or not self.Target.Character then return end
            local targetRoot = self.Target.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
            if not targetRoot then return end

            local dist = (targetRoot.Position - self.Root.Position).Magnitude
            if dist < CONFIG.RangedRange + 5 and hasLineOfSight(self, targetRoot.Position) then
                local hum = self.Target.Character:FindFirstChildOfClass("Humanoid")
                if hum then
                    hum:TakeDamage(CONFIG.RangedDamage)
                    HorrorEvents.TriggerHorrorPulse(0.4)
                end
            end
        end)
    else
        -- Melee
        if self.Target and self.Target.Character then
            local hum = self.Target.Character:FindFirstChildOfClass("Humanoid")
            if hum then
                hum:TakeDamage(22)
            end
        end
    end
end

-- ==================== MAIN UPDATE ====================

function EntityAI:Update(playerPositions: {[Player]: Vector3}, dt: number)
    if not self.Root or self.Humanoid.Health <= 0 then return end

    local now = tick()
    local closestPlayer: Player? = nil
    local closestDist = math.huge
    local closestPos = Vector3.zero

    for player, pos in playerPositions do
        local dist = (pos - self.Root.Position).Magnitude
        if dist < closestDist then
            closestDist = dist
            closestPlayer = player
            closestPos = pos
        end
    end

    if not closestPlayer then
        self.State = "Idle"
        return
    end

    self.Target = closestPlayer

    -- Proximity sanity drain
    if closestDist < CONFIG.SanityDrainRadius then
        HorrorEvents.ApplySanityDrain(closestPlayer, 6 * dt)
    end

    -- State logic
    if closestDist < CONFIG.MeleeRange then
        self.State = "Attacking"
        self:PerformAttack("Melee", closestPos)
    elseif closestDist < CONFIG.RangedRange and hasLineOfSight(self, closestPos) then
        self.State = "Attacking"
        self:PerformAttack("Ranged", closestPos)
    elseif closestDist < 60 then
        self.State = "Chasing"
    else
        self.State = "Idle"
    end

    -- Pathfinding
    if self.State == "Chasing" and now - self.LastPathfind > CONFIG.PathfindInterval then
        self.LastPathfind = now
        self:ComputePath(closestPos)
    end

    -- Move along path
    if self.CurrentPath and #self.CurrentPath > 0 then
        local nextPoint = self.CurrentPath[1]
        self.Humanoid:MoveTo(nextPoint)
        if (self.Root.Position - nextPoint).Magnitude < 5 then
            table.remove(self.CurrentPath, 1)
        end
    end
end

function EntityAI.UpdateAll(playerPositions: {[Player]: Vector3}, dt: number)
    for _, entity in activeEntities do
        entity:Update(playerPositions, dt)
    end
end

function EntityAI.SpawnTestEntity(spawnPos: Vector3): Entity
    local template = Instance.new("Model")
    local root = Instance.new("Part")
    root.Name = "HumanoidRootPart"
    root.Size = Vector3.new(2, 4, 1)
    root.Position = spawnPos
    root.Anchored = false
    root.CanCollide = true
    root.Parent = template
    template.PrimaryPart = root

    local entity = EntityAI.Create(template, spawnPos)
    template:Destroy()

    return entity
end

function EntityAI.Initialize()
    print("[EntityAI] Initialized successfully - Server-authoritative horror AI ready")
end

function EntityAI.Destroy()
    globalMaid:Cleanup()
    for _, entity in activeEntities do
        if entity.Maid then entity.Maid:Cleanup() end
        if entity.Model then entity.Model:Destroy() end
    end
    table.clear(activeEntities)
end

return EntityAI