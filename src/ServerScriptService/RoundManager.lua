--!strict
-- RoundManager.server.lua (ServerScriptService)
-- Complete round state, quota, win/lose conditions, and lobby reset flow.

local Utils = require(game.ReplicatedStorage.Modules.Utils)
local LobbyManager = require(script.Parent.LobbyManager)

local RoundManager = {}

local EXTRACTION_QUOTA = 1200  -- Tuned for ~6-8 min matches
local currentExtracted = 0
local roundActive = false
local roundStartTime = 0

local WinRemote = Utils.CreateRemoteEvent("RoundWin")
local LoseRemote = Utils.CreateRemoteEvent("RoundLose")

local function checkWinCondition()
	if currentExtracted >= EXTRACTION_QUOTA then
		print("=== [RoundManager] WIN — Crew paid the toll and escaped! ===")
		roundActive = false
		WinRemote:FireAllClients(true)
		task.delay(4, function()
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
	print(`[RoundManager] New round started. Quota: {EXTRACTION_QUOTA}`)
end

function RoundManager.GetProgress(): (number, number, boolean)
	return currentExtracted, EXTRACTION_QUOTA, roundActive
end

function RoundManager.Initialize()
	RoundManager.StartRound()
	print("[RoundManager] Initialized with win/lose flow")
end

function RoundManager.Destroy()
	roundActive = false
	currentExtracted = 0
end

return RoundManager