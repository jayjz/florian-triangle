--!strict
-- RoundManager.server.lua (ServerScriptService)
-- Handles round state, quota tracking, and win/lose conditions.
-- One Piece themed: "Escape the Florian Triangle by paying the toll."

local EXTRACTION_QUOTA = 1000 -- Beli needed to escape

local currentExtracted = 0
local roundActive = false

local function checkWinCondition()
    if currentExtracted >= EXTRACTION_QUOTA then
        print("=== [RoundManager] WIN — Crew has paid the toll and escaped the Florian Triangle ===")
        roundActive = false
        -- Future: Fire RemoteEvent to all clients to show win screen
    end
end

function RoundManager.AddExtracted(amount: number)
    currentExtracted += amount
    print(`[RoundManager] Total extracted: {currentExtracted} / {EXTRACTION_QUOTA}`)

    checkWinCondition()
end

function RoundManager.StartRound()
    currentExtracted = 0
    roundActive = true
    print("[RoundManager] New round started. Quota:", EXTRACTION_QUOTA)
end

function RoundManager.GetProgress(): (number, number, boolean)
    return currentExtracted, EXTRACTION_QUOTA, roundActive
end

-- Expose to other server scripts
_G.RoundManager = RoundManager

print("[RoundManager] Loaded")