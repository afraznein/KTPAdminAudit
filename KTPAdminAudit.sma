/* KTP Admin Audit v2.1.0
 * Menu-based admin kick/ban with full audit logging
 *
 * AUTHOR: Nein_
 * VERSION: 2.1.0
 * DATE: 2025-12-21
 * GITHUB: https://github.com/KTP-Community/KTPAdminAudit
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
 *   .kick / /kick  - Open kick menu (requires ADMIN_KICK flag "c")
 *   .ban  / /ban   - Open ban menu (requires ADMIN_BAN flag "d")
 *
 * ========== ADMIN FLAGS ==========
 *   c - ADMIN_KICK     - Required to kick players
 *   d - ADMIN_BAN      - Required to ban players
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

#pragma semicolon 1

// KTP native for dropping clients via ReHLDS API (bypasses blocked kick command)
native ktp_drop_client(id, const reason[] = "");

#define PLUGIN "KTP Admin Audit"
#define VERSION "2.1.0"
#define AUTHOR "Nein_"

// Menu action constants
#define ACTION_NONE     0
#define ACTION_KICK     1
#define ACTION_BAN      2

// Menu state per player
new g_menuAction[33];       // ACTION_NONE, ACTION_KICK, or ACTION_BAN
new g_menuTarget[33];       // Selected target player id
new g_menuPage[33];         // Current menu page for pagination
new g_validPlayers[33][32]; // Valid player indices for each admin
new g_validPlayerCount[33]; // Count of valid players

// Ban duration options (in minutes, 0 = permanent)
new const g_banDurations[] = { 60, 1440, 10080, 0 };
new const g_banDurationNames[][] = { "1 Hour", "1 Day", "1 Week", "Permanent" };

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

	log_amx("[%s] v%s initialized", PLUGIN, VERSION);
}

public plugin_cfg()
{
	// Load shared Discord configuration
	ktp_discord_load_config();
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

	client_print(id, print_chat, "[KTP] %s v%s by %s", PLUGIN, VERSION, AUTHOR);
	client_print(id, print_chat, "[KTP] Use .kick or .ban for audited admin actions.");
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
	get_players(players, num, "ch");  // connected, not HLTV

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
