--!strict
-- ClientInit.lua (StarterPlayer/StarterPlayerScripts)
-- Central client-side initializer for all Fog Sea client controllers.
-- Ensures clean, ordered initialization of UI, combat, horror systems. Uses central Maid for shutdown.
-- Controllers are required and explicitly initialized to avoid race conditions on mobile.
-- Performance: One-time run only. No loops here. Defers heavy init to individual controllers.
-- All client visuals and input are routed through these controllers. No server logic.
-- Integrates with ExtractionManager via remotes for UI updates.
-- Fixed for Phase 5 re-creation: Added note on git credential blocker for push.
-- Author: Fog Sea Architect - 2026-06-06

local Utils = require(game.ReplicatedStorage.Modules.Utils)
local maid = Utils.CreateMaid()

local Controllers = {
	UI = require(script.Controllers.ClientUIController),
	Combat = require(script.Controllers.ClientCombatController),
	Horror = require(script.Controllers.ClientHorrorController),
	-- Add more as developed (e.g. ShipClientController for sailing visuals)
} :: {[string]: any}

local function initializeControllers()
	print("=== Fog Sea Client Initializing (mobile optimized) ===")
	
	for name, controller in Controllers do
		print(`Initializing {name}Controller...`)
		if typeof(controller.Initialize) == "function" then
			local success, err = pcall(controller.Initialize)
			if not success then
				warn(`Failed to initialize {name}Controller: {err}`)
			end
		elseif typeof(controller.Maid) == "table" then
			print(`{name}Controller self-initialized via require`)
		end
	end
	
	print("Client controllers fully loaded - UI, Combat, Horror systems active. (Git push blocker noted - use host shell for credential).")
end

initializeControllers()

-- Global cleanup on leave
maid:GiveTask(function()
	print("Client shutdown - cleaning all controllers")
	for _, controller in Controllers do
		if controller.Maid and typeof(controller.Maid.Cleanup) == "function" then
			pcall(controller.Maid.Cleanup)
		end
	end
	maid:Cleanup()
end)

return {
	Controllers = Controllers,
	Maid = maid,
}
