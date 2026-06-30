--!strict
-- LobbyManager.lua (ServerScriptService)
-- Handles Foosha Village lobby, ready-up, non-blocking countdown, and game transition.
-- Fixed: Non-blocking timer via Heartbeat, type validation on remote, teleport safety.

local Utils = require(game.ReplicatedStorage.Modules.Utils)

local Players = Utils.GetService("Players")
local RunService = Utils.GetService("RunService")
local CollectionService = Utils.GetService("CollectionService")

local LobbyManager = {}
local MIN_PLAYERS = 1
local MAX_PLAYERS = 6
local COUNTDOWN_TIME = 10

local lobbySpawns = {} -- Tagged "LobbySpawn"
local gameSpawns = {} -- Tagged "GameSpawn"

local isInLobby = true
local countdownActive = false
local readyPlayers: {[Player]: boolean} = {}
local countdownStartTime = 0

local maid = Utils.CreateMaid()

local CountdownRemote = Utils.CreateRemoteEvent("LobbyCountdown")
local LobbyReadyRemote = Utils.CreateRemoteEvent("LobbyReady")

function LobbyManager.Initialize()
	lobbySpawns = CollectionService:GetTagged("LobbySpawn")
	gameSpawns = CollectionService:GetTagged("GameSpawn")

	Players.PlayerAdded:Connect(LobbyManager.OnPlayerAdded)
	Players.PlayerRemoving:Connect(LobbyManager.OnPlayerRemoving)

	LobbyReadyRemote.OnServerEvent:Connect(function(player: Player, isReady: any)
		-- Security: Type validation (audit P1)
		if typeof(isReady) ~= "boolean" then
			return
		end
		LobbyManager.SetReady(player, isReady)
	end)

	print("[LobbyManager] Initialized - Foosha Lobby Active")
end

function LobbyManager.OnPlayerAdded(player: Player)
	player.CharacterAdded:Connect(function(char: Model)
		task.defer(function() -- Non-blocking character load safety
			if isInLobby then
				LobbyManager.TeleportToLobby(player)
			else
				LobbyManager.TeleportToGame(player)
			end
		end)
	end)
end

function LobbyManager.OnPlayerRemoving(player: Player)
	readyPlayers[player] = nil
	LobbyManager.CheckStartCondition()
end

function LobbyManager.TeleportToLobby(player: Player)
	if #lobbySpawns == 0 then return end
	local spawn = lobbySpawns[math.random(1, #lobbySpawns)]
	local char = player.Character
	if not char then return end
	local root = char:FindFirstChild("HumanoidRootPart") :: BasePart?
	if root and spawn then
		root.CFrame = spawn.CFrame + Vector3.new(0, 5, 0)
		-- Physics hardening (best practice)
		root.AssemblyLinearVelocity = Vector3.zero
		root.AssemblyAngularVelocity = Vector3.zero
	end
end

function LobbyManager.SetReady(player: Player, isReady: boolean)
	readyPlayers[player] = isReady
	LobbyManager.CheckStartCondition()
end

function LobbyManager.CheckStartCondition()
	if countdownActive or not isInLobby then return end

	local readyCount = 0
	for _, ready in readyPlayers do
		if ready then readyCount += 1 end
	end

	local totalPlayers = #Players:GetPlayers()
	if totalPlayers >= MIN_PLAYERS and readyCount >= MIN_PLAYERS then
		LobbyManager.StartCountdown()
	end
end

-- Non-blocking countdown (Roblox-recommended pattern)
function LobbyManager.StartCountdown()
	countdownActive = true
	countdownStartTime = os.clock()
	print("[LobbyManager] Starting 10s countdown to Windmill Village...")

	maid:GiveTask(RunService.Heartbeat:Connect(function()
		local elapsed = os.clock() - countdownStartTime
		local remaining = math.max(0, COUNTDOWN_TIME - math.floor(elapsed))

		CountdownRemote:FireAllClients(remaining)

		if remaining <= 0 then
			LobbyManager.FinishCountdown()
		end
	end))
end

function LobbyManager.FinishCountdown()
	maid:DoCleaning() -- Stop countdown Heartbeat

	if not isInLobby then return end

	isInLobby = false
	local RoundManager = require(script.Parent.RoundManager)
	RoundManager.StartRound()

	for _, player in Players:GetPlayers() do
		LobbyManager.TeleportToGame(player)
	end

	print("[LobbyManager] Round started - Players teleported to Windmill Village")
	countdownActive = false
end

function LobbyManager.TeleportToGame(player: Player)
	if #gameSpawns == 0 then return end
	local spawn = gameSpawns[math.random(1, #gameSpawns)]
	local char = player.Character
	if not char then return end
	local root = char:FindFirstChild("HumanoidRootPart") :: BasePart?
	if root and spawn then
		root.CFrame = spawn.CFrame + Vector3.new(0, 5, 0)
		root.AssemblyLinearVelocity = Vector3.zero
		root.AssemblyAngularVelocity = Vector3.zero
	end
end

function LobbyManager.ReturnToLobby()
	isInLobby = true
	readyPlayers = {}

	-- Disable sailing mode for all returning players — restore Humanoid
	-- movement for Foosha Village lobby (on-foot socializing).
	-- Prevents ShipController / Humanoid tug-of-war in lobby.
	local ShipController = require(game.ReplicatedStorage.Modules.ShipController)
	for _, player in Players:GetPlayers() do
		ShipController.SetSailing(player, false)
		LobbyManager.TeleportToLobby(player)
	end
	print("[LobbyManager] Players returned to lobby")
end

function LobbyManager.Destroy()
	maid:Cleanup()
end

return LobbyManager