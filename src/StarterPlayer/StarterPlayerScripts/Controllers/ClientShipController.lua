--!strict
-- ClientShipController.lua (StarterPlayerScripts/Controllers)
-- Ship movement input + boarding visuals for ghost ship interiors.

local Utils = require(game.ReplicatedStorage.Modules.Utils)
local CollectionService = Utils.GetService("CollectionService")
local RunService = Utils.GetService("RunService")
local UserInputService = Utils.GetService("UserInputService")
local TweenService = Utils.GetService("TweenService")
local Players = Utils.GetService("Players")

local Remotes = {
	PlayerMoveInput = Utils.CreateRemoteEvent("PlayerMoveInput"),
	PlayerDocked = Utils.CreateRemoteEvent("PlayerDocked"),
}

local ClientShipController = {}
local maid = Utils.CreateMaid()

local lastDetection: {[Model]: number} = {}

local function createHighlight(model: Model, fillColor: Color3, outlineColor: Color3)
	local highlight = Instance.new("Highlight")
	highlight.FillColor = fillColor
	highlight.OutlineColor = outlineColor
	highlight.FillTransparency = 0.65
	highlight.OutlineTransparency = 0.15
	highlight.Adornee = model
	highlight.Parent = model
	maid:GiveTask(highlight)
end

local function onGhostShipAdded(ship: Model)
	if lastDetection[ship] and tick() - lastDetection[ship] < 1.8 then return end
	lastDetection[ship] = tick()
	createHighlight(ship, Color3.fromRGB(255, 90, 40), Color3.fromRGB(255, 180, 80))
end

function ClientShipController.Initialize()
	maid:GiveTask(CollectionService:GetInstanceAddedSignal("GhostShip"):Connect(onGhostShipAdded))

	for _, obj in CollectionService:GetTagged("GhostShip") do
		onGhostShipAdded(obj)
	end

	local player = Players.LocalPlayer

	-- Movement input — only fire when sailing is enabled + input CHANGED.
	-- ShipController.SetSailing() sets player:SetAttribute("SailingEnabled", bool)
	-- to gate input. Change detection prevents:
	-- 1. Input spam during sailing (60 Hz RenderStepped → server, wasted bandwidth)
	--    Before: holding W → 60 identical packets/sec → server rate-limits to 12.5Hz
	--    → 47.5/60 packets/sec DROPPED + 80ms artificial latency
	--    After: press W → 1 packet, hold W 5 sec → 0 packets, release W → 1 stop packet
	--    → ~2-10 packets/sec actual (direction changes only), zero artificial latency
	-- 2. ShipState velocity pollution from on-foot WASD (stale velocity launch bug)
	-- Server validates via isInputAllowed() as defense-in-depth.
	local lastMoveDir = Vector3.new(0, 0, 0)
	maid:GiveTask(RunService.RenderStepped:Connect(function()
		if player:GetAttribute("SailingEnabled") ~= true then
			-- Reset lastMoveDir when not sailing so first sailing input always fires
			-- (prevents: sail → board → exit → press W → moveDir unchanged from pre-board
			-- → change detection blocks input → ship won't move until direction changes)
			lastMoveDir = Vector3.new(0, 0, 0)
			return
		end

		local moveDir = Vector3.new(0, 0, 0)
		if UserInputService:IsKeyDown(Enum.KeyCode.W) then moveDir += Vector3.new(0, 0, -1) end
		if UserInputService:IsKeyDown(Enum.KeyCode.S) then moveDir += Vector3.new(0, 0, 1) end
		if UserInputService:IsKeyDown(Enum.KeyCode.A) then moveDir += Vector3.new(-1, 0, 0) end
		if UserInputService:IsKeyDown(Enum.KeyCode.D) then moveDir += Vector3.new(1, 0, 0) end

		if moveDir.Magnitude > 1 then
			moveDir = moveDir.Unit
		end

		-- Only fire when input CHANGED (including stop: moveDir going to zero).
		-- Threshold 0.01 catches direction changes, ignores float precision noise.
		-- This fixes the "ship never stops" bug: previously client only fired when
		-- moveDir.Magnitude > 0, so releasing keys → NO packet → server never gets
		-- stop command → ship sails forever at last velocity. Now: keys released →
		-- moveDir = (0,0,0) → differs from lastMoveDir → FireServer(Vector3.zero)
		-- → server sets targetVelocity = 0 → ship decelerates via Lerp → stops.
		if (moveDir - lastMoveDir).Magnitude > 0.01 then
			lastMoveDir = moveDir
			Remotes.PlayerMoveInput:FireServer(moveDir)
		end
	end))

	-- Docking feedback
	maid:GiveTask(Remotes.PlayerDocked.OnClientEvent:Connect(function(shipModel: Model)
		print("[ClientShipController] Boarded ghost ship interior - horror intensified")

		-- Camera shake + FOV kick
		local camera = workspace.CurrentCamera
		if not camera then return end
		local character = player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid") :: Humanoid?

		-- FOV kick
		local baseFov = camera.FieldOfView
		local ti = TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
		local tweenOut = TweenService:Create(camera, ti, {FieldOfView = baseFov + 8})
		tweenOut:Play()
		tweenOut.Completed:Connect(function()
			local ti2 = TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
			TweenService:Create(camera, ti2, {FieldOfView = baseFov}):Play()
		end)

		-- Screen shake via Humanoid.CameraOffset
		if humanoid then
			task.spawn(function()
				local duration = 0.6
				local start = os.clock()
				while os.clock() - start < duration do
					local t = (os.clock() - start) / duration
					local intensity = (1 - t) * 0.8
					humanoid.CameraOffset = Vector3.new(
						(math.random() * 2 - 1) * intensity,
						(math.random() * 2 - 1) * intensity,
						0
					)
					RunService.RenderStepped:Wait()
				end
				humanoid.CameraOffset = Vector3.new()
			end)
		end
	end))

	print("[ClientShipController] Initialized - Ship interiors boarding active")
end

function ClientShipController.Destroy()
	maid:Cleanup()
	table.clear(lastDetection)
end

return ClientShipController