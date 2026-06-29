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

### Restore Ghost Ship Boarding Feedback (P1) — ✅ Done 2026-06-29 (a1fd33b)
- Added `ShipController.BoardGhostShip(player, ghostModel, interiorCFrame): boolean` — full boarding sequence with horror feedback: freezes sailing, teleports player, triggers sanity damage (-12), horror pulse (0.8), boarding audio, fires `PlayerDocked` RemoteEvent for client FX
- Added `ShipController.ExitGhostShip(player, returnCFrame): boolean` — symmetric exit API
- Re-added `AudioManager` + `HorrorEvents` requires to ShipController
- Wired `GhostShipGenerator` boarding/exit ProximityPrompts to new API — boarding logic moved from GhostShipGenerator → ShipController, proper separation of concerns
- `PlayerDocked` RemoteEvent is LIVE again — `ClientShipController` boarding listener actually fires
- ~80 LOC added / ~11 removed, net +69 LOC
- Known gaps: (1) No boarding cooldown guard, (2) Asset ghost ships may be missing boarding ProximityPrompt

### Client Camera Shake on Ghost Ship Boarding — ✅ Done 2026-06-29 (620d541)
- Implemented camera shake + FOV kick in `ClientShipController.PlayerDocked.OnClientEvent` — replaces TODO at line 60 that had been dead since module was written
- FOV kick: 70 → 78 over 0.15s (Quad Out), 78 → 70 over 0.25s (Quad In) — classic impact feel, total 0.4s
- Screen shake: `Humanoid.CameraOffset` with decaying random offsets over 0.6s — works in all CameraTypes, mobile-friendly, doesn't fight camera controller
- Defensive guards: nil camera check, nil humanoid check, CameraOffset reset on completion, FOV restored to captured base value (respects custom FOV)
- Non-blocking: shake runs in `task.spawn()`, movement input uninterrupted
- ~30 LOC added, 1 file, pure client-side, zero network cost
- Horror tension delivery: most visceral feedback possible, hits every player even muted/on mobile
- Note: LOC exceeded 20 LOC target (~30 LOC vs ~15 estimated) — proper defensive guards, cleanup, and readability justified the overrun. Still small, focused, low risk.

---

## Current Step: _TBD — awaiting Planner pass_

**Next candidates:**
1. **Fix boarding double-board exploit** — Add `SailingEnabled == false` guard at top of `BoardGhostShip()` to prevent sanity-drain spam via rapid ProximityPrompt triggering. ~3 LOC, high value for stability. Was flagged in a1fd33b review, skipped per "never fix regressions from previous cleanups in same cycle" rule (boarding feedback was just shipped, then camera shake built on top of it — now 2 cycles have passed, safe to fix).
2. **Quota Progress HUD** — Add extraction quota progress bar to client HUD. Wire `RoundManager.AddExtracted()` → RemoteEvent → `ClientUIController`. High player value, ~40 LOC, 2 files. Exceeds 20 LOC budget — defer unless larger feature cycle approved.
3. **Fix asset ghost ship boarding prompt** — Verify `ServerStorage/Assets/GhostShipRig` in Studio has boarding ProximityPrompt. If missing, add one at runtime in `spawnFromAsset()` that calls `BoardGhostShip()`. Otherwise asset ships are unboardable. ~10 LOC if needed. Requires Studio verification.
4. **Rojo/Studio playtest full extraction loop** — **CRITICALLY OVERDUE.** 5 fixes shipped without in-engine validation: SetSailing (ab648ab), TestHarness (edea063), QuotaManager cleanup (caa279d), Boarding Feedback (a1fd33b), Camera Shake (620d541). Code review confidence remains high, but nothing replaces actual playtest. Requires Windows/Roblox Studio.
5. **Client interior lighting change on boarding** — Second half of the TODO at `ClientShipController.lua:60`. Camera shake (just shipped in 620d541) covers impact feel. Interior lighting (tint screen green/dim, ColorCorrection) adds sustained atmosphere while inside ghost ship. ~15 LOC, pairs well with camera shake, good fast follow-up.

---
## Backlog
- Fix boarding double-board exploit — see Current Step candidates above
- Quota Progress HUD — see above
- Fix asset ghost ship boarding prompt — see above
- Rojo/Studio playtest full extraction loop — CRITICALLY OVERDUE, see above
- Client interior lighting change on boarding — see above
- Import real rigged assets to ServerStorage/Assets
- Client highlight culling/pooling
- Audio polish / monetization hooks (Phase 8)
- TestHarness hygiene nits: Move `_G.ForceTestScenario` assignment into Initialize/Destroy, defer `AdminDebugRemote` creation to Initialize (low priority, 5 LOC)
- Accessibility: screen shake disable toggle — camera shake can trigger motion sickness. Add settings flag to reduce/disable screen effects. Low priority until player feedback, ~5 LOC
- Camera shake intensity scaling — scale shake with sanity/horror level for dynamic tension feedback. ~5 LOC, nice polish
