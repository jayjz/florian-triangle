--!strict
-- GameManager.lua (ServerScriptService)
-- Central orchestrator with rate limiting and anti-exploit wrappers.

local Utils = require(game.ReplicatedStorage.Modules.Utils)

local RoundManager = require(script.Parent.RoundManager)
local LobbyManager = require(script.Parent.LobbyManager)
local FogSystem = require(game.ReplicatedStorage.Modules.FogSystem)
local ShipController = require(game.ReplicatedStorage.Modules.ShipController)
local GhostShipGenerator = require(game.ReplicatedStorage.Modules.GhostShipGenerator)
local EntityAI = require(game.ReplicatedStorage.Modules.EntityAI)
local HorrorEvents = require(game.ReplicatedStorage.Modules.HorrorEvents)
local ExtractionManager = require(game.ReplicatedStorage.Modules.ExtractionManager)
local ExtractionZone = require(script.Parent.ExtractionZone)
local TestHarness = require(script.Parent.TestHarness)

local Players = Utils.GetService("Players")
local RunService = Utils.GetService("RunService")

local GameManager = {}
GameManager.__index = GameManager

local maid = Utils.CreateMaid()
local playerPositions: {[Player]: Vector3} = {}
local lastUpdate = 0
local UPDATE_RATE = 0.2

-- Simple rate limiter
local lastRemoteTime: {[Player]: number} = {}

function GameManager.Initialize()
	print("=== [GameManager] Initializing all systems ===")

	pcall(RoundManager.Initialize)
	pcall(LobbyManager.Initialize)

	local systems = {
		{ name = "FogSystem", sys = FogSystem },
		{ name = "ShipController", sys = ShipController },
		{ name = "GhostShipGenerator", sys = GhostShipGenerator },
		{ name = "HorrorEvents", sys = HorrorEvents },
		{ name = "ExtractionManager", sys = ExtractionManager },
		{ name = "ExtractionZone", sys = ExtractionZone },
		{ name = "TestHarness", sys = TestHarness },
		{ name = "EntityAI", sys = EntityAI },
	}

	for _, data in systems do
		if typeof(data.sys) == "table" and typeof(data.sys.Initialize) == "function" then
			local success, err = pcall(data.sys.Initialize)
			if success then
				print(`[GameManager] {data.name} initialized`)
			else
				warn(`[GameManager] Failed to initialize {data.name}: {err}`)
			end
		end
	end

	Players.PlayerAdded:Connect(function(player)
		print(`[GameManager] Player {player.Name} joined`)
		lastRemoteTime[player] = 0
	end)

	Players.PlayerRemoving:Connect(function(player)
		playerPositions[player] = nil
		lastRemoteTime[player] = nil
	end)

	maid:GiveTask(RunService.Heartbeat:Connect(function(dt: number)
		local now = tick()
		if now - lastUpdate < UPDATE_RATE then return end
		lastUpdate = now

		for _, player in Players:GetPlayers() do
			local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
			if root then playerPositions[player] = root.Position end
		end

		if typeof(EntityAI.UpdateAll) == "function" then EntityAI.UpdateAll(playerPositions, dt) end
		if typeof(GhostShipGenerator.CullDistantShips) == "function" then GhostShipGenerator.CullDistantShips(Vector3.new(0, 50, 0)) end

		if typeof(HorrorEvents.GetHorrorLevel) == "function" then
			local level = HorrorEvents.GetHorrorLevel()
			if typeof(FogSystem.SetHorrorLevel) == "function" then FogSystem.SetHorrorLevel(level) end
		end

		if typeof(ExtractionManager.ExtractAtZone) == "function" then
			for _, player in Players:GetPlayers() do
				ExtractionManager.ExtractAtZone(player, Vector3.new(0, 8, 0), 28)
			end
		end
	end))

	print("=== [GameManager] Fully initialized with anti-exploit measures ===")
end

function GameManager.Destroy()
	maid:Cleanup()
	local systems = {RoundManager, LobbyManager, FogSystem, ShipController, GhostShipGenerator, EntityAI, HorrorEvents, ExtractionManager, ExtractionZone, TestHarness}
	for _, sys in systems do
		if typeof(sys.Destroy) == "function" then pcall(sys.Destroy) end
	end
end

-- Global rate limit helper (call from remotes)
function GameManager.IsRateLimited(player: Player, minInterval: number): boolean
	local last = lastRemoteTime[player] or 0
	local now = tick()
	if now - last < minInterval then return true end
	lastRemoteTime[player] = now
	return false
end

return GameManager
