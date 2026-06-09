--!strict
-- LobbyManager.server.lua (ServerScriptService)
-- Handles Foosha Village lobby, player ready-up, 10s countdown, then spawns to Windmill Village.
-- Integrates with RoundManager + GameManager.

local Utils = require(game.ReplicatedStorage.Modules.Utils)
local RoundManager = require(script.Parent.RoundManager)

local Players = Utils.GetService("Players")
local RunService = Utils.GetService("RunService")
local CollectionService = Utils.GetService("CollectionService")

local LobbyManager = {}

local MIN_PLAYERS = 2
local MAX_PLAYERS = 6
local COUNTDOWN_TIME = 10

local lobbySpawns = {}  -- Tagged "LobbySpawn"
local gameSpawns = {}   -- Tagged "GameSpawn"

local isInLobby = true
local countdownActive = false
local readyPlayers: {[Player]: boolean} = {}

local maid = Utils.CreateMaid()
local CountdownRemote = Utils.CreateRemoteEvent("LobbyCountdown")

function LobbyManager.Initialize()
	-- Find spawns
	lobbySpawns = CollectionService:GetTagged("LobbySpawn")
	gameSpawns = CollectionService:GetTagged("GameSpawn")

	Players.PlayerAdded:Connect(LobbyManager.OnPlayerAdded)
	Players.PlayerRemoving:Connect(LobbyManager.OnPlayerRemoving)

	print("[LobbyManager] Initialized - Foosha Lobby Active")
end

function LobbyManager.OnPlayerAdded(player: Player)
	player.CharacterAdded:Connect(function(char)
		task.wait(1)
		LobbyManager.TeleportToLobby(player)
	end)
end

function LobbyManager.OnPlayerRemoving(player: Player)
	readyPlayers[player] = nil
	LobbyManager.CheckStartCondition()
end

function LobbyManager.TeleportToLobby(player: Player)
	if #lobbySpawns > 0 then
		local spawn = lobbySpawns[math.random(1, #lobbySpawns)]
		local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		if root and spawn then
			root.CFrame = spawn.CFrame + Vector3.new(0, 5, 0)
		end
	end
end

function LobbyManager.SetReady(player: Player, isReady: boolean)
	readyPlayers[player] = isReady
	LobbyManager.CheckStartCondition()
end

function LobbyManager.CheckStartCondition()
	local readyCount = 0
	for _, ready in readyPlayers do
		if ready then readyCount += 1 end
	end

	local totalPlayers = #Players:GetPlayers()

	if totalPlayers >= MIN_PLAYERS and readyCount >= MIN_PLAYERS and not countdownActive and isInLobby then
		LobbyManager.StartCountdown()
	end
end

function LobbyManager.StartCountdown()
	countdownActive = true
	print("[LobbyManager] Starting 10s countdown to Windmill Village...")

	for i = COUNTDOWN_TIME, 0, -1 do
		CountdownRemote:FireAllClients(i)
		task.wait(1)
	end

	-- Transition to game
	isInLobby = false
	RoundManager.StartRound()  -- Or via GameManager

	for _, player in Players:GetPlayers() do
		LobbyManager.TeleportToGame(player)
	end

	print("[LobbyManager] Round started - Players teleported to Windmill Village")
	countdownActive = false
end

function LobbyManager.TeleportToGame(player: Player)
	if #gameSpawns > 0 then
		local spawn = gameSpawns[math.random(1, #gameSpawns)]
		local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		if root and spawn then
			root.CFrame = spawn.CFrame + Vector3.new(0, 5, 0)
		end
	end
end

function LobbyManager.Destroy()
	maid:Cleanup()
end

return LobbyManager