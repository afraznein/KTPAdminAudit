/* KTP Admin Audit v2.6.0
 * Menu-based admin kick/ban/changemap with full audit logging
 *
 * AUTHOR: Nein_
 * VERSION: 2.6.0
 * DATE: 2026-01-01
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
 * ========== CHANGELOG ==========
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
#include <reapi>

#pragma semicolon 1

// KTP native for dropping clients via ReHLDS API (bypasses blocked kick command)
native ktp_drop_client(id, const reason[] = "");

// KTP native to check if match is in progress (from KTPMatchHandler)
native ktp_is_match_active();

#define PLUGIN "KTP Admin Audit"
#define VERSION "2.6.0"
#define AUTHOR "Nein_"

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
new g_menuPage[33];         // Current menu page for pagination
new g_validPlayers[33][32]; // Valid player indices for each admin
new g_validPlayerCount[33]; // Count of valid players

// Ban duration options (in minutes, 0 = permanent)
new const g_banDurations[] = { 60, 1440, 10080, 0 };
new const g_banDurationNames[][] = { "1 Hour", "1 Day", "1 Week", "Permanent" };

// Changelevel hook variables
new g_pendingChangeMap[64];          // Map to change to after countdown
new g_changeMapCountdown = 0;        // Countdown seconds remaining
new g_changeMapTaskId = 54321;       // Task ID for countdown
new bool:g_changeLevelPending = false;  // Flag to track pending changelevel
const CHANGELEVEL_COUNTDOWN_SECS = 5;   // Seconds to wait before map change

public plugin_init()
{
	register_plugin(PLUGIN, VERSION, AUTHOR);

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

	log_amx("[%s] v%s initialized (changelevel hook active)", PLUGIN, VERSION);
}

public plugin_cfg()
{
	// Load shared Discord configuration
	ktp_discord_load_config();

	// Load map list from ktp_maps.ini
	load_map_list();
}

public client_putinserver(id)
{
	// Announce to admins with a delay
	if (!is_user_bot(id) && !is_user_hltv(id))
	{
		if (get_user_flags(id) & (ADMIN_KICK | ADMIN_BAN))
		{
			set_task(5.0, "fn_show_version", id);
		}
	}
}

public fn_show_version(id)
{
	if (!is_user_connected(id))
		return;

	client_print(id, print_chat, "%s version %s by %s", PLUGIN, VERSION, AUTHOR);
}

public client_disconnected(id)
{
	// Clear menu state
	g_menuAction[id] = ACTION_NONE;
	g_menuTarget[id] = 0;
	g_menuPage[id] = 0;
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

	// Show player selection menu
	g_menuAction[id] = ACTION_KICK;
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

	// Show player selection menu
	g_menuAction[id] = ACTION_BAN;
	g_menuPage[id] = 0;
	show_player_menu(id);

	return PLUGIN_HANDLED;
}

// ===========================================================================
// Player List Building
// ===========================================================================

build_player_list(admin_id, bool:checkImmunity)
{
	new players[32], num;
	get_players(players, num, "c");  // connected (includes HLTV proxies)

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
	new menu[512], len = 0;
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
	new adminName[32], targetName[32], adminAuth[35], targetAuth[35];
	new adminIP[22], targetIP[22];

	get_user_name(admin_id, adminName, charsmax(adminName));
	get_user_name(target_id, targetName, charsmax(targetName));
	get_user_authid(admin_id, adminAuth, charsmax(adminAuth));
	get_user_authid(target_id, targetAuth, charsmax(targetAuth));
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
	ktp_discord_send_embed_audit("Admin KICK", description, KTP_DISCORD_COLOR_ORANGE);

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
	new adminName[32], targetName[32], adminAuth[35], targetAuth[35];
	new adminIP[22], targetIP[22];

	get_user_name(admin_id, adminName, charsmax(adminName));
	get_user_name(target_id, targetName, charsmax(targetName));
	get_user_authid(admin_id, adminAuth, charsmax(adminAuth));
	get_user_authid(target_id, targetAuth, charsmax(targetAuth));
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
	else
	{
		new days = duration / 1440;
		formatex(durationStr, charsmax(durationStr), "%d day%s", days, days == 1 ? "" : "s");
	}

	// Log to server
	log_amx("[KTP] BAN: Admin '%s' <%s> (%s) banned '%s' <%s> (%s) for %s",
		adminName, adminAuth, adminIP,
		targetName, targetAuth, targetIP,
		durationStr);

	// Send to Discord audit channels
	new description[256];
	formatex(description, charsmax(description),
		"**Admin:** %s (`%s`)^n**Target:** %s (`%s`)^n**Duration:** %s",
		adminName, adminAuth, targetName, targetAuth, durationStr);
	ktp_discord_send_embed_audit("Admin BAN", description, KTP_DISCORD_COLOR_RED);

	// Notify players
	client_print(0, print_chat, "[KTP] %s was banned by admin %s (%s).", targetName, adminName, durationStr);

	// Execute the ban using SteamID (without kick - kick command is blocked)
	server_cmd("banid %d %s", duration, targetAuth);
	server_cmd("writeid");

	// Drop the client using ReHLDS DropClient API (bypasses blocked kick command)
	new banReason[64];
	formatex(banReason, charsmax(banReason), "Banned by admin (%s)", durationStr);
	ktp_drop_client(target_id, banReason);

	g_menuAction[admin_id] = ACTION_NONE;
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
	// Only log valid RCON commands (invalid ones are already logged by engine)
	if (!is_valid)
		return HC_CONTINUE;

	// Check for server control commands that we want to audit
	new cmd[32];
	copy(cmd, charsmax(cmd), command);
	trim(cmd);

	// Extract first word (the actual command)
	new space = contain(cmd, " ");
	if (space != -1)
		cmd[space] = 0;

	// Log quit/exit/restart commands to Discord
	if (equal(cmd, "quit") || equal(cmd, "exit") || equal(cmd, "restart") || equal(cmd, "_restart"))
	{
		// Log to server
		log_amx("[KTP] RCON: '%s' from %s", command, from_ip);

		// Send to Discord audit channels
		new description[256];
		formatex(description, charsmax(description),
			"**Command:** `%s`^n**Source IP:** %s",
			command, from_ip);
		ktp_discord_send_embed_audit("RCON Server Control", description, KTP_DISCORD_COLOR_ORANGE);
	}

	return HC_CONTINUE;
}

// ===========================================================================
// Console Command Audit Hook (catches LinuxGSM quit/restart via tmux)
// ===========================================================================

public hook_ExecuteServerStringCmd(const cmd[], source, id)
{
	// Extract first word (the actual command)
	new command[32];
	copy(command, charsmax(command), cmd);
	trim(command);

	new space = contain(command, " ");
	if (space != -1)
		command[space] = 0;

	// Skip _restart - it's triggered by admin .restart command which already logs
	// Also skip from RCON source (1) - already caught by RH_SV_Rcon hook
	if (equal(command, "_restart") || source == 1)
		return HC_CONTINUE;

	// Log quit/exit/restart commands to Discord (LinuxGSM console commands)
	if (equal(command, "quit") || equal(command, "exit") || equal(command, "restart"))
	{
		// Determine source description
		new sourceStr[32];
		switch (source)
		{
			case 0: copy(sourceStr, charsmax(sourceStr), "Console");
			case 1: copy(sourceStr, charsmax(sourceStr), "RCON");  // Should be caught by RH_SV_Rcon
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
		ktp_discord_send_embed_audit("Console Server Control", description, KTP_DISCORD_COLOR_ORANGE);
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
	ktp_discord_send_embed_audit("Admin Server Restart", description, KTP_DISCORD_COLOR_ORANGE);

	// Notify players
	client_print(0, print_chat, "[KTP] Server restart initiated by admin %s.", adminName);

	// Execute restart with a small delay for Discord message to send
	set_task(1.0, "fn_execute_restart");

	return PLUGIN_HANDLED;
}

public fn_execute_restart()
{
	server_cmd("_restart");
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
	ktp_discord_send_embed_audit("Admin Server Shutdown", description, KTP_DISCORD_COLOR_RED);

	// Notify players
	client_print(0, print_chat, "[KTP] Server shutdown initiated by admin %s.", adminName);

	// Execute quit with a small delay for Discord message to send
	set_task(1.0, "fn_execute_quit");

	return PLUGIN_HANDLED;
}

public fn_execute_quit()
{
	server_cmd("quit");
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
				copy(currentMap, endBracket - 1, line[1]);
				currentName[0] = EOS;  // Reset name for new section
			}
		}
		// Check for name = value
		else if (containi(line, "name") == 0)
		{
			new equals = contain(line, "=");
			if (equals != -1)
			{
				copy(currentName, charsmax(currentName), line[equals + 1]);
				trim(currentName);
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
	new menu[512], len = 0;

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
	ktp_discord_send_embed_audit("Admin Map Change", description, KTP_DISCORD_COLOR_ORANGE);

	// Notify players
	client_print(0, print_chat, "[KTP] Map changing to %s in %d seconds (admin: %s)",
		displayName, CHANGELEVEL_COUNTDOWN_SECS, adminName);

	// Store the pending map for the changelevel hook
	copy(g_pendingChangeMap, charsmax(g_pendingChangeMap), mapName);
	g_changeLevelPending = true;

	// Execute changelevel - hook will intercept and show countdown
	server_cmd("changelevel %s", mapName);
	server_exec();  // Force immediate execution so hook can intercept
}

// ===========================================================================
// Console Changelevel Hook (KTP-ReHLDS)
// Intercepts server_cmd("changelevel") and console changelevel commands
// ===========================================================================

public hook_Host_Changelevel_f(const map[], const startspot[])
{
	// If this is our pending .changemap request, supersede and show countdown
	if (g_changeLevelPending) {
		g_changeLevelPending = false;  // Reset flag

		// Start countdown
		start_changelevel_countdown();

		// Supersede the engine changelevel - we'll do it manually after countdown
		return HC_SUPERCEDE;
	}

	// Not our changelevel - allow it (could be from match end, vote, etc.)
	return HC_CONTINUE;
}

// Start the countdown before map change
stock start_changelevel_countdown()
{
	g_changeMapCountdown = CHANGELEVEL_COUNTDOWN_SECS;
	remove_task(g_changeMapTaskId);
	set_task(1.0, "task_changelevel_countdown", g_changeMapTaskId, .flags = "b");

	log_amx("[KTP] Changelevel countdown started: %d seconds to %s",
		CHANGELEVEL_COUNTDOWN_SECS, g_pendingChangeMap);

	// Initial HUD announcement
	set_hudmessage(255, 255, 0, -1.0, 0.35, 0, 0.0, 0.9, 0.0, 0.0, -1);
	show_hudmessage(0, "Map changing to %s in %d...", g_pendingChangeMap, g_changeMapCountdown);
}

// Countdown task for map change
public task_changelevel_countdown()
{
	g_changeMapCountdown--;

	if (g_changeMapCountdown <= 0) {
		// Time's up - execute changelevel
		remove_task(g_changeMapTaskId);

		// Execute the changelevel (won't be intercepted since g_changeLevelPending is false)
		server_cmd("changelevel %s", g_pendingChangeMap);
		return;
	}

	// Announce countdown in chat for last 3 seconds
	if (g_changeMapCountdown <= 3) {
		client_print(0, print_chat, "[KTP] Map changing in %d...", g_changeMapCountdown);
	}

	// HUD countdown
	set_hudmessage(255, 255, 0, -1.0, 0.35, 0, 0.0, 0.9, 0.0, 0.0, -1);
	show_hudmessage(0, "Map changing to %s in %d...", g_pendingChangeMap, g_changeMapCountdown);
}
