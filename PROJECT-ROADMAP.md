# Fog Sea (Florian Triangle) Project Roadmap

## Phase 1: Foundation (Complete)
- Core utils, Maid, RemoteEvent patterns, GameManager skeleton.
- GitHub setup, Rojo structure, best practices doc.

## Phase 2: Ghost Ships & AI (Complete - b6ef4c0)
- GhostShipGenerator, EntityAI, HorrorEvents with throttling and ownership.

## Phase 3: Core Loop Deepening (Complete)
- ShipController, improved GameManager with 5Hz loop.

## Phase 4: Client Visual Controllers & Network Fixes (Complete - a933018)
- ClientCombatController, ClientHorrorController, SetNetworkOwner(nil), RenderStepped visuals only.

## Phase 5: Extraction Loop & Client Polish (Complete - 55c3555)
- **ExtractionManager**: Loot chest spawning with pooling, ProximityPrompts, server-validated pickup, weight-based movement/jump penalties. Full types, per-chest Maids.
- **ClientUIController**: Sanity bar with color transitions and lerp, dynamic weight indicator + load bar, pooled feedback text popups for pickups, ProximityPromptService integration for client UX.
- **ClientInit**: Robust ordered controller init with pcall safety and centralized cleanup.
- Updated GameManager to orchestrate ExtractionManager.
- Performance: 3Hz server spawning, pooled models/prompts/feedback, RenderStepped limited to UI interpolation only. All client visuals via remotes.
- Status: **A- production core for extraction**. Ready for multiplayer extraction loop playtesting on mobile.

## Phase 6: Full Extraction + Escape (Next)
- Bank treasure on ship, timed escape sequence, weight-based horror scaling, full integration with sanity system.
- Object pooling expansion, distance culling for chests, mobile profiling.

## Phase 7: Polish, Audio, Monetization
- VFX, sound design, gamepasses (better ships), leaderboards.
- Full Roblox certification prep.

**Core Principles (locked in)**: 
- Mobile-first (throttled loops, pooling, no server visuals).
- Strict client/server separation (server: state/validation/penalties; client: bars, prompts, effects).
- Maid pattern, --!strict, exported types, Utils for all remotes.
- GitHub-first with atomic conventional commits.
- Brutally honest reviews only.

Last updated: 2026-06-06
