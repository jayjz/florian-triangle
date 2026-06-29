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

