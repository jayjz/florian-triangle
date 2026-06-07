--!strict
-- QuotaManager.lua (ReplicatedStorage/Modules)
-- Tracks total extracted loot and checks win condition.
-- One Piece themed: "Pay the toll to escape the Florian Triangle"

local QuotaManager = {}
QuotaManager.__index = QuotaManager

local TOTAL_QUOTA = 1000 -- Beli value needed to escape
local currentExtracted = 0

function QuotaManager.AddExtracted(amount: number)
    currentExtracted += amount
    print(`[Quota] Total extracted: {currentExtracted} / {TOTAL_QUOTA}`)
    
    if currentExtracted >= TOTAL_QUOTA then
        QuotaManager.TriggerWin()
    end
end

function QuotaManager.TriggerWin()
    print("=== [Quota] WIN CONDITION MET — Crew escapes the Florian Triangle ===")
    -- Future: Fire RemoteEvent to show win screen, end round, etc.
end

function QuotaManager.GetProgress(): (number, number)
    return currentExtracted, TOTAL_QUOTA
end

function QuotaManager.Reset()
    currentExtracted = 0
end

return QuotaManager