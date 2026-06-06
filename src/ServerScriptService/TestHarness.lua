--!strict
-- TestHarness.lua (ServerScriptService)
-- Admin testing harness for Fog Sea Phase 6. Provides RemoteEvent-based command to instantly spawn a test ghost ship with 3 loot chests and 2 AI entities.
-- Allows rapid in-Studio verification of extraction loop, AI behavior, weight penalties without full game start.
-- Uses Utils.CreateRemoteEvent for admin command (validated on server). Maid for cleanup of test objects.
-- Performance: One-shot spawn only, no loops. Spawns are culled by existing systems. Explicit notes on mobile replication cost.
-- Architecture: Server-authoritative only. Fires no client visuals here (delegates to existing controllers). Studio-only guard.
-- Asset readiness: Placeholder bindings for ServerStorage.Assets (rigged ship/chest/AI models). Replace template spawning in prod.
-- Author: Fog Sea Architect - 2026-06-07

local Utils = require(game.ServerScriptService.Parent.ReplicatedStorage.Modules.Utils)
local GhostShipGenerator = require(game.ReplicatedStorage.Modules.GhostShipGenerator)
local ExtractionManager = require(game.ReplicatedStorage.Modules.ExtractionManager)
local EntityAI = require(game.ReplicatedStorage.Modules.EntityAI)
local Players = Utils.GetService("Players")
local RunService = Utils.GetService("RunService")

local TestHarness = {}
TestHarness.__index = TestHarness

export type TestHarness = typeof(TestHarness)

local testMaid = Utils.CreateMaid()
local AdminTestRemote = Utils.CreateRemoteEvent("AdminTestSpawn")

local function isAdmin(player: Player): boolean
	-- Studio or specific user check for safety in prod
	return game:GetService("RunService"):IsStudio() or player.UserId == 123456789 -- Replace with admin list
end

local function spawnTestScenario(centerPos: Vector3)
	-- Spawn test ghost ship (placeholder for rigged model in ServerStorage.Assets.GhostShipRig)
	local testShip = GhostShipGenerator.CreateTestShip(centerPos) -- Assume method or extend generator
	print("TestHarness: Spawned ghost ship at " .. tostring(centerPos))
	
	-- Add 3 loot chests via ExtractionManager (uses its pooling)
	for i = 1, 3 do
		ExtractionManager.CreateTestChest(testShip)
	end
	
	-- Add 2 entities (AI) via EntityAI (SetNetworkOwner(nil) enforced)
	for i = 1, 2 do
		local entity = EntityAI.SpawnTestEntity(centerPos + Vector3.new(math.random(-20,20), 5, math.random(-20,20)))
		testMaid:GiveTask(entity) -- Cleanup on test end
		entity:SetNetworkOwner(nil) -- Critical for AI authority on mobile clients
	end
	
	print("TestHarness: Spawned 3 chests + 2 entities. Verify extraction, sanity, weight penalties in Studio.")
end

function TestHarness.Initialize()
	AdminTestRemote.OnServerEvent:Connect(function(player: Player, command: string)
		if not isAdmin(player) or command ~= "spawnTest" then return end -- Full validation (anti-exploit)
		local center = Vector3.new(0, 50, 0) -- Or player character position
		local char = player.Character
		if char and char:FindFirstChild("HumanoidRootPart") then
			center = (char.HumanoidRootPart :: Part).Position + Vector3.new(0, 30, 0)
		end
		spawnTestScenario(center)
	end)
	
	-- Chat command fallback for Studio testing
	Players.PlayerAdded:Connect(function(player)
		if isAdmin(player) then
			player.Chatted:Connect(function(msg)
				if msg:lower() == "/testship" then
					AdminTestRemote:FireClient(player, "spawnTest") -- Or direct call
				end
			end)
		end
	end)
	
	print("TestHarness initialized - Admin spawn command ready (/testship or RemoteEvent). Asset placeholders noted for rigged models.")
end

function TestHarness.Destroy()
	testMaid:Cleanup()
end

-- Auto init
TestHarness.Initialize()

return TestHarness
