--!strict
-- ClientMain.client.lua
-- Rojo entry point for the client (Compiles to a LocalScript in Studio)
-- This file exists solely to bootstrap the modular client framework.

print(">>> Client Bootstrapper Started <<<")

-- We use WaitForChild to ensure the ModuleScript has fully replicated to the client before requiring it.
local ClientInit = require(script.Parent:WaitForChild("ClientInit"))

print(">>> Client Bootstrapper Finished. Client framework is active. <<<")