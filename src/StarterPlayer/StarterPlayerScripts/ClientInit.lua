--!strict
-- ClientInit.lua (StarterPlayer/StarterPlayerScripts)
-- Single source of truth for client bootstrapping. Fixed double-init ordering.

local Utils = require(game.ReplicatedStorage.Modules.Utils)

local ClientInit = {
	Controllers = {
		UI = require(script.Parent.Controllers.ClientUIController),
		Ship = require(script.Parent.Controllers.ClientShipController),
		Combat = require(script.Parent.Controllers.ClientCombatController),
		Horror = require(script.Parent.Controllers.ClientHorrorController),
		Mist = require(script.Parent.Controllers.ClientMistController),
	}
}

local initialized = false

function ClientInit.Initialize()
	if initialized then
		warn("[ClientInit] Already initialized — skipping duplicate")
		return
	end
	initialized = true

	print("=== Fog Sea Client Initializing ===")

	for name, ctrl in ClientInit.Controllers do
		if typeof(ctrl.Initialize) == "function" then
			local ok, err = pcall(ctrl.Initialize)
			if not ok then
				warn(`[ClientInit] {name} controller failed: {err}`)
			else
				print(`[ClientInit] {name} controller initialized`)
			end
		end
	end
end

-- Single execution point (removed self-call at bottom)
return ClientInit