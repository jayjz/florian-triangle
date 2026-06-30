--!strict
-- RoundManager.lua (ServerScriptService)
-- Complete round state, quota, win/lose conditions, and lobby reset flow.
-- Integrated FogSystem closing circle on round start.

local Utils = require(game.ReplicatedStorage.Modules.Utils)
local FogSystem = require(game.ReplicatedStorage.Modules.FogSystem)  -- Added require

local RoundManager = {}

local EXTRACTION_QUOTA = 1200  -- Tuned for ~6-8 min matches
local currentExtracted = 0
local roundActive = false
local roundStartTime = 0

local WinRemote = Utils.CreateRemoteEvent("RoundWin")
local LoseRemote = Utils.CreateRemoteEvent("RoundLose")

local function spawnGhostShips()
	local GhostShipGenerator = require(game.ReplicatedStorage.Modules.GhostShipGenerator)
	local numShips = math.random(2, 4)
	print(`[RoundManager] Spawning {numShips} ghost ships...`)
	for i = 1, numShips do
		local angle = math.rad(math.random(0, 360))
		local dist = math.random(150, 300)
		local spawnPos = Vector3.new(math.cos(angle) * dist, 50, math.sin(angle) * dist)
		GhostShipGenerator.CreateTestShip(spawnPos)
	end
end

local function checkWinCondition()
	if currentExtracted >= EXTRACTION_QUOTA then
		print("=== [RoundManager] WIN — Crew paid the toll and escaped! ===")
		roundActive = false
		WinRemote:FireAllClients(true)
		task.delay(4, function()
			local LobbyManager = require(script.Parent.LobbyManager)
			LobbyManager.ReturnToLobby()
		end)
	end
end

local function checkLoseCondition()
	local elapsed = tick() - roundStartTime
	if elapsed > 480 then  -- 8 minutes max
		print("=== [RoundManager] LOSE — The mist claimed the crew ===")
		roundActive = false
		LoseRemote:FireAllClients(true)
		task.delay(4, function()
			local LobbyManager = require(script.Parent.LobbyManager)
			LobbyManager.ReturnToLobby()
		end)
	end
end

function RoundManager.AddExtracted(amount: number)
	if not roundActive then return end
	currentExtracted += amount
	print(`[RoundManager] Total extracted: {currentExtracted} / {EXTRACTION_QUOTA}`)
	checkWinCondition()
end

function RoundManager.StartRound()
	currentExtracted = 0
	roundActive = true
	roundStartTime = tick()
	
	-- Start the mist closing circle when round begins
	FogSystem.StartClosingCircle()
	
	-- Spawn ghost ships for scavenging
	spawnGhostShips()

	-- Enable ship sailing mode for all players.
	-- ShipController defaults to SailingEnabled = false (Humanoid movement,
	-- for lobby / ghost ship interiors). At round start (Windmill Village),
	-- players board their crew ship and begin sailing — activate
	-- ShipController physics, disable Humanoid movement to prevent
	-- tug-of-war between Humanoid.WalkSpeed (16) and AssemblyLinearVelocity (58).
	local ShipController = require(game.ReplicatedStorage.Modules.ShipController)
	local Players = game:GetService("Players")
	for _, player in Players:GetPlayers() do
		ShipController.SetSailing(player, true)
	end
	
	print(`[RoundManager] New round started. Quota: {EXTRACTION_QUOTA}`)
end

function RoundManager.GetProgress(): (number, number, boolean)
	return currentExtracted, EXTRACTION_QUOTA, roundActive
end

function RoundManager.Initialize()
	-- Round normally starts via LobbyManager or GameManager
	print("[RoundManager] Initialized with win/lose flow")
end

function RoundManager.Destroy()
	roundActive = false
	currentExtracted = 0
end

return RoundManager
