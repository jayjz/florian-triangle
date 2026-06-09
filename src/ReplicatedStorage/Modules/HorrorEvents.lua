--!strict
-- HorrorEvents.lua (ReplicatedStorage/Modules)
-- Production hallucination + sanity system with server triggers.
-- Integrates with FogSystem closing circle for dynamic horror escalation.

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

	print("[HorrorEvents] Initialized - Hallucination system active")
end

function HorrorEvents:Update(dt: number)
	for player, level in playerSanity do
		if not player.Character then continue end
		local root = player.Character:FindFirstChild("HumanoidRootPart")
		if not root then continue end

		-- Increased decay in dense fog or outside safe zone
		local inDenseFog = FogSystem.GetVisibilityDistance() < 70
		local outsideSafeZone = not FogSystem.IsInSafeZone(root.Position)
		
		local decay = CONFIG.BaseDecay
		if outsideSafeZone then
			decay *= 4.0 -- Deadly outside safe zone
		elseif inDenseFog then
			decay *= CONFIG.FogMultiplier
		end
		
		local newSanity = Utils.Clamp(level - (decay * dt), 0, 100)
		playerSanity[player] = newSanity
		
		-- Only fire if value changed significantly to save bandwidth
		if math.floor(level) ~= math.floor(newSanity) then
			Remotes.SanityChanged:FireClient(player, math.floor(newSanity))
		end

		-- Hallucination triggers at low sanity
		if newSanity < CONFIG.HallucinationThreshold then
			local now = tick()
			if not lastHallucination[player] or (now - lastHallucination[player]) > CONFIG.HallucinationCooldown then
				-- Chance increases as sanity drops
				local chance = (CONFIG.HallucinationThreshold - newSanity) / 100 + 0.05
				if math.random() < chance then
					local hType = math.random(1, 3) -- 1=Shadow, 2=Whispers, 3=Glitch/Fake Entity
					Remotes.HallucinationTriggered:FireClient(player, hType)
					lastHallucination[player] = now
				end
			end
		end
	end
end

function HorrorEvents.TriggerSanityDamage(player: Player, amount: number)
	local current = playerSanity[player]
	if current then
		playerSanity[player] = Utils.Clamp(current - amount, 0, 100)
		Remotes.SanityChanged:FireClient(player, math.floor(playerSanity[player]))
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
