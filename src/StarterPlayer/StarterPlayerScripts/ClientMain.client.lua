--!strict
-- ClientMain.client.lua (StarterPlayerScripts)
-- Primary client bootstrapper for Fog Sea.
-- Only responsible for calling ClientInit once.

local ClientInit = require(script.Parent.ClientInit)

print("[ClientMain] Client bootstrapped successfully.")

-- Call Initialize only once from the bootstrapper
if typeof(ClientInit.Initialize) == "function" then
    ClientInit.Initialize()
end