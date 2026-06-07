--!strict
-- RoundManager.server.lua - Updated
local RoundManager = {}
local Utils = require(game.ReplicatedStorage.Modules.Utils)  -- Add for Remote

local EXTRACTION_QUOTA = 1000
local currentExtracted = 0
local roundActive = false

local WinRemote = Utils.CreateRemoteEvent("RoundWin")  -- New: Client feedback

local function checkWinCondition()
    if currentExtracted >= EXTRACTION_QUOTA then
        print("=== [RoundManager] WIN — Crew has paid the toll! ===")
        roundActive = false
        WinRemote:FireAllClients(true)  -- Signal win
        -- TODO: Round reset logic
    end
end

-- AddExtracted, StartRound, GetProgress unchanged...

function RoundManager.Initialize()
    RoundManager.StartRound()
    print("[RoundManager] Initialized successfully")
end

return RoundManager