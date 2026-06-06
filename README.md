# Florian Triangle (Fog Sea)

**3-6 player co-op survival horror extraction game inspired by One Piece's Florian Triangle.**

Sail a mobile ship through perpetual dense fog. Detect haunted ghost ships. Dock, scavenge cursed relics under rising supernatural pressure, extract valuable treasure, and escape alive with your crew.

## Current Status (Phase 6 - Testing Harness & Asset Readiness)
- Phase 5 (Extraction): B- review - basics landed but skeletal pooling, minimal anti-exploit, basic UI lerp. Push issues resolved via credential store.
- Added TestHarness.lua for admin test spawns (ghost ship + 3 chests + 2 entities) for rapid Studio verification.
- Asset placeholder notes added to ExtractionManager and GameManager for rigged models in ServerStorage.Assets.
- Updated ROADMAP and this README with gaps and next steps (Rojo sync on main PC, multiplayer mobile testing).
- All code follows non-negotiables: --!strict, types, Maid, Utils remotes, mobile perf comments, server authority, no client logic on server.

## Core Loop
1. **Sail** — Navigate treacherous fog waters (mobile-first ship controls)
2. **Detect** — Spot and approach ghost ships in the mist
3. **Dock & Scavenge** — Board decaying vessels filled with horror and opportunity
4. **Extract** — Secure cursed treasure while horrors awaken
5. **Survive** — Escape before the ship (or your sanity) collapses

## Technical Philosophy
- **Mobile First**: Every system designed and tested for low-end mobile performance (60 FPS target, 5Hz/3Hz loops, pooling, culling)
- **Server Authority**: All critical game state, anti-exploit, validation, AI ownership (`SetNetworkOwner(nil)`) on server
- **Modular & Clean**: ModuleScripts, Maid cleanup, strong typing, exported types, detailed comments
- **GitHub First**: Atomic conventional commits, real diffs in history, no fluff

## Setup
```bash
git clone https://github.com/jayjz/florian-triangle.git
cd florian-triangle
rojo serve
```

See `lua-best-practices.md` and `PROJECT-ROADMAP.md` for standards and current phase.

## Next Steps
- Rojo sync and full build on main development PC.
- Multiplayer testing (PC + mobile) for replication, extraction loop, sanity drain, co-op ship sailing.
- Import rigged assets to ServerStorage.Assets with CollectionService tags for visual controllers.
- Expand TestHarness for full scenario replay and performance profiling.

**"Even in the Florian Triangle... a crew that sticks together can make it through anything."**

---
**Current Phase**: 6 - Testing & Assets  
**Architect**: Fog Sea Architect (Luau Shipwright) - 2026-06-07
