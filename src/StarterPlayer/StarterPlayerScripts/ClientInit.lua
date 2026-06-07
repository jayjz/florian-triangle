--!strict
-- ClientInit.lua (StarterPlayerScripts)

local Utils = require(game.ReplicatedStorage.Modules.Utils)
local maid = Utils.CreateMaid()

local ClientInit = {
    Controllers = {
        UI     = require(script.Parent.Controllers.ClientUIController),
        Ship   = require(script.Parent.Controllers.ClientShipController),
        Combat = require(script.Parent.Controllers.ClientCombatController),
        Horror = require(script.Parent.Controllers.ClientHorrorController),
    }
}

function ClientInit.Initialize()
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

ClientInit.Initialize()

return ClientInit