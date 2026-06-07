--!strict
-- RoundManager.server.lua
local Utils = require(game.ReplicatedStorage.Modules.Utils)
local RoundManager = {}

local EXTRACTION_QUOTA = 1000
local currentExtracted = 0
local roundActive = false

local WinRemote = Utils.CreateRemoteEvent("RoundWin")

local function checkWinCondition()
	if currentExtracted >= EXTRACTION_QUOTA then
		print("=== [RoundManager] WIN — Crew paid the toll! ===")
		roundActive = false
		WinRemote:FireAllClients(true)
	end
end

function RoundManager.AddExtracted(amount: number)
	if not roundActive then return end
	currentExtracted += amount
	print(`[RoundManager] Extracted: {currentExtracted} / {EXTRACTION_QUOTA}`)
	checkWinCondition()
end

function RoundManager.StartRound()
	currentExtracted = 0
	roundActive = true
	print(`[RoundManager] Round started. Quota: {EXTRACTION_QUOTA}`)
end

function RoundManager.GetProgress()
	return currentExtracted, EXTRACTION_QUOTA, roundActive
end

function RoundManager.Initialize()
	RoundManager.StartRound()
	print("[RoundManager] Initialized")
end

return RoundManager