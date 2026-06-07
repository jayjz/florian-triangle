--!strict
-- HorrorEvents.lua (ReplicatedStorage/Modules)
-- Production horror & sanity system. API fixed: TriggerHorrorPulse now takes intensity only (no player param per review). Uses FireAllClients for all players (Smothering Mist perception on client).
-- No _G. Server calculates, clients perceive via remotes.
-- Integrates with FogSystem for GlobalFogPhase.

local Utils = require(script.Parent.Utils)
local FogSystem = require(script.Parent.FogSystem)
local RunService = Utils.GetService("RunService")
local Players = Utils.GetService("Players")

local HorrorEvents = {}
HorrorEvents.__index = HorrorEvents

local playerSanity: {[Player]: number} = {}
local globalMaid = Utils.CreateMaid()

local Remotes = {
    SanityChanged = Utils.CreateRemoteEvent("SanityChanged"),
    HorrorPulse = Utils.CreateRemoteEvent("HorrorPulse"),
    HallucinationTriggered = Utils.CreateRemoteEvent("HallucinationTriggered"),
}

local CONFIG = {
    BaseDecay = 3.8,
    FogMultiplier = 2.8,
    UpdateRate = 0.25,
    HallucinationThreshold = 45,
}

function HorrorEvents.Initialize()
    globalMaid:GiveTask(RunService.Heartbeat:Connect(function(dt: number)
        HorrorEvents:Update(dt)
    end))

    Players.PlayerAdded:Connect(function(player)
        playerSanity[player] = 100
    end)

    Players.PlayerRemoving:Connect(function(player)
        playerSanity[player] = nil
    end)

    print("[HorrorEvents] Initialized with fixed API (no player param on TriggerHorrorPulse)")
end

function HorrorEvents:Update(dt: number)
    for player, level in playerSanity do
        if not player.Character then continue end
        local root = player.Character:FindFirstChild("HumanoidRootPart")
        if not root then continue end

        local inDenseFog = FogSystem.GetVisibilityDistance() < 60
        local decay = CONFIG.BaseDecay * (inDenseFog and CONFIG.FogMultiplier or 1.0)

        playerSanity[player] = Utils.Clamp(level - (decay * dt), 0, 100)
        Remotes.SanityChanged:FireClient(player, math.floor(playerSanity[player]))
    end
end

function HorrorEvents.TriggerHorrorPulse(intensity: number)
    -- Fixed per Priority 0: intensity only, FireAllClients for group horror perception
    Remotes.HorrorPulse:FireAllClients(Utils.Clamp(intensity, 0, 2))
    FogSystem.TriggerHorrorPulse(intensity)
end

function HorrorEvents.GetHorrorLevel(): number
    local total, count = 0, 0
    for _, level in playerSanity do
        total += (100 - level) / 100
        count += 1
    end
    return count > 0 and (total / count) or 0.2
end

function HorrorEvents.Destroy()
    globalMaid:Cleanup()
    table.clear(playerSanity)
end

return HorrorEvents
