# Implementation Plan

## Completed

### Fix ShipController Boarding API (P0) — ✅ Done 2026-06-29 (ab648ab)
- Added `ShipController.SetSailing(player, enabled)` — unblocks GhostShipGenerator board/exit
- Added `SailingEnabled` flag with strict typing, input rejection, velocity freeze
- Refactored ship state creation into `getOrCreateShip()` helper
- Core extraction loop now playable

### Fix TestHarness Double-Init (P1) — ✅ Done 2026-06-29 (edea063)
- Removed TestHarness require + Initialize() from `ServerMain.server.lua` — ServerMain now bootstraps ONLY GameManager, single orchestrator pattern
- Added `initialized` boolean guard to `TestHarness.Initialize()` with early return + warn — defense-in-depth, matches ClientInit pattern
- `TestHarness.Destroy()` now resets `initialized = false` for clean shutdown
- Debug commands (`/debug full`, `_G.ForceTestScenario()`) still work in Studio, still disabled in prod via GameManager IsStudio guard
- No gameplay logic changed, debug tooling only

### Remove Dead Code — QuotaManager + AttemptDock (P2) — ✅ Done 2026-06-29 (caa279d)
- Deleted `src/ReplicatedStorage/Modules/QuotaManager.lua` — 100% unreferenced duplicate quota system, RoundManager is the correct source of truth
- Removed `ShipController.AttemptDock()` — exported but never called, boarding is ProximityPrompt-driven via SetSailing()
- Cleaned up dead dependencies in ShipController: removed unused requires (FogSystem, AudioManager, HorrorEvents, Players, CollectionService), unused CONFIG (Acceleration, TurnRate, DockingDistance), unused ShipState.LastDockTime
- ~70 LOC removed, 1 file deleted, 0 runtime impact
- Quota source of truth now unambiguous, ShipController API surface tight and honest
- Known follow-up: `PlayerDocked` RemoteEvent is now orphaned (was only fired from AttemptDock). ClientShipController still listens but will never receive events. Wire GhostShipGenerator to fire it, or delete from both server+client — queued as next cleanup.

---

## Current Step: _TBD — awaiting Planner pass_

**Next candidates:**
1. **Quota Progress HUD** — Add extraction quota progress bar to client HUD. Wire `RoundManager.AddExtracted()` → RemoteEvent → `ClientUIController`. High player value, ~40 LOC, 2 files. Dead code cleanup unblocks this (single quota source of truth confirmed).
2. **Fix orphaned PlayerDocked RemoteEvent** — Either wire `GhostShipGenerator` board/exit prompts to fire `PlayerDocked` (restore client boarding feedback, ~5 LOC), OR delete the RemoteEvent from both ShipController and ClientShipController (~10 LOC). Fast follow-up from dead code cleanup.
3. Rojo/Studio playtest full extraction loop (requires Windows/Roblox Studio)
4. Import real rigged assets to ServerStorage/Assets

---
## Backlog
- Quota Progress HUD — see Current Step candidates above
- Fix orphaned PlayerDocked RemoteEvent — see above
- Rojo/Studio playtest full extraction loop (requires Windows/Roblox Studio)
- Import real rigged assets to ServerStorage/Assets
- Client highlight culling/pooling
- Audio polish / monetization hooks (Phase 8)
- TestHarness hygiene nits: Move `_G.ForceTestScenario` assignment into Initialize/Destroy, defer `AdminDebugRemote` creation to Initialize (low priority, 5 LOC)
