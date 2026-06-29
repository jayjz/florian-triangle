# Implementation Plan

## Completed

### Fix ShipController Boarding API (P0) — ✅ Done 2026-06-29 (ab648ab)
- Added `ShipController.SetSailing(player, enabled)` — unblocks GhostShipGenerator board/exit
- Added `SailingEnabled` flag with strict typing, input rejection, velocity freeze
- Refactored ship state creation into `getOrCreateShip()` helper
- Core extraction loop now playable

---

### Fix TestHarness Double-Init (P1) — ✅ Done 2026-06-29 (edea063)
- Removed TestHarness require + Initialize() from `ServerMain.server.lua` — ServerMain now bootstraps ONLY GameManager, single orchestrator pattern
- Added `initialized` boolean guard to `TestHarness.Initialize()` with early return + warn — defense-in-depth, matches ClientInit pattern
- `TestHarness.Destroy()` now resets `initialized = false` for clean shutdown
- Debug commands (`/debug full`, `_G.ForceTestScenario()`) still work in Studio, still disabled in prod via GameManager IsStudio guard
- No gameplay logic changed, debug tooling only

---

## Current Step: _TBD — awaiting Planner pass_

**Next candidates:**
1. Remove dead `ShipController.AttemptDock()` or wire it to ProximityPrompt system
2. Rojo/Studio playtest full extraction loop (requires Windows/Roblox Studio)
3. Import real rigged assets to ServerStorage/Assets

---
## Backlog
- Rojo/Studio playtest full extraction loop
- Remove dead `ShipController.AttemptDock()` or wire it to ProximityPrompt system
- Import real rigged assets to ServerStorage/Assets
- Client highlight culling/pooling
- Audio polish / monetization hooks (Phase 8)
