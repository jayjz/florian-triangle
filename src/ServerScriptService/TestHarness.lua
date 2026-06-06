--!strict
-- TestHarness.lua (ServerScriptService)
-- Full debug menu for Fog Sea cleanup phase. RemoteEvent "AdminDebugCommand" supports commands: "spawnTestShip", "spawnEntities count", "spawnChests count", "setDifficulty level".
-- Server-authoritative spawning using existing generators/managers. Validates commands to prevent exploits.
-- Maid for per-test cleanup of spawned objects. Performance: One-shot commands only, no persistent loops. Spawning defers to subsystems' throttling (3Hz/5Hz).
-- Architecture: Integrates with GameManager. All state on server; clients receive visuals via existing remotes/controllers only. Studio + admin guard.
-- Roblox realities: SetNetworkOwner(nil) on all spawned AI. No server visuals. Comments on mobile replication cost.
-- Author: Fog Sea Architect - 2026-06-07

local Utils = require(game.ReplicatedStorage.Modules.Utils)
local GhostShipGenerator = require(game.ReplicatedStorage.Modules.GhostShipGenerator)
local ExtractionManager = require(game.ReplicatedStorage.Modules.ExtractionManager)
local EntityAI = require(game.ReplicatedStorage.Modules.EntityAI)
local Players = Utils.GetService("Players")
local RunService = Utils.GetService("RunService")

local TestHarness = {}
TestHarness.__index = TestHarness

export type DebugCommand = "spawnTestShip" | "spawnEntities" | "spawnChests" | "setDifficulty"
export type TestHarness = typeof(TestHarness)

local testMaid = Utils.CreateMaid()
local AdminDebugRemote = Utils.CreateRemoteEvent("AdminDebugCommand")

local currentDifficulty = 1

local function isAdmin(player: Player): boolean
	-- Production guard: Studio or specific UserId list. Prevents exploit in live games.
	return RunService:IsStudio() or player.UserId == 0 -- Replace with real admin system
end

local function executeDebugCommand(player: Player, command: DebugCommand, param: number?)
	if not isAdmin(player) then return end
	
	local center = Vector3.new(0, 50, 0)
	local char = player.Character
	if char and char:FindFirstChild("HumanoidRootPart") then
		center = (char.HumanoidRootPart :: Part).Position + Vector3.new(0, 30, 50)
	end
	
	if command == "spawnTestShip" then
		-- Uses generator (placeholder for rigged asset)
		local ship = GhostShipGenerator.CreateTestShip(center)
		for i = 1, 3 do
			ExtractionManager.CreateTestChest(ship)
		end
		for i = 1, 2 do
			local e = EntityAI.SpawnTestEntity(center + Vector3.new((i-1)*10, 0, 0))
			e.Root:SetNetworkOwner(nil) -- Critical for mobile AI replication
			testMaid:GiveTask(e.Model)
		end
		print(`Test ship + 3 chests + 2 entities spawned by {player.Name}`)
	elseif command == "spawnEntities" then
		local count = math.clamp(param or 3, 1, 8)
		for i = 1, count do
			local e = EntityAI.SpawnTestEntity(center + Vector3.new(i*8, 0, 0))
			e.Root:SetNetworkOwner(nil)
			testMaid:GiveTask(e.Model)
		end
		print(`Spawned {count} test entities`)
	elseif command == "spawnChests" then
		local count = math.clamp(param or 3, 1, 6)
		local ship = GhostShipGenerator.CreateTestShip(center)
		for i = 1, count do
			ExtractionManager.CreateTestChest(ship)
		end
		print(`Spawned {count} test chests`)
	elseif command == "setDifficulty" then
		currentDifficulty = math.clamp(param or 1, 1, 5)
		print(`Difficulty set to {currentDifficulty}`)
	end
end

function TestHarness.Initialize()
	AdminDebugRemote.OnServerEvent:Connect(function(player: Player, command: DebugCommand, param: number?)
		executeDebugCommand(player, command, param)
	end)
	
	-- Chat fallback for quick Studio testing
	Players.PlayerAdded:Connect(function(player: Player)
		if isAdmin(player) then
			player.Chatted:Connect(function(msg: string)
				local lower = msg:lower()
				if lower:find("/debug") then
					-- Parse simple commands from chat
					if lower:find("ship") then
						AdminDebugRemote:FireServer("spawnTestShip")
					elseif lower:find("entity") then
						local count = tonumber(lower:match("%d+")) or 2
						AdminDebugRemote:FireServer("spawnEntities", count)
					end
				end
			end)
		end
	end)
	
	print("TestHarness full debug menu initialized (AdminDebugCommand RemoteEvent, mobile-safe spawning, NetworkOwner fixes).")
end

function TestHarness.Destroy()
	testMaid:Cleanup()
end

TestHarness.Initialize()

return TestHarness
