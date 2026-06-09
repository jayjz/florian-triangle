--!strict
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
	UpdateRate = 0.25,
	HallucinationThreshold = 45,
	HallucinationCooldown = 8,
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
		local root = player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if not root then continue end

		-- Defensive nil protection
		local multiplier = 0.0
		if FogSystem and FogSystem.GetSanityDrainMultiplier then
			multiplier = FogSystem.GetSanityDrainMultiplier(root.Position)
		end

		local decay = CONFIG.BaseDecay * multiplier
		local newSanity = Utils.Clamp(level - (decay * dt), 0, 100)
		playerSanity[player] = newSanity

		if math.floor(level) ~= math.floor(newSanity) then
			Remotes.SanityChanged:FireClient(player, math.floor(newSanity))
		end

		-- Hallucinations at low sanity
		if newSanity < CONFIG.HallucinationThreshold then
			local now = tick()
			if not lastHallucination[player] or (now - lastHallucination[player]) > CONFIG.HallucinationCooldown then
				local chance = (CONFIG.HallucinationThreshold - newSanity) / 100 + 0.12
				if math.random() < chance then
					local hType = math.random(1, 4)
					Remotes.HallucinationTriggered:FireClient(player, hType)
					lastHallucination[player] = now
				end
			end
		end
	end
end

function HorrorEvents.TriggerSanityDamage(player: Player, amount: number)
	if playerSanity[player] then
		playerSanity[player] = Utils.Clamp(playerSanity[player] - amount, 0, 100)
	end
end

function HorrorEvents.TriggerHorrorPulse(intensity: number)
	-- Can be expanded later
end

function HorrorEvents.GetHorrorLevel(): number
	return 0 -- Placeholder - expand with actual logic if needed
end

function HorrorEvents.Destroy()
	globalMaid:Cleanup()
end

return HorrorEvents