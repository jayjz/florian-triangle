# TASK: Florian Triangle

ONE TREASURE PIECE [HORROR] — Co-op survival horror extraction game set in the cursed Florian Triangle (One Piece lore).

Players sail a living ship through the Smothering Mist, board haunted ghost ships to scavenge cursed treasure, and extract at the Cursed Beacon before the mist claims the crew.

Target: 3-6 players, 5-12 min matches, mobile-first 60FPS.
Core pillars: Fog closing circle, sanity/horror escalation, weight-based loot, crew communication.

## Current Focus (2026-06-29)
Branch: `agent/autonomous-florian-triangle`
Status: Post-Phase 7 / FogSystem P0 fix. Asset binding complete, client tag consumers wired.

Immediate blocker: Ghost ship boarding is broken — `ShipController.SetSailing()` is called by `GhostShipGenerator` but does not exist in `ShipController.lua`. Boarding/exiting will error at runtime, blocking any playtest.

Next: Fix ShipController boarding API, then Rojo/Studio playtest.
