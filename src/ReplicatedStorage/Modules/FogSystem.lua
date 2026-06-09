--!strict
-- FogSystem.lua (ReplicatedStorage/Modules)
local Utils = require(script.Parent.Utils)
local TweenService = Utils.GetService("TweenService")
local RunService = Utils.GetService("RunService")

local FogSystem = {}
FogSystem.__index = FogSystem

local CONFIG = {
	InitialRadius = 450,
	MinRadius = 60,
	ShrinkTime = 420,
	centerPosition = Vector3.new(0, 50, 0),
}

local currentSafeRadius = CONFIG.InitialRadius
local shrinkTween: Tween? = nil
local initialized = false
local maid = Utils.CreateMaid()

function FogSystem.StartClosingCircle()
	if shrinkTween then shrinkTween:Cancel() end
	local tweenInfo = TweenInfo.new(CONFIG.ShrinkTime, Enum.EasingStyle.Linear)
	shrinkTween = TweenService:Create({Radius = CONFIG.InitialRadius}, tweenInfo, {Radius = CONFIG.MinRadius})
	shrinkTween:Play()
	print("[FogSystem] Closing circle started - Mist is now active")
end

function FogSystem.Initialize()
	if initialized then return end
	initialized = true

	maid:GiveTask(RunService.Heartbeat:Connect(function()
		if shrinkTween and shrinkTween.PlaybackState == Enum.PlaybackState.Playing then
			currentSafeRadius = shrinkTween:GetValue().Radius or currentSafeRadius
		end
	end))

	print("[FogSystem] Initialized - Closing Green Smothering Mist ready")
end

function FogSystem.GetSafeRadius(): number
	return currentSafeRadius
end

function FogSystem.IsInSafeZone(position: Vector3): boolean
	return (position - CONFIG.centerPosition).Magnitude <= currentSafeRadius
end

-- THIS IS THE FUNCTION THAT WAS MISSING
function FogSystem.GetSanityDrainMultiplier(position: Vector3): number
	if FogSystem.IsInSafeZone(position) then
		return 0.0
	end
	local distanceOutside = (position - CONFIG.centerPosition).Magnitude - currentSafeRadius
	return 1.0 + (distanceOutside * 0.012)
end

function FogSystem.Destroy()
	if shrinkTween then shrinkTween:Cancel() end
	maid:Cleanup()
end

return FogSystem