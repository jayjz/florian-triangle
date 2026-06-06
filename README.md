# Florian Triangle (Fog Sea)

**3-6 player co-op survival horror extraction game inspired by One Piece's Florian Triangle.**

Sail a mobile ship through perpetual dense fog. Detect haunted ghost ships. Dock, scavenge cursed relics under rising supernatural pressure, extract valuable treasure, and escape alive with your crew.

## Current Status (Phase 7 - Asset Binding & Playtesting Prep)
- Phase 6 B- review: Good NetworkOwnership and harness, but visuals and asset readiness skeletal.
- Added ServerStorage/Assets structure notes and placeholder model references in GhostShipGenerator, ExtractionManager, EntityAI (rigged models to be bound for animations/sounds).
- Expanded TestHarness with "fullTestScenario" command that spawns ship + chests + entities + applies difficulty.
- Updated README with complete development workflow (Rojo sync steps, Studio testing on main PC, mobile emulator notes).
- All files --!strict, Maid, Utils.CreateRemoteEvent, detailed mobile performance comments, full diffs.

## Development Workflow
1. **Rojo Sync on Main PC**: `cd /home/abundance333/Documents/florian-triangle && rojo serve` (syncs src/ to Roblox Studio place).
2. **Studio Testing**: Open in Roblox Studio on main PC. Use TestHarness commands (/debug full or RemoteEvent "AdminDebugCommand" with "fullTestScenario").
3. **Mobile Emulator**: Use Roblox Studio's mobile emulator (Device: iPhone 11, throttle CPU). Test extraction loop, AI pathfinding (3Hz), UI lerp on RenderStepped, replication with NetworkOwner(nil).
4. **Asset Binding**: Place rigged models in ServerStorage.Assets (GhostShipRig, LootChestRig, CorruptedPirateRig). Update generators to :Clone() from there + CollectionService tags for client controllers.
5. **GitHub**: Always verify with `git status + log + ls-remote`, full diffs, atomic commits, push. Credential helper store for PAT.
6. **Playtesting Prep**: Multiplayer test (2-4 players, PC+mobile) for sanity/extraction synergy, fog culling, co-op ship sailing.

See PROJECT-ROADMAP.md for phases and lua-best-practices.md for standards.

## Core Loop
1. **Sail** — Navigate treacherous fog waters (mobile-first ship controls)
2. **Detect** — Spot and approach ghost ships in the mist
3. **Dock & Scavenge** — Board decaying vessels filled with horror and opportunity
4. **Extract** — Secure cursed treasure while horrors awaken
5. **Survive** — Escape before the ship (or your sanity) collapses

## Technical Philosophy
- **Mobile First**: 60 FPS target, 5Hz/3Hz loops, pooling, culling, NetworkOwner(nil) on AI.
- **Server Authority**: All state, validation, damage, penalties on server. Remotes for client visuals only.
- **Modular**: Maid cleanup, strong typing, exported types, Utils for remotes/services.
- **GitHub First**: Clean history, real diffs, honest reviews.

**"Even in the Florian Triangle... a crew that sticks together can make it through anything."**

---
**Current Phase**: 7 - Asset Binding & Playtesting Prep (B- visuals readiness)
**Architect**: Fog Sea Architect - 2026-06-07
