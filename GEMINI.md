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
1. Fix all require path errors (GameManager, LobbyManager, RoundManager)
2. Fix ClientUIController syntax errors
3. Complete ExtractionZone + round win/lose → lobby reset flow
4. Secure ShipController (input validation + anti-exploit)
5. Terrain island tagging + dynamic spawning
6. Polish sanity/hallucination + audio

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