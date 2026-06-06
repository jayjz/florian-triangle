# Fog Sea (Florian Triangle) Project Roadmap

## Phase 7: Asset Binding & Playtesting Prep (Completed - Commit 032272c)
- Added ServerStorage/Assets structure notes and placeholder model references in GhostShipGenerator, ExtractionManager, EntityAI (rigged models, CollectionService tags for client controllers).
- Expanded TestHarness with "fullTestScenario" command (spawns ship + chests + entities + applies difficulty).
- Updated README.md with complete development workflow (Rojo sync steps, Studio testing on main PC, mobile emulator notes, asset binding steps).
- All files --!strict, Maid, Utils.CreateRemoteEvent, performance comments (0.5Hz spawn, pooling, culling), full architecture explanations.
- Self-review B- (skeletal visuals, placeholder templates, no actual rigged assets imported yet).
- Status: Playtesting prep complete. Ready for full asset import and multiplayer test. Last updated 2026-06-07.

## Phase 6: Testing Harness & Asset Readiness (Completed)
- TestHarness for admin spawns, B- review on visuals/asset readiness.

Previous phases: Extraction (B-), Cleanup (B-), core systems.

Next: Fog system, co-op sailing, full playtest with rigged assets.

**Development Workflow:**
- Rojo sync: `cd /home/abundance333/Documents/florian-triangle && rojo serve`
- Studio testing on main PC with TestHarness commands.
- Mobile emulator for replication/sanity tests.
- Bind rigged models in ServerStorage.Assets before playtest.

(See MEMORY.md for timestamps and gaps.)
