# Lua/Luau Best Practices - Fog Sea

**Production-grade standards for Florian Triangle (Fog Sea). All code must follow these rules.**

## 1. Performance (Mobile First)
- **NEVER** use `wait()` — use `task.wait()`, `task.defer()`, `task.delay()`
- Avoid table recreation in hot loops. Reuse tables where possible (`table.clear()`)
- Profile with MicroProfiler. Target < 8ms per frame on low-end mobile
- Limit raycasts, heartbeats, and `RunService.Heartbeat` listeners
- Use object pooling for projectiles, VFX, entities
- Prefer `local` variables. Avoid repeated `game:GetService()` calls — cache them

## 2. Security & Server Authority
- **All game state lives on the server**
- Never trust the client. Validate *everything*
- Use proper RemoteEvent wrappers with type checking and rate limiting
- Implement anti-exploit patterns (sanity checks, movement validation, etc.)
- Use `RemoteEvent:FireClient()` selectively. Prefer `FireAllClients()` with filtering when possible

## 3. Code Organization
- **Modular ModuleScripts only**
- Use `Knit` or custom dependency injection for services
- Strict folder structure under `ReplicatedStorage.Modules`
- One class/responsibility per ModuleScript when possible
- Use `Maid` pattern for cleanup
- Prefer composition over deep inheritance

## 4. Naming & Style
- `PascalCase` for modules, classes, enums
- `camelCase` for variables, functions, parameters
- `SCREAMING_SNAKE_CASE` for constants
- Descriptive names. `playerCharacter` > `char`
- File names must match main exported symbol
- Add performance and security notes in comments for complex systems

## 5. Error Handling & Robustness
- Use `assert()`, `warn()`, and proper pcall where appropriate
- Never let errors silently fail in critical paths
- Add context to all warnings/errors (`"FogSea.ShipController: Failed to dock - {reason}"`)

## 6. RemoteEvents Pattern
```lua
-- In ReplicatedStorage.Events
local Remotes = {
    PlayerDocked = ReplicatedStorage.Events.PlayerDocked,
    -- ...
}

-- Server: always validate first
-- Client: use typed wrappers with Promise support where appropriate
```

## 7. Git & Contribution
- One logical change per commit
- Clear commit messages: `type(scope): description`
- Example: `feat(ship): implement ghost ship docking system`
- Update this document when new patterns are established
- All PRs must pass code review against these standards

**This is not optional.** These standards exist because we are targeting mobile players in a horror extraction game where performance = immersion and security = fair play.

*Last Updated: 2026-06-06 by Fog Sea Architect*
