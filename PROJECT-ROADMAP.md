# Fog Sea (Florian Triangle) Project Roadmap

## Phase 7: Asset Binding & Playtesting Prep (Completed - Commit 1ed95ba)
- Created src/ServerStorage/Assets folder and default.project.json for clean Rojo sync (includes ServerStorage/Assets).
- Fixed TestHarness "fullTestScenario" with initialization guard and complete testable round (ship + 3 chests + 2 entities + difficulty).
- Made asset binding concrete in GhostShipGenerator, ExtractionManager, EntityAI with ServerStorage.Assets.*Rig references (placeholder logic) and CollectionService tags ("GhostShip", "LootChest", "CorruptedPirate").
- Updated README.md and this file with accurate B- status, next steps (Rojo sync on Windows PC + Studio testing with TestHarness).
- All files --!strict, Maid, Utils, performance comments, full diffs.
- Self-review B- (see below). Last updated 2026-06-07.

## Previous Phases
- Phase 6: Testing Harness (B- visuals/asset readiness).
- Phase 5: Extraction (B- skeletal pooling/anti-exploit).
- Earlier: Core, AI, client controllers.

**Next Steps:**
- Rojo sync on Windows PC: copy default.project.json, `rojo serve`.
- Studio testing: Use TestHarness commands for full round, verify tags in client controllers, mobile emulator for performance.
- Import real rigged models to ServerStorage.Assets and update placeholder logic.
- Full multiplayer playtest for extraction/sanity synergy.

(See MEMORY.md for timestamps and gaps.)
