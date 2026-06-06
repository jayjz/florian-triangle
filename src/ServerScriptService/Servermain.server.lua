--!strict
print(">>> Server Bootstrapper Started <<<")
local GameManager = require(script.Parent.GameManager)
-- GameManager auto-initializes at the bottom of its file, so we don't need to call Initialize() here.
print(">>> Server Bootstrapper Finished <<<")