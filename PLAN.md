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

### Fix BoardGhostShip Double-Board Exploit + Debounce — ✅ Done 2026-06-30 (eaccc03)
- Added double-board exploit guard + debounce to `BoardGhostShip()` — ProximityPrompt with HoldDuration = 0 = instant spam, player mashing E → sanity damage / horror pulse / audio / client FX all stacked per call → griefing vector + mobile DoS
- Two-layer guard: (1) SailingEnabled check — blocks re-entry while already docked, (2) Debounce check — `os.clock() - LastBoardTime < 1.5s` → reject, blocks rapid spam during state transitions
- Added `ShipState.LastBoardTime: number` field, `CONFIG.BoardingDebounce = 1.5` (tunable)
- 1 file (`ShipController.lua`), ~15 LOC changed
- Normal boarding unaffected, spam boarding rejected, exit → re-board works correctly
- Fixes BUG_AUDIT_2026-06-29.md — Boarding double-board exploit
- Unblocks clean playtesting — boarding feedback chain now hardened against abuse

---

## Current Step: ROJO/STUDIO PLAYTEST — FULL EXTRACTION LOOP — CRITICALLY OVERDUE

**Status: 10 fixes shipped without in-engine validation. STOP SHIPPING CODE. VALIDATE WHAT WE HAVE.**

**Fixes awaiting playtest:**
1. SetSailing API (ab648ab) — unblocks ghost ship boarding
2. TestHarness double-init (edea063) — debug stability
3. QuotaManager dead code cleanup (caa279d) — ~70 LOC removed
4. Boarding Feedback restore (a1fd33b) — sanity damage, horror pulse, audio, client FX
5. Camera Shake (620d541) — screen shake + FOV kick on boarding
6. ApplySanityDrain (9fd75c8) — entities damage sanity via proximity aura, unblocks EntityAI
7. EntityAI.Destroy table mutation (0126c9d) — fixes server OOM / memory leak over multiple rounds
8. Sanity Decay Math (633c6ff) — was 15× too slow, horror pillar restored
9. BoardGhostShip exploit guard (eaccc03) — debounce + SailingEnabled check, prevents griefing
10. **[UNCOMMITTED — IN WORKING TREE]** Fix ShipController / Humanoid tug-of-war — physics bug: ShipController setting AssemblyLinearVelocity every frame fighting Humanoid movement controller (WalkSpeed 16 vs 58 studs/sec) → player yanked/pulled in weird directions, frozen inside ghost ships. Fix: proper movement handoff — ShipController ONLY sets AssemblyLinearVelocity when SailingEnabled = true, disables Humanoid.WalkSpeed/AutoRotate during sailing, restores Humanoid movement when on foot (lobby / ghost ship interiors). Default SailingEnabled = false (Humanoid movement), opt-in to ShipController at round start. Fixes: ShipController.lua, RoundManager.lua, LobbyManager.lua — **READY TO COMMIT, NEEDS PLAYTEST CONFIRMATION**

**Playtest Checklist:**
- [ ] Spawn in Foosha Village lobby → verify normal Humanoid movement (WalkSpeed 16, no yanking/pulling)
- [ ] Ready up → teleport to Windmill Village → verify ShipController sailing movement activates (58 studs/sec, weight penalties apply, NO Humanoid tug-of-war)
- [ ] Sail to ghost ship → board via ProximityPrompt → verify: screen shakes + FOV kicks + sanity drops (-12) + horror pulse fires + boarding audio plays + client FX fires + boarding debounce blocks spam (try mashing E rapidly → should only board ONCE)
- [ ] Inside ghost ship interior → verify: Humanoid movement WORKS (WalkSpeed 16, can walk around freely, NO freezing, can reach loot chests)
- [ ] Loot chests → verify: weight penalty affects movement speed, inventory updates, sanity drain from fog still ticking (~1/sec)
- [ ] Exit ghost ship → verify: ShipController sailing movement RESTORED (58 studs/sec), Humanoid movement disabled, no tug-of-war
- [ ] Sail to extraction beacon → verify: quota increments, win condition triggers
- [ ] Lobby return → verify: Humanoid movement restored (WalkSpeed 16), ShipController hands off cleanly, no residual velocity drift
- [ ] Repeat for 3 full rounds → verify: NO memory leaks (Ctrl+Shift+F3 memory stats flat), NO accumulating entities/chests in Workspace, EntityAI cleanup works (no ghost pirates), sanity decay works end-to-end (should hit 70 sanity / first hallucination within ~30s in fog)
- [ ] Entity combat → verify: corrupted pirates drain sanity on proximity (~6/sec), AI pathfinding works, ranged attacks fire (may miss frequently — Bug #4, known, not blocking playtest)
- [ ] Boarding exploit guard → verify: rapid ProximityPrompt spam → only ONE boarding succeeds per 1.5s, no sanity/horror/audio spam

**Why playtest NOW (not after more fixes):**
- 10 fixes, 0 in-engine validations — code review confidence is high but NOT a substitute for actual playtest
- Horror systems (ApplySanityDrain + EntityAI.Destroy + sanity decay) are THE core gameplay loop — need to FEEL them in-engine before shipping more code
- Movement system just got a MAJOR refactor (ShipController / Humanoid handoff) — physics bugs are exactly the kind of thing that code review misses but playtesting catches immediately (see: the bug Georgie just reported — "player gets yanked/pulled when walking normally" — caught by playtesting in ~30 seconds, would NEVER be caught by code review alone, because the code "looks correct" — AssemblyLinearVelocity assignment is intentional, the bug is the INTERACTION with Humanoid movement controller, a runtime emergent behavior)
- Boarding exploit guard needs real ProximityPrompt spam testing — does 1.5s debounce feel good? Too strict? Too lenient? Only playtesting can answer
- Sanity decay rate (now 15× faster) — is it TOO aggressive? Do players go insane in 12 seconds and quit in frustration? Or is it PERFECT horror tension? Playtest or guess — guessing is how you ship unfun games

**Next code fix (AFTER successful playtest confirms all 10 fixes work):**
- **Fix EntityAI ranged attack LOS bug — Bug #4 (HIGH)** — `hasLineOfSight()` returns `false` during cooldown instead of cached result → ranged attacks almost always miss. ~1 LOC fix (`return cachedLOS` instead of `return false`), high gameplay value (AI combat actually works). Smallest high-value change, ready to go.
- Alternative: **Quota Progress HUD** — if playtesting shows players don't know how close they are to extraction quota, add progress bar. ~40 LOC, exceeds budget, split into smaller steps if needed.
- Alternative: **Client interior lighting on boarding** — if playtesting shows ghost ship interiors feel flat despite camera shake, add ColorCorrection dim/green tint for sustained atmosphere. ~15 LOC, pairs with camera shake.

**Risk of NOT playtesting:** We ship 3 more fixes (ranged LOS, Quota HUD, interior lighting), now 13 fixes unvalidated, a fundamental movement bug like the ShipController/Humanoid tug-of-war slips through, players quit after 30 seconds because basic movement feels broken, all the horror tension / entity AI / sanity systems work we did is WASTED because nobody plays long enough to experience it. **Playtest first. Always.**

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
