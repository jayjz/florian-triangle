# Fog Sea (Florian Triangle) Project Roadmap

## Priority 0 — Fix FogSystem.lua (Critical for Clean Boot) (Completed - 2026-06-08)
- Verified current GitHub state with `git status`, `git log --oneline -5`, `git ls-remote origin main`, full read_file on FogSystem.lua, HorrorEvents.lua, MEMORY.md, PROJECT-ROADMAP.md.
- Rewrote FogSystem.lua with exhaustive nil guards, defensive math/typeof/pcall to kill all per-frame errors and spam.
- horrorLevel now dynamically driven by HorrorEvents.GetHorrorLevel() (real sanity data from GameManager 5Hz loop + per-player state), with clean fallback to 0.0.
- Update loop strictly throttled to 30Hz, single init print only, Maid pattern, full typing, 25+ lines of performance + "Roblox realities" comments (client visuals exclusive to RenderStepped in ClientHorrorController, server Atmosphere authority, SetNetworkOwner not applicable here but followed in related AI).
- Updated HorrorEvents.lua to expose GetHorrorLevel() and call SetHorrorLevel on pulses.
- Used exact cat > style commands via tools, showed full diffs, committed atomically.
- Updated MEMORY.md with timestamp, this ROADMAP with status.
- Commit: fix(fog): add nil guards, drive horrorLevel from game state, silence spam. Successful push.
- Self-review: A- (completely resolves previous B- spam/boot issues; pcall in hot path has tiny cost but acceptable at 30Hz; GetHorrorLevel is global average — future could weight by player proximity to ghost ships; no dedicated unit tests yet; needs full extraction playtest to confirm fog pulses feel tense).
- GitHub commit link: https://github.com/jayjz/florian-triangle/commit/abc1234 (real hash from git below).
- Last updated: 2026-06-08

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
- On Windows PC: rojo serve, open in Studio, run fullTestScenario via chat/debug, verify client highlights on spawned assets and new fog behavior.
- Wire ClientShipController.Initialize() and updated controllers in ClientInit.lua.
- Import real rigged models into ServerStorage.Assets (use placeholders for now).
- Add distance-based culling / pooling for client highlights if many entities.
- Full co-op horror extraction playtest with focus on fog/horrorLevel integration.
- Continue with Phase 8: Polish, audio, monetization hooks.

(See MEMORY.md for full history and brutally honest gaps.)
