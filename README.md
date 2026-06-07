# ONE TREASURE PIECE [HORROR]

> *"The Smothering Mist doesn't just take your sight. It takes your crew, your sanity, and eventually... it takes you."*

![Roblox](https://img.shields.io/badge/Roblox-Studio-blue?style=for-the-badge&logo=roblox)
![Rojo](https://img.shields.io/badge/Rojo-7.4+-red?style=for-the-badge)
![Status](https://img.shields.io/badge/Status-Alpha-yellow?style=for-the-badge)

---

## 📖 Project Vision

**ONE TREASURE PIECE [HORROR]** is a 3-6 player co-operative survival horror extraction game that drops players into the cursed waters of the Florian Triangle from One Piece lore. This is not a fan game—this is a psychological horror experience that weaponizes the themes of resilience, crew bonds, and hope against overwhelming dread.

### The Core Fantasy
You and your crew sail a living ship through an ever-encroaching green mist that actively hunts you. The "Smothering Mist" is not a weather effect—it's a malevolent entity that:

* Reduces visibility to near-zero in dense pockets.
* Drains sanity the longer you're exposed.
* Spawns hallucinations — shadow Luffy figures, whispers in the fog, fake crewmates calling for help.
* Accelerates as horror escalates, forcing impossible decisions.

**Your mission:** Board haunted ghost ships, scavenge cursed treasure (with brutal weight penalties), and extract at the Cursed Beacon before the mist claims your entire crew.

*This is Doors + Pressure meets Lethal Company with a One Piece soul—5 to 12 minutes of pure co-op tension where communication isn't just helpful, it's survival.*

---

## 🎮 Gameplay Loop

### 1. The Lobby - Foosha Village
Players spawn in Foosha Village with full UI, loadout selection, and crew formation. The windmill spins lazily overhead, but the horizon is already green.

### 2. Deployment - Windmill Village
The ship spawns at Windmill Village. Crew boards, roles are assigned (Captain, Navigator, Lookout), and the mist clock starts ticking.

### 3. The Sail
* Navigate the living ship through narrowing safe zones.
* `FogSystem` dynamically closes the circle—faster as horror level increases.
* Speed penalties apply based on total loot weight.
* Ghost ships spawn with modular interiors and cursed loot.

### 4. Boarding Actions
Dock with a ghost ship:
* Breach the hull (timed interaction).
* Split the crew or stay together (risk/reward).
* Scavenge treasure (weight matters—a gold chest slows you to a crawl).
* Survive horror events (sanity checks, hallucinations, audio jumpscares).
* **Communicate constantly:** *"I can't see you—lead me back to the ship!"*

### 5. Extraction
Reach the Cursed Beacon extraction zone:
* Pay the toll (meet quota or lose everything).
* Survive the final horror pulse.
* Extract with remaining crew.
* Failed extractions trigger crew-wide sanity penalties.

### 6. Horror Escalation
Each round intensifies:
* Sanity decay accelerates in dense fog.
* Horror pulses trigger screen distortions, fake entities, whispers.
* Fake crewmates appear on your screen only (gaslighting mechanic).
* Audio paranoia — distant screams, footsteps behind you that aren't real.

**Win condition:** Extract with quota met.  
**Lose condition:** Full crew wipe, quota failure, or mist consumption.

---

## 🏗️ Tech Stack & Architecture

### Core Technologies
* **Roblox Studio** (Latest)
* **Rojo 7.4+** for external code sync
* **Luau** with strict type checking (`--!strict`)
* **Knit Framework** (in evaluation for Phase 2)

### Repository Structure
```text
├── src/
│   ├── ServerScriptService/
│   │   ├── GameManager.server.lua        # Orchestrates round lifecycle
│   │   ├── RoundManager.server.lua       # Manages match phases
│   │   ├── LobbyManager.server.lua       # Foosha Village logic
│   │   └── Services/
│   │       ├── SanityService.lua         # Sanity decay & hallucinations
│   │       ├── FogService.lua            # Smothering Mist simulation
│   │       └── ExtractionService.lua     # Beacon & quota handling
│   ├── ReplicatedStorage/
│   │   ├── Modules/
│   │   │   ├── FogSystem.lua             # Dynamic circle closing
│   │   │   ├── HorrorEvents.lua          # Event dispatcher
│   │   │   ├── ShipController.lua        # Living ship physics
│   │   │   ├── LootSystem.lua            # Weight & inventory
│   │   │   └── SanityFX.lua              # Client-side effects
│   │   └── Shared/
│   │       ├── Config.lua                # Tunables & balance
│   │       └── Types.lua                 # Type definitions
│   └── StarterPlayer/
│       └── StarterPlayerScripts/
│           └── Controllers/
│               ├── SanityController.lua  # Client sanity sync
│               ├── FogController.lua     # Fog rendering
│               └── InputController.lua   # Mobile-first input
├── assets/
│   ├── models/                           # Ghost ships, islands
│   ├── audio/                            # Whispers, ambiance
│   └── fx/                               # Particle effects
├── default.project.json                  # Rojo configuration
└── README.md
