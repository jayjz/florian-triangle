# Implementation Plan

## Current Step: Fix ShipController Boarding API (P0)

**Problem:** `GhostShipGenerator.lua` calls `ShipController.SetSailing(player, true/false)` on board/exit, but `ShipController.lua` does not export `SetSailing`. This causes a runtime error when players try to board ghost ships, blocking the core extraction loop.

**Fix:**
1. Add `ShipController.SetSailing(player: Player, enabled: boolean)` to `ShipController.lua`
   - Toggle sailing state, freeze/unfreeze velocity, update activeShips entry
   - Guard against nil player / missing ship entry
2. Verify `ShipController.AttemptDock()` is unused (boarding is ProximityPrompt-driven in GhostShipGenerator) — keep it for now, may wire later
3. Test via TestHarness fullTestScenario in Studio

**Acceptance:**
- [ ] `SetSailing` exists with proper --!strict typing
- [ ] Boarding a ghost ship no longer errors
- [ ] Exiting via hatch teleports player back and re-enables sailing
- [ ] No regression in weight penalty / movement input

**Files:**
- `src/ReplicatedStorage/Modules/ShipController.lua` — add SetSailing()

---
## Backlog
- Rojo/Studio playtest full extraction loop
- Import real rigged assets to ServerStorage/Assets
- Client highlight culling/pooling
- Audio polish / monetization hooks (Phase 8)
