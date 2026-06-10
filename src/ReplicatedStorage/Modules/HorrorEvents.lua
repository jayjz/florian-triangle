--!strict
-- HorrorEvents.lua
-- Fixed: Added missing TriggerSanityDamage/TriggerHorrorPulse (P0 from audit), throttled to 4Hz, os.clock(), stronger guards.

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
	UpdateRate = 0.25, -- 4Hz
	HallucinationThreshold = 45,
	HallucinationCooldown = 8,
}

local lastHallucination: {[Player]: number} = {}
local lastUpdate = 0

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
	local now = os.clock()
	if now - lastUpdate < CONFIG.UpdateRate then return end
	lastUpdate = now

	for player, level in playerSanity do
		if not player or not player.Parent then continue end
		if not player.Character then continue end
		local root = player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if not root then continue end

		local multiplier = 0.0
		if FogSystem and typeof(FogSystem.GetSanityDrainMultiplier) == "function" then
			multiplier = FogSystem.GetSanityDrainMultiplier(root.Position)
		end

		local decay = CONFIG.BaseDecay * multiplier
		local newSanity = Utils.Clamp(level - (decay * dt), 0, 100)
		playerSanity[player] = newSanity

		if math.floor(level) ~= math.floor(newSanity) then
			Remotes.SanityChanged:FireClient(player, math.floor(newSanity))
		end

		-- Hallucinations
		if newSanity < CONFIG.HallucinationThreshold then
			local hNow = os.clock()
			if not lastHallucination[player] or (hNow - lastHallucination[player]) > CONFIG.HallucinationCooldown then
				local chance = (CONFIG.HallucinationThreshold - newSanity) / 100 + 0.12
				if math.random() < chance then
					local hType = math.random(1, 4)
					Remotes.HallucinationTriggered:FireClient(player, hType)
					lastHallucination[player] = hNow
				end
			end
		end
	end
end

-- P0 Fixes: Missing methods called from ShipController
function HorrorEvents.TriggerSanityDamage(player: Player, amount: number)
	if not player or not playerSanity[player] then return end
	playerSanity[player] = Utils.Clamp(playerSanity[player] - amount, 0, 100)
	Remotes.SanityChanged:FireClient(player, math.floor(playerSanity[player]))
end

function HorrorEvents.TriggerHorrorPulse(intensity: number)
	Remotes.HorrorPulse:FireAllClients(intensity)
end

-- Bonus: Expose for GameManager
function HorrorEvents.GetHorrorLevel(): number
	local total, count = 0, 0
	for _, sanity in playerSanity do
		total += sanity
		count += 1
	end
	return count > 0 and (100 - total / count) or 0
end

function HorrorEvents.Destroy()
	globalMaid:Cleanup()
end

return HorrorEvents