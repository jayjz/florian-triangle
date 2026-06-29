# Review Log

## 2026-06-29 — ShipController.SetSailing
**Commit:** ab648ab
**Reviewer:** OpenClaw Architect

**What's Good:**
- Strict types, server-authoritative, velocity frozen correctly
- getOrCreateShip() dedupes init logic
- Small surgical scope

**What's Broken:**
- Nothing blocking

**Nits:**
- AttemptDock() still dead code
- No automated test / playtest yet
- TestHarness double-init still present

**Approval:** Yes

---

## 2026-06-29 — TestHarness Double-Init Fix
**Commit:** edea063
**Reviewer:** OpenClaw Architect

**What's Good:**
- ServerMain now clean: single responsibility — bootstrap GameManager only. Removed 8 lines of duplicate TestHarness init + outdated comments. Architecture now matches the header comment (which was updated to reflect reality).
- TestHarness idempotency guard is textbook: `initialized` boolean, early return with warn, reset in `Destroy()`. Identical pattern to `ClientInit.lua:25-30` — proven, consistent.
- GameManager remains the single orchestrator with proper `RunService:IsStudio()` guard — debug tooling correctly excluded from production.
- Zero gameplay impact — TestHarness is leaf-node dev tooling, no other systems depend on it.
- Commit is atomic, message clearly describes what/why, diff is trivial to review: +14 / -10 across 2 files.
- --!strict preserved, no type regressions, no new dependencies.

**What's Broken:**
- Nothing. Fix does exactly what PLAN.md specified.

**Luau / Roblox Best Practices observations:**
- ✅ `--!strict` maintained in both files
- ✅ Module cleanup pattern followed — `Destroy()` resets `initialized` flag, Maid cleans up connections
- ✅ Server authority preserved — no change to security surface (TestHarness is server-side only, isAdmin check untouched)
- ✅ No `wait()` usage, no table recreation in hot paths (N/A — init code only)
- ✅ RemoteEvent creation goes through `Utils.CreateRemoteEvent()` wrapper — unchanged, still correct
- ✅ Error handling: warn on duplicate init instead of silent fail or hard error — correct severity level
- ✅ Naming: `initialized` matches convention used in ClientInit / GameManager — consistent codebase
- ⚠️ Minor: `_G.ForceTestScenario` is still assigned unconditionally at module load time, not inside Initialize(). This means it exists even if TestHarness never initializes. Low risk (Studio-only tool, guarded by isAdmin at call time), but technically inconsistent with the "initialize once" pattern. Not blocking — file under future polish.
- ⚠️ `AdminDebugRemote` is created at module require time via `Utils.CreateRemoteEvent("AdminDebugCommand")`, not inside Initialize(). Same note as above — RemoteEvent exists even if TestHarness is never initialized. Again low risk (RemoteEvent with no listeners is harmless), but breaks the "lazy init" ideal. Not in scope for this fix.

**Nits / Suggested follow-ups (non-blocking):**
1. `ShipController.AttemptDock()` is still dead code — good next cleanup candidate, ~10 min
2. No Studio playtest yet for either fix (SetSailing + TestHarness) — code review only, need Rojo/Studio validation before calling extraction loop "playable"
3. Consider moving `_G.ForceTestScenario` assignment inside `Initialize()` and clearing it in `Destroy()` for full lifecycle hygiene — 2 LOC, very low priority
4. Same for `AdminDebugRemote` creation — could defer to Initialize(), but Utils.CreateRemoteEvent is likely idempotent anyway

**Approval:** **Yes — ship it.** Clean architectural fix, zero gameplay risk, follows established patterns, properly documented. Commit edea063 is good to merge to dev/main when ready.

