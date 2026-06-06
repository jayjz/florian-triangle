# Fog Sea (Florian Triangle) Project Roadmap

## Phase 7: Asset Binding & Playtesting Prep + Structural Fixes (Completed - 2026-06-08)
- Fixed Rojo structure: default.project.json now has explicit "$className": "DataModel" at root + complete tree for ServerStorage/Assets.
- Created/verified src/ServerStorage/Assets folder.
- Patched TestHarness.lua with isGameManagerInitialized boolean guard preventing duplicate Initialize() calls.
- Created ClientShipController.lua and updated ClientUIController.lua to consume CollectionService tags ("GhostShip", "LootChest") via GetInstanceAddedSignal with client-side Highlight for visual confirmation in Studio.
- Updated MEMORY.md and this ROADMAP with today's date and details.
- Git verification, atomic commit "fix(core): establish Rojo DataModel, patch TestHarness guard, add client tag consumers", successful push.
- Self-review: B (addresses all 4 critical gaps listed; client tag consumers now exist but not yet wired into ClientInit.lua; highlights are dev aids only and should be conditional on RunService:IsStudio(); no real 3D assets yet; needs immediate Windows Rojo playtest to validate sync).
- Last updated: 2026-06-08

## Previous Phases
- Phase 7 initial: B- due to missing client consumers, incorrect project.json, folder issues, init guard.
- Phase 6: Testing Harness (B-).
- Phase 5: Extraction (B-).

**Next Steps:**
- On Windows PC: rojo serve, open in Studio, run fullTestScenario via chat/debug, verify client highlights on spawned assets.
- Wire ClientShipController.Initialize() and updated controllers in ClientInit.lua.
- Import real rigged models into ServerStorage.Assets (use placeholders for now).
- Add distance-based culling / pooling for client highlights if many entities.
- Full co-op horror extraction playtest.

(See MEMORY.md for full history and brutally honest gaps.)
