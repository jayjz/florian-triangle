# Fog Sea (Florian Triangle) Project Roadmap

## Phase 6: Testing Harness & Asset Readiness (In Progress)
- Added TestHarness.lua in ServerScriptService for admin /testship command or RemoteEvent to spawn test ghost ship + 3 chests + 2 entities for Studio verification.
- Updated ExtractionManager.lua and GameManager.lua with placeholder asset binding notes for ServerStorage rigged models (chests, ships, AI rigs, CollectionService tags).
- Updated README.md and PROJECT-ROADMAP.md with Phase 5 B- review (skeletal pooling, basic anti-exploit), gaps, and next steps (Rojo sync on main PC, multiplayer testing on mobile).
- All files --!strict, strong typing, Maid, Utils.CreateRemoteEvent, mobile perf comments, architecture notes.
- Commit: "feat(test): add testing harness and roadmap update"
- Status: Testing harness enables rapid iteration. Self-review below. Last updated 2026-06-07.

## Phase 5: Extraction Loop & Client Polish (Completed - Commit 1c6c347)
- Loot system, weight penalties, sanity/weight UI, initializer.
- Gaps: Skeletal pooling, minimal anti-exploit, basic lerp only (B- review).

Previous phases: Core setup, GhostShip, EntityAI, client controllers, network ownership.

Next after Phase 6: Fog system polish, co-op ship sailing, full playtest.

**Next Steps:** 
- Sync Rojo project on main development PC.
- Multiplayer testing (mobile + PC) for replication lag on extraction/AI.
- Rig assets in Blender and import to ServerStorage.Assets.
