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
- **Regression introduced:** `PlayerDocked` RemoteEvent orphaned, all boarding feedback lost (sanity damage, horror pulse, audio, client FX) — fixed in next step

### Restore Ghost Ship Boarding Feedback (P1) — ✅ Done 2026-06-29 (a1fd33b)
- Added `ShipController.BoardGhostShip(player, ghostModel, interiorCFrame): boolean` — full boarding sequence with horror feedback: freezes sailing, teleports player, triggers sanity damage (-12), horror pulse (0.8), boarding audio, fires `PlayerDocked` RemoteEvent for client FX. All external calls guarded with `typeof() == "function"` + `pcall()` with warn-on-failure.
- Added `ShipController.ExitGhostShip(player, returnCFrame): boolean` — symmetric exit API, restores sailing, teleports back
- Re-added `AudioManager` + `HorrorEvents` requires to ShipController (correctly removed in caa279d, now needed again with real callers)
- Added `BoardingSanityDamage` / `BoardingHorrorPulse` to CONFIG for tunability
- Wired `GhostShipGenerator` boarding/exit ProximityPrompts to new API — boarding logic moved from GhostShipGenerator → ShipController, proper separation of concerns, single source of truth for all boarding state transitions
- `SetSailing()` kept exported as low-level primitive with clear documentation — `BoardGhostShip`/`ExitGhostShip` are the high-level API
- `PlayerDocked` RemoteEvent is LIVE again — `ClientShipController` boarding listener actually fires, camera shake TODO unblocked
- ~80 LOC added / ~11 removed across 2 files, net +69 LOC
- Server-authoritative, --!strict clean, defensive programming exemplary (pcall + typeof guards on every external call)
- **Known gaps:** (1) No boarding cooldown / double-board guard — player could spam ProximityPrompt to drain own sanity rapidly. Recommend: check `SailingEnabled == false` at BoardGhostShip entry, reject if already inside. ~3 LOC. (2) Asset-spawned ghost ships (`ServerStorage/Assets/GhostShipRig`) may be missing boarding ProximityPrompt — only procedural ships (`CreateTestShip`) have it wired up. Need to verify in Studio, add prompt if missing.

---

## Current Step: _TBD — awaiting Planner pass_

**Next candidates:**
1. **Fix boarding double-board exploit** — Add `SailingEnabled == false` guard at top of `BoardGhostShip()` to prevent sanity-drain spam. ~3 LOC, high value for stability, flagged in REVIEW.md. Fast follow-up from boarding feedback fix.
2. **Quota Progress HUD** — Add extraction quota progress bar to client HUD. Wire `RoundManager.AddExtracted()` → RemoteEvent → `ClientUIController`. High player value, ~40 LOC, 2 files.
3. **Fix asset ghost ship boarding prompt** — Verify `ServerStorage/Assets/GhostShipRig` in Studio has boarding ProximityPrompt. If missing, add one at runtime in `spawnFromAsset()` that calls `BoardGhostShip()`. Otherwise asset ships are unboardable. ~10 LOC if needed.
4. Rojo/Studio playtest full extraction loop (requires Windows/Roblox Studio) — **OVERDUE.** 4 fixes shipped without in-engine validation: SetSailing, TestHarness, QuotaManager cleanup, Boarding Feedback. Code review confidence is high, but nothing replaces actual playtest.
5. Import real rigged assets to ServerStorage/Assets

---
## Backlog
- Fix boarding double-board exploit — see Current Step candidates above
- Quota Progress HUD — see above
- Fix asset ghost ship boarding prompt — see above
- Rojo/Studio playtest full extraction loop — OVERDUE, see above
- Import real rigged assets to ServerStorage/Assets
- Client highlight culling/pooling
- Audio polish / monetization hooks (Phase 8)
- TestHarness hygiene nits: Move `_G.ForceTestScenario` assignment into Initialize/Destroy, defer `AdminDebugRemote` creation to Initialize (low priority, 5 LOC)
- ClientShipController camera shake / interior lighting — `PlayerDocked` event now fires correctly, TODO at `ClientShipController.lua:60` is unblocked. ~15 LOC with tween CameraOffset + Lighting.ColorCorrection
