--!strict
local GameManager = require(script.Parent.GameManager)
local TestHarness = require(script.Parent.TestHarness)

GameManager.Initialize()
-- TestHarness self-initializes on require
print("ServerMain: Server bootstrapped successfully.")
