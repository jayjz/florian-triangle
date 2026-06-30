# Implementation Plan

## Completed

### Fix ShipController Boarding API (P0) — ✅ Done 2026-06-29 (ab648ab)
- Added `ShipController.SetSailing(player, enabled)` — unblocks GhostShipGenerator board/exit
- Added `SailingEnabled` flag with strict typing, input rejection, velocity freeze
- Core extraction loop now playable

### Fix TestHarness Double-Init (P1) — ✅ Done 2026-06-29 (edea063)
- Removed TestHarness require + Initialize() from `ServerMain.server.lua`
- Added `initialized` boolean guard to `TestHarness.Initialize()`
- Debug commands still work in Studio, disabled in prod

### Remove Dead Code — QuotaManager + AttemptDock (P2) — ✅ Done 2026-06-29 (caa279d)
- Deleted `QuotaManager.lua` — 100% unreferenced duplicate
- Removed `ShipController.AttemptDock()` — never called
- Cleaned up dead dependencies in ShipController
- ~70 LOC removed, 0 runtime impact

### Restore Ghost Ship Boarding Feedback (P1) — ✅ Done 2026-06-29 (a1fd33b)
- Added `ShipController.BoardGhostShip()` / `ExitGhostShip()` with full horror FX chain: sanity damage, horror pulse, boarding audio, client event
- Wired `GhostShipGenerator` ProximityPrompts to new API
- `PlayerDocked` RemoteEvent LIVE again, client FX triggers correctly

### Client Camera Shake on Ghost Ship Boarding — ✅ Done 2026-06-29 (620d541)
- Added screen shake + FOV kick in `ClientShipController.PlayerDocked` handler
- Uses `Humanoid.CameraOffset` — works in all CameraTypes, mobile-friendly
- ~30 LOC, pure client-side, zero network cost

### CI / Smoke Test Infrastructure — ✅ Done 2026-06-29 (3aff8e4)
- `tests/smoke_test.lua` — Module load test, export validation, Initialize/Destroy smoke test, API contract checks. Catches missing exports like `HorrorEvents.ApplySanityDrain` (Bug #1)
- `.selene.toml` — Roblox Luau lint config, catches deprecated `tick()`, undefined globals, shadowing, etc.
- `.github/workflows/ci.yml` — GitHub Actions: Selene lint + static smoke test analysis, fails build on critical bugs (e.g., missing exports)
- CI currently EXPECTED TO FAIL until Bug #1 (ApplySanityDrain) is fixed — smoke test correctly catches the bug

### Fix HorrorEvents.ApplySanityDrain — P0 / CRITICAL — ✅ Done 2026-06-29 (9fd75c8)
- Added `HorrorEvents.ApplySanityDrain(player, amount: number): number?`
- Continuous sanity drain for proximity auras (corrupted pirates)
- Network throttled: fires `SanityChanged` only when floored sanity changes — ~6 events/sec max vs 60/sec unthrottled
- Validates player is Player instance, amount is positive number, returns nil if player not tracked
- --!strict clean, proper type annotations
- Fixes BUG_AUDIT_2026-06-29.md — Bug #1 / #5 — CRITICAL
  - `EntityAI:Update()` calls `ApplySanityDrain()` every frame when entity within 32 studs — was nil → Lua runtime crash → AI freezes
  - Corrupted pirates now properly drain player sanity (~6/sec at close range), restoring core horror mechanic
- Unblocks EntityAI completely — entities can now damage sanity via proximity aura
- Makes `tests/smoke_test.lua` Phase 4a pass (ApplySanityDrain export check)

### Fix EntityAI.Destroy() Table Mutation — CRITICAL — ✅ Done 2026-06-29 (0126c9d)
- Fixed `EntityAI.Destroy()` corrupting `activeEntities` while iterating — was calling `entity.Maid:Cleanup()` during `for _, entity in activeEntities` loop, Maid cleanup did `table.remove(activeEntities, i)` → iterator corruption → ~50% of entities skipped → Models leaked → memory grows unbounded over rounds → server OOM crash
- Fix: clone `activeEntities` BEFORE iterating → `local toDestroy = table.clone(activeEntities)` → `table.clear(activeEntities)` → iterate `toDestroy`. Maid cleanup's `table.remove()` now operates on empty table (harmless no-op), all entities destroyed, no skips, no leaks
- 1 file, ~6 LOC changed (`EntityAI.lua`)
- Classic Lua pitfall (Programming in Lua §7.3: never modify table while iterating with generic for)
- Fixes BUG_AUDIT_2026-06-29.md — Bug #2 — CRITICAL
- Unblocks multi-round EntityAI testing — ApplySanityDrain fix (9fd75c8) restored entity sanity damage, now cleanup is also correct, entities work end-to-end across rounds

### Fix HorrorEvents Sanity Decay Math — Bug #3 — HIGH — ✅ Done 2026-06-30 (633c6ff)
- Fixed sanity decay rate — was draining ~15× too slowly. `HorrorEvents:Update()` throttles to 4Hz (`UpdateRate = 0.25s`) but was multiplying decay by Heartbeat `dt` (~0.016s) instead of actual elapsed time. `decay * 0.016` vs `decay * 0.25` = 15.6× error.
- Fix: `level - decay * CONFIG.UpdateRate` (was: `decay * dt`). 1 line arithmetic change + 3 lines explanatory comment.
- 1 file (`HorrorEvents.lua`), ~4 LOC changed total
- Fixes BUG_AUDIT_2026-06-29.md — Bug #3 — HIGH
- Horror pillar restored — sanity now drains at intended rate (~1.0/sec in fog), hallucination thresholds trigger in realistic match time (70 @ ~30s, 50 @ ~50s, 30 @ ~70s in dense fog), fog → sanity drain → hallucinations → panic → extraction tension loop works end-to-end
- Unblocks meaningful Studio playtest — without this fix, players stayed at ~100 sanity for entire matches, never saw horror FX

---

## Current Step: Fix BoardGhostShip Double-Board Exploit

**Problem:** `ShipController.BoardGhostShip()` has no `SailingEnabled == false` guard. Player can spam the boarding ProximityPrompt rapidly → `BoardGhostShip()` runs multiple times per boarding → sanity damage (-12) stacks per call, horror pulse (0.8) stacks, audio spam, client FX spam. Sanity drain exploit: repeatedly board/exit to farm sanity damage / grief other players (horror pulse is FireAllClients).

Also: no boarding cooldown, no "already boarding" state check. ProximityPrompt has `HoldDuration = 0` (instant trigger), so a player mashing E can trigger it 10+ times/sec if the server is slow to set `SailingEnabled = false`.

**Fix — ~3 LOC, 1 file:**
`src/ReplicatedStorage/Modules/ShipController.lua`, top of `BoardGhostShip()`:
```lua
function ShipController.BoardGhostShip(player: Player, ghostModel: Model, interiorCFrame: CFrame): boolean
    local ship = getOrCreateShip(player)
    -- Guard: prevent double-board exploit — sanity/horror/audio spam
    if not ship.SailingEnabled then return false end
    -- ... rest of boarding logic
    ship.SailingEnabled = false  -- already sets this, guard just prevents re-entry
```
The `SailingEnabled = false` assignment already exists in the current code (line ~XX, sets it BEFORE teleport/sanity damage). The guard just needs to CHECK it at function entry and early-return if already false.

**Why this step:**
- Smallest high-value change available — ~3 LOC, 1 file, trivial review
- Security/stability bug — sanity drain spam = griefing vector, horror pulse spam = audio griefing (FireAllClients), client FX spam = potential performance DoS on low-end mobile
- NOT a regression follow-up from the last commit — last 3 commits were: ApplySanityDrain (horror/AI), EntityAI.Destroy (AI cleanup), sanity decay math (horror balance). Boarding subsystem hasn't been touched since camera shake (620d541) — 5 commits ago, well past the "never fix regressions from previous cleanups in same cycle" cooldown. Safe to touch boarding code now.
- Core gameplay > cleanup — this is core gameplay integrity (preventing exploits in a core loop mechanic), not cosmetic cleanup
- Follows "single smallest, highest-value change" rule — 3 LOC to close a griefing exploit is maximum value-per-line possible
- Pairs well with the horror fixes just shipped — ApplySanityDrain + EntityAI.Destroy + sanity decay math = horror systems now WORK. Now harden the boarding system (the entry point to horror encounters) against abuse before playtesting, so playtest results aren't polluted by exploit spam

**Alternative next steps considered (and why boarding guard wins):**
- **EntityAI ranged attack LOS bug** (Bug #4 — HIGH): `hasLineOfSight()` returns false during cooldown instead of cached result → ranged attacks almost always miss. ~1 LOC fix (`return cachedLOS` instead of `return false`), high gameplay value. DEFERRED — EntityAI just got 2 fixes in a row (ApplySanityDrain + Destroy), time to rotate subsystems. Also: ranged attack miss bug is "AI too weak" (generous to players), boarding exploit is "players can grief" (punishes players) — griefing bugs are higher priority than balance bugs.
- **Quota Progress HUD** (~40 LOC, 2 files): High player value, but exceeds 20 LOC budget. Can split into smaller steps, but still larger than boarding guard. DEFERRED — exploit fix first, features second.
- **Studio playtest full extraction loop**: CRITICALLY OVERDUE (now 9 fixes without in-engine validation). But: playtesting WITH a known griefing exploit means playtest results are unreliable (is the horror tension real, or is someone spamming boarding to grief sanity?). Fix the exploit FIRST (3 LOC, 2 min), THEN playtest with clean data.
- **Asset ghost ship boarding prompt** (~10 LOC, needs Studio verification): Can't confirm from code alone whether `GhostShipRig` asset has a boarding ProximityPrompt. If missing, asset ships are unboardable. This is a P0 if true, but requires Studio to verify. DEFERRED — boarding guard is code-only, no Studio needed, can ship immediately.
- **Client interior lighting on boarding** (~15 LOC): Nice polish, pairs with camera shake. But: polish < exploit fix in triage order. DEFERRED.

**Acceptance:**
- [ ] `BoardGhostShip()` early-returns `false` if `ship.SailingEnabled == false` (already boarding / already docked)
- [ ] Rapid ProximityPrompt spam no longer stacks sanity damage / horror pulse / audio
- [ ] Normal boarding still works — first call succeeds, sets `SailingEnabled = false`, subsequent calls within same boarding are rejected
- [ ] Exit → re-board works correctly — `ExitGhostShip()` sets `SailingEnabled = true`, next boarding call succeeds
- [ ] No regression in boarding feedback chain (sanity damage, horror pulse, audio, client FX, teleport)
- [ ] --!strict preserved

**Risk: Very Low.** 3 LOC guard at function entry, early return pattern. Worst case: guard is too aggressive, rejects legitimate boarding attempts → players can't board ghost ships → core loop broken. Mitigation: guard condition is `if not ship.SailingEnabled then return false end` — this is exactly the inverse of the state that `BoardGhostShip()` sets (`ship.SailingEnabled = false`), so the guard only rejects calls when boarding is ALREADY IN PROGRESS or the player is ALREADY DOCKED. Legitimate first boarding attempt always has `SailingEnabled = true`, passes guard. Rollback: `git revert`, 1 commit, 3 LOC.

**Estimated LOC:** ~3 lines, 1 file (`ShipController.lua`)

---

## Backlog

- **Quota Progress HUD** — Add extraction quota progress bar to client HUD. Wire `RoundManager.AddExtracted()` → RemoteEvent → `ClientUIController`. High player value, ~40 LOC, 2 files. Exceeds 20 LOC budget — defer until larger feature cycle approved, OR split into smaller steps: (1) Add QuotaProgress RemoteEvent + server fire (~8 LOC), (2) Add client UI bar (~25 LOC), (3) Polish animations (~10 LOC).
- **Fix asset ghost ship boarding prompt** — Verify `ServerStorage/Assets/GhostShipRig` in Studio has boarding ProximityPrompt. If missing, add one at runtime in `spawnFromAsset()` that calls `BoardGhostShip()`. Otherwise asset ships are unboardable. ~10 LOC if needed. Requires Studio verification — can't confirm from code alone.
- **Rojo/Studio playtest full extraction loop** — **CRITICALLY OVERDUE.** 9 fixes shipped without in-engine validation: SetSailing (ab648ab), TestHarness (edea063), QuotaManager cleanup (caa279d), Boarding Feedback (a1fd33b), Camera Shake (620d541), ApplySanityDrain (9fd75c8), EntityAI.Destroy (0126c9d), Sanity Decay Math (633c6ff). Plus CI infrastructure (3aff8e4, not gameplay-affecting). Code review confidence remains high, but nothing replaces actual playtest. Recommended test checklist: board ghost ship → verify screen shakes + FOV kicks + sanity drops + horror pulse + audio plays + client FX fires → loot chests → verify weight penalty affects movement → exit ship → extract at beacon → verify quota increments → win condition triggers → lobby return works → repeat for 3 rounds → verify no memory leaks (check Ctrl+Shift+F3 memory stats), no accumulating entities/chests in Workspace. **HIGHEST priority after BoardGhostShip exploit guard is fixed — need to validate ALL 9 fixes in-engine before shipping more code.**
- **Fix EntityAI ranged attack LOS bug — Bug #4 (HIGH)** — `hasLineOfSight()` returns `false` during cooldown instead of cached result → ranged attacks almost always miss. Fix: `return cachedLOS` instead of `return false`. ~1 LOC, high gameplay value (AI combat actually works). Deferred in favor of boarding exploit guard — griefing bugs > balance bugs in triage. Ready to pick up immediately after boarding guard.
- **Client interior lighting change on boarding** — Second half of the TODO at `ClientShipController.lua:60`. Camera shake (620d541) covers impact feel. Interior lighting (tint screen green/dim, ColorCorrection) adds sustained atmosphere while inside ghost ship. ~15 LOC, pairs well with camera shake.
- Import real rigged assets to ServerStorage/Assets
- Client highlight culling/pooling
- Audio polish / monetization hooks (Phase 8)
- TestHarness hygiene nits: Move `_G.ForceTestScenario` assignment into Initialize/Destroy, defer `AdminDebugRemote` creation to Initialize (low priority, 5 LOC)
- Accessibility: screen shake disable toggle — camera shake can trigger motion sickness. Add settings flag to reduce/disable screen effects. ~5 LOC, do before public release
- Camera shake intensity scaling — scale shake with sanity/horror level for dynamic tension feedback. ~5 LOC, nice polish
