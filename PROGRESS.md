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

**Reviewer notes:** See REVIEW below.
