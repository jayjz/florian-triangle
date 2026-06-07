--!strict
-- ClientMain.client.lua (StarterPlayerScripts)
-- Single source of truth for client-side bootstrapping in Florian Triangle (Fog Sea).
-- Responsibilities: Load ClientInit, enforce single initialization, handle errors gracefully,
-- and provide clear startup logging for debugging in Studio/Play tests.
-- Prevents duplicate controller inits when combined with ClientInit guards.

local ClientInit = require(script.Parent.ClientInit)

print("[ClientMain] Bootstrapping client...")

local success, err = pcall(function()
	if typeof(ClientInit.Initialize) == "function" then
		ClientInit.Initialize()
	else
		warn("[ClientMain] ClientInit.Initialize() not found")
	end
end)

if success then
	print("[ClientMain] Client successfully bootstrapped.")
else
	warn(`[ClientMain] Bootstrap failed: {err}`)
end