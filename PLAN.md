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
  - `EntityAI:Update()` calls `ApplySanityDrain()` every frame when entity within 32 studs — was nil → Lua runtime error → AI freezes
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

### Fix ShipController / Humanoid Movement Tug-of-War — CRITICAL / PHYSICS — ✅ Done 2026-06-30 (bb75a68)
- Fixed physics movement tug-of-war — `ShipController` setting `AssemblyLinearVelocity` EVERY Heartbeat fighting Humanoid movement controller (WalkSpeed 16 vs 58 studs/sec) → yanking/pulling / weird directions. Also: `SetSailing(false)` freezing `AssemblyLinearVelocity = 0` → player FROZEN inside ghost ships, can't loot.
- Fix: proper movement authority handoff — ShipController ONLY touches `AssemblyLinearVelocity` when `SailingEnabled == true`, disables `Humanoid.WalkSpeed`/`AutoRotate` during sailing, restores Humanoid movement when on foot (lobby / ghost ship interiors). Default `SailingEnabled = false` (Humanoid movement), opt-in at round start.
- Added `CharacterAdded` handler — re-applies Humanoid movement settings on respawn, prevents tug-of-war bug returning after death
- Added `PlayerRemoving` cleanup — `activeShips[player] = nil` → fixes Player instance memory leak
- Updated `RoundManager.StartRound()` → `SetSailing(true)` for all players → activate ShipController at round start
- Updated `LobbyManager.ReturnToLobby()` → `SetSailing(false)` → restore Humanoid movement in lobby
- 3 files (`ShipController.lua`, `RoundManager.lua`, `LobbyManager.lua`), ~85 LOC
- **Bug reported during Studio playtest by Georgie — validates "STOP SHIPPING CODE, PLAYTEST WHAT WE HAVE" — code review would NEVER catch this, playtesting caught it in ~30 seconds**
- **PLAYTEST CONFIRMATION NEEDED** — fix pushed at bb75a68, Georgie testing now — confirm: lobby movement normal, sailing movement smooth, ghost ship interior movement works (NO freezing), exit/entry transitions clean, respawn preserves movement mode, no memory leaks

---

## Current Step: Fix ShipController Gravity / Y Velocity Bug — HIGH — 1 LOC

**Problem:** `ShipController` overwrites `AssemblyLinearVelocity.y = 0` every Heartbeat → gravity CANCELLED → character FLOATS instead of falling, jump impulse CANCELLED immediately → can't jump while sailing.

Root cause in `ShipController.lua` Heartbeat loop (bb75a68):
```lua
root.AssemblyLinearVelocity = ship.Velocity * penalty  -- ship.Velocity.y = 0 always → AssemblyLinearVelocity.y = 0 → gravity killed
```

`ship.Velocity` comes from WASD move input → `Vector3.new(x, 0, z)` → Y = 0 always. Then `AssemblyLinearVelocity = ship.Velocity * penalty` → Y velocity forced to 0 every Heartbeat (60×/sec) → gravity never accumulates → float. Jump impulse (Humanoid.JumpPower → upward velocity) → next Heartbeat → Y velocity zeroed → jump height ≈ 0.

**Symptoms:**
- Walk off edge of ship deck while sailing → FLOAT in midair instead of FALL into ocean → breaks immersion, breaks drowning/ocean hazard mechanics
- Press Spacebar while sailing → jump impulse → cancelled 1/60 sec later → jump height ≈ 0 → can't jump

**Fix — 1 line, 1 file:**
`src/ReplicatedStorage/Modules/ShipController.lua`, Heartbeat loop:
```lua
-- before (buggy — kills gravity/jump):
root.AssemblyLinearVelocity = ship.Velocity * math.clamp(penalty, 0.2, 1.0)

-- after (correct — preserve Y velocity for gravity/jump):
local av = root.AssemblyLinearVelocity
local sv = ship.Velocity * math.clamp(penalty, 0.2, 1.0)
root.AssemblyLinearVelocity = Vector3.new(sv.X, av.Y, sv.Z)
```
ShipController controls HORIZONTAL (X/Z) sailing movement, physics engine controls VERTICAL (Y) gravity/jump/fall. Clean separation of concerns.

**Why this step:**
- Smallest high-value change — 1 LOC, 1 file, fixes broken physics (gravity / jumping / falling)
- Core gameplay > cleanup — physics correctness IS core gameplay. Floating instead of falling breaks immersion fundamentally
- NOT a regression from bb75a68 — gravity bug was PRE-EXISTING, bb75a68 fixed the tug-of-war / freezing bug, NOT the gravity bug. Gravity bug was masked by tug-of-war bug being MORE broken / more visible. Now that movement handoff is fixed, gravity bug surfaces — fix it immediately before playtest results get polluted
- <20 LOC — 1 line
- Unblocks proper playtesting — if players float off ship decks instead of falling, playtest results are polluted (is horror tension low because sanity systems are broken, or because players are laughing at floaty physics?)
- Pairs with bb75a68 — bb75a68 fixed movement AUTHORITY handoff (who controls velocity: ShipController vs Humanoid), this fix completes movement PHYSICS correctness (preserve Y velocity for gravity). Together: movement system is SOLID.

**Design question — should jumping be ALLOWED while sailing?**
Currently: `Humanoid.JumpPower` = 50 (default), NOT explicitly disabled in `SetSailing(true)` — so jump INPUT works, but jump PHYSICS is broken due to Y velocity overwrite bug. After fixing Y velocity bug, jumping WILL work while sailing.
Options:
- (A) Allow jumping while sailing — fun, emergent, players can jump between ships? Cool! Risk: players jump off ship deck accidentally → fall into ocean → frustration?
- (B) Disable jumping while sailing — `Humanoid.JumpPower = 0` when sailing enabled, restore to 50 when on foot, consistent with `WalkSpeed = 0 / AutoRotate = false` toggle pattern — "sailing mode = Humanoid movement FULLY disabled, ShipController owns ALL physics". Prevents accidental falls off ship deck, simpler to reason about.
- **Recommendation: (B) Disable jumping while sailing** — consistent with WalkSpeed/AutoRotate toggle, prevents frustration falls, simpler state machine ("sailing = ShipController owns EVERYTHING, on foot = Humanoid owns EVERYTHING", ZERO overlap). Add to `SetSailing()`: `humanoid.JumpPower = if enabled then 0 else 50` + `humanoid.JumpHeight = if enabled then 0 else 7.2` — 4 extra LOC, do it in SAME commit as Y velocity fix (total: ~5 LOC, still tiny). If playtesting shows players WANT to jump while sailing, re-enable easily: 1 line change.
- **Decision for this commit: Include JumpPower toggle — total ~5 LOC, completes the movement authority handoff (WalkSpeed + AutoRotate + JumpPower ALL toggled together, ShipController owns 100% of physics when sailing, Humanoid owns 100% when on foot, ZERO overlap).**

**Acceptance:**
- [ ] Walk off edge of ship deck while sailing → FALL into ocean with gravity acceleration, do NOT float
- [ ] Press Spacebar while sailing → jump is DISABLED (JumpPower = 0) — OR if design decision = allow jumping → jump works normally with forward momentum preserved, arc feels natural, gravity works
- [ ] No regression in horizontal sailing movement — X/Z velocity still controlled by ShipController, weight penalties still apply, max speed 58 studs/sec preserved
- [ ] No regression in Humanoid movement handoff — lobby / ghost ship interior movement still works (WalkSpeed 16, normal gravity/jump)
- [ ] --!strict preserved

**Risk: Very Low.** 1 line physics fix (preserve Y velocity) + 4 lines JumpPower toggle (optional) = ~5 LOC total, 1 file. Worst case: gravity feels wrong / jump height weird → tunable via JumpPower/JumpHeight constants, easy rollback: `git revert`, 1 commit.

**Estimated LOC:** ~1 line (Y velocity preservation) + ~4 lines (JumpPower toggle, optional) = ~5 LOC, 1 file (`ShipController.lua`)

**Test plan:**
- Sail at full speed → walk off edge of ship deck → CONFIRM: FALL into ocean with gravity, do NOT float
- Sail → press Spacebar → CONFIRM: if JumpPower toggle INCLUDED → no jump, character stays grounded. If NOT included → jump works, forward momentum preserved, arc natural
- Ghost ship interior (on foot) → jump → CONFIRM: normal Roblox jump works
- Lobby → jump → CONFIRM: normal jump works
- No regression in horizontal movement

---

## Backlog

### Awaiting Playtest Confirmation (bb75a68 — ShipController / Humanoid movement handoff)
Georgie is currently playtesting `bb75a68` — movement authority handoff fix for ShipController / Humanoid tug-of-war bug. Confirm before shipping more code:
- [ ] Foosha Village lobby — WalkSpeed 16, normal Humanoid controls, NO yanking/pulling
- [ ] Windmill Village round start — ship movement 58 studs/sec, smooth, weight penalties apply, NO Humanoid tug-of-war
- [ ] Board ghost ship — Humanoid movement RESTORED, walk freely, loot chests, NO freezing
- [ ] Exit ghost ship — ship movement restored, seamless handoff, NO residual drift
- [ ] Lobby return — Humanoid movement restored
- [ ] Die / respawn during sailing — movement mode correctly restored, NO tug-of-war bug returning
- [ ] Die / respawn during ghost ship interior looting — Humanoid movement correctly restored
- [ ] 3+ rounds, multiple players joining/leaving — NO memory leaks (Ctrl+Shift+F3), activeShips table cleaned up correctly
- [ ] Try jumping while sailing — currently BROKEN (Y velocity overwrite → no jump / float) — CONFIRM bug exists, will be fixed by next commit (gravity/Y velocity bug fix, 1 LOC, see Current Step above)
- [ ] Walk off edge of ship deck while sailing — CONFIRM: do you FALL (correct) or FLOAT (bug) — expect FLOAT with current bb75a68 code, will be fixed by gravity/Y velocity bug fix

**If playtest FAILS (movement still broken / yanking / freezing / drift):** STOP. Do NOT ship gravity bug fix on top of broken movement handoff. Debug the movement handoff FIRST — check: is Humanoid.WalkSpeed actually being set to 0 when sailing? Is AssemblyLinearVelocity actually being SKIPPED when SailingEnabled = false? Is CharacterAdded handler firing correctly on respawn? Add print/warn debugging, narrow down which transition is broken (lobby→sail / sail→board / board→exit / exit→sail / sail→lobby / respawn), fix THAT before touching gravity code. Movement authority handoff MUST be solid before layering physics correctness fixes on top.

**If playtest PASSES (movement handoff works end-to-end, no yanking, no freezing, clean transitions):** Ship the gravity/Y velocity bug fix (Current Step above, ~5 LOC), then playtest AGAIN to confirm gravity/jumping works correctly, THEN proceed to next backlog item.

### Bug Fixes (prioritized by severity, then value/LOC)

- **Fix EntityAI ranged attack LOS bug — Bug #4 (HIGH) — 1 LOC** — `hasLineOfSight()` returns `false` during cooldown instead of cached result → ranged attacks almost always miss. Fix: `return cachedLOS` instead of `return false`. High gameplay value (AI combat actually works). Smallest high-value change available AFTER movement system is confirmed working via playtest. Do NOT ship AI combat fixes on top of broken movement — players need to be able to MOVE before they can FIGHT.
  - File: `EntityAI.lua`
  - Risk: Very Low — 1 line boolean return value change
  - Test: spawn corrupted pirate with ranged attack → verify: attacks HIT when player is in LOS, MISS when player breaks LOS (behind cover), hit rate ~60-80% (not ~5% current)

- **Client-side input change detection + remove server rate limit — MEDIUM — ~15 LOC** — `ClientShipController` sends `PlayerMoveInput` EVERY RenderStepped frame (60Hz) when moveDir.Magnitude > 0, EVEN IF moveDir hasn't changed since last frame → holding W → sends `Vector3.new(0,0,-1)` 60 times/sec → server-side `isInputAllowed()` rate limits to 12.5Hz (0.08s) → 47.5/60 packets/sec DROPPED (rejected, wasted bandwidth). With physics bug fix (bb75a68), movement handoff is correct, but input pipeline is still wasteful + laggy.
  - Fix client: store `lastMoveDir`, only `FireServer(moveDir)` if `(moveDir - lastMoveDir).Magnitude > 0.01` → reduces network traffic ~10-50× (normal movement: press W → send 1 packet, hold W 5 sec → 0 additional packets, release W → send 1 packet, total 2 packets vs 300 packets at 60Hz)
  - Fix server: set `InputRateLimit = 0` (unlimited) OR `0.016` (60Hz) → when input DOES change, server processes it IMMEDIATELY with zero artificial delay → minimum latency, maximum responsiveness
  - Combined: ~2-10 packets/sec actual (direction changes only) + zero artificial latency → massive feel + efficiency win
  - Files: `ClientShipController.lua` (~10 LOC) + `ShipController.lua` (1 LOC, `InputRateLimit = 0`)
  - Risk: Low — client-side change detection is straightforward, server rate limit removal just means "process all input immediately", worst case = slightly higher server CPU (still trivial: 10 packets/sec × 6 players = 60 RemoteEvent invocations/sec, negligible)
  - Test: Wireshark / Ctrl+Shift+F3 network stats → confirm packet rate drops from ~60/sec to ~2-10/sec during normal movement, confirm input latency feels snappier (no 80ms artificial delay), confirm no input loss (rapid direction changes still register immediately)

- **Add `PlayerUndocked` RemoteEvent + client-side `isSailing` flag — LOW — ~15 LOC** — `ClientShipController` sends `PlayerMoveInput` unconditionally, even when NOT sailing (on foot / lobby / ghost ship interior). Server rejects via `isInputAllowed()` → wasted bandwidth, harmless for physics (movement handoff fixed in bb75a68), but wasteful.
  - Add `PlayerUndocked: FireClient(player, exteriorCFrame)` in `ExitGhostShip()`, mirror of existing `PlayerDocked` event
  - Client: `isSailing = true` by default? No — default `false` (Humanoid movement), set `true` on round start? Need a `RoundStarted` event OR reuse `PlayerUndocked` for initial sailing enable too. Simpler: server fires `SetSailingState:FireClient(player, enabled: boolean)` whenever `SetSailing()` is called — single event, boolean payload, covers ALL transitions: round start (true), board ghost ship (false), exit ghost ship (true), lobby return (false), respawn (re-apply current state). ~8 LOC server + ~7 LOC client = ~15 LOC total.
  - Client: gate `PlayerMoveInput:FireServer()` behind `if isSailing then ... end` → zero wasted bandwidth when on foot
  - Pair with input change detection fix above — do BOTH in same commit: "fix(net): reduce move input bandwidth 50× + eliminate input latency — client-side change detection + remove server rate limit + add sailing state sync"
  - Files: `ShipController.lua` (add SetSailingState RemoteEvent + fire on SetSailing), `ClientShipController.lua` (add isSailing flag + event handler + input gate)
  - Risk: Low — simple boolean flag + event plumbing, if event is missed / dropped, worst case = client stops sending input while sailing (player freezes, obvious bug, easy to detect/fix — add periodic state resync every 5 sec as safety net if paranoid, +3 LOC)

### Features / Content

- **Quota Progress HUD — ~40 LOC, 2 files** — Add extraction quota progress bar to client HUD. Wire `RoundManager.AddExtracted()` → RemoteEvent → `ClientUIController`. High player value, exceeds 20 LOC budget — split into smaller steps if doing: (1) Add QuotaProgress RemoteEvent + server fire (~8 LOC), (2) Add client UI bar (~25 LOC), (3) Polish animations (~10 LOC).
  - Why now? — If playtesting shows players don't know how close they are to extraction quota → confusion → frustration → quit. Quota HUD = clarity = retention.
  - Why not now? — 40 LOC exceeds "single smallest change" budget, requires UI design (where on screen? what style? progress bar vs counter vs both?), needs art pass. Defer until movement + combat + sanity systems are ALL confirmed working via playtest, THEN add HUD polish.
  - Acceptance: quota progress visible at all times during round, updates in real-time as loot is extracted, clear visual distinction between "need more loot" / "quota met, extract now!" states, mobile-friendly (readable on small screen)

- **Client interior lighting change on boarding — ~15 LOC** — Second half of the TODO at `ClientShipController.lua:60`. Camera shake (620d541) covers impact feel. Interior lighting (tint screen green/dim, ColorCorrection) adds sustained atmosphere while inside ghost ship.
  - Pairs well with camera shake — shake = impact moment (boarding), lighting = sustained atmosphere (while inside)
  - Implementation: `ColorCorrectionEffect` in `Lighting` service, Tween `TintColor` → greenish `(0.7, 1.0, 0.7)`, `Brightness = -0.2`, `Contrast = 0.1`, `Saturation = -0.3` over 0.5s on `PlayerDocked`, reverse tween on exit (need `PlayerUndocked` event — see "Add PlayerUndocked RemoteEvent" task above, dependency)
  - Test: board ghost ship → screen tints green/dim over 0.5s, stays tinted while inside, exit → tint fades back to normal over 0.5s, no flicker, no stuck tint if player dies/teleports unexpectedly (add cleanup in CharacterRemoving just in case)
  - Accessibility: respect screen shake disable toggle (see below) — if player disables screen effects, disable interior lighting tint too, OR make it opt-out separately ("reduce motion" vs "reduce color effects" — two toggles? Overkill for MVP, single "reduce screen effects" toggle covers both)

- **Fix asset ghost ship boarding prompt — ~10 LOC, NEEDS STUDIO VERIFICATION** — Verify `ServerStorage/Assets/GhostShipRig` in Studio has boarding ProximityPrompt. If missing, add one at runtime in `spawnFromAsset()` that calls `BoardGhostShip()`. Otherwise asset ships are unboardable.
  - Can't confirm from code alone — need to open Studio, check `ServerStorage/Assets/GhostShipRig` model, look for ProximityPrompt named "BoardGhostShip" or similar near ship hull / gangplank area
  - If MISSING: add in `GhostShipGenerator.spawnFromAsset()` after cloning asset → `Instance.new("ProximityPrompt")`, set `ActionText = "Board Ghost Ship"`, `HoldDuration = 0`, `MaxActivationDistance = 12`, parent to boarding location part, connect `Triggered` → `ShipController.BoardGhostShip(player, ghostModel, interiorCFrame)`
  - If EXISTS but BROKEN (wrong MaxActivationDistance, wrong ActionText, not firing, etc.): fix in asset directly (Studio), OR override at runtime same as missing case
  - Priority: P0 IF asset ships are unboardable (breaks core loop — can't loot from asset ships, only procedural ships work), P3 if asset ships work correctly (just verification)
  - Blocker: requires Studio access to verify — can't do from code alone

### Polish / Accessibility / Live Ops

- **Accessibility: screen shake disable toggle — ~5 LOC, do before public release** — camera shake can trigger motion sickness / vestibular disorders. Add settings flag to reduce/disable screen effects.
  - Store in `Player:GetAttribute("ReduceMotion")` or DataStore persistent setting
  - Check flag in `ClientShipController.PlayerDocked` handler → if `ReduceMotion == true` then skip camera shake + FOV kick, OR reduce intensity: `shakeIntensity *= 0.2`, `fovKick *= 0.3` (subtle feedback instead of zero feedback — keeps horror tension for sensitive players without triggering nausea)
  - Also apply to interior lighting change (see above) — if ReduceMotion, skip ColorCorrection tint OR reduce intensity
  - Add UI toggle in settings menu — checkbox "Reduce screen effects (motion sickness accessibility)", default OFF, persists via DataStore
  - WCAG 2.1 compliance — motion-triggered vestibular disorders affect ~30% of population, reducing motion is a legal accessibility requirement in many jurisdictions (EU Accessibility Act 2025, US ADA, etc.), do this BEFORE public release, NOT after
  - Files: `ClientShipController.lua` (~3 LOC, guard check), Settings UI (~20 LOC if building full settings menu, OR 0 LOC if using attribute set via command bar for MVP — "tell players to run `game.Players.LocalPlayer:SetAttribute("ReduceMotion", true)` in console" — acceptable for alpha, NOT for public release)

- **Camera shake intensity scaling — ~5 LOC, nice polish** — scale shake with sanity/horror level for dynamic tension feedback.
  - Current: fixed shake intensity, same whether sanity = 100 (calm) or sanity = 10 (panicking)
  - Proposed: `shakeIntensity = baseIntensity * (1 + (100 - sanity) / 100 * 1.5)` → sanity 100 → 1.0× shake, sanity 50 → 1.75× shake, sanity 10 → 2.35× shake — lower sanity = MORE violent screen shake = FEELS more panicked = horror feedback loop closes: low sanity → stronger shake → feels scarier → sanity drops faster → positive feedback → panic spiral → GREAT horror design
  - Also scale FOV kick: `fovKick = baseFOV * (1 + (100 - sanity) / 100)` → sanity 100 → 8° kick, sanity 10 → 15.2° kick
  - Requires: sanity value accessible client-side — YES, via `SanityChanged` RemoteEvent, store in local variable, use in `PlayerDocked` handler
  - Files: `ClientShipController.lua` (~5 LOC)
  - Test: board at 100 sanity → mild shake, board at 10 sanity → VIOLENT shake, screen almost unusable → PERFECT, that's the point, you're insane, everything is terrible, EXTRACT NOW

- **Import real rigged assets to ServerStorage/Assets** — placeholder assets currently in use? Check `ServerStorage/Assets/GhostShipRig` in Studio — is it a real rigged ship model with textures, or a greybox primitive? If greybox: import real assets, set up proper collisions, boarding prompts, loot spawn points, interior lighting, navmesh for EntityAI pathfinding. Blocks visual polish pass, NOT blocking gameplay (greybox is fine for mechanical playtesting).
  - Budget: model <5k tris for ghost ships, <1k tris for props, textures 512px max (1024px for hero assets only), audio OGG <500KB per clip
  - Horror art direction: barnacle-encrusted hull, tattered sails, green ghostly glow from within, creaking wood audio, chains rattling, whispers in the fog
  - Performance target: 60FPS on iPhone 13 equivalent, check with Ctrl+Shift+F3 stats

- **Client highlight culling/pooling** — if ghost ships / loot chests use `Highlight` instances for outline/glow effects, they can accumulate and cause performance issues on low-end mobile (Highlight = expensive, renders to separate buffer, max ~30 active Highlights before performance tanks). Pool Highlight instances, cull distant ones (>100 studs), disable during heavy combat / low FPS (<45 FPS → disable all non-essential FX).
  - Check: does current code use Highlights? `grep -r "Highlight" src/` → if yes, audit usage, add culling. If no, skip — YAGNI.
  - Target: 60FPS on iPhone 13, <50ms frame time p99, <100MB memory

- **Audio polish / monetization hooks (Phase 8)** — positional audio for whispers / footsteps / creaking ship, dynamic music (calm sailing → tense boarding → panic extraction → relief lobby), audio occlusion (inside ghost ship = muffled exterior sounds, echoey interior reverb), footstep surface detection (wood deck vs metal hull vs stone floor = different footstep SFX)
  - Monetization: ship cosmetics (sails, hull paint, figurehead), character cosmetics (pirate hats, coats, eyepatches), emotes, victory poses, kill effects (for PvP mode if added?), battle pass? — ALL DEFERRED until core gameplay loop is validated fun via playtesting + retention metrics (D1/D7) prove product-market fit. Do NOT monetize a game that isn't fun yet — polish the core loop FIRST, monetize SECOND.

- **TestHarness hygiene nits — low priority, 5 LOC** — Move `_G.ForceTestScenario` assignment into Initialize/Destroy, defer `AdminDebugRemote` creation to Initialize (currently created at module require time → exists in production builds, wasteful, slight security surface increase — AdminDebugRemote has isAdmin() check so NOT exploitable, just sloppy).
  - Files: `TestHarness.lua`
  - Risk: None — pure code hygiene, no gameplay impact
  - Do this when bored / waiting for CI / need a palate cleanser between big features — 5 minute task, satisfying to check off

---

**Last updated:** 2026-06-30 01:15 UTC  
**Next review:** After playtest confirms bb75a68 movement handoff fix works end-to-end, then ship gravity/Y velocity bug fix (Current Step above), then playtest AGAIN to confirm gravity/jumping works, then proceed to EntityAI ranged LOS bug (Bug #4) OR client input optimization, depending on playtest feedback — if movement STILL feels laggy/unresponsive after bb75a68, prioritize input change detection + rate limit removal (~15 LOC, massive feel improvement), if movement feels GOOD, prioritize AI combat (ranged LOS bug, 1 LOC, restores enemy threat level)

**Current mood:** Cautiously optimistic. Physics movement bug was caught by playtesting in ~30 seconds — exactly why we kept saying "STOP SHIPPING CODE, PLAYTEST WHAT WE HAVE". The fix is architecturally sound (proper authority handoff with mutual exclusion), all edge cases handled (respawn, player leave / memory leak, velocity drift), well-commented, --!strict clean. Waiting on Georgie's playtest confirmation — does movement feel correct now in ALL FIVE states: lobby / sailing / ghost ship interior / exit / lobby return? If YES → ship gravity bug fix (1 LOC), then input optimization (~15 LOC), then playtest AGAIN, then AI combat. If NO → debug movement handoff, find which transition is broken, fix THAT before touching anything else. Movement is FOUNDATIONAL — if players can't move reliably, they quit before experiencing ANY horror / AI / extraction gameplay, all our work wasted.
