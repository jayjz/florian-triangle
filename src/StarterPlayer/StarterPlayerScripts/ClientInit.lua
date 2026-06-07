--!strict
-- ClientInit.lua - Updated with guard
local Utils = require(game.ReplicatedStorage.Modules.Utils)
local maid = Utils.CreateMaid()

local ClientInit = {
    Controllers = {
        UI = require(script.Parent.Controllers.ClientUIController),
        Ship = require(script.Parent.Controllers.ClientShipController),
        Combat = require(script.Parent.Controllers.ClientCombatController),
        Horror = require(script.Parent.Controllers.ClientHorrorController),
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
                warn(`[ClientInit] {name} failed: {err}`)
            end
        end
    end
end

-- Ensure single call from ClientMain if needed
ClientInit.Initialize()

return ClientInit