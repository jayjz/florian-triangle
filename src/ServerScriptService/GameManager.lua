--!strict
-- GameManager.lua (ServerScriptService)
-- Central server orchestrator for Florian Triangle (Fog Sea).
-- Responsibilities: Bootstrap all systems in correct dependency order, coordinate 5Hz game loop,
-- manage player lifecycle, route horror/fog signals, integrate Lobby → Round flow,
-- and ensure clean shutdown with Maid propagation.
-- Optimizations: Throttled updates, defensive pcall guards, reduced extraction spam risk,
-- LobbyManager integration for Foosha → Windmill Village transition.

local Utils = require(script.Parent.Parent.ReplicatedStorage.Modules.Utils)

-- Systems (loaded once, in dependency-friendly order)
local RoundManager = require(script.Parent.RoundManager)
local LobbyManager = require(script.Parent.LobbyManager)  -- NEW: Lobby & round start
local FogSystem = require(script.Parent.Parent.ReplicatedStorage.Modules.FogSystem)
local ShipController = require(script.Parent.Parent.ReplicatedStorage.Modules.ShipController)
local GhostShipGenerator = require(script.Parent.Parent.ReplicatedStorage.Modules.GhostShipGenerator)
local EntityAI = require(script.Parent.Parent.ReplicatedStorage.Modules.EntityAI)
local HorrorEvents = require(script.Parent.Parent.ReplicatedStorage.Modules.HorrorEvents)
local ExtractionManager = require(script.Parent.Parent.ReplicatedStorage.Modules.ExtractionManager)
local ExtractionZone = require(script.Parent.ExtractionZone)
local TestHarness = require(script.Parent.TestHarness)

local Players = Utils.GetService("Players")
local RunService = Utils.GetService("RunService")

local GameManager = {}
GameManager.__index = GameManager

local maid = Utils.CreateMaid()
local playerPositions: {[Player]: Vector3} = {}
local lastUpdate = 0
local UPDATE_RATE = 0.2 -- 5Hz server tick (balances responsiveness + performance)

function GameManager.Initialize()
	print("=== [GameManager] Initializing all systems ===")

	-- Critical first: Round state + Lobby flow
	RoundManager.Initialize()
	LobbyManager.Initialize()

	local systems = {
		{ name = "FogSystem",          sys = FogSystem },
		{ name = "ShipController",     sys = ShipController },
		{ name = "GhostShipGenerator", sys = GhostShipGenerator },
		{ name = "HorrorEvents",       sys = HorrorEvents },
		{ name = "ExtractionManager",  sys = ExtractionManager },
		{ name = "ExtractionZone",     sys = ExtractionZone },
		{ name = "TestHarness",        sys = TestHarness },
		{ name = "EntityAI",           sys = EntityAI },
		{ name = "LobbyManager",       sys = LobbyManager },  -- Already initialized above
	}

	for _, data in systems do
		if typeof(data.sys) == "table" and typeof(data.sys.Initialize) == "function" then
			local success, err = pcall(data.sys.Initialize)
			if success then
				print(`[GameManager] {data.name} initialized`)
			else
				warn(`[GameManager] Failed to initialize {data.name}: {err}`)
			end
		else
			warn(`[GameManager] {data.name} missing Initialize()`)
		end
	end

	-- Player lifecycle
	Players.PlayerAdded:Connect(function(player)
		print(`[GameManager] Player {player.Name} joined`)
		player.CharacterAdded:Connect(function()
			task.wait(1.5) -- Allow character to settle
			if typeof(ShipController.InitializeForPlayer) == "function" then
				ShipController.InitializeForPlayer(player)
			end
		end)
	end)

	Players.PlayerRemoving:Connect(function(player)
		playerPositions[player] = nil
	end)

	-- Main throttled game loop (5Hz)
	maid:GiveTask(RunService.Heartbeat:Connect(function(dt: number)
		local now = tick()
		if now - lastUpdate < UPDATE_RATE then return end
		lastUpdate = now

		-- Update tracked positions for AI/pathfinding
		for _, player in Players:GetPlayers() do
			local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
			if root then
				playerPositions[player] = root.Position
			end
		end

		-- Subsystem updates (defensive checks)
		if typeof(EntityAI.UpdateAll) == "function" then
			EntityAI.UpdateAll(playerPositions, dt)
		end
		if typeof(GhostShipGenerator.CullDistantShips) == "function" then
			GhostShipGenerator.CullDistantShips(Vector3.new(0, 50, 0))
		end

		-- Horror → Fog bridge (Smothering Mist driver)
		if typeof(HorrorEvents.GetHorrorLevel) == "function" then
			local level = HorrorEvents.GetHorrorLevel()
			if typeof(FogSystem.SetHorrorLevel) == "function" then
				FogSystem.SetHorrorLevel(level)
			end
		end

		-- Extraction (throttled; future: add quota check to avoid spam)
		if typeof(ExtractionManager.ExtractAtZone) == "function" then
			for _, player in Players:GetPlayers() do
				ExtractionManager.ExtractAtZone(player, Vector3.new(0, 8, 0), 28)
			end
		end
	end))

	print("=== [GameManager] Fully initialized (Production) ===")
end

function GameManager.Destroy()
	maid:Cleanup()

	-- Propagate cleanup to prevent memory leaks
	if typeof(RoundManager.Destroy) == "function" then RoundManager.Destroy() end
	if typeof(LobbyManager.Destroy) == "function" then LobbyManager.Destroy() end
	if typeof(EntityAI.Destroy) == "function" then EntityAI.Destroy() end
	if typeof(HorrorEvents.Destroy) == "function" then HorrorEvents.Destroy() end
	if typeof(GhostShipGenerator.Destroy) == "function" then GhostShipGenerator.Destroy() end
	if typeof(ExtractionManager.Destroy) == "function" then ExtractionManager.Destroy() end
	if typeof(TestHarness.Destroy) == "function" then TestHarness.Destroy() end
	if typeof(ExtractionZone.Destroy) == "function" then ExtractionZone.Destroy() end
end

return GameManager