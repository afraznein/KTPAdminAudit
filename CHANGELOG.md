# Changelog

All notable changes to KTP Admin Audit will be documented in this file.

## [2.7.16] - 2026-07-08

Fix wave from the 2026-07-06 Wave-2 full-surface assessment (AA-1/AA-2/AA-3/AA-4/AA-5 + the .928 RCON-audit consumer).

### Fixed
- **Stale `.changemap` lock survived map changes (AA-1, match-integrity)** — globals persist across map changes in extension mode, so a lock set in the last ~10s of a map carried a gametime timestamp from the *previous* map's clock onto the new one. Gametime restarts per map, so `lockAge` computed negative and the 15s timeout never fired — the stale lock could supersede ANY server changelevel (including KTPMatchHandler half transitions) for ~20 minutes of new-map gametime. All lock state (`g_changeMapInProgress`, `g_changeMapLockTime`, countdown, pending map/display name) now resets in `plugin_cfg` on every map, and the timeout check treats `lockAge < 0` as expired.
- **Acting admin's flags not re-checked at execute (AA-2)** — 2.7.15 closed the *target* immunity TOCTOU but not *actor* auth: an admin de-flagged (re-auth, live revoke) after opening the menu could still finish a queued kick/ban. `execute_kick`/`execute_ban` now re-check `ADMIN_KICK`/`ADMIN_BAN` at execute time and log the denial.
- **One-frame countdown-zero overwrite race (AA-3)** — the countdown cleared `g_changeMapInProgress` one frame before the queued `changelevel` flushed; a `.changemap` landing in that frame could start a second flow over the first. The lock is now held through the queued changelevel (the hook already passes our own same-map changelevel), cleared by `plugin_cfg` on the new map. A wedged lock self-heals via the existing 15s timeout, now also checked in `cmd_changemap`.
- **Kick-only drop reason claimed a ban duration (AA-5)** — the invalid-SteamID (kick-only) path handed the client a drop reason with a duration in it. A kick reason never mentions a duration now.
- **`_restart` console commands skipped by the audit hook** — `hook_ExecuteServerStringCmd` unconditionally skipped `_restart`, so an un-audited console `_restart` was invisible. Only the `_restart` issued by our own `.restart` command (already audited) is debounced; any other `_restart` is now logged and embedded like `quit`/`exit`/`restart`.
- **Menu state dangled on target disconnect** — an admin sitting in the ban duration menu kept `g_menuTarget`/`g_menuAction` pointing at a disconnected (recyclable) slot; the auth TOCTOU guard masked the worst outcome but the stale menu stayed alive. `client_disconnected` now cancels any admin mid-flow on that target (with a chat notice) and clears the departing player's `g_validPlayerCount`, which was never reset.
- **Countdown HUD/chat used the raw map filename** — announcements now use the display name from `ktp_maps.ini` (the Discord embed already did); logs keep the raw filename. *Note: the assessment wording said the countdown "Discord embed" used the raw name — in source the embed already used the display name; the raw-name surfaces were the HUD/chat announcements, fixed here.*

### Added
- **Timed-ban persistence (AA-4, full fix)** — the engine's `SV_WriteId_f` writes only permanent filters (`banTime == 0`), so a "1 Week" ban really lasted until the next 03:00 nightly restart while the audit log and Discord embed claimed the full duration. Every timed ban now appends a record to `<configsdir>/ktp_timed_bans.ini` (`steamid|unban_epoch|admin_steamid|target_name|admin_name`); at boot (`plugin_cfg`, latched to once per process) the file is read, expired entries are dropped and logged (`TIMED_BAN_EXPIRED`), duplicates dedup latest-wins, malformed lines are skipped with their content logged, and each live entry is re-applied via `banid <remaining_minutes> <steamid>` (`TIMED_BAN_REAPPLY sid=... remaining_min=...`, remaining recomputed from the stored epoch, rounded up). No `writeid` — re-application every boot carries it. To fully lift a timed ban early, `removeid` alone is not enough: also delete its line from `ktp_timed_bans.ini`.
- **Failed-RCON audit with batching (.928 consumer)** — `hook_SV_Rcon` previously discarded `is_valid == false` audits (which fire on ReHLDS .928+; inert on .927). Each failure is now logged locally (`RCON AUTH FAIL`, passwords already stripped engine-side), and accumulated per source IP (count, first/last timestamp, last command name, 16-IP table with overflow counter). A repeating 60s task flushes ONE summary embed per window, and only when the window saw failures — the Discord relay has no queue and failure storms can hit 60/min, past Discord limits. `is_valid == true` handling unchanged.

### Removed
- **Stale repo-local `amxxpc32.so`** — a glibc-2.38 build that shadowed the fleet compiler when compiling from the repo cwd. Both `compile.sh` and `compile.bat` copy the compiler from the KTPAMXX build tree, so nothing referenced it.

## [2.7.15] - 2026-07-06

Fix wave from the 2026-07-05 full-stack review (Part 2 P2 items).

### Fixed
- **Ban-flow immunity TOCTOU** — immunity was checked when the admin selected the player (menu filter + double-check), but never re-checked after the duration menu. Flags granted in that window (target re-auths as admin, live flag grant) could still get an immune player banned. `execute_ban` now re-checks `ADMIN_IMMUNITY` right next to the existing SteamID TOCTOU guard, covering the whole select→duration→execute chain.
- **"1 Week" ban logged and announced as "7 days"** — the duration string builder had no weeks tier, so the 10080-minute option's log line, Discord embed, chat announcement, and drop reason all disagreed with the menu label. Added a weeks tier (`1 week`).
- **`get_players "c"` comment** claimed the flag means "connected" — it means *skip bots*. HLTV proxies still pass and are intentionally NOT filtered: they've been kickable from the menu by design since v2.3.0 (stuck-proxy recovery).

## [2.7.14] - 2026-06-12

### Fixed
- **`.changemap` countdown wedged the next map's AMXX task scheduler** (PR #1, contributed by Cadaver / JimmyLockhart65616). `server_exec()` in `task_changelevel_countdown()` and `task_changelevel_safety()` ran the changelevel synchronously inside the AMXX task callback, which left every `set_task()` in the destination map's `plugin_cfg` registered (`task_exists() == 1`) but never dispatched — silently killing repeating tasks in other plugins. The visible casualty was **KTPHudObserver** (HUD timer + capture-zone polling dead for the whole map, only after an admin `.changemap`). Removed both `server_exec()` calls; the queued `changelevel` flushes on the next engine frame (same pattern KTPMatchHandler uses). The v2.7.6 `server_exec()` was only needed for the old hook-supercede routing that v2.7.7 removed, so its rationale no longer applies. Reproduced + A/B-verified on the local KTP stack (`dod_anzio → dod_flash`): with `server_exec()` the new map's HudObserver tasks got 0 dispatches; without it, ~300.
- **Header/define version mismatch** — the file header and `VERSION:` comment said `2.7.12` while `PLUGIN_VERSION` was `2.7.13`. Reconciled all three to `2.7.14`.

## [2.7.13] - 2026-04-25

### Added
- **Adopted `ktp_version_reporter` shared include** — plugin now registers with the fleet-wide `amx_ktp_versions` rcon command (ADMIN_RCON). Output reports name, version, build SHA, and build time alongside other KTP plugins. See KTPMatchHandler 0.10.116 for the canary release introducing the include.
- **`compile.sh` build-info generation** — git short SHA + UTC build time written to `build_info.inc` and baked into the .amxx so the rcon command can report what's actually deployed.

### Changed
- **Standardized version constants** — `PLUGIN`/`VERSION`/`AUTHOR` `#define`s renamed to `PLUGIN_NAME`/`PLUGIN_VERSION`/`PLUGIN_AUTHOR` (matching every other KTP plugin's convention). All call sites updated (`register_plugin`, init log, version client_print). No behavioral change.

### Fixed
- **`compile.sh` temp-dir nesting bug** — `cp -r src dst` accumulates nested `include/` dirs on re-runs. Added `rm -rf "$TEMP_BUILD"` before `mkdir`. Discovered while wiring `ktp_version_reporter`.

## [2.7.12] - 2026-03-24

### Fixed
- **Ban duration menu shows wrong name if target disconnected** — `show_duration_menu` read the target player's name without checking if they were still connected. If the target disconnected between player selection and duration menu display, the name shown was from whoever now occupied that slot. Added `is_user_connected` guard.
- **`task_flush_banlist` could accumulate on rapid sequential bans** — Used no task ID, so two rapid bans queued two separate `writeid` tasks. Added `TASK_FLUSH_BANLIST` constant with `remove_task` before `set_task` to collapse into a single deferred write.
- **Changelevel hook blocked match-end changelevel during countdown** — `hook_Host_Changelevel_f` returned `HC_SUPERCEDE` for ANY changelevel while the countdown lock was held, including match-end changelevel from KTPMatchHandler. Now allows changelevel if the requested map matches `g_pendingChangeMap`.
- **`get_user_authid` hardcoded buffer length** — Passed `34` instead of `charsmax(g_menuTargetAuth[])`. Numerically identical but inconsistent with the rest of the file. Normalized.

---

## [2.7.11] - 2026-03-13

### Fixed
- **Slot recycling TOCTOU on kick/ban** — Between menu selection and action execution, a player slot could be recycled to a different player. Now stores target's SteamID at selection time (`g_menuTargetAuth`) and validates it matches before executing kick or ban. Prevents wrong-player actions.
- **`banid` not flushed before player drop** — `server_cmd("banid ...")` queued the command but `ktp_drop_client` fired before the buffer was flushed. Added `server_exec()` immediately after `banid` so the ban is in memory before the player is dropped. Deferred `writeid` still handles disk flush.
- **`STEAM_ID_PENDING`/LAN/BOT bans silently fail** — Pre-auth or LAN players have non-persistent SteamIDs that `banid` can't use. Now warns the admin and falls back to kick-only with a log entry.
- **Empty player list infinite menu redisplay** — If all players disconnect while admin has the menu open, navigation keys caused an infinite redisplay loop. Added early-out guard when `g_validPlayerCount` is zero.
- **INI `name` key prefix match** — `contain(line, "name") == 0` matched any key starting with "name" (e.g., `nameserver=...`). Now splits on `=` first and compares the extracted key, consistent with `ktp_discord.inc`.
- **Dead `case 1` in `hook_ExecuteServerStringCmd`** — Unreachable branch (RCON source filtered by early return). Removed and added comment explaining why.
- **Header version mismatch** — Comment block said v2.7.9, `#define VERSION` was 2.7.10. Synchronized to 2.7.11.

---

## [2.7.10] - 2026-03-13

### Changed
- **Deferred ban file flush** — `writeid` + `server_exec()` moved from `execute_ban()` to a 0.1s deferred task (`task_flush_banlist`). The `banid` command adds the SteamID to the in-memory ban list immediately; the disk flush can happen asynchronously. Removes 5-10ms of synchronous disk I/O from the menu handler frame.

---

## [2.7.9] - 2026-03-13

### Fixed
- **Version message task used raw player ID as task ID** — Could collide if an admin reconnects within 5 seconds. Now uses `id + TASK_VERSION_BASE` offset and extracts player ID from task ID in the callback. Task is also removed on `client_disconnected`.
- **`banid`/`writeid` not flushed with `server_exec()`** — Ban commands were queued but not guaranteed to flush before `ktp_drop_client` fired. If the server crashed in the same frame, the ban record could be lost. Added `server_exec()` after `writeid`.
- **`fn_execute_restart`/`fn_execute_quit` used implicit task ID 0** — Could silently collide with other default-ID tasks. Now use dedicated `TASK_RESTART` (54323) and `TASK_QUIT` (54324) constants. Also added `server_exec()` after both commands for consistency.

### Changed
- Changemap task IDs from mutable globals (`g_changeMapTaskId`/`g_changeMapSafetyTaskId`) to `#define` constants (`TASK_CHANGELEVEL`/`TASK_CHANGELEVEL_SAFETY`).
- `containi` → `contain` in INI map parser for consistency with rest of codebase.
- Added source constant documentation comment on `hook_ExecuteServerStringCmd` (0=Console, 1=RCON, 2=Redirect).

---

## [2.7.8] - 2026-03-11

### Fixed
- **Changelevel countdown safety fallback** — Added single-fire `task_changelevel_safety()` at countdown+5s as fallback for when the repeating countdown task fails to register (~10% failure rate from hookchain context). If the normal countdown completes, the safety task is a no-op.
- **`copy()` buffer overflow in INI map parser** — `load_map_list()` did not clamp the copy length to `charsmax(currentMap)`. A map name longer than 31 chars in `ktp_maps.ini` could overflow the `currentMap[32]` buffer.
- **`build_player_list` missing bounds check** — No guard against writing past `g_validPlayers[admin_id][32]` inner dimension. Added `sizeof` bounds check before insertion.
- **Safety fallback did not clear `g_changeMapCountdown`** — `task_changelevel_safety()` reset `g_changeMapInProgress` but left the countdown variable at a stale value.
- **`compile.sh` dead error block** — `set -e` caused the script to exit before the manual `$? -ne 0` check could run. Removed `set -e` so the error message is actually reachable.

## [2.7.7] - 2026-03-08

### Fixed
- **Intermittent changemap countdown failure** (~10% failure rate) - `.changemap` countdown started but never completed. `execute_changemap()` used a roundabout path: `server_cmd("changelevel")` → hook intercepts → `HC_SUPERCEDE` → `start_changelevel_countdown()`. Calling `set_task()` from inside the hookchain handler intermittently failed to register the task. Now calls `start_changelevel_countdown()` directly — no hook interaction needed.
  - Reported on Denver 1, March 8 2026 — analysis found 4 failures across ATL2, DEN1, NY1 in March

### Removed
- **`g_changeLevelPending` flag** - No longer needed without hook-based routing for `.changemap`

## [2.7.6] - 2026-03-04

### Fixed
- **Changemap countdown never executed changelevel** - `task_changelevel_countdown()` called `server_cmd("changelevel")` without `server_exec()`, so the command sat in the buffer and was never processed. The initial call in `execute_changemap()` worked because it used both `server_cmd()` + `server_exec()`. Added `server_exec()` after the countdown's `server_cmd` call.
  - Reported on Chicago 2 (27016), March 3 2026 — admin attempted `.changemap dod_anjou_a4` three consecutive times, each time the countdown started but the map never changed, requiring `.quit` to restart

### Added
- **Debug logging at countdown completion** - Logs confirmation when countdown reaches zero and changelevel is executed, for future troubleshooting

## [2.7.5] - 2026-02-25

### Fixed
- **Changemap race condition** - Two players could open `.changemap` menu simultaneously and both complete a selection. The second selection overwrote the first's pending map and restarted the countdown, sending duplicate Discord audit messages. Added `g_changeMapInProgress` check in `execute_changemap()` (was only checked in `cmd_changemap()` when opening the menu).
- **Menu buffer truncation** - Player and map selection menus used 512-byte buffers that could overflow with long map/player names (up to ~675 bytes with max-length names), silently cutting off navigation controls (Next/Prev/Cancel). Increased to 1024 bytes.

## [2.7.4] - 2026-02-19

### Fixed
- **Changelevel lock could get permanently stuck** - `g_changeMapInProgress` lock could remain set if the countdown task failed to fire (e.g., plugin reload mid-countdown), blocking ALL future changelevel attempts including mapcycle rotation and manual console commands
  - Caused 160ms phys spikes on NY 27015 for 3+ hours (2026-02-19) — engine repeatedly attempting blocked changelevel in physics loop

### Added
- **15-second safety timeout on changelevel lock** - Auto-resets if expired, with log warning
- **Lock age shown in block log** - Blocked changelevel messages now include time since lock was set

## [2.7.3] - 2026-01-23

### Fixed
- **Changemap countdown completion blocked itself** - After 5-second countdown, the changelevel command was blocked by its own race condition protection (`g_changeMapInProgress` still true)
  - Fix: Reset `g_changeMapInProgress = false` before executing the final changelevel command

## [2.7.2] - 2026-01-20

### Fixed
- **Concurrent changemap crash** - Server crash when two players use `.changemap` simultaneously
  - Reported on Atlanta 2, January 18 2026

### Added
- **g_changeMapInProgress lock** - Prevents race condition from concurrent `.changemap` requests
- **Changelevel blocking during countdown** - Other changelevel attempts blocked while changemap in progress

### Technical
- Added check in `cmd_changemap` to reject if changemap already in progress
- Added check in `hook_Host_Changelevel_f` to block other changelevel sources during countdown

## [2.7.1] - 2026-01-11

### Added
- **RCON quit/exit commands now BLOCKED** - Returns HC_SUPERCEDE to prevent anonymous server shutdowns
- **Discord alert when RCON quit/exit is blocked** - Shows source IP for accountability

### Changed
- **Discord embed titles now include `:ktp:` emoji** - Consistent branding across all Discord notifications
  - Admin KICK, Admin BAN, RCON Quit BLOCKED, RCON Server Control
  - Console Server Control, Admin Server Restart, Admin Server Shutdown, Admin Map Change

### Security
- RCON quit/exit blocked - use `.quit` in-game for audited server shutdown

## [2.6.0] - 2026-01-01

### Added
- **Changelevel Hook with Countdown** - `RH_Host_Changelevel_f` hook for `.changemap` (KTP-ReHLDS)
- **5-second countdown before map change** - HUD display and chat announcements
- **Chat countdown announcements** - Last 3 seconds shown in chat

### Changed
- `.changemap` now supersedes engine changelevel to show countdown

### Technical
- Uses `Host_Changelevel_f` hook (console changelevel command)

## [2.5.1] - 2025-12-31

### Added
- **Match active check** - Uses `ktp_is_match_active()` native from KTPMatchHandler

### Changed
- `.changemap` blocked during active matches (live, pending, prestart)

## [2.5.0] - 2025-12-31

### Changed
- **Changemap for all players** - `.changemap` now available to ALL players (no admin flag required)
- **Consolidated version announcement** - Single message on admin join

## [2.4.0] - 2025-12-29

### Added
- **Map Change Command** - `.changemap` / `/changemap` menu-based map selection
  - Maps loaded from `ktp_maps.ini` (shared with KTPMatchHandler)
  - Shows display name with actual map filename in parentheses
  - Requires ADMIN_MAP flag ("f")
  - Discord audit logging with from/to map names
- `ktp_changemap` console command for map menu access

### Notes
- ADMIN_MAP is flag "f" (not "g" as sometimes documented)

## [2.3.1] - 2025-12-29

### Fixed
- Skip logging `_restart` in ExecuteServerStringCmd hook (already logged by admin command)
- Skip RCON source in ExecuteServerStringCmd hook (already caught by RH_SV_Rcon)

## [2.3.0] - 2025-12-29

### Added
- **Console Command Audit** - RH_ExecuteServerStringCmd hook to audit ALL console commands
  - Catches quit/restart commands from LinuxGSM (via tmux), not just RCON
  - Logs source type (Console, RCON, Redirect) to Discord
- **Admin Server Control Commands** - `.restart` and `.quit` say commands
  - Requires ADMIN_RCON flag ("l")
  - Full Discord audit logging with admin name and SteamID
  - 1-second delay for Discord message before execution
- **HLTV Kick Support** - HLTV proxies now appear in `.kick` player menu
  - Changed get_players filter from "ch" to "c" to include HLTV

### Requirements
- KTP-ReHLDS with RH_ExecuteServerStringCmd hook support
- KTP-ReAPI v5.29.0.361-ktp+ with ExecuteServerStringCmd hookchain

## [2.2.0] - 2025-12-23

### Added
- **RCON Audit Logging** - Server control commands logged via RH_SV_Rcon hook
  - Logs `quit`, `exit`, `restart`, `_restart` RCON commands
  - Discord notifications to all audit channels
  - Shows command and source IP for accountability

### Requirements
- KTP-ReHLDS with SV_Rcon hook support
- KTP-ReAPI v5.29.0.361-ktp+ with RH_SV_Rcon hookchain

## [2.1.0] - 2025-12-21

### Changed
- **ktp_drop_client native** - Uses new KTPAMXX native instead of `server_cmd("kick")`
  - Calls ReHLDS `DropClient` API directly
  - Bypasses blocked kick console command in KTP ReHLDS
  - Requires KTP AMX 2.5+ with ReHLDS API integration

### Fixed
- Kick execution now works with KTP ReHLDS where kick command is blocked at engine level

### Build
- Updated compile.bat to use WSL with KTPAMXX Linux compiler
- Automatic staging to server plugins directory

## [2.0.0] - 2025-12-20

### Added
- **Menu-based kick/ban** - Interactive player selection menus
- **Ban duration selection** - 1 hour, 1 day, 1 week, or permanent
- **Admin flag permissions** - ADMIN_KICK (c) for kick, ADMIN_BAN (d) for ban
- **Immunity protection** - Players with ADMIN_IMMUNITY (a) cannot be kicked/banned
- `.kick` and `/kick` commands for kick menu
- `.ban` and `/ban` commands for ban menu

### Changed
- Complete rewrite from RCON interception to menu-based system
- Admins must be **connected to server** to use kick/ban
- All actions require appropriate admin flags in users.ini

### Removed
- RCON kick command interception (no longer needed)
- Console-based kick command hook

### Security
- Prevents remote/untraceable kicks via HLSW or RCON
- Full audit trail: admin name, SteamID, IP, target details, action

## [1.3.0] - 2025-12-20

### Changed
- Now uses `ktp_discord.inc` for shared Discord configuration loading
- Unified Discord integration with other KTP plugins

## [1.2.0] - 2025-12-03

### Fixed
- Changed from `register_srvcmd` to `register_concmd` for kick command interception
  - `register_srvcmd` cannot hook built-in engine commands like `kick`
  - Now properly intercepts kick commands before engine processes them
- Use `get_configsdir()` for dynamic config path resolution

### Improved
- Now works properly with both KTP AMX and standard AMX Mod X
- Documentation updated to reflect dynamic path handling

## [1.1.0] - 2025-11-24

### Added
- Multi-channel support - sends to ALL configured audit channels
- Per-match-type audit channels (competitive, 12man, scrim)

### Changed
- Now collects any key containing `discord_channel_id_audit` or `discord_channel_id_admin`

### Improved
- Better configuration flexibility with up to 10 audit channels
- Detailed logging shows which channels received notifications

## [1.0.0] - 2025-11-24

### Added
- Initial release
- RCON kick detection and logging
- Discord notification with admin and target details
- SteamID, name, and IP logging for accountability
- Separate admin audit Discord channel support
- AMX log integration
- cURL-based Discord webhook support
