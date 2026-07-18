/* KTP Admin Audit v2.7.18
 * Menu-based admin kick/ban/changemap with full audit logging
 *
 * AUTHOR: Nein_
 * VERSION: 2.7.18
 * DATE: 2026-07-18
 * GITHUB: https://github.com/afraznein/KTPAdminAudit
 *
 * ========== OVERVIEW ==========
 * Provides secure, auditable kick and ban functionality. Unlike RCON-based
 * commands, this plugin requires admins to be connected to the server and
 * logs all actions to Discord for accountability.
 *
 * Designed to work with ReHLDS that has kick/ban commands blocked at the
 * engine level, ensuring all player removals go through this audited system.
 *
 * ========== FEATURES ==========
 * - Menu-based player selection for kick/ban
 * - Admin flag-based permissions (ADMIN_KICK, ADMIN_BAN)
 * - Ban duration selection (1 hour, 1 day, 1 week, permanent)
 * - Full Discord audit logging to all configured audit channels
 * - Immunity protection (ADMIN_IMMUNITY)
 * - Pagination for servers with many players
 * - Failed attempt logging
 *
 * ========== REQUIREMENTS ==========
 * - KTP AMX / AMX Mod X 1.9+
 * - KTP ReHLDS with kick/ban commands blocked (recommended)
 * - ktp_discord.inc (shared Discord integration)
 *
 * ========== COMMANDS ==========
 *   .kick / /kick          - Open kick menu (requires ADMIN_KICK flag "c")
 *   .ban  / /ban           - Open ban menu (requires ADMIN_BAN flag "d")
 *   .unban <steamid>       - Lift a ban: removeid + writeid + timed-ban
 *                            record removal (requires ADMIN_BAN flag "d")
 *   .changemap / /changemap - Open map change menu (available to ALL players)
 *   .restart / /restart    - Restart server (requires ADMIN_RCON flag "l")
 *   .quit / /quit          - Shutdown server (requires ADMIN_RCON flag "l")
 *
 * ========== ADMIN FLAGS ==========
 *   c - ADMIN_KICK     - Required to kick players
 *   d - ADMIN_BAN      - Required to ban players
 *   l - ADMIN_RCON     - Required for .restart / .quit commands
 *   a - ADMIN_IMMUNITY - Protected from kick/ban
 *
 * ========== CONFIGURATION ==========
 * Uses shared discord.ini via ktp_discord.inc
 * Path: <configsdir>/discord.ini
 *
 * Audit messages are sent to all channels matching:
 *   discord_channel_id_audit*
 *   discord_channel_id_admin
 *
 * Timed-ban persistence file: <configsdir>/ktp_timed_bans.ini
 * (engine writeid only saves permanent filters; timed bans are recorded with
 * their unban epoch and re-applied at boot for the remaining time)
 *
 * ========== CHANGELOG ==========
 * v2.7.18 (2026-07-18) - .changemap match-liveness TOCTOU closed. The map menu
 *                        has an unbounded timeout and the countdown runs 5s, so
 *                        a match could go live after the menu opened (liveness
 *                        was checked only once, at menu open) and the changelevel
 *                        would then force-end it (MatchHandler ends the match on
 *                        ANY changelevel). Now re-checked at execute time and
 *                        every countdown tick incl. the fire, plus the safety
 *                        fallback — aborts + clears the lock if a match is live.
 * v2.7.17 (2026-07-08) - .unban <steamid>: removeid + deferred writeid +
 *                        timed-ban record removal in one audited command
 *                        (closes the manual-removeid re-ban trap); strict
 *                        SteamID shape validation before server_cmd
 * v2.7.16 (2026-07-08) - Wave-2 fixes: stale changemap lock, actor re-check,
 *                        timed-ban persistence, RCON failure batching
 *   * FIXED: .changemap lock survived map changes (globals persist in extension
 *     mode) with a gametime stamp from the previous map — negative lockAge
 *     defeated the 15s timeout, letting a stale lock supersede ANY changelevel
 *     (incl. match half transitions) for ~20min of new-map gametime. Lock
 *     globals now reset in plugin_cfg; timeout treats negative age as expired.
 *   * FIXED: acting admin's flags now re-checked at kick/ban execute time
 *     (2.7.15 covered target immunity; a de-authed admin could still finish
 *     a queued action).
 *   + ADDED: timed-ban persistence via ktp_timed_bans.ini — timed bans died at
 *     the nightly restart because writeid only saves permanent filters. Each
 *     timed ban is recorded with its unban epoch and re-applied at boot for
 *     the remaining minutes; expired entries are dropped and logged.
 *   + ADDED: failed RCON auth attempts (is_valid=false, fires on .928+ engine)
 *     are now consumed — each logged locally, batched per source IP into ONE
 *     Discord summary embed per 60s window (relay has no queue).
 *   * FIXED: kick-only drop reason no longer claims a ban duration.
 *   * FIXED: console _restart is now audited like other control commands
 *     (our own .restart-issued _restart is debounced, not double-logged).
 *   * FIXED: ban menu state cleared when the target disconnects mid-menu;
 *     g_validPlayerCount now cleared on disconnect.
 *   * FIXED: one-frame window at countdown zero where a second .changemap
 *     could start before the queued changelevel flushed — the lock is now
 *     held through the changelevel and cleared on the new map.
 *   * CHANGED: countdown HUD/chat announcements use the map display name.
 *
 * v2.7.15 (2026-07-06) - Ban-flow immunity re-check + label/comment fixes
 *   * FIXED: immunity checked only at player-select — flags granted between
 *     the select and duration menus (re-auth, live grant) could still ban an
 *     immune player. execute_ban now re-checks next to the auth TOCTOU guard.
 *   * FIXED: "1 Week" menu label logged/announced as "7 days" — duration
 *     string builder gained a weeks tier.
 *   * FIXED: get_players "c" comment claimed "connected" (flag = skip bots).
 *
 * v2.7.14 (2026-06-12) - Fix Changemap Wedging Destination Map's Task Scheduler (PR #1)
 *   * FIXED: .changemap countdown wedged the next map's AMXX task scheduler.
 *     server_exec() in task_changelevel_countdown() (and the safety fallback) ran the
 *     changelevel synchronously inside the task callback, leaving every set_task() on
 *     the new map registered (task_exists==1) but never dispatched — silently killing
 *     repeating tasks in other plugins (notably KTPHudObserver's HUD/cap polling went
 *     dead for the whole map). Removed server_exec(); the queued changelevel flushes on
 *     the next engine frame. The v2.7.6 server_exec() was only needed for the old
 *     hook-supercede path that v2.7.7 removed.
 *   * FIXED: header/VERSION said 2.7.12 while PLUGIN_VERSION define was 2.7.13 — reconciled.
 *   * Contributed by Cadaver (JimmyLockhart65616), repro'd + verified on the local stack.
 *
 * v2.7.11 (2026-03-13) - Code Review Fixes
 *   * FIXED: Slot recycling TOCTOU — store SteamID at menu selection, validate before kick/ban
 *   * FIXED: banid not flushed before drop — added server_exec() before ktp_drop_client
 *   * FIXED: STEAM_ID_PENDING/LAN/BOT bans silently fail — now warns admin, kick-only
 *   * FIXED: Empty player list infinite menu redisplay — early-out guard
 *   * FIXED: INI name key prefix match — split on '=' before comparing key
 *   * FIXED: Dead case 1 in hook_ExecuteServerStringCmd switch — removed unreachable branch
 *   * FIXED: Header version mismatch (was v2.7.9, define was 2.7.10)
 *
 * v2.7.9 (2026-03-13) - Task ID Safety + Ban Flush
 *   * FIXED: fn_show_version task used raw player ID — could collide on reconnect
 *   * FIXED: banid/writeid not flushed with server_exec() — ban could be lost on crash
 *   + CHANGED: Changemap task IDs from mutable globals to #define constants
 *   + CHANGED: containi → contain in INI parser for consistency
 *   * FIXED: fn_execute_restart/fn_execute_quit used implicit task ID 0
 *   + ADDED: server_exec() after _restart and quit commands for consistency
 *   + ADDED: Source constant documentation on hook_ExecuteServerStringCmd
 *
 * v2.7.8 (2026-03-11) - Add Safety Fallback for Changemap Countdown
 *   * FIXED: set_task(1.0, ..., .flags="b") intermittently fails to register,
 *     causing the changelevel lock to get stuck for 8+ minutes until safety timeout.
 *     Added a single-fire safety task that executes changelevel after countdown+5s
 *     if the repeating countdown task never fired.
 *   + ADDED: TASK_CHANGELEVEL_SAFETY for safety fallback task
 *   * NOTE: Reported 3 failures on NY servers (Mar 1, 6, 8)
 *
 * v2.7.7 (2026-03-08) - Fix Intermittent Changemap Countdown Failure
 *   * FIXED: .changemap countdown started but never completed (~10% failure rate).
 *     execute_changemap() used a roundabout path: server_cmd("changelevel") → hook
 *     intercepts → HC_SUPERCEDE → start_changelevel_countdown(). set_task() called
 *     from inside the hookchain handler intermittently failed to register the task.
 *     Now calls start_changelevel_countdown() directly — no hook interaction needed.
 *   * REMOVED: g_changeLevelPending flag (no longer needed without hook-based routing)
 *   * NOTE: Reported on Denver 1, March 8 2026 — analysis found 4 failures across
 *     ATL2, DEN1, NY1 in March alone, all post-v2.7.6
 *
 * v2.7.6 (2026-03-04) - Fix Changemap Countdown Not Executing
 *   * FIXED: .changemap countdown completed but map never changed — server_cmd("changelevel")
 *     in task_changelevel_countdown() was not followed by server_exec(), so the command
 *     sat in the buffer and was never processed. Added server_exec() after server_cmd.
 *   + ADDED: Debug log at countdown=0 to confirm task fires for future troubleshooting
 *   * NOTE: Reported on Chicago 2 (27016), March 3 2026 — 3 consecutive failures
 *
 * v2.7.5 (2026-02-25) - Changemap Race Condition & Menu Buffer Fix
 *   * FIXED: Two players could open .changemap menu simultaneously and both
 *     complete a selection — second selection overwrote the first's countdown,
 *     sending duplicate Discord audit messages
 *   + ADDED: g_changeMapInProgress check in execute_changemap() (was only in cmd_changemap)
 *   * FIXED: Map and player menu buffers (512 bytes) could truncate with long names,
 *     cutting off navigation controls (Next/Prev/Cancel)
 *   + CHANGED: Menu buffers increased from 512 to 1024 bytes
 *
 * v2.7.4 (2026-02-19) - Fix Stuck Changelevel Lock
 *   * FIXED: g_changeMapInProgress lock could get permanently stuck if countdown
 *     task failed to fire (e.g., plugin reload mid-countdown), blocking ALL future
 *     changelevel attempts including mapcycle and manual console commands
 *   + ADDED: 15-second safety timeout on changelevel lock - auto-resets if expired
 *   + ADDED: Log warning when lock timeout triggers
 *   * NOTE: Caused 160ms phys spikes on NY 27015 for 3+ hours (2026-02-19) due to
 *     engine repeatedly attempting blocked changelevel in physics loop
 *
 * v2.7.2 (2026-01-20) - Fix Concurrent Changemap Crash
 *   * FIXED: Server crash when two players use .changemap simultaneously
 *   + ADDED: g_changeMapInProgress lock to prevent concurrent requests
 *   + ADDED: Block other changelevel commands during active countdown
 *   * NOTE: Reported crash on Atlanta 2, January 18 2026
 *
 * v2.7.1 (2026-01-11) - Block RCON Quit/Exit
 *   + ADDED: RCON quit/exit commands now BLOCKED (returns HC_SUPERCEDE)
 *   + ADDED: Discord alert when RCON quit/exit is blocked (shows source IP)
 *   * SECURITY: Prevents anonymous server shutdowns via RCON
 *   * NOTE: Use .quit in-game for audited server shutdown
 *
 * v2.6.0 (2026-01-01) - Changelevel Hook with Countdown
 *   + ADDED: RH_Host_Changelevel_f hook for .changemap (KTP-ReHLDS)
 *   + ADDED: 5-second countdown before map change with HUD display
 *   + ADDED: Chat announcements during countdown
 *   * CHANGED: .changemap now supersedes engine changelevel for countdown
 *   * TECHNICAL: Uses Host_Changelevel_f hook (console changelevel command)
 *
 * v2.5.1 (2025-12-31) - Block Changemap During Matches
 *   + ADDED: Uses ktp_is_match_active() native from KTPMatchHandler
 *   * CHANGED: .changemap blocked during active matches (live, pending, prestart)
 *
 * v2.5.0 (2025-12-31) - Changemap for All Players
 *   * CHANGED: .changemap now available to ALL players (no admin flag required)
 *   * CHANGED: Consolidated version announcement to single message
 *
 * v2.4.0 (2025-12-29) - Map Change Command
 *   + ADDED: .changemap / /changemap command with menu-based map selection
 *   + ADDED: Map list loaded from ktp_maps.ini (shared with KTPMatchHandler)
 *   + ADDED: Shows display name and actual map filename in menu
 *   + ADDED: Discord audit logging for map changes
 *
 * v2.3.1 (2025-12-29) - Fix Discord Spam on .restart/.quit
 *   * FIXED: Skip logging _restart in ExecuteServerStringCmd (already logged by admin command)
 *   * FIXED: Skip RCON source in ExecuteServerStringCmd (already caught by RH_SV_Rcon)
 *
 * v2.3.0 (2025-12-29) - Console Command Audit & Admin Aliases
 *   + ADDED: RH_ExecuteServerStringCmd hook to audit ALL console commands (not just RCON)
 *   + ADDED: .restart / .quit admin say commands with Discord audit
 *   + ADDED: HLTV proxies now appear in .kick menu (previously excluded)
 *   * CHANGED: Console commands like quit/restart from LinuxGSM are now logged
 *
 * v2.2.0 (2025-12-23) - RCON Audit Logging
 *   + ADDED: RCON quit/exit/restart command logging via RH_SV_Rcon hook
 *   + ADDED: Discord notifications for server control commands
 *   * REQUIRES: KTP-ReHLDS and KTP-ReAPI with SV_Rcon hook support
 *
 * v2.1.0 (2025-12-21) - ReHLDS DropClient Integration
 *   * CHANGED: Uses ktp_drop_client native instead of server_cmd("kick")
 *   * CHANGED: Works with ReHLDS where kick command is blocked at engine level
 *   + ADDED: ktp_drop_client calls ReHLDS DropClient API directly
 *
 * v2.0.0 (2025-12-20) - Complete Overhaul
 *   * REPLACED: Old RCON interception with menu-based kick/ban system
 *   + ADDED: Menu-based kick command (.kick)
 *   + ADDED: Menu-based ban command (.ban) with duration selection
 *   + ADDED: Ban durations: 1 hour, 1 day, 1 week, permanent
 *   + ADDED: Immunity protection (ADMIN_IMMUNITY flag)
 *   + ADDED: Pagination for player selection menus
 *   + ADDED: Failed attempt logging
 *   * CHANGED: Uses ktp_discord.inc for Discord integration
 *   * CHANGED: Designed for ReHLDS with blocked kick/ban commands
 *   - REMOVED: RCON command interception (obsolete with ReHLDS changes)
 *
 * v1.3.0 (2025-12-20) - Shared Discord Config
 *   * CHANGED: Now uses ktp_discord.inc for config loading
 *
 * v1.2.0 (2025-12-03) - KTP AMX Compatibility
 *   * FIXED: Changed from register_srvcmd to register_concmd
 *
 * v1.1.0 (2025-11-24) - Multi-Channel Audit Support
 *   + ADDED: Per-match-type audit channels
 *
 * v1.0.0 (2025-11-24) - Initial Release
 *   + ADDED: RCON kick detection and logging
 */

#include <amxmodx>
#include <amxmisc>
#include <ktp_discord>
#include <ktp_version_reporter>
#include <reapi>

#pragma semicolon 1

// KTP native for dropping clients via ReHLDS API (bypasses blocked kick command)
native ktp_drop_client(id, const reason[] = "");

// KTP native to check if match is in progress (from KTPMatchHandler)
native ktp_is_match_active();

#define PLUGIN_NAME    "KTP Admin Audit"
#define PLUGIN_VERSION "2.7.18"
#define PLUGIN_AUTHOR  "Nein_"

// Menu action constants
#define ACTION_NONE      0
#define ACTION_KICK      1
#define ACTION_BAN       2
#define ACTION_CHANGEMAP 3

// Map list
#define MAX_MAPS 64
new g_mapList[MAX_MAPS][32];      // Actual map filename (e.g., dod_anzio)
new g_mapNames[MAX_MAPS][32];     // Display name (e.g., Anzio)
new g_mapCount = 0;

// Menu state per player
new g_menuAction[33];       // ACTION_NONE, ACTION_KICK, or ACTION_BAN
new g_menuTarget[33];       // Selected target player id
new g_menuTargetAuth[33][35]; // SteamID at selection time (TOCTOU guard)
new g_menuPage[33];         // Current menu page for pagination
new g_validPlayers[33][32]; // Valid player indices for each admin
new g_validPlayerCount[33]; // Count of valid players

// Ban duration options (in minutes, 0 = permanent)
new const g_banDurations[] = { 60, 1440, 10080, 0 };
new const g_banDurationNames[][] = { "1 Hour", "1 Day", "1 Week", "Permanent" };

// Task ID offsets (must not collide with player IDs 1-32 or each other)
#define TASK_VERSION_BASE 5000       // Version message: id + TASK_VERSION_BASE
#define TASK_CHANGELEVEL 54321       // Changelevel countdown
#define TASK_CHANGELEVEL_SAFETY 54322 // Changelevel safety fallback
#define TASK_RESTART 54323            // Delayed server restart
#define TASK_QUIT 54324               // Delayed server quit
#define TASK_FLUSH_BANLIST 54325      // Deferred writeid after ban
#define TASK_RCON_FAIL_FLUSH 54326    // Batched RCON failure summary
#define TASK_FLUSH_BAN_RECORDS 54327  // Deferred timed-ban record append

// Timed-ban records are buffered and appended 0.1s later (same pattern as
// task_flush_banlist) so the fopen/fprintf/fclose never runs on the game
// thread inside the menu-handler frame — mid-match bans are exactly when a
// consumer-SSD journal stall would hurt.
#define MAX_PENDING_BAN_RECORDS 4
new g_pendingBanLines[MAX_PENDING_BAN_RECORDS][192];
new g_pendingBanLineCount = 0;

// Pending .unban file removals — same deferred-I/O discipline. Chronology is
// kept order-independent: a new ban cancels a same-sid pending unban, and a
// new unban drops same-sid pending ban lines, so flush order can't resurrect
// either side.
#define TASK_FLUSH_UNBANS 54328
new g_pendingUnbanSids[MAX_PENDING_BAN_RECORDS][44];
new g_pendingUnbanCount = 0;

// Changelevel hook variables
new g_pendingChangeMap[64];          // Map to change to after countdown
new g_pendingChangeMapDisplay[32];   // Display name for HUD/chat announcements
new g_changeMapCountdown = 0;        // Countdown seconds remaining
new bool:g_changeMapInProgress = false; // Lock to prevent concurrent .changemap requests
new Float:g_changeMapLockTime = 0.0;   // Timestamp when lock was set (for safety timeout)
const CHANGELEVEL_COUNTDOWN_SECS = 5;   // Seconds to wait before map change
const Float:CHANGELEVEL_LOCK_TIMEOUT = 15.0; // Safety timeout to prevent permanent lock

// Debounces the ExecuteServerStringCmd audit for the _restart we issue
// ourselves from .restart (already audited by cmd_restart)
new bool:g_ownRestartPending = false;

// Timed-ban persistence — engine writeid only saves permanent filters
// (banTime==0), so a timed banid evaporates at the nightly restart. Every
// timed ban is recorded with its unban epoch and re-applied at boot.
#define TIMED_BANS_FILE "ktp_timed_bans.ini"
#define MAX_TIMED_BANS 64
new bool:g_timedBansReapplied = false; // globals persist across map changes — latches reapply to once per boot

// RCON failure batching — the Discord relay has no queue and failed-rcon
// storms can hit 60/min (over Discord limits), so failures accumulate per
// source IP and flush as ONE summary embed per 60s window.
#define MAX_RCON_FAIL_IPS 16
new g_rconFailIp[MAX_RCON_FAIL_IPS][24];      // "ip:port" fits 22 chars
new g_rconFailCount[MAX_RCON_FAIL_IPS];
new g_rconFailFirst[MAX_RCON_FAIL_IPS];       // systime of first failure in window
new g_rconFailLast[MAX_RCON_FAIL_IPS];        // systime of latest failure
new g_rconFailLastCmd[MAX_RCON_FAIL_IPS][32]; // command name only (passwords stripped engine-side)
new g_rconFailIpCount = 0;
new g_rconFailOverflow = 0;                   // failures from IPs past table capacity

public plugin_init()
{
	register_plugin(PLUGIN_NAME, PLUGIN_VERSION, PLUGIN_AUTHOR);
	KTP_RegisterVersion(PLUGIN_NAME, PLUGIN_VERSION);

	// Register kick commands
	register_clcmd("say .kick", "cmd_kick");
	register_clcmd("say_team .kick", "cmd_kick");
	register_clcmd("say /kick", "cmd_kick");
	register_clcmd("say_team /kick", "cmd_kick");
	register_clcmd("ktp_kick", "cmd_kick");  // Console command

	// Register ban commands
	register_clcmd("say .ban", "cmd_ban");
	register_clcmd("say_team .ban", "cmd_ban");
	register_clcmd("say /ban", "cmd_ban");
	register_clcmd("say_team /ban", "cmd_ban");
	register_clcmd("ktp_ban", "cmd_ban");  // Console command

	register_clcmd("say .unban", "cmd_unban");
	register_clcmd("say_team .unban", "cmd_unban");
	register_clcmd("say /unban", "cmd_unban");
	register_clcmd("say_team /unban", "cmd_unban");
	register_clcmd("ktp_unban", "cmd_unban");  // Console command

	// Menu handlers
	register_menucmd(register_menuid("KTP Kick Menu"), 1023, "menu_player_handler");
	register_menucmd(register_menuid("KTP Ban Menu"), 1023, "menu_player_handler");
	register_menucmd(register_menuid("KTP Ban Duration"), 1023, "menu_duration_handler");
	register_menucmd(register_menuid("KTP Map Menu"), 1023, "menu_map_handler");

	// Register .restart / .quit admin commands
	register_clcmd("say .restart", "cmd_restart");
	register_clcmd("say_team .restart", "cmd_restart");
	register_clcmd("say /restart", "cmd_restart");
	register_clcmd("say_team /restart", "cmd_restart");
	register_clcmd("say .quit", "cmd_quit");
	register_clcmd("say_team .quit", "cmd_quit");
	register_clcmd("say /quit", "cmd_quit");
	register_clcmd("say_team /quit", "cmd_quit");

	// Register .changemap admin command
	register_clcmd("say .changemap", "cmd_changemap");
	register_clcmd("say_team .changemap", "cmd_changemap");
	register_clcmd("say /changemap", "cmd_changemap");
	register_clcmd("say_team /changemap", "cmd_changemap");
	register_clcmd("ktp_changemap", "cmd_changemap");  // Console command

	// Register RCON audit hook (KTP-ReHLDS/KTP-ReAPI)
	RegisterHookChain(RH_SV_Rcon, "hook_SV_Rcon", false);

	// Register console command audit hook (catches LinuxGSM quit/restart via tmux)
	RegisterHookChain(RH_ExecuteServerStringCmd, "hook_ExecuteServerStringCmd", false);

	// Register console changelevel hook (KTP-ReHLDS) - intercepts server_cmd("changelevel") for countdown
	RegisterHookChain(RH_Host_Changelevel_f, "hook_Host_Changelevel_f", false);

	// Tasks are cleared on map change — re-register the failure-summary window
	// every map. Window data lives in globals, so it survives the change.
	remove_task(TASK_RCON_FAIL_FLUSH);
	set_task(60.0, "task_flush_rcon_failures", TASK_RCON_FAIL_FLUSH, .flags = "b");

	set_task(0.1, "task_log_init");
}

public task_log_init()
{
	log_amx("[%s] v%s initialized (changelevel hook active)", PLUGIN_NAME, PLUGIN_VERSION);
}

public plugin_cfg()
{
	// Load shared Discord configuration
	ktp_discord_load_config();

	// Load map list from ktp_maps.ini
	load_map_list();

	// Globals persist across map changes in extension mode — a lock carried
	// over holds a gametime stamp from the PREVIOUS map's clock, which reads
	// as negative age on the new map and would supersede every changelevel.
	// Always start a map with the lock clear.
	reset_changemap_lock();

	// A ban/unban issued <0.1s before a changelevel loses its flush task to
	// the per-map task clear; the buffered entries survive in globals, so
	// flush them on the new map before anything else touches the file.
	// Ban appends before unban removals — the pending sets are already
	// chronology-reconciled, so this order is just append-then-filter.
	if (g_pendingBanLineCount > 0)
		task_flush_ban_records();
	if (g_pendingUnbanCount > 0)
		task_flush_unbans();

	// Re-apply persisted timed bans once per boot (latch survives map changes)
	if (!g_timedBansReapplied)
	{
		g_timedBansReapplied = true;
		reapply_timed_bans();
	}
}

public client_putinserver(id)
{
	// Announce to admins with a delay
	if (!is_user_bot(id) && !is_user_hltv(id))
	{
		if (get_user_flags(id) & (ADMIN_KICK | ADMIN_BAN))
		{
			set_task(5.0, "fn_show_version", id + TASK_VERSION_BASE);
		}
	}
}

public fn_show_version(taskid)
{
	new id = taskid - TASK_VERSION_BASE;
	if (id < 1 || id > MAX_PLAYERS || !is_user_connected(id))
		return;

	client_print(id, print_chat, "%s version %s by %s", PLUGIN_NAME, PLUGIN_VERSION, PLUGIN_AUTHOR);
}

public client_disconnected(id)
{
	// Clear menu state
	g_menuAction[id] = ACTION_NONE;
	g_menuTarget[id] = 0;
	g_menuTargetAuth[id][0] = EOS;
	g_menuPage[id] = 0;
	g_validPlayerCount[id] = 0;
	remove_task(id + TASK_VERSION_BASE);

	// Cancel any admin mid-kick/ban-flow on this target — the slot can be
	// recycled before they finish. The auth TOCTOU guard would catch the swap
	// at execute, but the dangling state kept a stale duration menu alive.
	// Scoped to kick/ban: g_menuTarget can hold a stale slot from a COMPLETED
	// action (nothing clears it on finish), so matching other action types
	// would cross-fire on unrelated menus (e.g. .changemap).
	for (new admin = 1; admin <= MAX_PLAYERS; admin++)
	{
		if (admin == id)
			continue;
		if ((g_menuAction[admin] == ACTION_KICK || g_menuAction[admin] == ACTION_BAN)
			&& g_menuTarget[admin] == id)
		{
			g_menuAction[admin] = ACTION_NONE;
			g_menuTarget[admin] = 0;
			g_menuTargetAuth[admin][0] = EOS;
			if (is_user_connected(admin))
				client_print(admin, print_chat, "[KTP] Target player disconnected - action cancelled.");
		}
	}
}

// ===========================================================================
// Kick Command
// ===========================================================================

public cmd_kick(id)
{
	// Check admin flag
	if (!(get_user_flags(id) & ADMIN_KICK))
	{
		client_print(id, print_chat, "[KTP] You don't have permission to kick players.");
		log_failed_attempt(id, "kick");
		return PLUGIN_HANDLED;
	}

	// Build list of kickable players
	if (!build_player_list(id, true))
	{
		client_print(id, print_chat, "[KTP] No players available to kick.");
		return PLUGIN_HANDLED;
	}

	// Show player selection menu — clear any stale target so the disconnect
	// sweep only matches a real selection from THIS flow
	g_menuAction[id] = ACTION_KICK;
	g_menuTarget[id] = 0;
	g_menuTargetAuth[id][0] = EOS;
	g_menuPage[id] = 0;
	show_player_menu(id);

	return PLUGIN_HANDLED;
}

// ===========================================================================
// Ban Command
// ===========================================================================

public cmd_ban(id)
{
	// Check admin flag
	if (!(get_user_flags(id) & ADMIN_BAN))
	{
		client_print(id, print_chat, "[KTP] You don't have permission to ban players.");
		log_failed_attempt(id, "ban");
		return PLUGIN_HANDLED;
	}

	// Build list of bannable players
	if (!build_player_list(id, true))
	{
		client_print(id, print_chat, "[KTP] No players available to ban.");
		return PLUGIN_HANDLED;
	}

	// Show player selection menu — clear any stale target so the disconnect
	// sweep only matches a real selection from THIS flow
	g_menuAction[id] = ACTION_BAN;
	g_menuTarget[id] = 0;
	g_menuTargetAuth[id][0] = EOS;
	g_menuPage[id] = 0;
	show_player_menu(id);

	return PLUGIN_HANDLED;
}

// ===========================================================================
// Unban Command
// removeid alone is not enough: writeid persists the removal for permanent
// filters, and the timed-ban file line must go too or the next boot's
// reapply silently re-bans (the manual-removeid trap).
// ===========================================================================

// STEAM_X:Y:Z — X and Y single digits, Z one or more digits. Deliberately
// strict: exotic shapes can be removeid'd from the console by hand.
stock bool:is_valid_steamid_shape(const sid[])
{
	if (!equal(sid, "STEAM_", 6)) return false;
	if (!isdigit(sid[6]) || sid[7] != ':') return false;
	if (!isdigit(sid[8]) || sid[9] != ':') return false;
	if (!sid[10]) return false;
	for (new i = 10; sid[i]; i++)
	{
		if (!isdigit(sid[i])) return false;
	}
	return true;
}

public cmd_unban(id)
{
	if (!(get_user_flags(id) & ADMIN_BAN))
	{
		client_print(id, print_chat, "[KTP] You don't have permission to unban players.");
		log_failed_attempt(id, "unban");
		return PLUGIN_HANDLED;
	}

	new args[96];
	read_args(args, charsmax(args));
	remove_quotes(args);
	trim(args);

	// say-path arrives as ".unban STEAM_..." — strip the command token;
	// the ktp_unban console path arrives as bare args.
	if (args[0] == '.' || args[0] == '/')
	{
		new pos = contain(args, " ");
		if (pos == -1)
			args[0] = EOS;
		else
		{
			new stripped[96];
			copy(stripped, charsmax(stripped), args[pos + 1]);
			copy(args, charsmax(args), stripped);
			trim(args);
		}
	}

	// Strict STEAM_X:Y:Z shape — nothing else may reach server_cmd. The
	// command buffer splits on ';' outside quotes, so a loose prefix check
	// would let an ADMIN_BAN admin smuggle ADMIN_RCON-tier commands
	// (`.unban STEAM_0:0:1;quit`) past both the privilege gate and the
	// audit trail; an unmatched '"' could swallow adjacent buffered cmds.
	if (!is_valid_steamid_shape(args))
	{
		client_print(id, print_chat, "[KTP] Usage: .unban STEAM_0:X:Y");
		return PLUGIN_HANDLED;
	}

	new adminName[32], adminAuth[44];
	get_user_name(id, adminName, charsmax(adminName));
	get_user_authid(id, adminAuth, charsmax(adminAuth));

	// In-memory filter now; writeid (persists the removal of permanent
	// filters) rides the same deferred task the ban path uses — engine ban
	// files are disk I/O too. The timed-ban file line goes via the deferred
	// rewrite.
	server_cmd("removeid %s", args);
	server_exec();
	remove_task(TASK_FLUSH_BANLIST);
	set_task(0.1, "task_flush_banlist", TASK_FLUSH_BANLIST);
	queue_timed_ban_removal(args);

	client_print(id, print_chat, "[KTP] Unbanned %s (filter removed; persisted-record removal queued).", args);
	log_amx("[KTP] UNBAN target=%s admin='%s' admin_steamid=%s", args, adminName, adminAuth);

	new description[256];
	formatex(description, charsmax(description),
		"**Admin:** %s (`%s`)^n**Target:** `%s`^n**Action:** removeid + writeid + timed-ban record removal",
		adminName, adminAuth, args);
	ktp_discord_send_embed_audit("<:KTP:1002382703020212245> Admin UNBAN", description, KTP_DISCORD_COLOR_ORANGE);

	return PLUGIN_HANDLED;
}

queue_timed_ban_removal(const sid[])
{
	// Chronology: an unban supersedes any same-sid ban line still waiting to
	// be appended. Prefix compare against "sid|" — sid is field 1 and can't
	// contain '|'.
	new sidLen = strlen(sid);
	for (new i = 0; i < g_pendingBanLineCount; i++)
	{
		if (equal(g_pendingBanLines[i], sid, sidLen) && g_pendingBanLines[i][sidLen] == '|')
		{
			// compact the pending array over the superseded line
			for (new j = i + 1; j < g_pendingBanLineCount; j++)
				copy(g_pendingBanLines[j - 1], charsmax(g_pendingBanLines[]), g_pendingBanLines[j]);
			g_pendingBanLineCount--;
			i--;
		}
	}

	// Already queued? (double .unban)
	for (new i = 0; i < g_pendingUnbanCount; i++)
	{
		if (equal(g_pendingUnbanSids[i], sid))
			return;
	}

	if (g_pendingUnbanCount >= MAX_PENDING_BAN_RECORDS)
		task_flush_unbans();

	copy(g_pendingUnbanSids[g_pendingUnbanCount], charsmax(g_pendingUnbanSids[]), sid);
	g_pendingUnbanCount++;

	remove_task(TASK_FLUSH_UNBANS);
	set_task(0.1, "task_flush_unbans", TASK_FLUSH_UNBANS);
}

public task_flush_unbans()
{
	if (g_pendingUnbanCount <= 0)
		return;

	new path[192];
	get_timed_bans_path(path, charsmax(path));

	new file = fopen(path, "r");
	if (!file)
	{
		// No file = nothing persisted = nothing to remove.
		g_pendingUnbanCount = 0;
		return;
	}

	// Same static-buffer approach as reapply_timed_bans — too big for the
	// AMX stack, touched only on unban.
	static keptLines[MAX_TIMED_BANS][192];
	new keptCount = 0, removedCount = 0;
	new line[192];
	while (!feof(file) && keptCount < MAX_TIMED_BANS)
	{
		fgets(file, line, charsmax(line));
		trim(line);
		if (!line[0])
			continue;

		// Prefix compare against "sid|" — sid is field 1, can't contain '|'.
		new bool:drop = false;
		for (new i = 0; i < g_pendingUnbanCount; i++)
		{
			new sidLen = strlen(g_pendingUnbanSids[i]);
			if (equal(line, g_pendingUnbanSids[i], sidLen) && line[sidLen] == '|')
			{
				drop = true;
				break;
			}
		}
		if (drop)
		{
			removedCount++;
			continue;
		}
		copy(keptLines[keptCount], charsmax(keptLines[]), line);
		keptCount++;
	}
	new bool:hitCap = (keptCount >= MAX_TIMED_BANS && !feof(file));
	fclose(file);

	if (removedCount == 0)
	{
		// Nothing matched (permanent-only ban, or no record) — leave the
		// file untouched: no needless rewrite, no crash window, and the
		// cap can't silently prune unrelated bans on a no-op.
		g_pendingUnbanCount = 0;
		return;
	}

	if (hitCap)
		log_amx("[KTP] WARNING: %s has more than %d timed bans - extra entries dropped AND removed from the file at rewrite", path, MAX_TIMED_BANS);

	// In-place "w" rewrite: same accepted boot/crash window as
	// reapply_timed_bans (comment there).
	new out = fopen(path, "w");
	if (out)
	{
		for (new i = 0; i < keptCount; i++)
			fprintf(out, "%s^n", keptLines[i]);
		fclose(out);
	}

	for (new i = 0; i < g_pendingUnbanCount; i++)
		log_amx("[KTP] TIMED_BAN_UNBAN_REMOVED sid=%s", g_pendingUnbanSids[i]);
	log_amx("[KTP] Timed-ban file rewritten after unban: kept=%d removed=%d", keptCount, removedCount);
	g_pendingUnbanCount = 0;
}

// ===========================================================================
// Player List Building
// ===========================================================================

build_player_list(admin_id, bool:checkImmunity)
{
	new players[32], num;
	get_players(players, num, "c");  // "c" = skip bots; HLTV proxies intentionally NOT filtered — kickable by design (v2.3.0)

	g_validPlayerCount[admin_id] = 0;

	for (new i = 0; i < num; i++)
	{
		new pid = players[i];

		// Skip self
		if (pid == admin_id)
			continue;

		// Skip bots
		if (is_user_bot(pid))
			continue;

		// Check immunity if enabled
		if (checkImmunity && (get_user_flags(pid) & ADMIN_IMMUNITY))
			continue;

		if (g_validPlayerCount[admin_id] >= sizeof(g_validPlayers[]))
			continue;
		g_validPlayers[admin_id][g_validPlayerCount[admin_id]] = pid;
		g_validPlayerCount[admin_id]++;
	}

	return g_validPlayerCount[admin_id];
}

// ===========================================================================
// Player Selection Menu
// ===========================================================================

show_player_menu(id)
{
	new menu[1024], len = 0;
	new title[64];

	if (g_menuAction[id] == ACTION_KICK)
		copy(title, charsmax(title), "Select player to KICK:");
	else
		copy(title, charsmax(title), "Select player to BAN:");

	len = formatex(menu, charsmax(menu), "\y%s^n^n", title);

	// Pagination
	new startIdx = g_menuPage[id] * 7;
	new endIdx = min(startIdx + 7, g_validPlayerCount[id]);
	new totalPages = (g_validPlayerCount[id] + 6) / 7;

	// Add players
	new itemNum = 0;
	for (new i = startIdx; i < endIdx; i++)
	{
		new pid = g_validPlayers[id][i];
		new playerName[32];
		get_user_name(pid, playerName, charsmax(playerName));

		itemNum++;
		len += formatex(menu[len], charsmax(menu) - len, "\r%d.\w %s^n", itemNum, playerName);
	}

	// Padding for unused slots
	while (itemNum < 7)
	{
		len += formatex(menu[len], charsmax(menu) - len, "^n");
		itemNum++;
	}

	// Navigation
	if (endIdx < g_validPlayerCount[id])
		len += formatex(menu[len], charsmax(menu) - len, "^n\r8.\w Next Page");
	else
		len += formatex(menu[len], charsmax(menu) - len, "^n\d8. Next Page");

	if (g_menuPage[id] > 0)
		len += formatex(menu[len], charsmax(menu) - len, "^n\r9.\w Previous Page");
	else
		len += formatex(menu[len], charsmax(menu) - len, "^n\d9. Previous Page");

	len += formatex(menu[len], charsmax(menu) - len, "^n^n\r0.\w Cancel");

	// Page indicator
	if (totalPages > 1)
		len += formatex(menu[len], charsmax(menu) - len, " \d(Page %d/%d)", g_menuPage[id] + 1, totalPages);

	new menuName[32];
	if (g_menuAction[id] == ACTION_KICK)
		copy(menuName, charsmax(menuName), "KTP Kick Menu");
	else
		copy(menuName, charsmax(menuName), "KTP Ban Menu");

	show_menu(id, 1023, menu, -1, menuName);
}

public menu_player_handler(id, key)
{
	// Cancel
	if (key == 9)
	{
		g_menuAction[id] = ACTION_NONE;
		return PLUGIN_HANDLED;
	}

	// Guard: all players disconnected while menu was open
	if (g_validPlayerCount[id] == 0)
	{
		client_print(id, print_chat, "[KTP] No players available.");
		g_menuAction[id] = ACTION_NONE;
		return PLUGIN_HANDLED;
	}

	// Next page
	if (key == 7)
	{
		new maxPage = (g_validPlayerCount[id] - 1) / 7;
		if (g_menuPage[id] < maxPage)
		{
			g_menuPage[id]++;
			show_player_menu(id);
		}
		else
		{
			show_player_menu(id);  // Stay on current page
		}
		return PLUGIN_HANDLED;
	}

	// Previous page
	if (key == 8)
	{
		if (g_menuPage[id] > 0)
		{
			g_menuPage[id]--;
		}
		show_player_menu(id);
		return PLUGIN_HANDLED;
	}

	// Player selection (keys 0-6 = items 1-7)
	new playerIndex = g_menuPage[id] * 7 + key;

	if (playerIndex >= g_validPlayerCount[id])
	{
		show_player_menu(id);  // Invalid selection, redisplay
		return PLUGIN_HANDLED;
	}

	new target = g_validPlayers[id][playerIndex];

	// Verify target is still valid
	if (!is_user_connected(target))
	{
		client_print(id, print_chat, "[KTP] Player is no longer connected.");
		g_menuAction[id] = ACTION_NONE;
		return PLUGIN_HANDLED;
	}

	// Double-check immunity
	if (get_user_flags(target) & ADMIN_IMMUNITY)
	{
		client_print(id, print_chat, "[KTP] That player has admin immunity.");
		g_menuAction[id] = ACTION_NONE;
		return PLUGIN_HANDLED;
	}

	g_menuTarget[id] = target;
	get_user_authid(target, g_menuTargetAuth[id], charsmax(g_menuTargetAuth[]));

	if (g_menuAction[id] == ACTION_KICK)
	{
		// Execute kick directly
		execute_kick(id, target);
	}
	else if (g_menuAction[id] == ACTION_BAN)
	{
		// Show ban duration menu
		show_duration_menu(id);
	}

	return PLUGIN_HANDLED;
}

// ===========================================================================
// Ban Duration Menu
// ===========================================================================

show_duration_menu(id)
{
	// Verify target is still connected (could have disconnected between menu selections)
	if (!is_user_connected(g_menuTarget[id])) {
		client_print(id, print_chat, "[KTP] Target player disconnected.");
		return;
	}

	new menu[256], len = 0;
	new targetName[32];
	get_user_name(g_menuTarget[id], targetName, charsmax(targetName));

	len = formatex(menu, charsmax(menu), "\yBan Duration for %s:^n^n", targetName);

	for (new i = 0; i < sizeof(g_banDurations); i++)
	{
		len += formatex(menu[len], charsmax(menu) - len, "\r%d.\w %s^n", i + 1, g_banDurationNames[i]);
	}

	len += formatex(menu[len], charsmax(menu) - len, "^n^n\r0.\w Cancel");

	show_menu(id, 1023, menu, -1, "KTP Ban Duration");
}

public menu_duration_handler(id, key)
{
	// Cancel
	if (key == 9)
	{
		g_menuAction[id] = ACTION_NONE;
		return PLUGIN_HANDLED;
	}

	// Duration selection
	if (key >= 0 && key < sizeof(g_banDurations))
	{
		new target = g_menuTarget[id];

		// Verify target is still valid
		if (!is_user_connected(target))
		{
			client_print(id, print_chat, "[KTP] Player is no longer connected.");
			g_menuAction[id] = ACTION_NONE;
			return PLUGIN_HANDLED;
		}

		execute_ban(id, target, g_banDurations[key]);
	}

	g_menuAction[id] = ACTION_NONE;
	return PLUGIN_HANDLED;
}

// ===========================================================================
// Execute Kick
// ===========================================================================

execute_kick(admin_id, target_id)
{
	// Actor re-check: flags can be revoked between menu open and execute
	// (2.7.15 re-checked target immunity; the actor needs the same treatment)
	if (!(get_user_flags(admin_id) & ADMIN_KICK))
	{
		client_print(admin_id, print_chat, "[KTP] You no longer have permission to kick players.");
		log_failed_attempt(admin_id, "kick (at execute)");
		g_menuAction[admin_id] = ACTION_NONE;
		return;
	}

	// TOCTOU guard: verify slot still holds the same player selected in menu
	new currentAuth[35];
	get_user_authid(target_id, currentAuth, charsmax(currentAuth));
	if (!equal(currentAuth, g_menuTargetAuth[admin_id]))
	{
		client_print(admin_id, print_chat, "[KTP] Target player changed - kick cancelled.");
		log_amx("[KTP] KICK CANCELLED (slot changed occupant): expected <%s> found <%s>", g_menuTargetAuth[admin_id], currentAuth);
		g_menuAction[admin_id] = ACTION_NONE;
		return;
	}

	new adminName[32], targetName[32], adminAuth[35], targetAuth[35];
	new adminIP[22], targetIP[22];

	get_user_name(admin_id, adminName, charsmax(adminName));
	get_user_name(target_id, targetName, charsmax(targetName));
	get_user_authid(admin_id, adminAuth, charsmax(adminAuth));
	copy(targetAuth, charsmax(targetAuth), currentAuth);
	get_user_ip(admin_id, adminIP, charsmax(adminIP), 1);
	get_user_ip(target_id, targetIP, charsmax(targetIP), 1);

	// Log to server
	log_amx("[KTP] KICK: Admin '%s' <%s> (%s) kicked '%s' <%s> (%s)",
		adminName, adminAuth, adminIP,
		targetName, targetAuth, targetIP);

	// Send to Discord audit channels
	new description[256];
	formatex(description, charsmax(description),
		"**Admin:** %s (`%s`)^n**Target:** %s (`%s`)",
		adminName, adminAuth, targetName, targetAuth);
	ktp_discord_send_embed_audit("<:KTP:1002382703020212245> Admin KICK", description, KTP_DISCORD_COLOR_ORANGE);

	// Notify players
	client_print(0, print_chat, "[KTP] %s was kicked by admin %s.", targetName, adminName);

	// Execute the kick using ReHLDS DropClient API (bypasses blocked kick command)
	ktp_drop_client(target_id, "Kicked by admin");

	g_menuAction[admin_id] = ACTION_NONE;
}

// ===========================================================================
// Execute Ban
// ===========================================================================

execute_ban(admin_id, target_id, duration)
{
	// Actor re-check: flags can be revoked between menu open and execute
	// (2.7.15 re-checked target immunity; the actor needs the same treatment)
	if (!(get_user_flags(admin_id) & ADMIN_BAN))
	{
		client_print(admin_id, print_chat, "[KTP] You no longer have permission to ban players.");
		log_failed_attempt(admin_id, "ban (at execute)");
		g_menuAction[admin_id] = ACTION_NONE;
		return;
	}

	// TOCTOU guard: verify slot still holds the same player selected in menu
	new currentAuth[35];
	get_user_authid(target_id, currentAuth, charsmax(currentAuth));
	if (!equal(currentAuth, g_menuTargetAuth[admin_id]))
	{
		client_print(admin_id, print_chat, "[KTP] Target player changed - ban cancelled.");
		log_amx("[KTP] BAN CANCELLED (slot changed occupant): expected <%s> found <%s>", g_menuTargetAuth[admin_id], currentAuth);
		g_menuAction[admin_id] = ACTION_NONE;
		return;
	}

	// Immunity re-check: the select menu filtered immune players, but flags
	// can be granted between the select and duration menus (re-auth, live
	// admin grant) — without this, that window bans an immune player.
	if (get_user_flags(target_id) & ADMIN_IMMUNITY)
	{
		new aName[32], tName[32];
		get_user_name(admin_id, aName, charsmax(aName));
		get_user_name(target_id, tName, charsmax(tName));
		client_print(admin_id, print_chat, "[KTP] That player has admin immunity - ban cancelled.");
		log_amx("[KTP] BAN CANCELLED (immunity gained mid-flow): admin '%s' target '%s'", aName, tName);
		g_menuAction[admin_id] = ACTION_NONE;
		return;
	}

	new adminName[32], targetName[32], adminAuth[35], targetAuth[35];
	new adminIP[22], targetIP[22];

	get_user_name(admin_id, adminName, charsmax(adminName));
	get_user_name(target_id, targetName, charsmax(targetName));
	get_user_authid(admin_id, adminAuth, charsmax(adminAuth));
	copy(targetAuth, charsmax(targetAuth), currentAuth);
	get_user_ip(admin_id, adminIP, charsmax(adminIP), 1);
	get_user_ip(target_id, targetIP, charsmax(targetIP), 1);

	new durationStr[32];
	if (duration == 0)
	{
		copy(durationStr, charsmax(durationStr), "permanent");
	}
	else if (duration < 60)
	{
		formatex(durationStr, charsmax(durationStr), "%d minute%s", duration, duration == 1 ? "" : "s");
	}
	else if (duration < 1440)
	{
		new hours = duration / 60;
		formatex(durationStr, charsmax(durationStr), "%d hour%s", hours, hours == 1 ? "" : "s");
	}
	else if (duration < 10080)
	{
		new days = duration / 1440;
		formatex(durationStr, charsmax(durationStr), "%d day%s", days, days == 1 ? "" : "s");
	}
	else
	{
		// Weeks tier so the log/embed/chat wording matches the menu label
		// ("1 Week" used to log as "7 days")
		new weeks = duration / 10080;
		formatex(durationStr, charsmax(durationStr), "%d week%s", weeks, weeks == 1 ? "" : "s");
	}

	// Check SteamID validity before logging/notifying — determines ban vs kick-only
	new bool:invalidSteamId = (equal(targetAuth, "STEAM_ID_PENDING") || equal(targetAuth, "STEAM_ID_LAN") || equal(targetAuth, "BOT") || !targetAuth[0]);

	if (invalidSteamId)
	{
		// Kick-only path — ban cannot be persisted with this SteamID
		log_amx("[KTP] KICK (invalid SteamID): Admin '%s' <%s> (%s) kicked '%s' <%s> (%s) — ban not persistent",
			adminName, adminAuth, adminIP,
			targetName, targetAuth, targetIP);

		new description[256];
		formatex(description, charsmax(description),
			"**Admin:** %s (`%s`)^n**Target:** %s (`%s`)^n**Note:** Invalid SteamID — kick only, ban not persistent",
			adminName, adminAuth, targetName, targetAuth);
		ktp_discord_send_embed_audit("<:KTP:1002382703020212245> Admin KICK (invalid SteamID)", description, KTP_DISCORD_COLOR_ORANGE);

		client_print(0, print_chat, "[KTP] %s was kicked by admin %s (ban failed: invalid SteamID).", targetName, adminName);
		client_print(admin_id, print_chat, "[KTP] Warning: SteamID '%s' is not persistent. Player kicked but ban will not hold.", targetAuth);
	}
	else
	{
		// Normal ban path — SteamID is valid and persistent
		log_amx("[KTP] BAN: Admin '%s' <%s> (%s) banned '%s' <%s> (%s) for %s",
			adminName, adminAuth, adminIP,
			targetName, targetAuth, targetIP,
			durationStr);

		new description[256];
		formatex(description, charsmax(description),
			"**Admin:** %s (`%s`)^n**Target:** %s (`%s`)^n**Duration:** %s",
			adminName, adminAuth, targetName, targetAuth, durationStr);
		ktp_discord_send_embed_audit("<:KTP:1002382703020212245> Admin BAN", description, KTP_DISCORD_COLOR_RED);

		client_print(0, print_chat, "[KTP] %s was banned by admin %s (%s).", targetName, adminName, durationStr);

		// Execute the ban using SteamID (without kick - kick command is blocked)
		// banid adds to in-memory ban list; server_exec flushes immediately so ban
		// is active before the player is dropped. Deferred writeid saves to disk.
		server_cmd("banid %d %s", duration, targetAuth);
		server_exec();
		remove_task(TASK_FLUSH_BANLIST);
		set_task(0.1, "task_flush_banlist", TASK_FLUSH_BANLIST);

		// writeid only persists permanent filters — record timed bans so boot
		// can re-apply the remainder
		if (duration > 0)
			record_timed_ban(targetAuth, targetName, adminAuth, adminName, duration);
	}

	// Drop the client using ReHLDS DropClient API (bypasses blocked kick command)
	// A kick-only drop must never claim a ban duration
	new banReason[64];
	if (invalidSteamId)
		copy(banReason, charsmax(banReason), "Kicked by admin");
	else
		formatex(banReason, charsmax(banReason), "Banned by admin (%s)", durationStr);
	ktp_drop_client(target_id, banReason);

	g_menuAction[admin_id] = ACTION_NONE;
}

// Deferred ban file flush — avoids blocking menu handler with disk I/O
public task_flush_banlist()
{
	server_cmd("writeid");
	server_exec();
}

// ===========================================================================
// Timed-Ban Persistence
// The engine's SV_WriteId_f writes only permanent filters (banTime==0), so a
// timed banid silently dies at the nightly restart. We own persistence: every
// timed ban appends a record here; boot re-applies the remaining minutes.
// Record format (one per line, names last so a '|' in a name can't corrupt
// the load-bearing fields):
//   steamid|unban_epoch|admin_steamid|target_name|admin_name
// ===========================================================================

get_timed_bans_path(path[], len)
{
	new configsDir[128];
	get_configsdir(configsDir, charsmax(configsDir));
	formatex(path, len, "%s/%s", configsDir, TIMED_BANS_FILE);
}

record_timed_ban(const targetAuth[], const targetName[], const adminAuth[], const adminName[], durationMin)
{
	// Chronology: a re-ban supersedes any same-sid pending unban removal.
	for (new i = 0; i < g_pendingUnbanCount; i++)
	{
		if (equal(g_pendingUnbanSids[i], targetAuth))
		{
			for (new j = i + 1; j < g_pendingUnbanCount; j++)
				copy(g_pendingUnbanSids[j - 1], charsmax(g_pendingUnbanSids[]), g_pendingUnbanSids[j]);
			g_pendingUnbanCount--;
			break;
		}
	}

	if (g_pendingBanLineCount >= MAX_PENDING_BAN_RECORDS)
	{
		// 4+ bans inside one 0.1s window: flush inline rather than lose a
		// record — the stall risk beats a silent drop.
		task_flush_ban_records();
	}

	formatex(g_pendingBanLines[g_pendingBanLineCount], charsmax(g_pendingBanLines[]),
		"%s|%d|%s|%s|%s",
		targetAuth, get_systime() + durationMin * 60, adminAuth, targetName, adminName);
	g_pendingBanLineCount++;

	remove_task(TASK_FLUSH_BAN_RECORDS);
	set_task(0.1, "task_flush_ban_records", TASK_FLUSH_BAN_RECORDS);
}

public task_flush_ban_records()
{
	if (g_pendingBanLineCount <= 0)
		return;

	new path[192];
	get_timed_bans_path(path, charsmax(path));

	new file = fopen(path, "a");
	if (!file)
	{
		log_amx("[KTP] WARNING: Could not open %s - %d timed ban record(s) will not survive a restart",
			path, g_pendingBanLineCount);
		g_pendingBanLineCount = 0;
		return;
	}

	for (new i = 0; i < g_pendingBanLineCount; i++)
		fprintf(file, "%s^n", g_pendingBanLines[i]);
	fclose(file);
	g_pendingBanLineCount = 0;
}

// Boot-time re-apply: read records, drop expired ones (rewrite the file
// without them), banid the remainder. Duplicate steamids: latest line wins.
// No writeid — re-application every boot carries the persistence.
reapply_timed_bans()
{
	new path[192];
	get_timed_bans_path(path, charsmax(path));

	new file = fopen(path, "r");
	if (!file)
		return; // fresh install or no timed bans recorded

	// static: too large for the AMX stack; only touched once per boot
	static sids[MAX_TIMED_BANS][35];
	static epochs[MAX_TIMED_BANS];
	static rawLines[MAX_TIMED_BANS][160];
	new count = 0, malformed = 0;

	new line[160];
	while (fgets(file, line, charsmax(line)))
	{
		trim(line);
		if (!line[0] || line[0] == ';' || line[0] == '#')
			continue;

		// steamid|unban_epoch|...
		new pipe1 = contain(line, "|");
		new bool:ok = (pipe1 > 0);
		new sid[35], epoch = 0;
		if (ok)
		{
			copy(sid, min(pipe1, charsmax(sid)), line);
			new epochStart = pipe1 + 1;
			new pipe2 = contain(line[epochStart], "|");
			if (pipe2 > 0)
			{
				new epochStr[16];
				copy(epochStr, min(pipe2, charsmax(epochStr)), line[epochStart]);
				epoch = str_to_num(epochStr);
			}
			// only persistent Steam IDs are ever recorded
			ok = (epoch > 0 && equal(sid, "STEAM_", 6));
		}
		if (!ok)
		{
			malformed++;
			log_amx("[KTP] TIMED_BAN_MALFORMED skipped: '%s'", line);
			continue;
		}

		// latest-wins dedup
		new idx = -1;
		for (new i = 0; i < count; i++)
		{
			if (equal(sids[i], sid))
			{
				idx = i;
				break;
			}
		}
		if (idx == -1)
		{
			if (count >= MAX_TIMED_BANS)
			{
				log_amx("[KTP] WARNING: %s has more than %d timed bans - extra entries dropped AND removed from the file at rewrite", path, MAX_TIMED_BANS);
				continue;
			}
			idx = count++;
			copy(sids[idx], charsmax(sids[]), sid);
		}
		epochs[idx] = epoch;
		copy(rawLines[idx], charsmax(rawLines[]), line);
	}
	fclose(file);

	// Apply live entries, collect which to keep
	new now = get_systime();
	new applied = 0, expired = 0;
	static bool:keep[MAX_TIMED_BANS];
	for (new i = 0; i < count; i++)
	{
		new remaining = epochs[i] - now;
		if (remaining <= 0)
		{
			keep[i] = false;
			expired++;
			log_amx("[KTP] TIMED_BAN_EXPIRED sid=%s (dropped from %s)", sids[i], TIMED_BANS_FILE);
			continue;
		}
		keep[i] = true;
		new remainingMin = (remaining + 59) / 60; // round up — never under-ban
		server_cmd("banid %d %s", remainingMin, sids[i]);
		log_amx("[KTP] TIMED_BAN_REAPPLY sid=%s remaining_min=%d", sids[i], remainingMin);
		applied++;
	}
	// No server_exec() — the buffered banids flush on the next engine frame,
	// long before any client can finish connecting at boot.

	// Rewrite without expired/duplicate/malformed lines. In-place "w" rewrite:
	// a crash between truncate and fclose loses the file — accepted (boot-only,
	// ms-wide window, bans also live in the engine's in-memory list until the
	// next stop).
	new out = fopen(path, "w");
	if (!out)
	{
		log_amx("[KTP] WARNING: Could not rewrite %s - expired entries not pruned", path);
	}
	else
	{
		for (new i = 0; i < count; i++)
		{
			if (keep[i])
				fprintf(out, "%s^n", rawLines[i]);
		}
		fclose(out);
	}

	if (applied || expired || malformed)
		log_amx("[KTP] Timed-ban persistence: %d re-applied, %d expired, %d malformed", applied, expired, malformed);
}

// ===========================================================================
// Failed Attempt Logging
// ===========================================================================

log_failed_attempt(id, const action[])
{
	new name[32], auth[35], ip[22];
	get_user_name(id, name, charsmax(name));
	get_user_authid(id, auth, charsmax(auth));
	get_user_ip(id, ip, charsmax(ip), 1);

	log_amx("[KTP] DENIED: '%s' <%s> (%s) attempted .%s without permission", name, auth, ip, action);
}

// ===========================================================================
// RCON Audit Logging (KTP-ReHLDS hook)
// ===========================================================================

public hook_SV_Rcon(const command[], const from_ip[], bool:is_valid)
{
	// Failed auth (fires on .928+ engines): consume with batching — one
	// summary embed per 60s window, never one embed per failure
	if (!is_valid)
	{
		record_rcon_failure(command, from_ip);
		return HC_CONTINUE;
	}

	// Check for server control commands that we want to audit/block
	new cmd[32];
	copy(cmd, charsmax(cmd), command);
	trim(cmd);

	// Extract first word (the actual command)
	new space = contain(cmd, " ");
	if (space != -1)
		cmd[space] = 0;

	// BLOCK quit/exit commands via RCON - force use of .quit menu for accountability
	// These commands execute immediately and kill the server before Discord logging can complete
	if (equal(cmd, "quit") || equal(cmd, "exit"))
	{
		// Log the blocked attempt
		log_amx("[KTP] BLOCKED RCON quit/exit from %s - use .quit command in-game", from_ip);

		// Send alert to Discord (this will complete since we're blocking the quit)
		new description[256];
		formatex(description, charsmax(description),
			"**Blocked Command:** `%s`^n**Source IP:** %s^n^n*RCON quit/exit is disabled. Use `.quit` in-game.*",
			command, from_ip);
		ktp_discord_send_embed_audit("<:KTP:1002382703020212245> RCON Quit BLOCKED", description, KTP_DISCORD_COLOR_RED);

		return HC_SUPERCEDE;  // Block the command
	}

	// Log restart commands (these don't kill server immediately)
	if (equal(cmd, "restart") || equal(cmd, "_restart"))
	{
		log_amx("[KTP] RCON: '%s' from %s", command, from_ip);

		new description[256];
		formatex(description, charsmax(description),
			"**Command:** `%s`^n**Source IP:** %s",
			command, from_ip);
		ktp_discord_send_embed_audit("<:KTP:1002382703020212245> RCON Server Control", description, KTP_DISCORD_COLOR_ORANGE);
	}

	return HC_CONTINUE;
}

// ===========================================================================
// RCON Failure Batching
// Every failure gets a local log line (log_amx is async-safe on this fleet);
// Discord sees ONE per-IP summary per 60s window — the relay has no queue
// and failure storms can exceed Discord limits.
// ===========================================================================

record_rcon_failure(const command[], const from_ip[])
{
	// Passwords are stripped engine-side; keep just the command name
	new cmd[32];
	copy(cmd, charsmax(cmd), command);
	trim(cmd);
	new space = contain(cmd, " ");
	if (space != -1)
		cmd[space] = 0;

	log_amx("[KTP] RCON AUTH FAIL from %s (cmd: '%s')", from_ip, cmd);

	new idx = -1;
	for (new i = 0; i < g_rconFailIpCount; i++)
	{
		if (equal(g_rconFailIp[i], from_ip))
		{
			idx = i;
			break;
		}
	}
	if (idx == -1)
	{
		if (g_rconFailIpCount >= MAX_RCON_FAIL_IPS)
		{
			g_rconFailOverflow++;
			return;
		}
		idx = g_rconFailIpCount++;
		copy(g_rconFailIp[idx], charsmax(g_rconFailIp[]), from_ip);
		g_rconFailCount[idx] = 0;
		g_rconFailFirst[idx] = get_systime();
	}
	g_rconFailCount[idx]++;
	g_rconFailLast[idx] = get_systime();
	copy(g_rconFailLastCmd[idx], charsmax(g_rconFailLastCmd[]), cmd);
}

public task_flush_rcon_failures()
{
	if (g_rconFailIpCount == 0 && g_rconFailOverflow == 0)
		return; // quiet window — no embed

	new total = g_rconFailOverflow;
	for (new i = 0; i < g_rconFailIpCount; i++)
		total += g_rconFailCount[i];

	// "Audited": the engine throttles failure audits (~1/s global), so these
	// counts are a floor — a brute-force storm shows ~60/window regardless of
	// its real rate. The local per-failure log has the same ceiling.
	new description[768], len = 0;
	new now = get_systime();
	len = formatex(description, charsmax(description),
		"**Audited failed attempts (last 60s):** %d from %d IP%s",
		total, g_rconFailIpCount, g_rconFailIpCount == 1 ? "" : "s");

	for (new i = 0; i < g_rconFailIpCount; i++)
	{
		len += formatex(description[len], charsmax(description) - len,
			"^n`%s` — %d attempt%s (first %ds ago, last %ds ago, last cmd: `%s`)",
			g_rconFailIp[i], g_rconFailCount[i], g_rconFailCount[i] == 1 ? "" : "s",
			now - g_rconFailFirst[i], now - g_rconFailLast[i],
			g_rconFailLastCmd[i][0] ? g_rconFailLastCmd[i] : "(none)");

		if (len >= charsmax(description) - 128)
		{
			len += formatex(description[len], charsmax(description) - len, "^n(list truncated)");
			break;
		}
	}
	if (g_rconFailOverflow)
		formatex(description[len], charsmax(description) - len,
			"^n(+%d attempts from IPs beyond table capacity)", g_rconFailOverflow);

	log_amx("[KTP] RCON failure window flushed: %d attempts from %d IPs (+%d overflow)",
		total - g_rconFailOverflow, g_rconFailIpCount, g_rconFailOverflow);
	ktp_discord_send_embed_audit("<:KTP:1002382703020212245> RCON Auth Failures", description, KTP_DISCORD_COLOR_RED);

	// Reset the window
	g_rconFailIpCount = 0;
	g_rconFailOverflow = 0;
}

// ===========================================================================
// Console Command Audit Hook (catches LinuxGSM quit/restart via tmux)
// ===========================================================================

public hook_ExecuteServerStringCmd(const cmd[], source, id)
{
	// source values from KTP-ReHLDS: 0 = Console (stdin/tmux), 1 = RCON, 2 = Redirect
	// Extract first word (the actual command)
	new command[32];
	copy(command, charsmax(command), cmd);
	trim(command);

	new space = contain(command, " ");
	if (space != -1)
		command[space] = 0;

	// Skip RCON source (1) - already caught by RH_SV_Rcon hook
	if (source == 1)
		return HC_CONTINUE;

	// Skip only OUR OWN _restart (already audited by cmd_restart); any other
	// console _restart is a server control command like the rest
	if (equal(command, "_restart") && g_ownRestartPending)
	{
		g_ownRestartPending = false;
		return HC_CONTINUE;
	}

	// Log quit/exit/restart commands to Discord (LinuxGSM console commands)
	if (equal(command, "quit") || equal(command, "exit") || equal(command, "restart") || equal(command, "_restart"))
	{
		// Determine source description
		new sourceStr[32];
		switch (source)
		{
			case 0: copy(sourceStr, charsmax(sourceStr), "Console");
			// case 1 (RCON) is filtered at early return above — caught by RH_SV_Rcon hook
			case 2: copy(sourceStr, charsmax(sourceStr), "Redirect");
			default: formatex(sourceStr, charsmax(sourceStr), "Unknown (%d)", source);
		}

		// Log to server
		log_amx("[KTP] CONSOLE: '%s' (source: %s)", cmd, sourceStr);

		// Send to Discord audit channels
		new description[256];
		formatex(description, charsmax(description),
			"**Command:** `%s`^n**Source:** %s",
			cmd, sourceStr);
		ktp_discord_send_embed_audit("<:KTP:1002382703020212245> Console Server Control", description, KTP_DISCORD_COLOR_ORANGE);
	}

	return HC_CONTINUE;
}

// ===========================================================================
// Admin .restart Command
// ===========================================================================

public cmd_restart(id)
{
	// Check admin flag
	if (!(get_user_flags(id) & ADMIN_RCON))
	{
		client_print(id, print_chat, "[KTP] You don't have permission to restart the server.");
		log_failed_attempt(id, "restart");
		return PLUGIN_HANDLED;
	}

	new adminName[32], adminAuth[35];
	get_user_name(id, adminName, charsmax(adminName));
	get_user_authid(id, adminAuth, charsmax(adminAuth));

	// Log to server
	log_amx("[KTP] RESTART: Admin '%s' <%s> initiated server restart", adminName, adminAuth);

	// Send to Discord audit channels
	new description[256];
	formatex(description, charsmax(description),
		"**Admin:** %s (`%s`)^n**Action:** Server Restart",
		adminName, adminAuth);
	ktp_discord_send_embed_audit("<:KTP:1002382703020212245> Admin Server Restart", description, KTP_DISCORD_COLOR_ORANGE);

	// Notify players
	client_print(0, print_chat, "[KTP] Server restart initiated by admin %s.", adminName);

	// Execute restart with a small delay for Discord message to send
	set_task(1.0, "fn_execute_restart", TASK_RESTART);

	return PLUGIN_HANDLED;
}

public fn_execute_restart(taskid)
{
	// Debounce the console-audit hook for this one _restart — cmd_restart
	// already sent the audit embed. The hook fires inside server_exec below,
	// so the flag's lifetime is this call.
	g_ownRestartPending = true;
	server_cmd("_restart");
	server_exec();
}

// ===========================================================================
// Admin .quit Command
// ===========================================================================

public cmd_quit(id)
{
	// Check admin flag
	if (!(get_user_flags(id) & ADMIN_RCON))
	{
		client_print(id, print_chat, "[KTP] You don't have permission to shutdown the server.");
		log_failed_attempt(id, "quit");
		return PLUGIN_HANDLED;
	}

	new adminName[32], adminAuth[35];
	get_user_name(id, adminName, charsmax(adminName));
	get_user_authid(id, adminAuth, charsmax(adminAuth));

	// Log to server
	log_amx("[KTP] QUIT: Admin '%s' <%s> initiated server shutdown", adminName, adminAuth);

	// Send to Discord audit channels
	new description[256];
	formatex(description, charsmax(description),
		"**Admin:** %s (`%s`)^n**Action:** Server Shutdown^n_Server may take up to 60 seconds to restart._",
		adminName, adminAuth);
	ktp_discord_send_embed_audit("<:KTP:1002382703020212245> Admin Server Shutdown", description, KTP_DISCORD_COLOR_RED);

	// Notify players
	client_print(0, print_chat, "[KTP] Server shutdown initiated by admin %s.", adminName);

	// Execute quit with a small delay for Discord message to send
	set_task(1.0, "fn_execute_quit", TASK_QUIT);

	return PLUGIN_HANDLED;
}

public fn_execute_quit(taskid)
{
	server_cmd("quit");
	server_exec();
}

// ===========================================================================
// Map List Loading
// ===========================================================================

load_map_list()
{
	g_mapCount = 0;

	new configsDir[128], filePath[192];
	get_configsdir(configsDir, charsmax(configsDir));
	formatex(filePath, charsmax(filePath), "%s/ktp_maps.ini", configsDir);

	new file = fopen(filePath, "r");
	if (!file)
	{
		log_amx("[KTP] Warning: Could not open %s for map list", filePath);
		return;
	}

	new line[128], currentMap[32], currentName[32];
	currentMap[0] = EOS;
	currentName[0] = EOS;

	while (fgets(file, line, charsmax(line)) && g_mapCount < MAX_MAPS)
	{
		trim(line);

		// Skip empty lines and comments
		if (!line[0] || line[0] == ';' || line[0] == '#')
			continue;

		// Check for section header [map_name]
		if (line[0] == '[')
		{
			// Save previous map if we had one with a name
			if (currentMap[0] && currentName[0])
			{
				// Verify map exists before adding
				new mapPath[64];
				formatex(mapPath, charsmax(mapPath), "maps/%s.bsp", currentMap);
				if (file_exists(mapPath))
				{
					copy(g_mapList[g_mapCount], charsmax(g_mapList[]), currentMap);
					copy(g_mapNames[g_mapCount], charsmax(g_mapNames[]), currentName);
					g_mapCount++;
				}
			}

			// Extract map name from [map_name]
			new endBracket = contain(line, "]");
			if (endBracket > 1)
			{
				// endBracket is position in original line, subtract 1 for the '[' offset
				new copyLen = endBracket - 1;
				if (copyLen > charsmax(currentMap)) copyLen = charsmax(currentMap);
				copy(currentMap, copyLen, line[1]);
				currentName[0] = EOS;  // Reset name for new section
			}
		}
		// Check for name = value (split on '=' first, then match key)
		else
		{
			new equals = contain(line, "=");
			if (equals > 0)
			{
				new key[32];
				copy(key, min(equals, charsmax(key)), line);
				trim(key);
				if (equal(key, "name"))
				{
					copy(currentName, charsmax(currentName), line[equals + 1]);
					trim(currentName);
				}
			}
		}
	}

	// Don't forget the last map in the file
	if (currentMap[0] && currentName[0] && g_mapCount < MAX_MAPS)
	{
		new mapPath[64];
		formatex(mapPath, charsmax(mapPath), "maps/%s.bsp", currentMap);
		if (file_exists(mapPath))
		{
			copy(g_mapList[g_mapCount], charsmax(g_mapList[]), currentMap);
			copy(g_mapNames[g_mapCount], charsmax(g_mapNames[]), currentName);
			g_mapCount++;
		}
	}

	fclose(file);
	log_amx("[KTP] Loaded %d maps from %s", g_mapCount, filePath);
}

// ===========================================================================
// Changemap Command
// ===========================================================================

public cmd_changemap(id)
{
	// No admin flag required - any player can change map
	// This encourages map rotation and keeps servers active

	// Block during active matches
	if (ktp_is_match_active())
	{
		client_print(id, print_chat, "[KTP] Cannot change map during an active match.");
		return PLUGIN_HANDLED;
	}

	// Block if a changemap is already in progress (prevents race condition crash).
	// The lock is now held through the queued changelevel and normally cleared
	// by plugin_cfg on the new map — if the changelevel somehow never ran, a
	// wedged lock self-heals here on the same timeout the hook uses.
	if (g_changeMapInProgress)
	{
		new Float:lockAge = get_gametime() - g_changeMapLockTime;
		if (lockAge < 0.0 || lockAge > CHANGELEVEL_LOCK_TIMEOUT)
		{
			log_amx("[KTP] WARNING: Changelevel lock expired after %.1f seconds - resetting (was locked for '%s')", lockAge, g_pendingChangeMap);
			reset_changemap_lock();
		}
		else
		{
			client_print(id, print_chat, "[KTP] Map change already in progress. Please wait.");
			return PLUGIN_HANDLED;
		}
	}

	if (g_mapCount == 0)
	{
		client_print(id, print_chat, "[KTP] No maps available. Check ktp_maps.ini.");
		return PLUGIN_HANDLED;
	}

	// Show map selection menu
	g_menuAction[id] = ACTION_CHANGEMAP;
	g_menuPage[id] = 0;
	show_map_menu(id);

	return PLUGIN_HANDLED;
}

// ===========================================================================
// Map Selection Menu
// ===========================================================================

show_map_menu(id)
{
	new menu[1024], len = 0;

	len = formatex(menu, charsmax(menu), "\ySelect map to change to:^n^n");

	// Pagination
	new startIdx = g_menuPage[id] * 7;
	new endIdx = min(startIdx + 7, g_mapCount);
	new totalPages = (g_mapCount + 6) / 7;

	// Add maps (show display name, actual map name in gray)
	new itemNum = 0;
	for (new i = startIdx; i < endIdx; i++)
	{
		itemNum++;
		len += formatex(menu[len], charsmax(menu) - len, "\r%d.\w %s \d(%s)^n", itemNum, g_mapNames[i], g_mapList[i]);
	}

	// Padding for unused slots
	while (itemNum < 7)
	{
		len += formatex(menu[len], charsmax(menu) - len, "^n");
		itemNum++;
	}

	// Navigation
	if (endIdx < g_mapCount)
		len += formatex(menu[len], charsmax(menu) - len, "^n\r8.\w Next Page");
	else
		len += formatex(menu[len], charsmax(menu) - len, "^n\d8. Next Page");

	if (g_menuPage[id] > 0)
		len += formatex(menu[len], charsmax(menu) - len, "^n\r9.\w Previous Page");
	else
		len += formatex(menu[len], charsmax(menu) - len, "^n\d9. Previous Page");

	len += formatex(menu[len], charsmax(menu) - len, "^n^n\r0.\w Cancel");

	// Page indicator
	if (totalPages > 1)
		len += formatex(menu[len], charsmax(menu) - len, " \d(Page %d/%d)", g_menuPage[id] + 1, totalPages);

	show_menu(id, 1023, menu, -1, "KTP Map Menu");
}

public menu_map_handler(id, key)
{
	// Cancel
	if (key == 9)
	{
		g_menuAction[id] = ACTION_NONE;
		return PLUGIN_HANDLED;
	}

	// Next page
	if (key == 7)
	{
		new maxPage = (g_mapCount - 1) / 7;
		if (g_menuPage[id] < maxPage)
		{
			g_menuPage[id]++;
			show_map_menu(id);
		}
		else
		{
			show_map_menu(id);  // Stay on current page
		}
		return PLUGIN_HANDLED;
	}

	// Previous page
	if (key == 8)
	{
		if (g_menuPage[id] > 0)
		{
			g_menuPage[id]--;
		}
		show_map_menu(id);
		return PLUGIN_HANDLED;
	}

	// Map selection (keys 0-6 = items 1-7)
	new mapIndex = g_menuPage[id] * 7 + key;

	if (mapIndex >= g_mapCount)
	{
		show_map_menu(id);  // Invalid selection, redisplay
		return PLUGIN_HANDLED;
	}

	execute_changemap(id, g_mapList[mapIndex], g_mapNames[mapIndex]);

	g_menuAction[id] = ACTION_NONE;
	return PLUGIN_HANDLED;
}

// ===========================================================================
// Execute Changemap
// ===========================================================================

execute_changemap(admin_id, const mapName[], const displayName[])
{
	// Double-check lock — two players may have opened the menu before either selected
	if (g_changeMapInProgress)
	{
		client_print(admin_id, print_chat, "[KTP] Map change already in progress. Please wait.");
		return;
	}

	// Re-check liveness at execute time. The menu has an unbounded timeout, so a
	// match may have gone live since cmd_changemap opened it (that's the only
	// liveness check). Firing now would force-end the match.
	if (ktp_is_match_active())
	{
		client_print(admin_id, print_chat, "[KTP] Cannot change map during an active match.");
		return;
	}

	new adminName[32], adminAuth[35];
	get_user_name(admin_id, adminName, charsmax(adminName));
	get_user_authid(admin_id, adminAuth, charsmax(adminAuth));

	new currentMap[32];
	get_mapname(currentMap, charsmax(currentMap));

	// Log to server
	log_amx("[KTP] CHANGEMAP: Admin '%s' <%s> changed map from %s to %s (%s)",
		adminName, adminAuth, currentMap, mapName, displayName);

	// Send to Discord audit channels
	new description[256];
	formatex(description, charsmax(description),
		"**Admin:** %s (`%s`)^n**From:** %s^n**To:** %s (`%s`)",
		adminName, adminAuth, currentMap, displayName, mapName);
	ktp_discord_send_embed_audit("<:KTP:1002382703020212245> Admin Map Change", description, KTP_DISCORD_COLOR_ORANGE);

	// Notify players
	client_print(0, print_chat, "[KTP] Map changing to %s in %d seconds (admin: %s)",
		displayName, CHANGELEVEL_COUNTDOWN_SECS, adminName);

	// Lock to prevent concurrent changemap requests (race condition fix)
	g_changeMapInProgress = true;
	g_changeMapLockTime = get_gametime();

	// Store the pending map and start countdown directly
	// (Previously used a roundabout server_cmd → hook → supercede → start_countdown path,
	// but set_task inside hookchain handlers intermittently failed to register)
	copy(g_pendingChangeMap, charsmax(g_pendingChangeMap), mapName);
	copy(g_pendingChangeMapDisplay, charsmax(g_pendingChangeMapDisplay), displayName);

	// Start countdown directly — after 5 seconds, task_changelevel_countdown will
	// call server_cmd("changelevel") which goes through the hook normally
	start_changelevel_countdown();
}

// ===========================================================================
// Console Changelevel Hook (KTP-ReHLDS)
// Intercepts server_cmd("changelevel") and console changelevel commands
// ===========================================================================

public hook_Host_Changelevel_f(const map[], const startspot[])
{
	// If a changemap countdown is in progress, block any other changelevel attempts
	// This prevents race conditions from concurrent .changemap or other sources
	if (g_changeMapInProgress) {
		// Allow changelevel if it's for the same map we're counting down to
		// (e.g., match-end changelevel to the same map during our countdown)
		if (equali(map, g_pendingChangeMap)) {
			return HC_CONTINUE;
		}

		// Safety timeout: if the lock has been held too long, something went wrong
		// (e.g., countdown task failed to fire after plugin reload). Reset and allow.
		// Negative age = stamp from a previous map's clock (gametime restarts per
		// map) — treat as expired, never as fresh.
		new Float:lockAge = get_gametime() - g_changeMapLockTime;
		if (lockAge < 0.0 || lockAge > CHANGELEVEL_LOCK_TIMEOUT) {
			log_amx("[KTP] WARNING: Changelevel lock expired after %.1f seconds - resetting (was locked for '%s')", lockAge, g_pendingChangeMap);
			reset_changemap_lock();
			return HC_CONTINUE;
		}
		log_amx("[KTP] Blocked changelevel to '%s' - changemap to '%s' already in progress (%.1fs ago)", map, g_pendingChangeMap, lockAge);
		return HC_SUPERCEDE;
	}

	// Not our changelevel - allow it (could be from match end, vote, etc.)
	return HC_CONTINUE;
}

// Clear all changemap lock state — called per map from plugin_cfg (globals
// persist across map changes in extension mode) and on lock timeout
reset_changemap_lock()
{
	g_changeMapInProgress = false;
	g_changeMapCountdown = 0;
	g_changeMapLockTime = 0.0;
	g_pendingChangeMap[0] = EOS;
	g_pendingChangeMapDisplay[0] = EOS;
	remove_task(TASK_CHANGELEVEL);
	remove_task(TASK_CHANGELEVEL_SAFETY);
}

// Start the countdown before map change
stock start_changelevel_countdown()
{
	g_changeMapCountdown = CHANGELEVEL_COUNTDOWN_SECS;
	remove_task(TASK_CHANGELEVEL);
	remove_task(TASK_CHANGELEVEL_SAFETY);
	set_task(1.0, "task_changelevel_countdown", TASK_CHANGELEVEL, .flags = "b");

	// Safety fallback: if the repeating task fails to register (intermittent AMX bug),
	// this single-fire task executes the changelevel after countdown + 5s buffer
	set_task(float(CHANGELEVEL_COUNTDOWN_SECS) + 5.0, "task_changelevel_safety", TASK_CHANGELEVEL_SAFETY);

	log_amx("[KTP] Changelevel countdown started: %d seconds to %s",
		CHANGELEVEL_COUNTDOWN_SECS, g_pendingChangeMap);

	// Initial HUD announcement (display name; raw filename stays in the logs)
	set_hudmessage(255, 255, 0, -1.0, 0.35, 0, 0.0, 0.9, 0.0, 0.0, -1);
	show_hudmessage(0, "Map changing to %s in %d...",
		g_pendingChangeMapDisplay[0] ? g_pendingChangeMapDisplay : g_pendingChangeMap, g_changeMapCountdown);
}

// A match can go live while the map menu sits open or during the 5s countdown.
// Firing the changelevel then would force-end it (MatchHandler ends the match on
// ANY changelevel). Abort + clear the lock instead. Returns true if it aborted.
bool:abort_changemap_if_match_live()
{
	if (!ktp_is_match_active())
		return false;

	log_amx("[KTP] Changemap to '%s' aborted - a match went live before the changelevel fired", g_pendingChangeMap);
	client_print(0, print_chat, "[KTP] Map change aborted - a match is now live.");
	reset_changemap_lock();  // also removes both changelevel tasks
	return true;
}

// Countdown task for map change
public task_changelevel_countdown()
{
	// Runs every tick, so this covers the final tick immediately before the fire.
	if (abort_changemap_if_match_live())
		return;

	g_changeMapCountdown--;

	if (g_changeMapCountdown <= 0) {
		// Time's up - execute changelevel
		remove_task(TASK_CHANGELEVEL);
		remove_task(TASK_CHANGELEVEL_SAFETY);

		// Keep the lock held: the queued changelevel flushes NEXT frame, and
		// clearing here opened a one-frame window where a second .changemap
		// could start and overwrite the pending state. The hook lets our own
		// (same-map) changelevel through; plugin_cfg clears the lock on the
		// new map, and the timeout self-heal covers a changelevel that dies.

		// Execute the changelevel
		log_amx("[KTP] Changelevel countdown complete - executing changelevel to %s", g_pendingChangeMap);
		server_cmd("changelevel %s", g_pendingChangeMap);
		// Do NOT server_exec() here. Forcing the changelevel to run synchronously
		// inside this task callback corrupts the AMXX task scheduler on the
		// DESTINATION map: every set_task() in the new map's plugin_cfg registers
		// (task_exists() == 1) but never dispatches — silently killing repeating
		// tasks in other plugins (e.g. KTPHudObserver's HUD timer / cap polling go
		// dead for that whole map). Let the queued command flush on the next engine
		// frame instead (same pattern KTPMatchHandler uses for its changelevels).
		// The v2.7.6 server_exec() was only needed for the old hook-supercede path
		// that v2.7.7 removed; reproduced + verified on the local stack 2026-06.
		return;
	}

	// Announce countdown in chat for last 3 seconds
	if (g_changeMapCountdown <= 3) {
		client_print(0, print_chat, "[KTP] Map changing in %d...", g_changeMapCountdown);
	}

	// HUD countdown (display name; raw filename stays in the logs)
	set_hudmessage(255, 255, 0, -1.0, 0.35, 0, 0.0, 0.9, 0.0, 0.0, -1);
	show_hudmessage(0, "Map changing to %s in %d...",
		g_pendingChangeMapDisplay[0] ? g_pendingChangeMapDisplay : g_pendingChangeMap, g_changeMapCountdown);
}

// Safety fallback: fires if the repeating countdown task failed to register
public task_changelevel_safety()
{
	if (!g_changeMapInProgress)
		return;  // Countdown already completed normally

	// Same liveness re-check as the countdown fire path — a match may have gone
	// live while the repeating task was dead.
	if (abort_changemap_if_match_live())
		return;

	// The repeating task never fired - execute changelevel directly
	log_amx("[KTP] WARNING: Changelevel countdown task failed - safety fallback executing changelevel to %s", g_pendingChangeMap);
	remove_task(TASK_CHANGELEVEL);

	// Lock stays held through the queued changelevel (same one-frame race as
	// the normal countdown path); plugin_cfg clears it on the new map
	g_changeMapCountdown = 0;
	server_cmd("changelevel %s", g_pendingChangeMap);
	// No server_exec() — see task_changelevel_countdown(): a synchronous exec from
	// inside a task callback wedges the destination map's AMXX task scheduler. The
	// queued command flushes on the next engine frame.
}
