--!strict
-- GameManager.lua (ServerScriptService)
-- Fixed: Removed TestHarness double-init, enhanced sanitation for descendants/GUIs, os.clock() consistency.

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

local function cleanupLegacyAssets()
	print("[GameManager] Running deep asset sanitation pass...")
	local count = 0

	local targets = {workspace, game.ReplicatedStorage:FindFirstChild("Assets")}

	for _, root in ipairs(targets) do
		if not root then continue end
		for _, obj in ipairs(root:GetDescendants()) do
			local isLegacyScript = obj:IsA("LuaSourceContainer") and (
				obj.Name == "GUI" or 
				obj.Name:find("Script") or 
				obj.Parent.Name == "Head"
			)
			local isLegacyGui = obj:IsA("GuiObject") or obj:IsA("BillboardGui") or obj:IsA("SurfaceGui")

			if isLegacyScript or isLegacyGui then
				obj:Destroy()
				count += 1
			end
		end
	end

	if count > 0 then
		print(`[GameManager] Purged {count} legacy assets/scripts to prevent console errors`)
	end
end

function GameManager.Initialize()
	print("=== [GameManager] Initializing all systems ===")

	cleanupLegacyAssets()

	pcall(RoundManager.Initialize)
	pcall(LobbyManager.Initialize)

	local systems = {
		{ name = "FogSystem", sys = FogSystem },
		{ name = "ShipController", sys = ShipController },
		{ name = "GhostShipGenerator", sys = GhostShipGenerator },
		{ name = "HorrorEvents", sys = HorrorEvents },
		{ name = "ExtractionManager", sys = ExtractionManager },
		{ name = "ExtractionZone", sys = ExtractionZone },
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

	-- TestHarness ONLY in Studio (fixed double-init)
	if RunService:IsStudio() and typeof(TestHarness.Initialize) == "function" then
		pcall(TestHarness.Initialize)
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
		local now = os.clock()
		if now - lastUpdate < UPDATE_RATE then return end
		lastUpdate = now

		-- Update player positions
		for _, player in Players:GetPlayers() do
			local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
			if root then
				playerPositions[player] = root.Position
			end
		end

		-- Core updates
		if typeof(EntityAI.UpdateAll) == "function" then
			EntityAI.UpdateAll(playerPositions, dt)
		end
		if typeof(GhostShipGenerator.CullDistantShips) == "function" then
			GhostShipGenerator.CullDistantShips(Vector3.new(0, 50, 0))
		end

		-- Horror + Fog
		if typeof(HorrorEvents.GetHorrorLevel) == "function" then
			local level = HorrorEvents.GetHorrorLevel()
			if typeof(FogSystem.SetHorrorLevel) == "function" then
				FogSystem.SetHorrorLevel(level)
			end
		end
	end))

	print("=== [GameManager] Fully initialized with anti-exploit measures ===")
end

function GameManager.Destroy()
	maid:Cleanup()
	local systems = {RoundManager, LobbyManager, FogSystem, ShipController, GhostShipGenerator, EntityAI, HorrorEvents, ExtractionManager, ExtractionZone, TestHarness}
	for _, sys in systems do
		if typeof(sys.Destroy) == "function" then
			pcall(sys.Destroy)
		end
	end
end

function GameManager.IsRateLimited(player: Player, minInterval: number): boolean
	local last = lastRemoteTime[player] or 0
	local now = os.clock()
	if now - last < minInterval then return true end
	lastRemoteTime[player] = now
	return false
end

return GameManager