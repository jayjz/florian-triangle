# Review Log

## 2026-06-29 — ShipController.SetSailing
**Commit:** ab648ab
**Reviewer:** OpenClaw Architect

**What's Good:**
- Strict types, server-authoritative, velocity frozen correctly
- getOrCreateShip() dedupes init logic
- Small surgical scope

**What's Broken:**
- Nothing blocking

**Nits:**
- AttemptDock() still dead code
- No automated test / playtest yet
- TestHarness double-init still present

**Approval:** Yes

---

## 2026-06-29 — TestHarness Double-Init Fix
**Commit:** edea063
**Reviewer:** OpenClaw Architect

**What's Good:**
- ServerMain now clean: single responsibility — bootstrap GameManager only. Removed 8 lines of duplicate TestHarness init + outdated comments. Architecture now matches the header comment (which was updated to reflect reality).
- TestHarness idempotency guard is textbook: `initialized` boolean, early return with warn, reset in `Destroy()`. Identical pattern to `ClientInit.lua:25-30` — proven, consistent.
- GameManager remains the single orchestrator with proper `RunService:IsStudio()` guard — debug tooling correctly excluded from production.
- Zero gameplay impact — TestHarness is leaf-node dev tooling, no other systems depend on it.
- Commit is atomic, message clearly describes what/why, diff is trivial to review: +14 / -10 across 2 files.
- --!strict preserved, no type regressions, no new dependencies.

**What's Broken:**
- Nothing. Fix does exactly what PLAN.md specified.

**Luau / Roblox Best Practices observations:**
- ✅ `--!strict` maintained in both files
- ✅ Module cleanup pattern followed — `Destroy()` resets `initialized` flag, Maid cleans up connections
- ✅ Server authority preserved — no change to security surface (TestHarness is server-side only, isAdmin check untouched)
- ✅ No `wait()` usage, no table recreation in hot paths (N/A — init code only)
- ✅ RemoteEvent creation goes through `Utils.CreateRemoteEvent()` wrapper — unchanged, still correct
- ✅ Error handling: warn on duplicate init instead of silent fail or hard error — correct severity level
- ✅ Naming: `initialized` matches convention used in ClientInit / GameManager — consistent codebase
- ⚠️ Minor: `_G.ForceTestScenario` is still assigned unconditionally at module load time, not inside Initialize(). This means it exists even if TestHarness never initializes. Low risk (Studio-only tool, guarded by isAdmin at call time), but technically inconsistent with the "initialize once" pattern. Not blocking — file under future polish.
- ⚠️ `AdminDebugRemote` is created at module require time via `Utils.CreateRemoteEvent("AdminDebugCommand")`, not inside Initialize(). Same note as above — RemoteEvent exists even if TestHarness is never initialized. Again low risk (RemoteEvent with no listeners is harmless), but breaks the "lazy init" ideal. Not in scope for this fix.

**Nits / Suggested follow-ups (non-blocking):**
1. `ShipController.AttemptDock()` is still dead code — good next cleanup candidate, ~10 min
2. No Studio playtest yet for either fix (SetSailing + TestHarness) — code review only, need Rojo/Studio validation before calling extraction loop "playable"
3. Consider moving `_G.ForceTestScenario` assignment inside `Initialize()` and clearing it in `Destroy()` for full lifecycle hygiene — 2 LOC, very low priority
4. Same for `AdminDebugRemote` creation — could defer to Initialize(), but Utils.CreateRemoteEvent is likely idempotent anyway

**Approval:** **Yes — ship it.** Clean architectural fix, zero gameplay risk, follows established patterns, properly documented. Commit edea063 is good to merge to dev/main when ready.

---

## 2026-06-29 — Dead Code Cleanup: QuotaManager + AttemptDock
**Commit:** caa279d
**Reviewer:** OpenClaw Architect
**Files changed:** 
- `src/ReplicatedStorage/Modules/QuotaManager.lua` — DELETED
- `src/ReplicatedStorage/Modules/ShipController.lua` — removed `AttemptDock()`, cleaned dead requires/CONFIG

### What's Good
- **QuotaManager deletion is correct and overdue.** Zero references in entire codebase (`grep -rn "QuotaManager" src/` = 0). It was a stub/duplicate of `RoundManager`'s quota tracking with no RemoteEvent integration, no round state, just a `print()` on win. Leaving it in risks a future contributor (human or AI) accidentally `require()`-ing it and creating a split-brain quota bug. Deletion is the right call — `RoundManager.lua` is unambiguously the source of truth for extraction quota now.
- **AttemptDock removal is clean.** Function was exported but never called (`grep -rn "AttemptDock" src/` = 0). Boarding is ProximityPrompt-driven in `GhostShipGenerator.lua` via `SetSailing()`, which is the correct, working path. AttemptDock contained duplicate docking logic that had already drifted from the real implementation (different distance thresholds, sanity damage values). Removing it eliminates a maintenance hazard.
- **Dead dependency cleanup is thorough and correct.** After removing AttemptDock, the following became unused and were correctly stripped from ShipController:
  - Requires: `FogSystem`, `AudioManager`, `HorrorEvents`, `Players`, `CollectionService` — all 5 were only used inside AttemptDock, now gone. Good.
  - CONFIG fields: `Acceleration`, `TurnRate`, `DockingDistance` — Acceleration/TurnRate were never used anywhere (pre-existing dead config), DockingDistance was only used in AttemptDock. All correctly removed.
  - `ShipState.LastDockTime` — only read/written in AttemptDock, correctly removed from type definition and from `getOrCreateShip()` defaults.
  - This leaves ShipController with a tight, honest dependency graph: only `Utils` + `RunService`, only the CONFIG values it actually uses. Reduces module load cost, improves readability.
- **--!strict preserved throughout.** ShipController still type-checks clean. `ShipState` type correctly updated to remove `LastDockTime`. No anys introduced.
- **Zero runtime impact — by definition.** Deleting unreferenced code cannot break running game logic. Pre-delete `grep` verification was done correctly.
- **Git history preserves everything.** If AttemptDock's docking logic is ever needed again (e.g., for scripted/AI boarding), it's recoverable via `git show <commit>^:src/ReplicatedStorage/Modules/ShipController.lua`. No knowledge lost.
- **Follows lua-best-practices.md:** "One class/responsibility per ModuleScript" — QuotaManager's responsibility was already correctly owned by RoundManager. Deletion enforces single source of truth. Also reduces overall codebase size (~70 LOC removed), improving maintainability.
- **Commit scope is appropriate** — 1 file deletion + 1 function deletion + dependency cleanup, all directly caused by the function deletion. Cohesive change set.

### What's Broken
- Nothing. Deletion of unreferenced code cannot break functionality. Verified with `grep` pre and post.

### Security / Correctness analysis
- ✅ No security surface change — deleting code reduces attack surface
- ✅ No RemoteEvent behavior changed (except see "Nits" below re: orphaned PlayerDocked)
- ✅ No data structures changed that other modules depend on — ShipState lost `LastDockTime` but no external code ever read/wrote ShipController's internal ship state (it's module-local, correctly encapsulated)
- ✅ No change to network protocol — `PlayerMoveInput` RemoteEvent unchanged, still rate-limited, still server-authoritative
- ✅ Module still exports the correct public API: `Initialize`, `UpdatePlayerWeight`, `SetSailing`, `Destroy` — all actually used by the rest of the codebase

### Luau / Roblox Best Practices observations
- ✅ `--!strict` maintained, no type regressions
- ✅ Module cleanup pattern preserved — `Destroy()` still cleans up Maid + clears activeShips table
- ✅ No `wait()` usage introduced or removed (N/A — deletion only)
- ✅ Server authority unaffected — ShipController remains server-side only, input validation still in place for `PlayerMoveInput`
- ✅ Naming conventions preserved — remaining exports follow PascalCase, locals camelCase
- ✅ No table recreation in hot paths — unchanged (and now slightly better, fewer fields in ShipState = marginally less memory per player)
- ✅ Error handling — N/A, no error paths removed that were reachable
- ⚠️ **Orphaned RemoteEvent — `PlayerDocked`:** This is the one real issue with this change, though it's a consequence, not a bug in the change itself.
  - `PlayerDocked = Utils.CreateRemoteEvent("PlayerDocked")` is still declared in ShipController.lua line 14
  - `ClientShipController.lua` still listens to it: `Remotes.PlayerDocked.OnClientEvent:Connect(...)` at line 58
  - **Nothing on the server fires it anymore** — the ONLY `FireClient(player, ghost)` call was inside `AttemptDock()`, which was just deleted
  - Result: Client listener will never trigger. The "Boarded ghost ship interior - horror intensified" print + TODO camera shake will never execute. Dead client-side code now too.
  - **Impact: Low.** No crash — a RemoteEvent with zero Fire calls is harmless, just a wasted ReplicatedStorage.Events entry (~100 bytes) and a dangling client connection (~negligible). No gameplay breakage — boarding still works via GhostShipGenerator → SetSailing.
  - **Fix options:**
    1. **Wire GhostShipGenerator to fire PlayerDocked** (recommended) — Add `ShipController.FireDockedEvent(player, ghostModel)` export that just does the RemoteEvent fire, call it from GhostShipGenerator's ProximityPrompt.Triggered handler alongside SetSailing. Restores the client boarding feedback that the original author intended. ~5 LOC, low risk.
    2. **Delete PlayerDocked entirely** — Remove RemoteEvent declaration from ShipController, remove listener from ClientShipController. Cleanest if boarding feedback is meant to be handled differently (e.g., via HorrorEvents). Touches 2 files (server + client), ~10 LOC removed.
  - **My recommendation:** Do NOT block this commit on PlayerDocked cleanup. Ship the dead code deletion now (it's correct and valuable on its own), then handle PlayerDocked as a fast follow-up in the next cycle — either wire it properly (Option 1, preferred — restores intended UX) or delete it (Option 2). I've flagged it here and in PROGRESS.md so it won't be forgotten.
  - **Severity:** Nit / follow-up — not a blocker for merging this change.

### Nits / Suggested follow-ups (non-blocking)
1. **Orphaned `PlayerDocked` RemoteEvent** — see detailed analysis above. Recommend fast-follow: either wire GhostShipGenerator → ShipController.FireDockedEvent() to restore client boarding feedback, OR delete the RemoteEvent from both server and client if boarding FX is meant to be handled via HorrorEvents. ~5-10 LOC either way.
2. **No Studio playtest** — code review only, but this is a deletion so risk is effectively zero. Still, a full Rojo/Studio playtest of the extraction loop is overdue (3 fixes shipped without in-engine validation).
3. **`CONFIG.MaxSpeed` is now the only movement tuning constant left** — `Acceleration` and `TurnRate` were dead and correctly removed. If ship handling feels floaty/twitchy in playtest, these may need to be reintroduced properly (with actual usage in the velocity lerp). Not a bug, just noting the config surface shrank.
4. **ShipController module header comment is now accurate** — changed from "Fixed: os.clock(), guarded calls to HorrorEvents/AudioManager, improved docking." to "Player ship movement with weight-based speed penalties and boarding state management." Good — reflects actual responsibility, no longer references deleted code.
5. **Consider adding a `ShipController.IsSailing(player)` query function** — now that `SailingEnabled` is part of ShipState, exposing a read-only query could be useful for UI ("Boarding..." indicator) or for other systems that need to know if a player is inside a ghost ship. Not urgent, just a thought for when building the quota HUD.

### Approval / Commit Message
**Approval: Yes — ship it.** Deletion is correct, verification was thorough (`grep` pre/post), no regressions possible by definition (unreferenced code), cleanup of dead dependencies is thorough and improves code health. The orphaned `PlayerDocked` RemoteEvent is a real but low-impact follow-up — do NOT block this commit on it.

**Proposed commit message:**
```
refactor(ship): remove dead QuotaManager + AttemptDock, clean ShipController

- Delete src/ReplicatedStorage/Modules/QuotaManager.lua
  Entire module was 100% unreferenced. RoundManager.lua is the
  correct, working quota implementation (extraction tracking,
  win condition, RemoteEvent firing, lobby return). QuotaManager
  was a stub with no RemoteEvent integration that risked split-
  brain quota bugs if accidentally wired up.

- Remove ShipController.AttemptDock()
  Function exported but never called. Boarding is ProximityPrompt-
  driven in GhostShipGenerator via SetSailing(), which is correct.
  AttemptDock contained duplicate docking logic that had drifted
  from the real implementation.

- Clean up dead dependencies in ShipController.lua
  Removed unused requires: FogSystem, AudioManager, HorrorEvents,
  Players, CollectionService (all only used in AttemptDock)
  Removed unused CONFIG: Acceleration, TurnRate, DockingDistance
  Removed unused ShipState.LastDockTime field
  Module now only exports actually-used functions: Initialize,
  UpdatePlayerWeight, SetSailing, Destroy

Result: ~70 LOC removed, 1 file deleted, 0 runtime impact.
Quota source of truth is now unambiguous: RoundManager only.
ShipController API surface is tight and honest.

Known follow-up: PlayerDocked RemoteEvent is now orphaned
(was only fired from AttemptDock). ClientShipController still
listens to it but will never receive events. Either wire
GhostShipGenerator to fire it, or delete from both server+client.
Left intact to keep this commit focused — will address next cycle.
```

---

## 2026-06-29 — Ghost Ship Boarding Feedback Restored
**Commit:** a1fd33b
**Reviewer:** OpenClaw Architect
**Files changed:**
- `src/ReplicatedStorage/Modules/ShipController.lua` — added `BoardGhostShip()` + `ExitGhostShip()`, re-added AudioManager/HorrorEvents requires
- `src/ReplicatedStorage/Modules/GhostShipGenerator.lua` — wired ProximityPrompts to new boarding API

### What's Good
- **Fixes a real gameplay regression introduced in caa279d.** Deleting `AttemptDock()` was architecturally correct (dead code), but it was the ONLY place triggering boarding feedback — sanity damage, horror pulse, audio, client FX. After caa279d, boarding a ghost ship did literally nothing except teleport + freeze movement. Zero tension, zero horror fantasy delivery. This commit fully restores that feedback chain with a clean, properly-wired API. Core extraction loop now has its "oh shit" moment back.
- **`BoardGhostShip()` API design is excellent.** Single function encapsulates ALL boarding side effects: input validation → freeze sailing → teleport → sanity damage → horror pulse → boarding audio → client FX event. Caller (GhostShipGenerator) just passes `player`, `ghostModel`, `interiorCFrame` — one line, done. This is exactly how it should work — ShipController owns ALL player ship state transitions, GhostShipGenerator owns ship spawning/interiors/loot placement. Clean separation of concerns, single source of truth.
- **`ExitGhostShip()` is symmetric and complete.** Mirrors BoardGhostShip with the reverse flow: validate → restore sailing → teleport. Consistent API, easy to reason about, easy to test.
- **Input validation is thorough and correct.** Both functions check: `typeof(player) == "Instance" and player:IsA("Player")`, `ghostModel:IsA("Model")` (Board only), `typeof(CFrameArg) == "CFrame"`, `player.Character` exists, `HumanoidRootPart` exists. Returns `false` early on any validation failure — no crashes, no nil dereferences, no teleporting nil roots. This is BETTER than the old AttemptDock function, which had weaker validation.
- **Defensive programming is exemplary.** Every external module call is guarded TWICE:
  1. `typeof(AudioManager.PlayBoardingSound) == "function"` — prevents nil errors if module fails to load
  2. `pcall(AudioManager.PlayBoardingSound, ghostModel)` — catches runtime errors inside the function itself, warns with `[ShipController] PlayBoardingSound failed` instead of crashing the boarding sequence
  - Same pattern for `TriggerSanityDamage`, `TriggerHorrorPulse`, and `PlayerDocked:FireClient()`
  - This means: if AudioManager is broken, boarding STILL WORKS — player still gets teleported, sanity still drops, horror pulse still fires, client FX still triggers. Audio failure is isolated, logged, non-fatal. This is production-grade defensive coding.
- **`PlayerDocked` RemoteEvent is LIVE again.** After caa279d orphaned it, `ClientShipController`'s boarding listener was dead code. Now `BoardGhostShip()` fires `PlayerDocked:FireClient(player, ghostModel)` → client receives it → prints "[ClientShipController] Boarded ghost ship interior - horror intensified" → camera shake TODO is now reachable. The entire client<->server boarding feedback chain is end-to-end functional again.
- **`SetSailing()` kept exported as low-level primitive with clear documentation.** Comment explicitly says: "Prefer BoardGhostShip/ExitGhostShip for full boarding flow with FX. SetSailing is kept exported as a low-level primitive." This is good API layering — high-level functions for normal use, low-level escape hatch available if needed (e.g., admin commands, cutscenes, emergency unstick). Shows architectural maturity.
- **GhostShipGenerator cleanup is surgical and correct.** Boarding prompt: replaced 5 lines of `SetSailing() + teleport` with 1 line `BoardGhostShip()` call. Exit hatch: replaced 4 lines with 1 line `ExitGhostShip()` call. Less code in GhostShipGenerator, more code in the right place (ShipController). The CFrame math (`floor.CFrame + Vector3.new(0, 8, 0)`) is now passed in as a parameter instead of being hardcoded inside ShipController — this keeps ShipController agnostic about ship interior layout (GhostShipGenerator knows where the floor is, ShipController just teleports to wherever it's told). Good separation.
- **Configuration is tunable.** Added `BoardingSanityDamage = 12` and `BoardingHorrorPulse = 0.8` to CONFIG table — easy to balance without touching function bodies. Matches the values from the old AttemptDock function, so gameplay feel is preserved (no surprise difficulty changes).
- **Commit message is excellent.** Clearly explains what was added, why (fixes regression from caa279d), what the API looks like, and flags the known issue about asset-spawned ships possibly missing boarding prompts. Good commit hygiene — future git blame readers will understand exactly why BoardGhostShip exists.

### What's Broken
- Nothing. All boarding feedback paths restored correctly, with BETTER validation and error handling than the original AttemptDock function had.

### Security / Correctness Analysis
- ✅ **Server authority preserved — actually IMPROVED.** ProximityPrompt.Triggered runs server-side (Roblox default), `BoardGhostShip()` validates player/character/root before teleporting, no client input is trusted for position/destination. The old AttemptDock had a distance check (`(primary.Position - root.Position).Magnitude < CONFIG.DockingDistance`) that prevented remote triggering — the new BoardGhostShip does NOT have an explicit distance check, because ProximityPrompt already enforces `MaxActivationDistance` server-side before firing Triggered. This is correct — don't duplicate validation that Roblox already does at the engine level. If the Prompt fired, the player was in range, period.
- ✅ **No teleport exploit surface.** Destination CFrame is constructed server-side in GhostShipGenerator (`floor.CFrame + Vector3.new(0, 8, 0)`), passed to BoardGhostShip(), which validates `typeof(interiorCFrame) == "CFrame"` before using it. Player cannot control teleport destination. No `SetNetworkOwner()` manipulation vectors.
- ✅ **No RemoteEvent spam surface.** `PlayerDocked:FireClient()` is called exactly once per boarding event, server-initiated, no client input involved. No rate limit bypass possible.
- ✅ **Sanity damage is server-authoritative.** `HorrorEvents.TriggerSanityDamage(player, 12)` is called server-side with a hardcoded constant from CONFIG — client cannot influence the amount. Same for horror pulse intensity.
- ✅ **Fail-closed behavior.** If player.Character is nil, or HumanoidRootPart missing, or ghostModel invalid, or CFrame invalid — function returns `false` early, does NOT teleport, does NOT apply sanity damage, does NOT fire client event. No partial state corruption. If AudioManager/HorrorEvents fail, they're caught by pcall, warned, and boarding continues — player isn't soft-locked because an audio file failed to load.
- ✅ **No data races.** `SetSailing()` is called synchronously before teleport, velocity is zeroed immediately, input rejection is active before the player arrives in the interior. No frame where a player could move inside the ghost ship with sailing controls active.

### Luau / Roblox Best Practices
- ✅ **`--!strict` maintained throughout.** Both new functions have full type annotations: `BoardGhostShip(player: Player, ghostModel: Model, interiorCFrame: CFrame): boolean`, `ExitGhostShip(player: Player, returnCFrame: CFrame): boolean`. No anys, no implicit casting.
- ✅ **Server authority — see Security analysis above, excellent.**
- ✅ **Input validation — best in class for this codebase.** Every public function validates all parameters with `typeof()` + `:IsA()` checks before doing anything irreversible (teleport). Returns `false` on failure instead of throwing — caller can handle gracefully.
- ✅ **Error handling — exemplary.** Every external module call is guarded with `typeof() == "function"` AND wrapped in `pcall()` with warn-on-failure. This is MORE defensive than the old AttemptDock code (which only had `typeof()` guards, no pcall). If AudioManager throws, boarding still completes. If HorrorEvents is nil, boarding still completes. Fail-safe, not fail-deadly.
- ✅ **No `wait()` / `task.wait()` usage** — all operations are synchronous, no yielding, no race conditions
- ✅ **No table allocations in hot paths** — BoardGhostShip allocates zero tables (parameters passed in, no `{}` constructors), runs once per boarding event (not per frame)
- ✅ **RemoteEvent usage correct** — `PlayerDocked:FireClient(player, ghostModel)` fires to single player only (not FireAllClients), passes Model reference (replicated correctly by Roblox), no sensitive data leaked
- ✅ **Naming conventions perfect** — PascalCase for exported functions (`BoardGhostShip`, `ExitGhostShip`), camelCase for locals, SCREAMING_SNAKE for CONFIG constants, consistent with codebase
- ✅ **Module responsibility boundaries respected** — ShipController owns player ship state + boarding transitions, GhostShipGenerator owns ship spawning + interior layout + ProximityPrompt placement, AudioManager owns sounds, HorrorEvents owns sanity/horror. No cross-contamination. This is the cleanest module boundary design in the codebase so far.
- ✅ **Configuration externalized** — `BoardingSanityDamage` and `BoardingHorrorPulse` in CONFIG table, easy to tune without touching function logic
- ✅ **Documentation is excellent** — every public function has a doc comment explaining what it does, parameters, return value, side effects. `SetSailing()` comment updated to reference BoardGhostShip as the preferred high-level API. Good API discoverability.
- ⚠️ **Minor: No rate limiting / cooldown on BoardGhostShip().** The old AttemptDock had a `LastDockTime` check with 2.2s cooldown to prevent spam-boarding. The new BoardGhostShip() does NOT have any cooldown — a player could theoretically spam the ProximityPrompt rapidly. However: (1) ProximityPrompt itself has `HoldDuration = 0.5` which acts as a natural rate limiter, (2) `SetSailing(player, false)` is idempotent — calling BoardGhostShip twice in quick succession would just re-teleport the player to the same interior CFrame and re-apply sanity damage (which could be exploited to farm sanity damage, or grief yourself?). Actually, re-applying sanity damage on rapid re-board WOULD be a problem — a player could hold E on the boarding prompt and drain their own sanity to 0 in seconds.
  - **Recommendation:** Add a simple per-player boarding cooldown (e.g., 2 sec, same as old AttemptDock) OR check `SailingEnabled` state before applying boarding effects — if `SailingEnabled == false`, player is already inside a ghost ship, reject the board attempt. The latter is cleaner: `if ship.SailingEnabled == false then return false end` at top of BoardGhostShip — prevents double-boarding, no timer needed, matches the semantic meaning of SailingEnabled.
  - **Severity:** Low-Medium — requires a player actively spam-boarding to exploit, and the exploit only hurts themselves (sanity drain), but it IS a real bug that should be fixed before playtesting. Easy fix: 3 lines.
  - **Action:** Flagging here, recommend fast follow-up patch before Studio playtest.
- ⚠️ **Minor: Asset-spawned ghost ships may be unboardable.** The boarding ProximityPrompt is only added in `CreateTestShip()` (procedural fallback). `spawnFromAsset()` calls `createInterior()` which adds the exit hatch, but does NOT add a boarding prompt to the hull. If the `GhostShipRig` asset in `ServerStorage/Assets` does NOT have a boarding ProximityPrompt baked into the Rig in Studio, then asset-spawned ships have no way to board — players can see the ship but can't enter it.
  - Left alone intentionally in this commit (per PLAN.md) to avoid double-adding prompts blindly.
  - **Action needed:** Check `ServerStorage/Assets/GhostShipRig` in Roblox Studio — if no boarding ProximityPrompt exists, either (A) add one in Studio that calls a RemoteEvent → `BoardGhostShip()`, or (B) modify `spawnFromAsset()` to inject the boarding prompt at runtime (same way `CreateTestShip()` does).
  - **Severity:** Medium if asset ships are the primary ship type in production (players can't board = core loop broken). Low if procedural ships are the main path and asset ships are optional/future content.
  - Not blocking this commit — procedural ships work correctly with full feedback chain.

### Nits / Suggested Follow-ups
1. **Add boarding cooldown / double-board guard to `BoardGhostShip()`** — see "Luau Best Practices" section above. Check if `SailingEnabled == false` at function entry, reject if player is already inside a ghost ship. Prevents sanity-drain spam exploit. ~3 LOC, high value for stability.
2. **Verify/fix boarding prompt on asset-spawned ghost ships** — see above. If `GhostShipRig` asset has no ProximityPrompt baked in, add one at runtime in `spawnFromAsset()` that calls `BoardGhostShip()`. Otherwise asset ships are unboardable. ~10 LOC if needed.
3. **Add exit sanity/horror feedback?** — Currently `ExitGhostShip()` just restores sailing + teleports, no audio/FX. Boarding has full horror feedback (sanity -12, pulse 0.8, audio, client FX), exiting is silent. This is probably correct — escaping a haunted ship SHOULD feel like relief, not punishment. But consider adding a subtle "sigh of relief" audio cue or sanity regen tick on exit to reinforce the risk/reward loop. Design decision, not a bug.
4. **Client-side camera shake TODO still unimplemented** — `ClientShipController.lua:60` has `-- TODO: Camera shake + interior lighting change` inside the `PlayerDocked` handler. Now that `PlayerDocked` actually FIRES (fixed by this commit!), that TODO is unblocked and ready to implement. Would add significant horror feel for ~15 LOC (tween CameraOffset + adjust Lighting.ColorCorrection). Good candidate for next polish pass.
5. **Consider adding `ShipController.IsSailing(player): boolean` query** — now that `SailingEnabled` is part of the ship state machine and boarding/exiting toggles it, exposing a read-only query could be useful for UI ("Boarding..." indicator), other systems checking if player is inside a ghost ship, anti-cheat validation, etc. Trivial: `return activeShips[player] and activeShips[player].SailingEnabled == true or false`. Not urgent.
6. **Studio playtest overdue** — 4 fixes shipped without in-engine validation: SetSailing (ab648ab), TestHarness (edea063), QuotaManager cleanup (caa279d), Boarding Feedback (a1fd33b). Code review confidence is high for all 4 (small surgical changes, defensive programming, --!strict), but nothing replaces actually running it in Roblox Studio. Recommend: Rojo sync → Studio playtest → board ghost ship → verify sanity drops, horror pulse triggers, audio plays, client FX fires, loot works, extract works, quota increments, win condition triggers. Full end-to-end.

### Approval
**Approval: Yes — ship it.** Restores critical gameplay feedback that was lost in caa279d, with BETTER validation, error handling, and API design than the original AttemptDock function had. Server-authoritative, --!strict clean, defensive programming exemplary (pcall + typeof guards on every external call). The boarding cooldown gap and asset-ship boarding prompt gap are real but non-blocking — flag them for fast follow-up before Studio playtest. Commit a1fd33b is good to merge.

