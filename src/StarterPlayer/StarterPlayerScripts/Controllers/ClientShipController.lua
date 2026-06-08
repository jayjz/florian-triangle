--!strict
-- ClientShipController.lua (StarterPlayerScripts/Controllers)
-- Ship movement input + boarding visuals for ghost ship interiors.

local Utils = require(game.ReplicatedStorage.Modules.Utils)
local CollectionService = Utils.GetService("CollectionService")
local RunService = Utils.GetService("RunService")
local UserInputService = Utils.GetService("UserInputService")

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

	-- Movement input
	maid:GiveTask(RunService.RenderStepped:Connect(function()
		local moveDir = Vector3.new(0, 0, 0)
		if UserInputService:IsKeyDown(Enum.KeyCode.W) then moveDir += Vector3.new(0, 0, -1) end
		if UserInputService:IsKeyDown(Enum.KeyCode.S) then moveDir += Vector3.new(0, 0, 1) end
		if UserInputService:IsKeyDown(Enum.KeyCode.A) then moveDir += Vector3.new(-1, 0, 0) end
		if UserInputService:IsKeyDown(Enum.KeyCode.D) then moveDir += Vector3.new(1, 0, 0) end

		if moveDir.Magnitude > 0 then
			Remotes.PlayerMoveInput:FireServer(moveDir.Unit)
		end
	end))

	-- Docking feedback
	maid:GiveTask(Remotes.PlayerDocked.OnClientEvent:Connect(function(shipModel: Model)
		print("[ClientShipController] Boarded ghost ship interior - horror intensified")
		-- TODO: Camera shake + interior lighting change
	end))

	print("[ClientShipController] Initialized - Ship interiors boarding active")
end

function ClientShipController.Destroy()
	maid:Cleanup()
	table.clear(lastDetection)
end

return ClientShipController