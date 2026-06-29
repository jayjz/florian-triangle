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

---

## Current Step: Fix HorrorEvents Sanity Decay Math — Bug #3 (HIGH)

**Problem:** Sanity drains ~15× too slowly. `HorrorEvents:Update()` runs at ~4Hz (throttled: `if os.clock() - last < CONFIG.UpdateRate then return end`, where `CONFIG.UpdateRate = 0.25`), but multiplies decay by Heartbeat `dt` (~0.016s) instead of actual elapsed time (~0.25s).

`decay * 0.016` vs `decay * 0.25` = 15.6× slower than intended. Players will never hit hallucination thresholds (70/50/30/10) in a normal 8-minute match. Horror tension loop gutted.

**Fix — 1 line, 1 file:**
`src/ReplicatedStorage/Modules/HorrorEvents.lua`, in `HorrorEvents.Update()`:
```lua
-- before (buggy):
local newSanity = level - decay * dt

-- after (correct):
local newSanity = level - decay * CONFIG.UpdateRate
```
Or use measured `elapsed = os.clock() - lastUpdateTime` for accuracy.

**Why this step:**
- Sanity decay = the core horror mechanic. Fog → sanity drain → hallucinations → panic → extraction tension. If sanity never drops, the entire horror pillar collapses
- 1 LOC, 1 file, trivial review — absolute smallest high-value change available
- EntityAI critical bugs are now fixed (ApplySanityDrain 9fd75c8 + Destroy 0126c9d) — entities work end-to-end. Now fix the passive sanity drain so the horror atmosphere actually works during playtesting
- Unblocks meaningful Studio playtest — without this fix, players stay at 100 sanity for entire matches, never see horror FX

**Acceptance:**
- [ ] Sanity drains at intended rate (~1.0/sec in fog, matches DESIGN.md)
- [ ] Hallucination thresholds trigger in realistic match time (70 @ ~30s, 50 @ ~50s, 30 @ ~70s in dense fog)
- [ ] No regression in other HorrorEvents functions (ApplySanityDrain, TriggerSanityDamage, TriggerHorrorPulse)
- [ ] --!strict preserved

**Risk: Very Low.** 1 line arithmetic fix. Worst case: sanity drains slightly faster/slower than target — tunable via CONFIG.

**Estimated LOC:** 1 line, 1 file

---

## Backlog

- **Fix boarding double-board exploit** — Add `SailingEnabled == false` guard at top of `BoardGhostShip()` to prevent sanity-drain spam via rapid ProximityPrompt triggering. ~3 LOC, high value for stability. Deferred per planning rule: "never fix regressions from previous cleanups in same cycle" — boarding subsystem had 2 consecutive commits (a1fd33b + 620d541), switched to EntityAI subsystem for variety. Ready to pick up after EntityAI.Destroy() fix.
- **Quota Progress HUD** — Add extraction quota progress bar to client HUD. Wire `RoundManager.AddExtracted()` → RemoteEvent → `ClientUIController`. High player value, ~40 LOC, 2 files. Exceeds 20 LOC budget — defer until larger feature cycle approved, OR split into smaller steps: (1) Add QuotaProgress RemoteEvent + server fire (~8 LOC), (2) Add client UI bar (~25 LOC), (3) Polish animations (~10 LOC).
- **Fix asset ghost ship boarding prompt** — Verify `ServerStorage/Assets/GhostShipRig` in Studio has boarding ProximityPrompt. If missing, add one at runtime in `spawnFromAsset()` that calls `BoardGhostShip()`. Otherwise asset ships are unboardable. ~10 LOC if needed. Requires Studio verification — can't confirm from code alone.
- **Rojo/Studio playtest full extraction loop** — **CRITICALLY OVERDUE.** 6 fixes shipped without in-engine validation: SetSailing (ab648ab), TestHarness (edea063), QuotaManager cleanup (caa279d), Boarding Feedback (a1fd33b), Camera Shake (620d541), ApplySanityDrain (9fd75c8). Plus CI infrastructure (3aff8e4, not gameplay-affecting). Code review confidence remains high, but nothing replaces actual playtest. Recommended test checklist: board ghost ship → verify screen shakes + FOV kicks + sanity drops + horror pulse + audio plays + client FX fires → loot chests → verify weight penalty affects movement → exit ship → extract at beacon → verify quota increments → win condition triggers → lobby return works → repeat for 3 rounds → verify no memory leaks (check Ctrl+Shift+F3 memory stats), no accumulating entities/chests in Workspace.
- **Client interior lighting change on boarding** — Second half of the TODO at `ClientShipController.lua:60`. Camera shake (620d541) covers impact feel. Interior lighting (tint screen green/dim, ColorCorrection) adds sustained atmosphere while inside ghost ship. ~15 LOC, pairs well with camera shake.
- Import real rigged assets to ServerStorage/Assets
- Client highlight culling/pooling
- Audio polish / monetization hooks (Phase 8)
- TestHarness hygiene nits: Move `_G.ForceTestScenario` assignment into Initialize/Destroy, defer `AdminDebugRemote` creation to Initialize (low priority, 5 LOC)
- Accessibility: screen shake disable toggle — camera shake can trigger motion sickness. Add settings flag to reduce/disable screen effects. ~5 LOC, do before public release
- Camera shake intensity scaling — scale shake with sanity/horror level for dynamic tension feedback. ~5 LOC, nice polish
