--!strict
-- ServerMain.server.lua (ServerScriptService)
-- Single source of truth for server-side bootstrapping.
-- Responsibilities: Initialize GameManager (core orchestrator + LobbyManager), TestHarness (debug tools),
-- propagate any critical errors, and ensure clean logging.
-- Ties directly into GameManager.Destroy() for proper round shutdowns.

local GameManager = require(script.Parent.GameManager)
local TestHarness = require(script.Parent.TestHarness)

print("[ServerMain] Bootstrapping server...")

local success, err = pcall(function()
	-- Core systems (GameManager now handles LobbyManager + RoundManager internally)
	GameManager.Initialize()

	-- Testing tools (Studio/dev only)
	if typeof(TestHarness.Initialize) == "function" then
		TestHarness.Initialize()
	end
end)

if success then
	print("[ServerMain] Server successfully bootstrapped (GameManager + Lobby ready)")
else
	warn(`[ServerMain] Bootstrap failed: {err}`)
	-- Optional: Graceful fallback or kick players in production
end

-- Optional: Listen for game shutdown / teleport to handle cleanup
game:BindToClose(function()
	print("[ServerMain] Game closing — cleaning up GameManager")
	if typeof(GameManager.Destroy) == "function" then
		GameManager.Destroy()
	end
end)