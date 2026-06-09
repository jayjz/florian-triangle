# GEMINI.md - Florian Triangle (ONE TREASURE PIECE [HORROR])

## Project Overview
- **Game**: 3-6 player co-op survival horror extraction game set in the Florian Triangle.
- **Core Loop**: Sail living ship → Enter Smothering Mist → Board haunted ghost ships → Scavenge cursed treasure (heavy weight penalty) → Return to Cursed Beacon → Escape before mist consumes crew.
- **Tone**: Psychological horror + One Piece spirit of crew resilience and hope.
- **Tech**: Rojo + Luau (strict mode), modular architecture, Maid pattern, server authority.

## Coding Standards (Strict)
- Always use `--!strict`
- Use Maid for cleanup
- Server is source of truth (especially for Fog, Extraction, Sanity, Round state)
- Prefer composition over inheritance
- Clear separation: ServerScriptService (logic), ReplicatedStorage/Modules (shared), StarterPlayerScripts (client controllers)
- All Remotes must be in ReplicatedStorage.Remotes
- Use descriptive variable names, no magic numbers
- Comment complex horror/sanity logic

## Architecture Rules
- GameManager → RoundManager → LobbyManager
- Client controllers mirror server modules where needed
- FogSystem is critical — never let client predict mist state
- Weight penalties must affect both movement and ship speed
- Hallucinations: Server-triggered, client visual only

## Current Priorities (Fix in this order)
1. COMPLETED: Lighting/Fog syntax and visibility fix.
2. COMPLETED: Island organization and Windmill optimization (< 800 descendants).
3. COMPLETED: Pirate NPC Rig integration in ServerStorage.Assets.
4. COMPLETED: Ghost Ship polish (richer hulls, dynamic interiors, boarding flow).
5. COMPLETED: Pirate combat tuning (EntityAI behavior, damage, health).
6. IN PROGRESS: Island loot variety (cursed relics, gold piles).
7. Terrain island tagging + dynamic spawning
8. Polish sanity/hallucination + audio

## Map State (Current)
- **Fog Center**: (0, 50, 0)
- **Extraction Beacon**: (0, 95, 0)
- **WindmillVillageIsland**: (300, 142, 300) [SafeZone, Island, ScavengePoint]
- **RuinedPirateVillage**: (-300, 120, 200) [Island, ScavengePoint]
- **GhostOutpost**: (200, 130, -350) [Island, ScavengePoint]
- **CursedGrove**: (-250, 115, -250) [Island, ScavengePoint]
- **AbandonedLighthouse**: (400, 150, 0) [Island, ScavengePoint]

## Asset Memory
- **CorruptedPirateRig**: Located in `ServerStorage.Assets`. Standard R15-compatible rig for `EntityAI`. Now features **Glowing Red Eyes** and **Ghostly Mist Particles** for lore compliance.
- **Windmill_Optimized**: Low-poly mesh version on Windmill island to maintain performance.
- **GhostShipTemplate**: Low-poly boat model in `ReplicatedStorage.Assets`. Used by `GhostShipGenerator` via object pooling.
- **Ghost Ship Interiors**: Welded to hulls but offset at +5000 Y for visual isolation. Moves dynamically with the ship hull.

## FlorianTriangleLore
- **The Smothering Mist**: A supernatural, permanent fog bank between Water 7 and Fish-Man Island. It is not natural; it is a living barrier that consumes the weak and hides ancient horrors.
- **Ghost Ships (Cursed Galleons)**: Hundreds of ships disappear annually. They return as hollow, spectral husks drifting without crews, serving as traps for greedy scavengers.
- **The Umibōzu Shadows**: Colossal, vaguely humanoid entities with glowing eyes that tower over the mist. They are the true masters of the Triangle. Seeing them triggers immediate Sanity Drain.
- **Thriller Bark Legacy**: While the giant island-ship has passed through, its lingering curse remains in the form of "Corrupted Pirates" (zombies) and ruined outposts.
- **The Toll (Cursed Treasure)**: Treasure found here is physically heavy and mentally taxing. It is a "toll" that must be paid to the Cursed Beacon to earn safe passage out.
- **Crew Resilience**: The only defense against the Triangle's psychological horror is the "Spirit of the Crew." Proximity to teammates stabilizes sanity.

### Lore Compliance Notes
- **Corrupted Pirates**: Now feature glowing red eyes and ghostly particles, aligning with the Thriller Bark legacy and Umibōzu aesthetic.
- **Spirit of the Crew**: Implementation of `getCrewResilienceMultiplier` in `EntityAI` reduces damage and sanity drain when teammates are within 35 studs.

## Memory / Context Rules
- Always read current file state via MCP before suggesting changes
- Maintain existing patterns (Maid, module structure, naming)
- When fixing bugs: Provide full corrected file when possible
- Test mentally for edge cases: 1 player, network lag, mobile, full weight

## Style
- Brutally direct. No fluff.
- Prefer simple, performant code over "clever"
- Horror atmosphere in audio, visuals, and text feedback

You are now an expert on this project. Use this file as permanent context.