---
name: plugin-dev
description: Use BEFORE writing or modifying any KTPAdminAudit Pawn code — menu/async TOCTOU rules, cross-plugin changelevel coupling, timed-ban persistence, and the compile/review/stage/verify workflow. Also use when planning a change, to know which invariants it touches.
---

# KTPAdminAudit Development

This plugin runs the fleet's only audited kick/ban/changemap/restart path on a
production fleet (24 instances) with active players. Follow every rule below;
when a rule and your instinct disagree, the rule wins — each one was paid for
with a production incident or a reviewer-caught near-miss.

## Hard safety rules
- **NEVER restart game servers** or issue LinuxGSM control commands without the
  operator's explicit permission in the current conversation.
- Deploys are staged as `KTPAdminAudit.amxx.new` in each instance's plugins dir
  and swap at the 03:00 ET nightly restart. Never hot-swap the live `.amxx`.
- Run the `ktp-code-review` agent on any nontrivial change BEFORE compiling for
  deploy.

## Architecture constraints
- **Extension mode**: KTPAMXX loads as a ReHLDS extension — there is NO Metamod
  and NO fakemeta. Engine hooks come only from KTP-ReAPI (`RH_*` hook chains).
  Never add a fakemeta/engine-module dependency.
- `hook_Host_Changelevel_f()` here and KTPMatchHandler's `OnChangeLevel()` are
  **both independently registered on the same `RH_Host_Changelevel_f`
  hookchain**. This plugin's hook only gatekeeps on its own
  `g_changeMapInProgress`/`g_pendingChangeMap` state — it does not supersede.
  Any changelevel `.changemap` queues still reaches MatchHandler's hook, which
  force-ends a live match on ANY changelevel while a match is live, regardless
  of the changelevel's origin. Re-check this coupling any time either plugin's
  changelevel handling changes.
- Globals persist across map changes in extension mode, but **gametime resets
  to near-zero per map**. A lock/timeout timestamp captured on one map and
  compared against gametime on the next map can go negative — treat any
  negative/wrapped elapsed-time as "expired," never as "not yet due." (Root
  cause of a real incident: a stale `.changemap` lock survived ~20 minutes
  into the next map because its 15s timeout check silently never fired.)
- Any persistent lock/latch that must not survive a map change belongs in
  `plugin_cfg`, reset unconditionally every map — not left to a timeout to
  eventually clear it.

## The menu/async TOCTOU rule (most important rule in this file)
Every admin menu here (`show_menu(..., -1, ...)`) uses an **unbounded timeout**
— it never expires on its own, so any state checked at menu-open time can go
stale for an arbitrarily long window before the player/admin acts on it. This
plugin has already been bitten by this shape twice and fixed it twice for
kick/ban but not (yet) for `.changemap`:
- **Fixed pattern (mirror this):** `execute_kick`/`execute_ban` re-check the
  acting admin's `ADMIN_KICK`/`ADMIN_BAN` flag and the target's
  `ADMIN_IMMUNITY` at execute time, and re-validate the target's SteamID
  against the one captured at menu-selection time (slots recycle on
  disconnect; a slot index alone is never identity).
- **Known open gap:** `ktp_is_match_active()` is checked exactly once, when
  `.changemap`'s menu opens (`cmd_changemap`). It is never re-checked in
  `execute_changemap()` or in either changelevel-firing task
  (`task_changelevel_countdown` / `task_changelevel_safety`) before the final
  `server_cmd("changelevel ...")`. `.changemap` requires no admin flag — any
  connected player can open it — so a match going live while the menu sits
  open can still force-end it. If you touch `.changemap`, close this gap
  (re-check liveness at execute time and again immediately before firing,
  aborting with a chat message if a match started) rather than assuming the
  existing race fixes already cover it — they cover other races in the same
  path, not this one.
- When adding any new menu or deferred action: capture the actor's and
  target's authid (not just slot) at capture time, and re-verify every
  permission/state precondition immediately before the action fires, not just
  when the menu was opened. Suppressing on mismatch is the safe direction; log
  the outcome unconditionally.

## Display-name freshness
Any player name shown in a menu, chat line, or log must be read live via
`get_user_name(id)` at build/format time. A name cached at connect time and
reused later goes stale on a mid-session rename (this is a filed, not-yet-fixed
class — the `.kick` menu list is the known instance). Keep cached names only
where identity-at-capture is the actual point (e.g. the SteamID stored for the
TOCTOU re-check above); never reuse a cached field purely for display.

## Command-injection discipline
Any user-supplied string that reaches `server_cmd`/`client_cmd` must be
shape-validated first — the command buffer splits on `;`, so a loose check
(e.g. accepting any string that merely "looks like" a SteamID) lets a
lower-privilege admin smuggle a higher-privilege command past the flag gate
and the audit trail. This is why `.unban <steamid>` strictly validates
`STEAM_X:Y:Z` shape before it touches `server_cmd`.

## Discord batching
The relay has **no rate limiting or queue of its own** — a failure storm can
exceed Discord's limits directly. Any consumer that can fire on a hot path
(the failed-RCON-auth audit is the existing example: per-source-IP counters,
one summary embed per 60s window, only when the window saw failures) must
batch, never emit one embed per event.

## Workflow
1. **Version bump** (every shipped change): `#define VERSION` and the header
   comment in the `.sma` (keep both in sync — mismatches have shipped before),
   new `CHANGELOG.md` section, README version line.
2. **Compile**: `wsl bash -c "cd '/mnt/n/Nein_/KTP Git Projects/KTPAdminAudit' && bash compile.sh"`
   (outputs `compiled/`, auto-stages to the KTP DoD Server test tree).
3. **Review**: `ktp-code-review` agent before any fleet stage.
4. **Fleet stage**: deploy as `.new` via paramiko (see root CLAUDE.md § SSH);
   verify staged md5 on all 24 active instances.
5. **Post-activation verify** (after the nightly): 24/24 on the new md5, no
   leftover `.new`, and check `/tmp` for cores — `find /tmp -maxdepth 1 -name
   'core.*' -mtime -1` on every host. A game-tree core search proves nothing
   (matches only core.so/core.ini/core.wav).

## Comments
Short, explain *why* not *what*, no ticket/finding IDs, never delete a
tripwire fact (a hard-won incident detail) while editing near it.
