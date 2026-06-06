--!strict
-- TestHarness.lua (ServerScriptService)
-- Expanded debug menu for Phase 7. RemoteEvent "AdminDebugCommand" includes "fullTestScenario" that spawns complete round (ship + 3 chests + 2 entities + difficulty + GameManager init).
-- Server-authoritative. Uses existing generators/managers. Validates all commands (anti-exploit).
-- Maid for test cleanup. Performance: One-shot only, defers to 3Hz/5Hz subsystem loops. No persistent work.
-- Architecture: Called from GameManager or chat. All spawning on server; visuals via remotes to client controllers only. Studio guard.
-- Asset binding: All spawns reference ServerStorage.Assets.*Rig placeholders (rigged models with animations to be bound in prod). Uses CollectionService tags.
-- Author: Fog Sea Architect - 2026-06-07

local Utils = require(game.ReplicatedStorage.Modules.Utils)
local GhostShipGenerator = require(game.ReplicatedStorage.Modules.GhostShipGenerator)
local ExtractionManager = require(game.ReplicatedStorage.Modules.ExtractionManager)
local EntityAI = require(game.ReplicatedStorage.Modules.EntityAI)
local GameManager = require(game.ServerScriptService.GameManager)
local Players = Utils.GetService("Players")
local RunService = Utils.GetService("RunService")

local TestHarness = {}
TestHarness.__index = TestHarness

export type DebugCommand = "spawnTestShip" | "spawnEntities" | "spawnChests" | "setDifficulty" | "fullTestScenario"
export type TestHarness = typeof(TestHarness)

local testMaid = Utils.CreateMaid()
local AdminDebugRemote = Utils.CreateRemoteEvent("AdminDebugCommand")

local currentDifficulty = 1

local function isAdmin(player: Player): boolean
	-- Production guard: Studio or admin list. Prevents exploits in live games.
	return RunService:IsStudio() or player.UserId == 0 -- Replace with real admin system
end

local function executeDebugCommand(player: Player, command: DebugCommand, param: number?)
	if not isAdmin(player) then return end
	
	local center = Vector3.new(0, 50, 0)
	local char = player.Character
	if char and char:FindFirstChild("HumanoidRootPart") then
		center = (char.HumanoidRootPart :: Part).Position + Vector3.new(0, 30, 50)
	end
	
	if command == "fullTestScenario" then
		-- Complete round: ship + 3 chests + 2 entities + difficulty + GameManager init
		GameManager.Initialize() -- Ensure full orchestration
		local ship = GhostShipGenerator.CreateTestShip(center) -- Placeholder for ServerStorage.Assets.GhostShipRig
		for i = 1, 3 do
			ExtractionManager.CreateTestChest(ship)
		end
		for i = 1, 2 do
			local e = EntityAI.SpawnTestEntity(center + Vector3.new(i*12, 0, 0))
			if e.Root then e.Root:SetNetworkOwner(nil) end
			testMaid:GiveTask(e.Model)
		end
		currentDifficulty = param or 2
		print(`Full test scenario spawned by {player.Name} at difficulty {currentDifficulty} with GameManager init`)
	elseif command == "spawnTestShip" then
		local ship = GhostShipGenerator.CreateTestShip(center)
		for i = 1, 3 do
			ExtractionManager.CreateTestChest(ship)
		end
		print(`Test ship spawned by {player.Name}`)
	elseif command == "spawnEntities" then
		local count = math.clamp(param or 3, 1, 8)
		for i = 1, count do
			local e = EntityAI.SpawnTestEntity(center + Vector3.new(i*8, 0, 0))
			if e.Root then e.Root:SetNetworkOwner(nil) end
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
	
	Players.PlayerAdded:Connect(function(player: Player)
		if isAdmin(player) then
			player.Chatted:Connect(function(msg: string)
				local lower = msg:lower()
				if lower:find("/debug") then
					if lower:find("full") then
						AdminDebugRemote:FireServer("fullTestScenario", 3)
					elseif lower:find("ship") then
						AdminDebugRemote:FireServer("spawnTestShip")
					end
				end
			end)
		end
	end)
	
	print("TestHarness expanded with fullTestScenario (asset binding notes, Maid, server authority, mobile comments, GameManager init).")
end

function TestHarness.Destroy()
	testMaid:Cleanup()
end

TestHarness.Initialize()

return TestHarness
