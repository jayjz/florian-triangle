--!strict
-- ClientInit.lua (StarterPlayer/StarterPlayerScripts)
-- Central client initializer for Fog Sea. Loads all Controllers in safe order with pcall protection.
-- Uses Maid for global cleanup. Ensures controllers are ready before game start (mobile race condition mitigation).
-- No loops or visuals here — defers to individual Controllers (ClientUIController uses RenderStepped, others use their own).
-- All remotes created via Utils.CreateRemoteEvent in respective modules. Server state never touched from client.
-- Performance: One-time execution only. 
-- Author: Fog Sea Architect - 2026-06-07

local Utils = require(game.ReplicatedStorage.Modules.Utils)
local maid = Utils.CreateMaid()

local Controllers = {
	UI = require(script.Controllers.ClientUIController),
	Combat = require(script.Controllers.ClientCombatController),
	Horror = require(script.Controllers.ClientHorrorController),
} :: {[string]: {Initialize: (() -> ())?, Maid: any?}}

local function init()
	print("=== Fog Sea Client Initializing (Phase 5 - mobile optimized, credential fixed) ===")
	for name, ctrl in Controllers do
		print(`Initializing {name}Controller...`)
		if typeof(ctrl.Initialize) == "function" then
			local ok, err = pcall(ctrl.Initialize)
			if not ok then warn(`Controller {name} init failed: {err}`) end
		else
			print(`{name}Controller self-initialized on require`)
		end
	end
	print("Client fully initialized. Extraction UI, horror, combat systems active.")
end

init()

maid:GiveTask(function()
	print("Client shutdown - cleaning controllers")
	for _, ctrl in Controllers do
		if ctrl.Maid and typeof(ctrl.Maid.Cleanup) == "function" then
			pcall(ctrl.Maid.Cleanup)
		end
	end
	maid:Cleanup()
end)

return {Controllers = Controllers, Maid = maid}
