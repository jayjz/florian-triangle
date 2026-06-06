# Florian Triangle (Fog Sea)

**3-6 player co-op survival horror extraction game inspired by One Piece's Florian Triangle.**

Sail a mobile ship through perpetual dense fog. Detect haunted ghost ships. Dock, scavenge cursed relics under rising supernatural pressure, extract valuable treasure, and escape alive with your crew.

## Current Status (Phase 7 - Asset Binding & Playtesting Prep, B-)
- rojo.json renamed/updated to default.project.json for Rojo sync (includes ServerStorage/Assets).
- src/ServerStorage/Assets folder created.
- Asset binding made concrete in GhostShipGenerator, ExtractionManager, EntityAI with ServerStorage.Assets.*Rig references (placeholder logic) and CollectionService tags.
- TestHarness "fullTestScenario" fixed with GameManager init guard and complete round spawn.
- Updated this README and PROJECT-ROADMAP.md with accurate status and next steps (Rojo sync on Windows PC + Studio testing with TestHarness).
- All files follow non-negotiables (--!strict, Maid, Utils, performance comments). Server skeleton strong but visuals/asset readiness skeletal (B- overall).

## Development Workflow (for Windows PC)
1. **Rojo Sync**: Copy default.project.json to project root if needed. Run `rojo serve` in terminal (syncs src/ to Studio place).
2. **Studio Testing on Main PC**: Open place in Roblox Studio. Use TestHarness commands (RemoteEvent "AdminDebugCommand" with "fullTestScenario" or chat /debug full). Verify spawning, tags, NetworkOwner(nil), performance.
3. **Mobile Emulator Notes**: In Studio, switch to mobile device emulator (iPhone 11), throttle CPU. Test extraction loop (3Hz), AI pathfinding, UI lerp on RenderStepped, replication lag with multiple players.
4. **Asset Binding**: Place rigged .rbxm models in ServerStorage.Assets (GhostShipRig, LootChestRig, CorruptedPirateRig). Update placeholder logic in generators to use :FindFirstChild("RigName") or Clone(). Add CollectionService tags for client controllers to consume.
5. **GitHub**: Always run verification commands first. Use full diffs, atomic commits. Credential helper may require `-c credential.helper=` for push in some envs.
6. **Playtesting Prep**: Multiplayer test (PC + mobile) for sanity/extraction, fog culling, co-op sailing. Use TestHarness for quick rounds.

See PROJECT-ROADMAP.md for phases/gaps and lua-best-practices.md for standards.

## Core Loop
1. **Sail** — Navigate treacherous fog waters (mobile-first ship controls)
2. **Detect** — Spot and approach ghost ships in the mist
3. **Dock & Scavenge** — Board decaying vessels filled with horror and opportunity
4. **Extract** — Secure cursed treasure while horrors awaken
5. **Survive** — Escape before the ship (or your sanity) collapses

**"Even in the Florian Triangle... a crew that sticks together can make it through anything."**

---
**Current Phase**: 7 - Asset Binding & Playtesting Prep (B-)
**Architect**: Fog Sea Architect - 2026-06-07
