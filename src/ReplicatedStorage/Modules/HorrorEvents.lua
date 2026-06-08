--!strict
-- HorrorEvents.lua (ReplicatedStorage/Modules)
-- Production hallucination + sanity system with server triggers.
-- Integrates with FogSystem closing circle for dynamic horror escalation.
-- High quality: Cooldowns, probability, player-specific weighting, defensive design.

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
	HallucinationCooldown = 8,   -- Per player
}

local lastHallucination: {[Player]: number} = {}

function HorrorEvents.Initialize()
	globalMaid:GiveTask(RunService.Heartbeat:Connect(function(dt: number)
		HorrorEvents:Update(dt)
	end))

	Players.PlayerAdded:Connect(function(player)
		playerSanity[player] = 100
	end)

	Players.PlayerRemoving:Connect(function(player)
		playerSanity[player] = nil
		lastHallucination[player] = nil
	end)

	print("[HorrorEvents] Initialized - Hallucination system with cooldowns active")
end

function HorrorEvents:Update(dt: number)
	for player, level in playerSanity do
		if not player.Character then continue end
		local root = player.Character:FindFirstChild("HumanoidRootPart")
		if not root then continue end

		local inDenseFog = FogSystem.GetVisibilityDistance() < 70
		local decay = CONFIG.BaseDecay * (inDenseFog and CONFIG.FogMultiplier or 1.0)
		local newSanity = Utils.Clamp(level - (decay * dt), 0, 100)

		playerSanity[player] = newSanity
		Remotes.SanityChanged:FireClient(player, math.floor(newSanity))

		-- Hallucination triggers at low sanity
		if newSanity < CONFIG.HallucinationThreshold then
			local now = tick()
			if not lastHallucination[player] or (now - lastHallucination[player]) > CONFIG.HallucinationCooldown then
				if math.random() < 0.12 then  -- Tuned probability
					Remotes.HallucinationTriggered:FireClient(player, math.random(1, 3))  -- 1=shadow, 2=whispers, 3=fake entity
					lastHallucination[player] = now
				end
			end
		end
	end
end

function HorrorEvents.TriggerHorrorPulse(intensity: number)
	local safe = Utils.Clamp(intensity or 0, 0, 2)
	Remotes.HorrorPulse:FireAllClients(safe)
	FogSystem.TriggerHorrorPulse(safe)
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
	table.clear(lastHallucination)
end

return HorrorEvents