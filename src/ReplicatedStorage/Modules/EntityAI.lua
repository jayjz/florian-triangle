--!strict
-- EntityAI.lua
-- Production-grade corrupted pirate AI for Fog Sea.
-- Server-authoritative with throttled PathfindingService (0.6s minimum), raycast LOS integrated with FogSystem culling,
-- multiple attack states (melee/ranged), sound-reactive behavior, and full Maid cleanup.
-- Mobile performance: No pathfinding on every frame, pooled attacks, distance culling, limited raycasts.
-- Architecture: One Entity per instance with its own Maid. GameManager calls UpdateAll() from ServerScriptService.
-- Author: Fog Sea Architect - 2026-06-06

local Utils = require(script.Parent.Utils)
local FogSystem = require(script.Parent.FogSystem)
local HorrorEvents = require(script.Parent.HorrorEvents)
local RunService = Utils.GetService("RunService")
local PathfindingService = Utils.GetService("PathfindingService")
local Workspace = Utils.GetService("Workspace")

local EntityAI = {}
EntityAI.__index = EntityAI

export type EntityState = "Idle" | "Chasing" | "Attacking" | "Fleeing" | "Stunned"
export type Entity = {
	Model: Model,
	Humanoid: Humanoid,
	Target: Player?,
	Health: number,
	State: EntityState,
	LastPathfind: number,
	LastLOSCheck: number,
	LastAttack: number,
	Maid: any,
	CurrentPath: {Vector3}?,
	AttackType: "Melee" | "Ranged",
}

export type EntityAI = typeof(EntityAI)

local activeEntities: {Entity} = {}
local attackPool = Utils.CreateObjectPool(Instance.new("Part"), 12) -- Pooled ranged attacks
local globalMaid = Utils.CreateMaid()

local CONFIG = {
	PathfindInterval = 0.6,      -- Critical: Do not lower. Pathfinding is expensive on mobile.
	LOSInterval = 0.4,
	AttackCooldown = 1.8,
	MeleeRange = 8,
	RangedRange = 25,
	ChaseSpeed = 22,
	SanityDrainRadius = 35,
	SoundReactDistance = 55,
}

-- Create new corrupted entity
function EntityAI.Create(template: Model, spawnPosition: Vector3): Entity
	local maid = Utils.CreateMaid()
	local model = template:Clone()
	model:PivotTo(CFrame.new(spawnPosition))
	model.Parent = Workspace
	
	local humanoid = model:FindFirstChildOfClass("Humanoid") or Instance.new("Humanoid", model)
	
	local entity: Entity = {
		Model = model,
		Humanoid = humanoid,
		Target = nil,
		Health = 125,
		State = "Idle",
		LastPathfind = 0,
		LastLOSCheck = 0,
		LastAttack = 0,
		Maid = maid,
		CurrentPath = nil,
		AttackType = "Melee",
	}
	
	-- Cleanup
	maid:GiveTask(model)
	maid:GiveTask(function()
		for i, e in activeEntities do
			if e == entity then
				table.remove(activeEntities, i)
				break
			end
		end
	end)
	
	table.insert(activeEntities, entity)
	return entity
end

-- Raycast LOS with FogSystem integration (expensive, throttled)
local function hasLineOfSight(entity: Entity, targetPos: Vector3): boolean
	if tick() - entity.LastLOSCheck < CONFIG.LOSInterval then
		return false
	end
	entity.LastLOSCheck = tick()
	
	local root = entity.Model.PrimaryPart
	if not root then return false end
	
	local distance = (targetPos - root.Position).Magnitude
	if distance > FogSystem.GetVisibilityDistance() * 1.2 then
		return false -- Fog culling
	end
	
	local raycastParams = RaycastParams.new()
	raycastParams.FilterDescendantsInstances = {entity.Model}
	raycastParams.FilterType = Enum.RaycastFilterType.Exclude
	
	local result = Workspace:Raycast(root.Position, targetPos - root.Position, raycastParams)
	return result == nil or (result.Instance and result.Instance:IsDescendantOf(targetPos))
end

function EntityAI:Update(playerPositions: {[Player]: Vector3}, dt: number)
	if not self.Model.PrimaryPart or not self.Humanoid then return end
	if self.Humanoid.Health <= 0 then return end
	
	local now = tick()
	local root = self.Model.PrimaryPart
	local closestPlayer: Player? = nil
	local closestDist = math.huge
	local closestPos = Vector3.zero
	
	for player, pos in playerPositions do
		local dist = (pos - root.Position).Magnitude
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
		HorrorEvents.ApplySanityDrain(closestPlayer, 8 * dt)
	end
	
	-- State machine
	if closestDist < CONFIG.MeleeRange and self.State ~= "Attacking" then
		self.State = "Attacking"
		self:PerformAttack("Melee", closestPos)
	elseif closestDist < CONFIG.RangedRange and self.State ~= "Attacking" then
		self.State = "Attacking"
		self:PerformAttack("Ranged", closestPos)
	elseif closestDist < CONFIG.SoundReactDistance then
		self.State = "Chasing"
	else
		self.State = "Idle"
	end
	
	-- Throttled pathfinding
	if self.State == "Chasing" and now - self.LastPathfind > CONFIG.PathfindInterval then
		self.LastPathfind = now
		self:ComputePath(closestPos)
	end
	
	-- Follow current path (simple waypoint follower)
	if self.CurrentPath and #self.CurrentPath > 0 then
		local nextPoint = self.CurrentPath[1]
		local direction = (nextPoint - root.Position).Unit
		self.Humanoid:MoveTo(nextPoint)
		if (root.Position - nextPoint).Magnitude < 6 then
			table.remove(self.CurrentPath, 1)
		end
	end
	
	-- Error handling
	if self.Health < 0 then
		self:Destroy()
	end
end

function EntityAI:ComputePath(targetPos: Vector3)
	local root = self.Model.PrimaryPart
	if not root then return end
	
	local path = PathfindingService:CreatePath({
		AgentRadius = 3.5,
		AgentHeight = 6,
		AgentCanJump = true,
		WaypointSpacing = 10, -- Performance optimization
	})
	
	path:ComputeAsync(root.Position, targetPos)
	
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
		local projectile = attackPool:Get()
		projectile.Size = Vector3.new(1.5, 1.5, 1.5)
		projectile.Color = Color3.fromRGB(170, 20, 20)
		projectile.Material = Enum.Material.Neon
		projectile.CanCollide = false
		projectile.Parent = Workspace
		
		local root = self.Model.PrimaryPart
		if root then
			projectile.Position = root.Position + Vector3.new(0, 4, 0)
			local direction = (targetPos - projectile.Position).Unit
			projectile.AssemblyLinearVelocity = direction * 65
			
			task.delay(2.5, function()
				if projectile and projectile.Parent then
					attackPool.Return(projectile)
				end
			end)
		end
	else
		-- Melee attack (simulated)
		if self.Target and self.Target.Character then
			local targetHum = self.Target.Character:FindFirstChildOfClass("Humanoid")
			if targetHum then
				targetHum:TakeDamage(18)
				HorrorEvents.TriggerHorrorPulse(0.5)
			end
		end
	end
end

function EntityAI.UpdateAll(playerPositions: {[Player]: Vector3}, dt: number)
	for _, entity in activeEntities do
		entity:Update(playerPositions, dt)
	end
end

function EntityAI.DestroyEntity(entity: Entity)
	entity.Maid:Cleanup()
	for i, e in activeEntities do
		if e == entity then
			table.remove(activeEntities, i)
			break
		end
	end
end

function EntityAI.Destroy()
	globalMaid:Cleanup()
	for _, entity in activeEntities do
		entity.Maid:Cleanup()
	end
	table.clear(activeEntities)
end

return EntityAI
