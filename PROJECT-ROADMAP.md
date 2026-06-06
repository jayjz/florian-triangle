# Fog Sea (Florian Triangle) Project Roadmap

## Phase 5: Extraction Loop & Client Polish (Completed - Commit 2197535)
- Re-created the three Phase 5 files with full production code: ExtractionManager.lua (loot spawning, weight penalties, ProximityPrompt validation), ClientUIController.lua (sanity bar, weight indicator with color lerp and object pooling, prompts), ClientInit.lua (central initializer with pcall safety).
- Priority 0: Verified exact state with git commands, force-fixed credential helper using PAT with `git -c credential.helper=` bypass.
- All code uses --!strict, exported types, Maid pattern for cleanup, Utils.CreateRemoteEvent, 3Hz server throttling, RenderStepped only for UI lerp on client, explicit comments on mobile performance and "client visuals only" rule.
- Atomic commit + successful push. Updated MEMORY.md with [2026-06-07] timestamp.
- Status: Fully synced to GitHub. Ready for Phase 6 (fog effects, ship sailing co-op).

(See previous phases. Last updated 2026-06-07)