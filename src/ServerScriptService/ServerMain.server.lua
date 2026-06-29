--!strict
-- ServerMain.server.lua (ServerScriptService)
-- Single source of truth for server-side bootstrapping.
-- Responsibilities: Initialize GameManager (core orchestrator).
-- GameManager handles all subsystem initialization internally (LobbyManager, RoundManager,
-- FogSystem, ShipController, GhostShipGenerator, EntityAI, HorrorEvents, ExtractionManager,
-- ExtractionZone, TestHarness).
-- Ties directly into GameManager.Destroy() for proper round shutdowns.

local GameManager = require(script.Parent.GameManager)

print("[ServerMain] Bootstrapping server...")

local success, err = pcall(function()
	-- Core orchestrator - initializes all subsystems internally
	GameManager.Initialize()
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
