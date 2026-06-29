# Progress

## 2026-06-29 — Repo Audit (Architect pass)

**Branch:** `agent/autonomous-florian-triangle` @ origin/dev base
**Audit scope:** Full `src/` tree, PROJECT-ROADMAP.md, MEMORY.md, CONTEXT.md, lua-best-practices.md

### What's Good
- FogSystem P0 fix is in (nil guards, horrorLevel from GameManager, 30Hz throttle)
- Client tag consumers ARE wired — `ClientShipController` is required in `ClientInit.lua`, contrary to PROJECT-ROADMAP note from June 8
- Rojo structure is correct (`default.project.json` with DataModel root)
- ExtractionManager → ShipController.UpdatePlayerWeight integration works
- Server authority patterns followed, Maid cleanup everywhere, --!strict throughout
- GameManager pcall-wraps all system Initialize() calls

### What's Broken
- **P0: `ShipController.SetSailing()` missing.** `GhostShipGenerator.lua:111` and `:171` call it on board/exit. Will error at runtime, blocking core loop. This is the immediate blocker.
- `ShipController.AttemptDock()` exists but is never called (boarding is ProximityPrompt-driven in GhostShipGenerator, bypassing it)
- `TestHarness.Initialize()` is called in BOTH `ServerMain.server.lua` AND `GameManager.Initialize()` — double-init guard exists but still sloppy
- No real asset rigs in `ServerStorage/Assets` — procedural fallback only
- No automated tests, no CI

### Next Step
Fix `ShipController.SetSailing(player, enabled)` — smallest safe change that unblocks boarding/playtesting. See IMPLEMENTATION_PLAN.md.

### Self-Review
Audit honest, no scope creep. One P0 bug identified with exact file/line numbers. Proposed fix is surgical (one function, ~15 LOC).

---

## 2026-06-29 — ShipController.SetSailing Fix (Implemented)

**Commit:** `ab648ab` — `fix(ship): add missing SetSailing API for ghost ship boarding`

**What was done:**
- Added `ShipController.SetSailing(player: Player, enabled: boolean)` — unblocks GhostShipGenerator board/exit at L111/L171
- Added `SailingEnabled: boolean` to `ShipState` type with proper --!strict typing
- Movement input now rejected when `SailingEnabled == false`
- Heartbeat velocity application zeros out when not sailing (prevents drift)
- Refactored ship state creation into `getOrCreateShip(player)` helper — eliminates duplication, ensures consistent defaults
- Velocity is zeroed immediately on `SetSailing(player, false)` to freeze the player

**What worked:**
- Clean --!strict types throughout, no anys
- Small surgical diff: 1 file, +41 / -7, all in ShipController.lua
- Maintains server authority, no client trust issues
- Consistent with existing Maid / Utils patterns

**What didn't / known gaps:**
- `ShipController.AttemptDock()` still exists but is unused (boarding is ProximityPrompt-driven in GhostShipGenerator) — left intact for future wiring, not in scope for this fix
- No automated test coverage — validated by code review only, needs Rojo/Studio playtest
- `TestHarness.Initialize()` double-call (ServerMain + GameManager) still present — out of scope, guard prevents crash
- No real asset rigs yet

**Next step:**
Rojo/Studio playtest full extraction loop (board ghost ship → loot → exit → extract), or tackle next smallest bug from audit list (TestHarness double-init cleanup).

**Reviewer notes:** See REVIEW.md

---

## 2026-06-29 — TestHarness Double-Init Fix (Implemented)

**Commit:** `edea063` — `fix(test): eliminate TestHarness double-init, add idempotency guard`

**What was done:**
- `ServerMain.server.lua`: Removed TestHarness require + Initialize() call entirely. ServerMain now bootstraps ONLY GameManager — single orchestrator pattern, matches architecture comment.
- `TestHarness.lua`: Added `initialized` boolean guard at top of `Initialize()`, early return with warn on duplicate call. Matches `ClientInit.lua` pattern. `Destroy()` now resets `initialized = false` for clean shutdown.
- GameManager keeps its `RunService:IsStudio()` guarded TestHarness init — this is now the single correct call site.

**What worked:**
- Clean separation of concerns: ServerMain = entry point → GameManager → all subsystems
- Defense-in-depth: even if someone calls Initialize() twice in future, guard prevents double event connections
- Small diff: 2 files, +14 / -10, debug tooling only, zero gameplay impact
- Comments updated in ServerMain to reflect actual architecture
- --!strict preserved, no type regressions

**What didn't / known gaps:**
- Still no automated test coverage / Studio playtest — code review only
- `ShipController.AttemptDock()` still dead code — next candidate for cleanup
- No real asset rigs in ServerStorage/Assets yet
- Full co-op extraction playtest still pending (requires Roblox Studio / Windows)

**Next step:**
Clean up dead `ShipController.AttemptDock()` or wire it to ProximityPrompt system, OR Rojo/Studio playtest full extraction loop. See PLAN.md.

**Reviewer notes:** See REVIEW.md

---

## 2026-06-29 — Dead Code Cleanup: QuotaManager + AttemptDock (Implemented)

**Commit:** caa279d

**What was done:**
- **Deleted `src/ReplicatedStorage/Modules/QuotaManager.lua`** — entire file, 34 LOC. Module was 100% unreferenced (`grep -r "QuotaManager" src/` = zero results). It was a duplicate/stub quota system conflicting with the real implementation in `RoundManager.lua`, which correctly handles extraction quota, win condition, RemoteEvent firing, and lobby return.
- **Removed `ShipController.AttemptDock(player)`** — deleted ~35 LOC function from `ShipController.lua`. Function was exported but never called anywhere (`grep -rn "AttemptDock" src/` = zero results). Boarding is ProximityPrompt-driven in `GhostShipGenerator.lua` via `SetSailing()`, which is the correct path.
- **Cleaned up dead dependencies in ShipController.lua** — removed unused requires: `FogSystem`, `AudioManager`, `HorrorEvents`, `Players`, `CollectionService`. Removed unused CONFIG fields: `Acceleration`, `TurnRate`, `DockingDistance`. Removed unused `ShipState.LastDockTime` field.
- Total: ~70 LOC removed, 1 file deleted, 0 lines added. Zero runtime impact.

**What worked:**
- Pre-delete verification: `grep` confirmed zero external references for both QuotaManager and AttemptDock
- Clean deletion — no other files needed changes, no broken imports
- ShipController module is now tighter: only exports `Initialize`, `UpdatePlayerWeight`, `SetSailing`, `Destroy` — all actually used
- Quota source of truth is now unambiguous: `RoundManager` only. No risk of split-brain quota bug from a future contributor accidentally wiring up the dead QuotaManager module
- --!strict preserved, no type regressions
- Follows lua-best-practices.md: "One class/responsibility per ModuleScript"

**What didn't / known gaps:**
- `PlayerDocked` RemoteEvent in ShipController is now orphaned — it was only ever fired from `AttemptDock()`, which is now deleted. The RemoteEvent is still declared (`Utils.CreateRemoteEvent("PlayerDocked")`) and `ClientShipController.lua` still listens to it (`Remotes.PlayerDocked.OnClientEvent`), but nothing on the server fires it anymore. This creates a dangling client listener that will never trigger ("Boarded ghost ship interior - horror intensified" message will never print).
  - **Recommendation:** Either (A) wire `GhostShipGenerator` board/exit ProximityPrompts to fire `PlayerDocked` so the client gets boarding feedback, OR (B) delete `PlayerDocked` RemoteEvent from both ShipController and ClientShipController in a follow-up cleanup. Left intact in this commit to keep the change focused on the PLAN.md scope (delete QuotaManager + AttemptDock only).
  - Left as a known issue, flagged in REVIEW.md
- No Studio playtest — code review only (deletion, so low risk)
- Still no real asset rigs, no automated tests

**Next step:**
Wire up Quota Progress HUD (add RemoteEvent for quota progress, update ClientUIController), OR clean up orphaned `PlayerDocked` RemoteEvent (server + client), OR Rojo/Studio playtest.

**Reviewer notes:** See REVIEW.md
