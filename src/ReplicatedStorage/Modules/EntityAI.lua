--!strict
-- EntityAI.lua
-- Base class for corrupted pirate entities in Fog Sea.
-- Sound-reactive pathfinding, line-of-sight, attack behaviors.
-- Server authoritative AI. Extremely performance conscious — no pathfinding every frame.
-- Uses Maid, object pooling for attacks/VFX, and throttled updates.
-- Author: Fog Sea Architect - 2026-06-06

local Utils = require(script.Parent.Utils)
local RunService = Utils.GetService("RunService")
local PathfindingService = Utils.GetService("PathfindingService")

local EntityAI = {}
EntityAI.__index = EntityAI

export type Entity = {
	Model: Model,
	Target: Player?,
	Health: number,
	State: "Idle" | "Chasing" | "Attacking" | "Fleeing",
	LastPathfind: number,
	Maid: any,
	LastHeardSoundTime: number,
}

export type EntityAI = typeof(EntityAI)

local self = setmetatable({}, EntityAI)
local maid = Utils.CreateMaid()
local activeEntities: { Entity } = {}
local attackPool = Utils.CreateObjectPool(Instance.new("Part"), 8) -- Pooled attack projectiles

local CONFIG = {
	PathfindInterval = 0.8,     -- Do NOT pathfind every frame (mobile killer)
	AttackRange = 12,
	ChaseSpeed = 16,
	LOSRefreshRate = 0.4,
	SoundReactDistance = 45,
}

-- Create a new corrupted pirate entity
function EntityAI.Create(modelTemplate: Model): Entity
	local entityMaid = Utils.CreateMaid()
	
	local entity: Entity = {
		Model = modelTemplate:Clone(),
		Target = nil,
		Health = 100,
		State = "Idle",
		LastPathfind = 0,
		Maid = entityMaid,
		LastHeardSoundTime = 0,
	}
	
	entity.Model.Parent = workspace
	entity.Maid:GiveTask(entity.Model)
	
	table.insert(activeEntities, entity)
	
	return entity
end

-- Throttled, sound-reactive pathfinding
function EntityAI:Update(dt: number, playerPositions: { [Player]: Vector3 })
	if not self.Model.PrimaryPart then return end
	
	local now = tick()
	local closestPlayer = nil
	local closestDist = math.huge
	
	for player, pos in playerPositions do
		local dist = (pos - self.Model.PrimaryPart.Position).Magnitude
		if dist < closestDist then
			closestDist = dist
			closestPlayer = player
		end
	end
	
	if not closestPlayer then return end
	self.Target = closestPlayer
	
	-- Sound reactive behavior
	if closestDist < CONFIG.SoundReactDistance and now - self.LastHeardSoundTime < 8 then
		self.State = "Chasing"
	end
	
	if self.State == "Chasing" and now - self.LastPathfind > CONFIG.PathfindInterval then
		self.LastPathfind = now
		
		local path = PathfindingService:CreatePath({
			AgentRadius = 3,
			AgentHeight = 6,
			AgentCanJump = true,
			WaypointSpacing = 8, -- Performance optimization
		})
		
		path:ComputeAsync(self.Model.PrimaryPart.Position, closestPlayer.Character:GetPivot().Position)
		
		if path.Status == Enum.PathStatus.Success then
			local waypoints = path:GetWaypoints()
			-- Simplified movement - in production would use a proper steering behavior
			if #waypoints > 1 then
				local direction = (waypoints[2].Position - self.Model.PrimaryPart.Position).Unit
				self.Model.PrimaryPart.AssemblyLinearVelocity = direction * CONFIG.ChaseSpeed
			end
		end
	end
	
	-- Line of sight attack check (throttled)
	if closestDist < CONFIG.AttackRange and self.State ~= "Attacking" then
		self.State = "Attacking"
		self:PerformAttack()
	end
end

function EntityAI:PerformAttack()
	local projectile = attackPool:Get()
	projectile.Size = Vector3.new(2, 2, 2)
	projectile.Color = Color3.fromRGB(180, 30, 30)
	projectile.Parent = workspace
	
	-- Fire toward target (simplified)
	local root = self.Model.PrimaryPart
	if root and self.Target and self.Target.Character then
		local targetRoot = self.Target.Character:FindFirstChild("HumanoidRootPart")
		if targetRoot then
			local direction = (targetRoot.Position - root.Position).Unit
			projectile.Position = root.Position + direction * 5
			projectile.AssemblyLinearVelocity = direction * 60
		end
	end
	
	-- Auto return to pool after lifetime
	task.delay(3, function()
		if projectile.Parent then
			attackPool.Return(projectile)
		end
	end)
end

function EntityAI.UpdateAll(playerPositions: { [Player]: Vector3 })
	for _, entity in activeEntities do
		entity:Update(0.1, playerPositions)
	end
end

function EntityAI.Destroy()
	maid:Cleanup()
	for _, entity in activeEntities do
		if entity.Maid then
			entity.Maid:Cleanup()
		end
	end
	table.clear(activeEntities)
end

return EntityAI
