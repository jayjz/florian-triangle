--!strict
-- Utils.lua
-- Core utilities for Fog Sea (Florian Triangle)
-- Production-grade, mobile-first utilities used by all systems.
-- Author: Fog Sea Architect - 2026-06-06

local Utils = {}

-- Type definitions (strong typing for the entire project)
export type Maid = {
	Cleanup: (self: Maid) -> (),
	GiveTask: (self: Maid, task: any) -> (),
	DoCleaning: (self: Maid) -> (),
}

export type Vector2i = { X: number, Y: number }

-- Classic Maid pattern - essential for memory management in Roblox
-- Critical for preventing memory leaks in long-running games
function Utils.CreateMaid(): Maid
	local maid = {}
	local tasks = {}

	function maid:GiveTask(task: any)
		table.insert(tasks, task)
	end

	function maid:Cleanup()
		for _, task in ipairs(tasks) do
			if typeof(task) == "function" then
				task()
			elseif typeof(task) == "RBXScriptConnection" then
				task:Disconnect()
			elseif task.Destroy then
				task:Destroy()
			elseif task.Disconnect then
				task:Disconnect()
			end
		end
		table.clear(tasks)
	end

	function maid:DoCleaning()
		self:Cleanup()
	end

	return maid
end

-- Fast math helpers (avoid math library where possible on mobile)
function Utils.Lerp(a: number, b: number, t: number): number
	return a + (b - a) * t
end

function Utils.Clamp(value: number, min: number, max: number): number
	return math.max(min, math.min(max, value))
end

-- Object pooling template (critical for performance in horror games with VFX/entities)
-- Usage note: Pooling reduces GC pressure significantly on mobile
function Utils.CreateObjectPool<T>(template: T, initialSize: number): {
	Get: (self: any) -> T,
	Return: (self: any, obj: T) -> (),
}
	local pool = {}
	local poolSize = initialSize or 8
	
	for i = 1, poolSize do
		table.insert(pool, template:Clone())
	end
	
	return {
		Get = function()
			if #pool > 0 then
				return table.remove(pool) :: T
			end
			return template:Clone() :: T
		end,
		Return = function(obj: T)
			if obj.Parent then
				obj.Parent = nil
			end
			table.insert(pool, obj)
		end,
	}
end

-- Cached GetService (performance critical - never call GetService in hot paths)
local Services = {}
function Utils.GetService(serviceName: string)
	if not Services[serviceName] then
		Services[serviceName] = game:GetService(serviceName)
	end
	return Services[serviceName]
end

-- RemoteEvent safe wrapper (prevents common anti-patterns)
function Utils.CreateRemoteEvent(name: string)
	local eventsFolder = Utils.GetService("ReplicatedStorage"):FindFirstChild("Events")
		or Instance.new("Folder")
	eventsFolder.Name = "Events"
	eventsFolder.Parent = Utils.GetService("ReplicatedStorage")
	
	local remote = eventsFolder:FindFirstChild(name)
	if not remote then
		remote = Instance.new("RemoteEvent")
		remote.Name = name
		remote.Parent = eventsFolder
	end
	return remote
end

return Utils
