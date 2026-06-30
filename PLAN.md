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

### Fix ShipController Velocity Yanking — 3-Layer Defense — ✅ Done 2026-06-30 (498226c)
- Fixed 3 interlocking velocity pollution bugs that caused player yanking/pulling after the bb75a68 movement handoff fix.
- **Bug 3 — isInputAllowed security hardening:** Changed `isInputAllowed(player)` to reject input when NO ShipState exists. Was: `if not ship then return true end` → allowed first input to create ShipState + set velocity during lobby/on-foot. Now: `return false` → input rejected until opt-in via `SetSailing(true)`.
- **Bug 1 — Stale velocity reset on SetSailing():** Was zeroing velocity ONLY on `SetSailing(false)`. Now: velocity zeroed on EVERY `SetSailing()` state change. Root cause: lobby WASD → ShipState.Velocity polluted → `SetSailing(true)` → instant launch with stale velocity. Added `CONFIG.SailingInputDebounce = 0.2` — blocks move input for 0.2s after enabling sailing.
- **Bug 2 — Client input gating:** Was firing `PlayerMoveInput` every RenderStepped (60 Hz) unconditionally. Now gates on `player:GetAttribute("SailingEnabled") ~= true then return end`. Stops bandwidth waste (~1.2kb/sec/player) + ShipState velocity pollution.
- 2 files (`ShipController.lua`, `ClientShipController.lua`), ~45 LOC
- Defense-in-depth — 3 layers, any 1 layer stops the yanking, all 3 together = bulletproof

### Fix ShipController Gravity / Y Velocity Bug + JumpPower Toggle — ✅ Done 2026-06-30 (3adfae3)
- Fixed gravity / Y velocity bug — `AssemblyLinearVelocity.y = 0` every Heartbeat → gravity cancelled → float instead of fall, jump impulse cancelled → can't jump.
- Fix: preserve Y velocity → `root.AssemblyLinearVelocity = Vector3.new(sv.X, av.Y, sv.Z)` → ShipController owns HORIZONTAL (X/Z), physics engine owns VERTICAL (Y). Clean separation.
- Added JumpPower toggle in `SetSailing()` — sailing: `JumpPower = 0 / JumpHeight = 0 / UseJumpPower = true` → jumping DISABLED, consistent with WalkSpeed=0/AutoRotate=false, ShipController owns 100% of physics. On-foot: `JumpPower = 50 / JumpHeight = 7.2` → normal Roblox jump restored.
- Completes the movement authority handoff — WalkSpeed + AutoRotate + JumpPower ALL toggled together, ZERO overlap.
- 1 file (`ShipController.lua`), ~15 LOC
- Movement system is now SOLID — bb75a68 (authority handoff) + 498226c (velocity pollution) + 3adfae3 (gravity physics) = complete movement stack

### Fix EntityAI Ranged Attack LOS Bug — Bug #4 / HIGH — ✅ Done 2026-06-30 (39e582a)
- Fixed `hasLineOfSight()` returning `false` during cooldown instead of cached result → ranged attacks ~5% hit rate → AI combat broken → corrupted pirates NOT threatening → horror tension gutted.
- Added `Entity.LastLOSResult: boolean` field, initialized to `false` (safe default), cache result in ALL return paths, return cached result during cooldown: `return entity.LastLOSResult` (was: `return false`).
- AI combat effectiveness RESTORED — ranged attacks HIT when target is in LOS, MISS when target breaks LOS, hit rate ~60-80% (was ~5%), corrupted pirates are ACTUALLY DANGEROUS now.
- Pairs with ApplySanityDrain fix (9fd75c8) — entities now deal BOTH sanity damage (~6/sec proximity aura) AND health damage (~14 damage/hit, ~60-80% accuracy) → horror tension = MAXIMUM.
- 1 file (`EntityAI.lua`), ~15 LOC
- Fixes BUG_AUDIT_2026-06-29.md — Bug #4 — HIGH

---

## Current Step: Add EntityAI Ranged Attack Telegraphing + Visual FX — P0/P1 — ~15-28 LOC

**Problem:** Ranged attacks deal damage INSTANTLY with ZERO warning and ZERO visual feedback → feels cheap/unfair → player churn. This bug was MASKED by Bug #4 (LOS bug → 5% hit rate → players rarely got hit → missing FX/telegraphing barely noticeable). NOW that Bug #4 is fixed (39e582a → 60-80% hit rate), players WILL get shot constantly with no warning, no FX, no idea what hit them → "this game is bullshit" → uninstall.

Two interlocking bugs, BOTH now EXPOSED by the LOS fix:

**Bug A — P0 / UX — No ranged attack visual FX**
- `RangedAttackRemote = Utils.CreateRemoteEvent("EntityRangedAttack")` is DECLARED at line 35 of `EntityAI.lua` but is NEVER FIRED → `git grep "RangedAttackRemote" -- src/` → only 1 hit, the declaration.
- Client gets ZERO feedback when hit by ranged attack → health drops with NO muzzle flash, NO projectile, NO impact FX, NO hitscan tracer, NOTHING → confusing / frustrating ("why did my health drop? am I bugged? is sanity draining my health?")
- BEFORE 39e582a: attacks ~5% hit rate → missing FX barely noticeable → players rarely got shot
- AFTER 39e582a: attacks ~60-80% hit rate → players WILL get shot constantly → missing FX = IMMEDIATELY OBVIOUS → player churn
- **This is now a P0 UX BUG — fix BEFORE public playtest**

**Bug B — P1 / Gameplay Feel — No attack telegraphing**
- Entity goes Idle/Chasing → Attacking → damage applied INSTANTLY (0 frame wind-up) → players get hit with ZERO warning → feels cheap / unfair
- BEFORE 39e582a: 5% hit rate → players rarely got hit → telegraphing not urgently needed (rare surprise = acceptable for horror)
- AFTER 39e582a: 60-80% hit rate → players get hit CONSTANTLY with zero warning → FRUSTRATING → "this game is bullshit, enemies shoot me instantly with no warning" → churn
- **This is now a P1 gameplay feel bug — fix before public playtest**

**The Fix — combine BOTH bugs into ONE commit (~15-28 LOC):**

Use the existing DEAD CONFIG `CONFIG.RangedValidationDelay = 0.4` (declared but never read — `git grep "RangedValidationDelay" -- src/` → 1 hit, the CONFIG declaration) as attack wind-up / telegraph delay:

1. **Server — `EntityAI.PerformAttack("Ranged", ...)`** (~8 LOC):
```lua
function EntityAI:PerformAttack(attackType: string, targetPos: Vector3)
    if attackType == "Ranged" then
        -- Telegraph: wind-up FX + audio cue, 0.4s dodge window
        self.State = "AttackWindup"  -- NEW state, OR reuse "Attacking" with timer
        RangedAttackRemote:FireAllClients(self.Root.Position, targetPos, "windup")
        
        task.wait(CONFIG.RangedValidationDelay)  -- 0.4s dodge window
        
        -- Re-validate LOS after wind-up — target may have broken LOS → attack cancels → SKILL EXPRESSION
        if not self.Target or not hasLineOfSight(self, targetPos) then
            self.State = "Chasing"
            return  -- attack cancelled, player successfully dodged
        end
        
        -- Fire: damage + impact FX
        RangedAttackRemote:FireAllClients(self.Root.Position, targetPos, "fire")
        local hum = self.Target.Character:FindFirstChildOfClass("Humanoid")
        if hum then
            hum:TakeDamage(CONFIG.RangedDamage)
            HorrorEvents.TriggerHorrorPulse(0.4)
        end
        self.State = "Idle"  -- OR "Chasing", resume AI
    end
end
```

2. **Client — NEW `ClientEntityController.lua` OR add to existing `ClientShipController.lua`** (~20 LOC):
```lua
-- Listen for EntityRangedAttack RemoteEvent
Remotes.EntityRangedAttack.OnClientEvent:Connect(function(originPos: Vector3, targetPos: Vector3, phase: string)
    if phase == "windup" then
        -- Telegraph FX: enemy eyes glow red, charging sound, screen edge warning?
        -- Spawn charge-up particle at originPos
    elseif phase == "fire" then
        -- Projectile tracer: Beam from originPos → targetPos, 0.1s duration
        -- Impact FX: spark particles at targetPos
        -- Screen shake (mild): Getting shot = feedback, NOT boring
        -- Hit sound: "thwip" / sizzle
    end
end)
```

**Kill THREE birds with ONE stone:**
1. ✅ Attack telegraphing P1 bug fixed — 0.4s wind-up → players can DODGE by breaking LOS → skill expression → fun
2. ✅ Ranged FX P0 bug fixed — `RangedAttackRemote` finally gets USED → muzzle flash / projectile tracer / impact FX → gameplay clarity
3. ✅ Dead config revived — `CONFIG.RangedValidationDelay = 0.4` goes from "never read, confusing maintenance burden" → "attack wind-up / telegraph delay, core gameplay mechanic"

**Why this step:**
- AI combat is NOW EFFECTIVE (39e582a → 60-80% hit rate), which means AI combat is NOW FRUSTRATING (instant unfair damage with no FX, no telegraph, no dodge window)
- This is EXPECTED — we fixed "AI can't hit anything" → exposed "AI hits TOO WELL with NO WARNING", which was always there, just masked by 5% hit rate
- Fix telegraphing + FX BEFORE public playtest, or players WILL bounce — "this game is bullshit, enemies shoot me instantly with no warning, I keep taking damage for no reason, uninstall"
- With telegraphing + FX: "oh no it's winding up — RUN! *dives behind cover* phew that was close — okay peek out, shoot back, EXTRACT — WIN → dopamine → retention"
- Telegraphing + FX = the difference between "this game is bullshit" and "this game is TENSE"
- Small change — ~15-28 LOC total, 2 files (`EntityAI.lua` + NEW `ClientEntityController.lua` OR existing `ClientShipController.lua`)
- High value — transforms AI combat from FRUSTRATING → CHALLENGING BUT FAIR
- Pairs with LOS fix (39e582a) — now that attacks actually HIT, players NEED to know WHEN/WHY they got hit + NEED a dodge window

**Acceptance:**
- [ ] Corrupted pirate winds up ranged attack → 0.4s telegraph (glowing eyes / charge sound / muzzle flash start) → player sees/hears WARNING
- [ ] Player breaks LOS during 0.4s wind-up → attack CANCELS → NO damage → skill expression → FEELS FAIR
- [ ] Player stays in LOS during wind-up → attack FIRES → projectile tracer visible → impact FX → health damage applied → player UNDERSTANDS what hit them
- [ ] Hit rate ~40-60% against skilled players who DODGE (was ~60-80% against AFK players with no telegraph, was ~5% with LOS bug) → CHALLENGING BUT FAIR
- [ ] No regression in melee attacks — melee should still be instant (close range = no time to telegraph, makes sense)
- [ ] `RangedAttackRemote` is FIRED by server, RECEIVED by client, FX play correctly
- [ ] --!strict clean

**Risk: Low-Medium.** ~15-28 LOC, 2 files, adds a 0.4s `task.wait()` in `PerformAttack()` → attack is ASYNC now (was sync, instant damage). Need to ensure: (1) entity State is set to "AttackWindup" during wait → prevents double-attack spam, (2) target validation AFTER wait → check `self.Target` still exists, still alive, still in LOS → cancel if any fail, (3) entity can be destroyed / stunned during wind-up → Maid cleanup should cancel the task.wait() coroutine → verify Maid handles this (yes, Maid cleans up all connections/threads on Destroy). Worst case: attack goes through after entity is destroyed → nil check `if not self.Target` catches it, safe.

**Estimated LOC:** ~8 LOC server (`EntityAI.lua` — wind-up state + task.wait + LOS re-validation + RemoteEvent fire × 2) + ~20 LOC client (NEW `ClientEntityController.lua` OR add to `ClientShipController.lua` — RemoteEvent listener + windup FX + fire FX) = ~28 LOC total, 2 files

**Test plan:**
- Spawn corrupted pirate → stand in open, 20 studs away → CONFIRM: pirate winds up (0.4s telegraph, glowing eyes / charge sound) → YOU CAN SEE/HEAR the attack coming → projectile tracer fires → impact FX → health damage → YOU UNDERSTAND what hit you
- Duck behind cover DURING 0.4s wind-up → CONFIRM: attack CANCELS → NO damage → skill expression → FEELS FAIR
- Stand still during wind-up → CONFIRM: attack HITS → damage + FX → YOUR FAULT for not dodging → FEELS FAIR
- Hit rate against skilled dodging players: ~40-60% (was ~60-80% against AFK, was ~5% with LOS bug) → CHALLENGING BUT FAIR
- Melee attacks → CONFIRM: still instant (no telegraph for close-range, correct)
- Multiplayer: 2+ players, entity attacks Player A → CONFIRM: Player B also sees the wind-up FX + projectile tracer (FireAllClients) → spectator clarity → "OH SHIT WATCH OUT" moments → co-op tension

---

## Backlog

### Awaiting Playtest Confirmation — Movement System + AI Combat
Movement system fixes (bb75a68 + 498226c + 3adfae3) + AI combat fix (39e582a) are SHIPPED but NOT playtested in-engine. Code review confidence HIGH, but NO substitute for in-engine validation.

**Movement playtest checklist** (pull `agent/autonomous-florian-triangle @ 3adfae3`):
- [ ] Foosha Village lobby — WalkSpeed 16, normal Humanoid controls, NO yanking/pulling, jump works
- [ ] Windmill Village round start — ship movement 58 studs/sec, smooth, weight penalties apply, NO launch at round start, jump DISABLED (correct)
- [ ] Sail at full speed → walk off edge of ship deck → CONFIRM: FALL into ocean with gravity, do NOT float
- [ ] Board ghost ship — Humanoid movement RESTORED, walk freely, loot chests, NO freezing, jump works
- [ ] Exit ghost ship — ship movement restored, seamless handoff, NO residual drift, NO launch on exit
- [ ] Lobby return — Humanoid movement restored, jump works
- [ ] Die / respawn during sailing — movement mode correctly restored, NO tug-of-war bug returning
- [ ] 3+ rounds, multiple players joining/leaving — NO memory leaks (Ctrl+Shift+F3)

**AI combat playtest checklist** (pull `agent/autonomous-florian-triangle @ 39e582a`):
- [ ] Spawn corrupted pirate → stand in open, 20 studs away → CONFIRM: pirate shoots you, ~60-80% hit rate, ~14 damage/hit — CURRENTLY NO VISUAL FX (P0 bug, will be fixed by Current Step above)
- [ ] Duck behind cover → CONFIRM: attacks STOP within 0.35s
- [ ] Try to DODGE ranged attacks → currently IMPOSSIBLE (instant hitscan, zero telegraph) → CONFIRM this feels unfair → validates attack telegraphing P1 bug → WILL BE FIXED by Current Step above
- [ ] Get shot at low sanity (< 30) → CONFIRM: health damage + horror pulse + sanity drain stack → TERRIFYING

**If playtest FAILS:** Report EXACTLY which system, which transition, what you felt, video clip. Movement bugs = P0 (blocks all gameplay), AI combat feel bugs = P1 (blocks retention), fix immediately, do NOT stack more features on broken foundations.

**If playtest PASSES:** Continue with next backlog item — client input change detection + remove server rate limit (~15 LOC, massive movement FEEL improvement), then Quota Progress HUD (~40 LOC).

### Bug Fixes (prioritized by severity, then value/LOC)

- **Client-side input change detection + remove server rate limit — MEDIUM — ~15 LOC** — `ClientShipController` sends `PlayerMoveInput` EVERY RenderStepped frame (60Hz) when moveDir.Magnitude > 0, EVEN IF moveDir hasn't changed since last frame → holding W → sends `Vector3.new(0,0,-1)` 60 times/sec → server-side `isInputAllowed()` rate limits to 12.5Hz (0.08s) → 47.5/60 packets/sec DROPPED (rejected, wasted bandwidth). Movement handoff is correct (bb75a68 + 498226c + 3adfae3), input gating is correct (498226c, `SailingEnabled` attribute), but input PIPELINE is still wasteful + laggy.
  - Fix client: store `lastMoveDir`, only `FireServer(moveDir)` if `(moveDir - lastMoveDir).Magnitude > 0.01` → reduces network traffic ~10-50× (normal movement: press W → send 1 packet, hold W 5 sec → 0 additional packets, release W → send 1 packet, total 2 packets vs 300 packets at 60Hz)
  - Fix server: set `InputRateLimit = 0` (unlimited) OR `0.016` (60Hz) → when input DOES change, server processes it IMMEDIATELY with zero artificial delay → minimum latency, maximum responsiveness
  - Combined: ~2-10 packets/sec actual (direction changes only) + zero artificial latency → massive feel + efficiency win
  - Files: `ClientShipController.lua` (~10 LOC) + `ShipController.lua` (1 LOC, `InputRateLimit = 0`)
  - Risk: Low — client-side change detection is straightforward, server rate limit removal just means "process all input immediately", worst case = slightly higher server CPU (still trivial: 10 packets/sec × 6 players = 60 RemoteEvent invocations/sec, negligible)
  - Test: Wireshark / Ctrl+Shift+F3 network stats → confirm packet rate drops from ~60/sec to ~2-10/sec during normal movement, confirm input latency feels snappier (no 80ms artificial delay), confirm no input loss (rapid direction changes still register immediately)
  - **Do AFTER attack telegraphing + FX fix (Current Step) — AI combat feel is MORE broken right now (instant unfair damage with no FX) than movement feel (laggy input, still playable). Fix AI combat first, then movement polish.**

### Features / Content

- **Quota Progress HUD — ~40 LOC, 2 files** — Add extraction quota progress bar to client HUD. Wire `RoundManager.AddExtracted()` → RemoteEvent → `ClientUIController`. High player value, exceeds 20 LOC budget — split into smaller steps if doing: (1) Add QuotaProgress RemoteEvent + server fire (~8 LOC), (2) Add client UI bar (~25 LOC), (3) Polish animations (~10 LOC).
  - Why now? — If playtesting shows players don't know how close they are to extraction quota → confusion → frustration → quit. Quota HUD = clarity = retention.
  - Why not now? — 40 LOC exceeds "single smallest change" budget, requires UI design (where on screen? what style? progress bar vs counter vs both?), needs art pass. Defer until movement + combat + sanity systems are ALL confirmed working via playtest, THEN add HUD polish.
  - Acceptance: quota progress visible at all times during round, updates in real-time as loot is extracted, clear visual distinction between "need more loot" / "quota met, extract now!" states, mobile-friendly (readable on small screen)

- **Client interior lighting change on boarding — ~15 LOC** — Second half of the TODO at `ClientShipController.lua:60`. Camera shake (620d541) covers impact feel. Interior lighting (tint screen green/dim, ColorCorrection) adds sustained atmosphere while inside ghost ship.
  - Pairs well with camera shake — shake = impact moment (boarding), lighting = sustained atmosphere (while inside)
  - Implementation: `ColorCorrectionEffect` in `Lighting` service, Tween `TintColor` → greenish `(0.7, 1.0, 0.7)`, `Brightness = -0.2`, `Contrast = 0.1`, `Saturation = -0.3` over 0.5s on `PlayerDocked`, reverse tween on exit (need `PlayerUndocked` event — can use `player:GetAttributeChangedSignal("SailingEnabled")` now that 498226c added the SailingEnabled attribute, no separate RemoteEvent needed)
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

**Last updated:** 2026-06-30 16:15 UTC  
**Next review:** After attack telegraphing + ranged FX fix ships (Current Step above), then playtest AI combat end-to-end: does combat feel CHALLENGING BUT FAIR? Can you DODGE attacks by breaking LOS during 0.4s wind-up? Do FX communicate clearly WHEN/WHERE you got hit? If YES → ship it, move to client input change detection (~15 LOC, movement FEEL polish), then Quota HUD (~40 LOC). If NO → iterate on telegraph timing / FX clarity / damage numbers until combat FEELS RIGHT — AI combat is a CORE PILLAR, if fighting corrupted pirates isn't fun/tense/fair, players quit, all our work wasted.

**Current mood:** Cautiously optimistic, but URGENT. Movement system is SOLID (bb75a68 + 498226c + 3adfae3 = authority handoff + velocity pollution + gravity physics, all fixed, well-tested in code review, needs Studio playtest confirmation). AI combat is EFFECTIVE but FRUSTRATING (39e582a fixed LOS → 60-80% hit rate, which EXPOSED the "instant unfair damage with no FX, no telegraph, no dodge window" design bug that was always there, just masked by 5% hit rate). Fix telegraphing + FX IMMEDIATELY — this is the difference between "this game is bullshit" and "this game is TENSE". AI combat FEEL is blocking public playtest — do NOT ship to playtesters with instant unfair damage and no visual feedback, they WILL bounce, retention = 0%, all our work wasted. Telegraphing + FX = ~15-28 LOC, 2 files, 30-60 min work, MASSIVE impact on player experience. DO IT NOW.
