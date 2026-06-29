--!strict
-- SmokeTest.lua
-- Automated smoke test for florian-triangle
--
-- PURPOSE: Catch critical bugs before they reach Studio / production
--   - Missing module exports (e.g., HorrorEvents.ApplySanityDrain)
--   - Initialize() crashes
--   - Nil dereferences at module load time
--   - RemoteEvent name mismatches
--   - Circular require dependencies
--
-- USAGE (Roblox Studio):
--   1. Place this file in ServerScriptService/Tests/SmokeTest.lua
--      (or require directly from Command Bar)
--   2. Command Bar: require(game.ServerScriptService.Tests.SmokeTest).Run()
--   3. Check Output window — all tests should PASS
--
-- CI USAGE:
--   This file is linted by Selene in CI (.github/workflows/ci.yml).
--   Full runtime execution requires Roblox Studio / Lune with Roblox
--   API stubs — CI currently runs static analysis only.
--   See: https://github.com/Roblox/luau / https://github.com/filiptibell/lune
--
-- EXPECTED FAILURES (pre-existing bugs, tracked):
--   - [FAIL] HorrorEvents.ApplySanityDrain — function does not exist
--     → EntityAI calls this every frame, causes runtime crash
--     → Fix tracked in PLAN.md / BUG_AUDIT_2026-06-29.md Bug #1
--
-- To run as standalone ModuleScript in Studio:
--   local SmokeTest = require(path.to.SmokeTest)
--   local results = SmokeTest.Run()
--   print("Passed:", results.passed, "Failed:", results.failed)

local SmokeTest = {}

type TestResult = {
	passed: number,
	failed: number,
	failures: {string},
}

-- Protected require — returns nil + error instead of crashing
local function safeRequire(module: ModuleScript): (any?, string?)
	local ok, result = pcall(require, module)
	if ok then return result, nil end
	return nil, tostring(result)
end

-- Check that a module exports expected functions
local function checkExports(moduleName: string, module: any, expected: {string}, results: TestResult)
	for _, fn in expected do
		if typeof(module[fn]) ~= "function" then
			results.failed += 1
			table.insert(results.failures, string.format(
				"[FAIL] %s.%s — expected function, got %s",
				moduleName, fn, typeof(module[fn])
			))
		else
			results.passed += 1
		end
	end
end

function SmokeTest.Run(): TestResult
	local results: TestResult = {passed = 0, failed = 0, failures = {}}
	
	print("========== FLORIAN TRIANGLE SMOKE TEST ==========")
	print("Branch: agent/autonomous-florian-triangle")
	print("")

	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local ServerScriptService = game:GetService("ServerScriptService")
	local ServerStorage = game:GetService("ServerStorage")

	-- ============================================================
	-- Phase 1: Module Load Test
	-- Require every ModuleScript, verify no load-time errors
	-- ============================================================
	print("Phase 1: Module Load Test")
	local modules: {[string]: any} = {}
	
	local modulePaths = {
		-- ReplicatedStorage Modules
		{"FogSystem", ReplicatedStorage:FindFirstChild("Modules") and ReplicatedStorage.Modules:FindFirstChild("FogSystem")},
		{"ShipController", ReplicatedStorage:FindFirstChild("Modules") and ReplicatedStorage.Modules:FindFirstChild("ShipController")},
		{"GhostShipGenerator", ReplicatedStorage:FindFirstChild("Modules") and ReplicatedStorage.Modules:FindFirstChild("GhostShipGenerator")},
		{"EntityAI", ReplicatedStorage:FindFirstChild("Modules") and ReplicatedStorage.Modules:FindFirstChild("EntityAI")},
		{"ExtractionManager", ReplicatedStorage:FindFirstChild("Modules") and ReplicatedStorage.Modules:FindFirstChild("ExtractionManager")},
		{"HorrorEvents", ReplicatedStorage:FindFirstChild("Modules") and ReplicatedStorage.Modules:FindFirstChild("HorrorEvents")},
		{"AudioManager", ReplicatedStorage:FindFirstChild("Modules") and ReplicatedStorage.Modules:FindFirstChild("AudioManager")},
		{"Utils", ReplicatedStorage:FindFirstChild("Modules") and ReplicatedStorage.Modules:FindFirstChild("Utils")},
		
		-- ServerScriptService
		{"GameManager", ServerScriptService:FindFirstChild("GameManager")},
		{"RoundManager", ServerScriptService:FindFirstChild("RoundManager")},
		{"LobbyManager", ServerScriptService:FindFirstChild("LobbyManager")},
		{"ExtractionZone", ServerScriptService:FindFirstChild("ExtractionZone")},
		{"TestHarness", ServerScriptService:FindFirstChild("TestHarness")},
	}

	for _, entry in modulePaths do
		local name, mod = entry[1], entry[2]
		if not mod or not mod:IsA("ModuleScript") then
			results.failed += 1
			table.insert(results.failures, string.format("[FAIL] Module not found: %s", name))
			continue
		end
		local loaded, err = safeRequire(mod :: ModuleScript)
		if loaded then
			modules[name] = loaded
			results.passed += 1
			print(string.format("  ✓ %s loaded", name))
		else
			results.failed += 1
			table.insert(results.failures, string.format("[FAIL] %s require() failed: %s", name, err or "unknown"))
			print(string.format("  ✗ %s FAILED TO LOAD: %s", name, err or "unknown"))
		end
	end
	print("")

	-- ============================================================
	-- Phase 2: Export Validation
	-- Verify critical functions exist with correct types
	-- This catches bugs like missing HorrorEvents.ApplySanityDrain
	-- ============================================================
	print("Phase 2: Export Validation")

	local expectedExports: {[string]: {string}} = {
		FogSystem = {"Initialize", "Destroy", "GetSafeRadius", "IsInSafeZone", "GetSanityDrainMultiplier", "StartClosingCircle"},
		ShipController = {"Initialize", "Destroy", "UpdatePlayerWeight", "SetSailing", "BoardGhostShip", "ExitGhostShip"},
		GhostShipGenerator = {"Initialize", "Destroy", "SpawnGhostShip", "CreateTestShip"},
		EntityAI = {"Initialize", "Destroy", "Create", "UpdateAll", "SpawnTestEntity"},
		ExtractionManager = {"Initialize", "Destroy", "RegisterChest", "HandlePickup", "ExtractAtZone", "GetPlayerWeight", "CreateTestChest"},
		HorrorEvents = {"Initialize", "Destroy", "TriggerSanityDamage", "TriggerHorrorPulse", "GetHorrorLevel", "ApplySanityDrain"}, -- ApplySanityDrain WILL FAIL — known bug #1
		AudioManager = {"Initialize", "Destroy", "PlayBoardingSound"},
		Utils = {"GetService", "CreateRemoteEvent", "CreateMaid", "Clamp", "Lerp", "CreateObjectPool"},
		GameManager = {"Initialize", "Destroy"},
		RoundManager = {"Initialize", "Destroy", "StartRound", "AddExtracted", "GetProgress"},
		LobbyManager = {"Initialize", "Destroy", "SetReady", "CheckStartCondition", "TeleportToGame", "TeleportToLobby", "ReturnToLobby"},
		ExtractionZone = {"Initialize", "Destroy"},
		TestHarness = {"Initialize", "Destroy"},
	}

	for name, expectedFns in expectedExports do
		local mod = modules[name]
		if mod then
			checkExports(name, mod, expectedFns, results)
		end
	end

	-- Report export check results
	local exportFails = {}
	for _, fail in results.failures do
		if fail:find("expected function") then
			table.insert(exportFails, fail)
		end
	end
	if #exportFails > 0 then
		print("  Export validation failures:")
		for _, f in exportFails do
			print("   ", f)
		end
	else
		print("  ✓ All expected exports present")
	end
	print("")

	-- ============================================================
	-- Phase 3: Initialize() Smoke Test
	-- Call Initialize() on each manager with pcall, verify no crash
	-- ============================================================
	print("Phase 3: Initialize() Smoke Test")
	local initOrder = {
		"Utils",
		"AudioManager",
		"FogSystem",
		"HorrorEvents",
		"ShipController",
		"GhostShipGenerator",
		"EntityAI",
		"ExtractionManager",
		"ExtractionZone",
		"LobbyManager",
		"RoundManager",
		"GameManager",
	}

	for _, name in initOrder do
		local mod = modules[name]
		if mod and typeof(mod.Initialize) == "function" then
			local ok, err = pcall(function()
				mod.Initialize()
			end)
			if ok then
				results.passed += 1
				print(string.format("  ✓ %s.Initialize() OK", name))
			else
				results.failed += 1
				table.insert(results.failures, string.format("[FAIL] %s.Initialize() crashed: %s", name, tostring(err)))
				print(string.format("  ✗ %s.Initialize() CRASHED: %s", name, tostring(err)))
			end
		end
	end
	print("")

	-- ============================================================
	-- Phase 4: API Contract Tests
	-- Test specific known-bug-prone APIs
	-- ============================================================
	print("Phase 4: API Contract Tests")

	-- Test 4a: HorrorEvents.ApplySanityDrain exists and is callable
	-- KNOWN TO FAIL — Bug #1 from BUG_AUDIT_2026-06-29.md
 do
		local HorrorEvents = modules["HorrorEvents"]
		if HorrorEvents then
			if typeof(HorrorEvents.ApplySanityDrain) ~= "function" then
				-- Expected failure — document it
				results.failed += 1
				table.insert(results.failures, "[FAIL] HorrorEvents.ApplySanityDrain — function does not exist (BUG #1 — EntityAI will crash)")
				print("  ✗ HorrorEvents.ApplySanityDrain MISSING — KNOWN BUG #1")
			else
				results.passed += 1
				print("  ✓ HorrorEvents.ApplySanityDrain exists")
			end
		end
	end

	-- Test 4b: ShipController boarding API
 do
		local ShipController = modules["ShipController"]
		if ShipController then
			local hasSetSailing = typeof(ShipController.SetSailing) == "function"
			local hasBoard = typeof(ShipController.BoardGhostShip) == "function"
			local hasExit = typeof(ShipController.ExitGhostShip) == "function"
			if hasSetSailing and hasBoard and hasExit then
				results.passed += 1
				print("  ✓ ShipController boarding API complete")
			else
				results.failed += 1
				table.insert(results.failures, string.format(
					"[FAIL] ShipController boarding API incomplete — SetSailing:%s BoardGhostShip:%s ExitGhostShip:%s",
					tostring(hasSetSailing), tostring(hasBoard), tostring(hasExit)
				))
			end
		end
	end

	-- Test 4c: RemoteEvent sanity — verify critical remotes exist
 do
		local ReplicatedStorage = game:GetService("ReplicatedStorage")
		local eventsFolder = ReplicatedStorage:FindFirstChild("Events")
		local requiredRemotes = {
			"PlayerMoveInput", "SanityChanged", "HorrorPulse",
			"WeightUpdated", "ExtractionSuccess", "RoundWin", "RoundLose",
		}
		local missingRemotes = {}
		for _, remoteName in requiredRemotes do
			local found = eventsFolder and eventsFolder:FindFirstChild(remoteName)
				or ReplicatedStorage:FindFirstChild(remoteName, true)
			if not found then
				table.insert(missingRemotes, remoteName)
			end
		end
		if #missingRemotes == 0 then
			results.passed += 1
			print("  ✓ Critical RemoteEvents present")
		else
			results.failed += 1
			table.insert(results.failures, "[FAIL] Missing RemoteEvents: " .. table.concat(missingRemotes, ", "))
		end
	end

	print("")

	-- ============================================================
	-- Phase 5: Cleanup Test
	-- Call Destroy() on all managers, verify no crash
	-- Catches: Maid cleanup bugs, table mutation during iteration, etc.
	-- ============================================================
	print("Phase 5: Cleanup Test")
	local destroyOrder = {
		"GameManager",
		"RoundManager",
		"LobbyManager",
		"ExtractionZone",
		"ExtractionManager",
		"EntityAI",
		"GhostShipGenerator",
		"ShipController",
		"HorrorEvents",
		"FogSystem",
		"AudioManager",
		"TestHarness",
	}
	for _, name in destroyOrder do
		local mod = modules[name]
		if mod and typeof(mod.Destroy) == "function" then
			local ok, err = pcall(function()
				mod.Destroy()
			end)
			if ok then
				results.passed += 1
			else
				results.failed += 1
				table.insert(results.failures, string.format("[FAIL] %s.Destroy() crashed: %s", name, tostring(err)))
				print(string.format("  ✗ %s.Destroy() CRASHED: %s", name, tostring(err)))
			end
		end
	end
	print("  ✓ Cleanup phase complete")
	print("")

	-- ============================================================
	-- Results
	-- ============================================================
	print("========== SMOKE TEST RESULTS ==========")
	print(string.format("Passed: %d", results.passed))
	print(string.format("Failed: %d", results.failed))
	if results.failed > 0 then
		print("")
		print("Failures:")
		for _, fail in results.failures do
			print("  " .. fail)
		end
		print("")
		print("KNOWN FAILURES (tracked, do not block CI yet):")
		print("  - HorrorEvents.ApplySanityDrain missing — Bug #1, fix in progress")
		print("    See: BUG_AUDIT_2026-06-29.md")
	end
	print("========================================")

	return results
end

return SmokeTest
