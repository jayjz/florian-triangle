--!strict
-- ServerMain.server.lua (ServerScriptService)
-- Primary server bootstrapper for Florian Triangle.
-- Ensures correct initialization order and prevents double-initialization.

local GameManager = require(script.Parent.GameManager)
local TestHarness = require(script.Parent.TestHarness)

-- Initialize core game systems first
GameManager.Initialize()

-- TestHarness self-initializes on require, but we explicitly call Initialize
-- for clarity and to ensure it runs after GameManager.
if type(TestHarness.Initialize) == "function" then
    TestHarness.Initialize()
end

print("[ServerMain] Server bootstrapped successfully.")
print("[ServerMain] GameManager + TestHarness ready for testing.")