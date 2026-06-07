--!strict
-- HorrorEvents.lua (ReplicatedStorage/Modules)
-- Production horror & sanity system. Drives sanity decay, pulses, hallucinations.
-- Optimized: Single Heartbeat, dense fog detection via FogSystem closing circle,
-- client remotes for group perception. Integrates tightly with new closing mist.

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
	UpdateRate = 0.25, -- Server sanity tick
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

	print("[HorrorEvents] Initialized - Integrated with Closing Smothering Mist")
end

function HorrorEvents:Update(dt: number)
	for player, level in playerSanity do
		if not player.Character then continue end
		local root = player.Character:FindFirstChild("HumanoidRootPart")
		if not root then continue end

		-- Use new FogSystem closing circle for dense fog detection
		local inDenseFog = FogSystem.GetVisibilityDistance() < 70
		local decay = CONFIG.BaseDecay * (inDenseFog and CONFIG.FogMultiplier or 1.0)
		local newSanity = Utils.Clamp(level - (decay * dt), 0, 100)

		playerSanity[player] = newSanity
		Remotes.SanityChanged:FireClient(player, math.floor(newSanity))

		-- Low sanity horror escalation
		if newSanity < CONFIG.HallucinationThreshold then
			-- TODO: Probability-based hallucination + Luffy-shadow jumpscare trigger
			if math.random() < 0.08 then
				Remotes.HallucinationTriggered:FireClient(player, 1) -- Type 1 = shadow figure
			end
		end
	end
end

function HorrorEvents.TriggerHorrorPulse(intensity: number)
	local safe = Utils.Clamp(intensity or 0, 0, 2)
	Remotes.HorrorPulse:FireAllClients(safe)           -- Group horror feel
	FogSystem.TriggerHorrorPulse(safe)                 -- Accelerates closing mist
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