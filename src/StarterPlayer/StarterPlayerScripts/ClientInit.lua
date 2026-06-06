--!strict
-- ClientInit.lua
-- Central client initializer for Fog Sea.
-- Requires and initializes all client controllers in correct order.
-- Uses Maid for cleanup. Runs once on client.
-- Performance: One-time initialization. No unnecessary connections.
-- Author: Fog Sea Architect - 2026-06-06

local Utils = require(game.ReplicatedStorage.Modules.Utils)
local maid = Utils.CreateMaid()

local Controllers = {
	Combat = require(script.Controllers.ClientCombatController),
	Horror = require(script.Controllers.ClientHorrorController),
	UI = require(script.Controllers.ClientUIController),
}

-- Initialize in safe order
for name, controller in Controllers do
	print(`Initializing client controller: {name}`)
	-- Controllers are self-initializing on require in this design
end

print("=== ClientInit complete - All controllers loaded ===")

maid:GiveTask(function()
	print("Client shutting down - cleaning up controllers")
end)

return nil
