# Florian Triangle (Fog Sea)

**3-6 player co-op survival horror extraction game inspired by One Piece's Florian Triangle.**

Sail a mobile ship through perpetual dense fog. Detect haunted ghost ships. Dock, scavenge cursed relics under rising supernatural pressure, extract valuable treasure, and escape alive with your crew.

## Core Loop
1. **Sail** — Navigate treacherous fog waters (mobile-first ship controls)
2. **Detect** — Spot and approach ghost ships in the mist
3. **Dock & Scavenge** — Board decaying vessels filled with horror and opportunity
4. **Extract** — Secure cursed treasure while horrors awaken
5. **Survive** — Escape before the ship (or your sanity) collapses

## Technical Philosophy
- **Mobile First**: Every system designed and tested for low-end mobile performance (60 FPS target)
- **Server Authority**: All critical game state, anti-exploit, and validation on server
- **Modular & Clean**: Heavy use of ModuleScripts, proper RemoteEvents, dependency injection
- **GitHub First**: Clean commit history, meaningful PRs, thorough documentation

## Setup
```bash
# Clone
git clone https://github.com/jayjz/florian-triangle.git
cd florian-triangle

# Install Rojo (https://rojo.space/)
rojo serve
```

See `lua-best-practices.md` for all coding standards.

## Folder Structure
```
.
├── src/                          # Main Roblox project (Rojo)
│   ├── ServerScriptService/
│   ├── ReplicatedStorage/
│   │   ├── Modules/             # Core systems, utilities, Knit services
│   │   ├── Events/              # RemoteEvent/RemoteFunction wrappers
│   │   └── Assets/
│   ├── StarterPlayer/
│   └── StarterGui/
├── lua-best-practices.md
├── CONTEXT.md
└── README.md
```

**"Even in the Florian Triangle... a crew that sticks together can make it through anything."**

---

**Current Phase**: Foundation & Architecture  
**Architect**: Fog Sea Architect (Luau Shipwright)
