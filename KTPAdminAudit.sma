/* KTP Admin Audit v1.2.0
 * Logs administrative actions (RCON kicks, bans, etc.) to Discord
 *
 * AUTHOR: Nein_
 * VERSION: 1.2.0
 * DATE: 2025-12-03
 *
 * ========== FEATURES ==========
 * - Monitors and logs RCON kick commands
 * - Records admin identity (SteamID, name, IP)
 * - Records target player identity
 * - Sends notifications to Discord webhook
 * - Multi-channel support (sends to ALL configured audit channels)
 * - Comprehensive logging to AMX logs
 *
 * ========== REQUIREMENTS ==========
 * - AMX ModX 1.9+
 * - ReHLDS (recommended for better hook support)
 * - cURL extension (for Discord notifications)
 *
 * ========== CONFIGURATION ==========
 * Uses same discord.ini as KTPMatchHandler
 * Path: <configsdir>/discord.ini (e.g., addons/ktpamx/configs/discord.ini)
 *
 * Required keys:
 *   discord_relay_url=<your relay endpoint>
 *   discord_channel_id=<your channel ID>
 *   discord_auth_secret=<your auth secret>
 *
 * Optional audit channel keys (can configure multiple):
 *   discord_channel_id_audit_competitive=<competitive audit channel>
 *   discord_channel_id_audit_12man=<12man/draft audit channel>
 *   discord_channel_id_audit_scrim=<scrim audit channel>
 *   discord_channel_id_admin=<legacy general admin channel>
 *
 * NOTE: Audit messages will be sent to ALL configured audit channels.
 *       This allows you to have separate audit logs for different match types.
 *
 * ========== CVARS ==========
 *   ktp_audit_discord_ini "<configsdir>/discord.ini"  // Path to Discord config (auto-detected)
 *   ktp_audit_log "1"                                  // Enable/disable logging
 *
 * ========== CHANGELOG ==========
 * v1.2.0 (2025-12-03) - KTP AMX Compatibility
 *   * FIXED: Changed from register_srvcmd to register_concmd for kick command
 *     (register_srvcmd cannot hook built-in engine commands)
 *   * FIXED: Use get_configsdir() for dynamic config path resolution
 *   * IMPROVED: Now works properly with KTP AMX and standard AMX Mod X
 *
 * v1.1.0 (2025-11-24) - Multi-Channel Audit Support
 *   + ADDED: Per-match-type audit channels (competitive, 12man, scrim)
 *   + CHANGED: Now sends to ALL configured audit channels (not just one)
 *   * IMPROVED: Better channel configuration flexibility
 *
 * v1.0.0 (2025-11-24) - Initial Release
 *   + ADDED: RCON kick detection and logging
 *   + ADDED: Discord notification with admin and target details
 *   + ADDED: SteamID, name, and IP logging for accountability
 *   + ADDED: Separate admin audit Discord channel support
 */

#include <amxmodx>
#include <amxmisc>

#if defined _reapi_included
    #define HAS_REAPI
#endif

#if defined _curl_included
    #define HAS_CURL
#endif

#pragma semicolon 1

#define PLUGIN "KTP Admin Audit"
#define VERSION "1.2.0"
#define AUTHOR "Nein_"

#define MAX_PLAYERS 32
#define MAX_AUDIT_CHANNELS 10

// Discord config
new g_discordRelayUrl[256];
new g_discordChannelId[64];
new g_discordAuthSecret[128];

// Audit channels (can have multiple)
new g_auditChannels[MAX_AUDIT_CHANNELS][64];
new g_auditChannelCount = 0;

// CVARs
new g_cvarDiscordIni;
new g_cvarAuditLog;

// Server info
new g_serverHostname[128];

public plugin_init() {
    register_plugin(PLUGIN, VERSION, AUTHOR);

    // Register CVARs - use get_configsdir() for proper path
    new configsDir[128];
    get_configsdir(configsDir, charsmax(configsDir));
    new defaultIniPath[192];
    formatex(defaultIniPath, charsmax(defaultIniPath), "%s/discord.ini", configsDir);
    g_cvarDiscordIni = register_cvar("ktp_audit_discord_ini", defaultIniPath);
    g_cvarAuditLog = register_cvar("ktp_audit_log", "1");

    // Hook the kick command using register_concmd
    // This intercepts the command before the engine processes it
    // Using ADMIN_RCON flag so only RCON/admin executions trigger our handler
    register_concmd("kick", "cmd_kick", ADMIN_RCON, "- intercepts kick for audit logging");

    // Cache server hostname
    get_cvar_string("hostname", g_serverHostname, charsmax(g_serverHostname));

    log_amx("[KTP Admin Audit] Plugin initialized v%s", VERSION);
}

public plugin_cfg() {
    load_discord_config();
}

// ================= Client Connect =================
public client_putinserver(id) {
    if (!is_user_bot(id) && !is_user_hltv(id)) {
        set_task(5.0, "fn_version_display", id);
    }
}

public fn_version_display(id) {
    if (is_user_connected(id)) {
        client_print(id, print_chat, "%s version %s by %s", PLUGIN, VERSION, AUTHOR);
        client_print(id, print_console, "%s version %s by %s", PLUGIN, VERSION, AUTHOR);
    }
}

// ================= RCON Command Hooks =================
public cmd_kick() {
    // Get command arguments
    new arg1[64], arg2[128];
    read_argv(1, arg1, charsmax(arg1));  // Target (can be name, userid, or steamid)
    read_argv(2, arg2, charsmax(arg2));  // Reason (optional)

    // Find who executed the command
    new adminId = find_admin_executing_command();
    new adminName[32], adminAuthId[44], adminIp[32];

    if (adminId > 0 && is_user_connected(adminId)) {
        get_user_name(adminId, adminName, charsmax(adminName));
        get_user_authid(adminId, adminAuthId, charsmax(adminAuthId));
        get_user_ip(adminId, adminIp, charsmax(adminIp), 1);
    } else {
        copy(adminName, charsmax(adminName), "Console/RCON");
        copy(adminAuthId, charsmax(adminAuthId), "N/A");
        copy(adminIp, charsmax(adminIp), "N/A");
    }

    // Try to find target player
    new targetId = find_target_player(arg1);
    new targetName[32], targetAuthId[44], targetIp[32];

    if (targetId > 0 && is_user_connected(targetId)) {
        get_user_name(targetId, targetName, charsmax(targetName));
        get_user_authid(targetId, targetAuthId, charsmax(targetAuthId));
        get_user_ip(targetId, targetIp, charsmax(targetIp), 1);
    } else {
        copy(targetName, charsmax(targetName), arg1);
        copy(targetAuthId, charsmax(targetAuthId), "Unknown");
        copy(targetIp, charsmax(targetIp), "Unknown");
    }

    new reason[128];
    if (arg2[0]) {
        copy(reason, charsmax(reason), arg2);
    } else {
        copy(reason, charsmax(reason), "No reason specified");
    }

    // Log to AMX
    log_amx("[KTP Admin Audit] KICK | Admin: %s [%s | %s] | Target: %s [%s | %s] | Reason: %s",
        adminName, adminAuthId, adminIp,
        targetName, targetAuthId, targetIp,
        reason);

    // Send to Discord
    #if defined HAS_CURL
    if (get_pcvar_num(g_cvarAuditLog)) {
        send_kick_to_discord(adminName, adminAuthId, adminIp, targetName, targetAuthId, targetIp, reason);
    }
    #endif

    return PLUGIN_CONTINUE;
}

// ================= Helper Functions =================
stock find_admin_executing_command() {
    // Try to find the player who executed the command
    // This is best-effort - RCON commands don't always have a clear source
    new players[MAX_PLAYERS], pnum;
    get_players(players, pnum, "ch");

    // Check for admin flag holders
    for (new i = 0; i < pnum; i++) {
        new id = players[i];
        if (get_user_flags(id) & ADMIN_KICK) {
            return id;
        }
    }

    return 0;  // Console/RCON
}

stock find_target_player(const target[]) {
    // Try to find player by name, userid, or authid
    new players[MAX_PLAYERS], pnum;
    get_players(players, pnum, "ch");

    // Try exact name match
    for (new i = 0; i < pnum; i++) {
        new id = players[i];
        new name[32];
        get_user_name(id, name, charsmax(name));
        if (equal(name, target)) {
            return id;
        }
    }

    // Try partial name match
    for (new i = 0; i < pnum; i++) {
        new id = players[i];
        new name[32];
        get_user_name(id, name, charsmax(name));
        if (containi(name, target) != -1) {
            return id;
        }
    }

    // Try userid
    new userid = str_to_num(target);
    if (userid > 0) {
        new id = find_player("i", userid);
        if (id > 0) return id;
    }

    // Try authid
    for (new i = 0; i < pnum; i++) {
        new id = players[i];
        new authid[44];
        get_user_authid(id, authid, charsmax(authid));
        if (equal(authid, target)) {
            return id;
        }
    }

    return 0;  // Not found
}

// ================= Discord Integration =================
stock load_discord_config() {
    // Reset to defaults
    g_discordRelayUrl[0] = 0;
    g_discordChannelId[0] = 0;
    g_discordAuthSecret[0] = 0;
    g_auditChannelCount = 0;
    for (new i = 0; i < MAX_AUDIT_CHANNELS; i++) {
        g_auditChannels[i][0] = 0;
    }

    new path[192];
    get_pcvar_string(g_cvarDiscordIni, path, charsmax(path));
    if (!path[0]) {
        // Use get_configsdir() for proper path resolution
        new configsDir[128];
        get_configsdir(configsDir, charsmax(configsDir));
        formatex(path, charsmax(path), "%s/discord.ini", configsDir);
    }

    new fp = fopen(path, "rt");
    if (!fp) {
        log_amx("[KTP Admin Audit] Discord config not found: %s", path);
        return;
    }

    new line[256], key[64], val[192];
    new loaded = 0;

    while (!feof(fp)) {
        fgets(fp, line, charsmax(line));
        trim(line);
        if (!line[0] || line[0] == ';' || line[0] == '#') continue;

        new eq = contain(line, "=");
        if (eq <= 0) continue;

        copy(key, min(eq, charsmax(key)), line);
        trim(key);
        for (new k = 0; key[k]; k++) key[k] = tolower(key[k]);

        copy(val, charsmax(val), line[eq + 1]);
        trim(val);

        if (!key[0] || !val[0]) continue;

        // Parse Discord config keys
        if (equal(key, "discord_relay_url")) {
            copy(g_discordRelayUrl, charsmax(g_discordRelayUrl), val);
            loaded++;
        } else if (equal(key, "discord_channel_id")) {
            copy(g_discordChannelId, charsmax(g_discordChannelId), val);
            loaded++;
        } else if (equal(key, "discord_auth_secret")) {
            copy(g_discordAuthSecret, charsmax(g_discordAuthSecret), val);
            loaded++;
        }
        // Collect ALL audit channel configurations
        else if (containi(key, "discord_channel_id_audit") != -1 || equal(key, "discord_channel_id_admin")) {
            if (g_auditChannelCount < MAX_AUDIT_CHANNELS) {
                copy(g_auditChannels[g_auditChannelCount], 63, val);
                log_amx("[KTP Admin Audit] Registered audit channel #%d from key '%s': %s",
                    g_auditChannelCount + 1, key, val);
                g_auditChannelCount++;
                loaded++;
            }
        }
    }
    fclose(fp);

    log_amx("[KTP Admin Audit] Discord config loaded: %d keys, %d audit channels from %s",
        loaded, g_auditChannelCount, path);
}

#if defined HAS_CURL
stock send_kick_to_discord(const adminName[], const adminAuthId[], const adminIp[],
                            const targetName[], const targetAuthId[], const targetIp[],
                            const reason[]) {
    // Check if Discord is configured
    if (!g_discordRelayUrl[0] || g_auditChannelCount == 0 || !g_discordAuthSecret[0]) {
        log_amx("[KTP Admin Audit] Discord not configured or no audit channels (channels: %d)", g_auditChannelCount);
        return;
    }

    // Build message
    new message[512];
    formatex(message, charsmax(message),
        "🚨 **ADMIN ACTION: KICK**\n**Admin:** %s [%s | %s]\n**Target:** %s [%s | %s]\n**Reason:** %s\n**Server:** %s",
        adminName, adminAuthId, adminIp,
        targetName, targetAuthId, targetIp,
        reason,
        g_serverHostname);

    // Escape special characters for JSON
    new escapedMsg[768];
    new msgLen = strlen(message);
    new j = 0;
    for (new i = 0; i < msgLen; i++) {
        if (j >= charsmax(escapedMsg) - 2) break;

        switch (message[i]) {
            case '"': { escapedMsg[j++] = 92; escapedMsg[j++] = '"'; }
            case 92: { escapedMsg[j++] = 92; escapedMsg[j++] = 92; }
            case 10: { escapedMsg[j++] = 92; escapedMsg[j++] = 'n'; }
            case 13: { escapedMsg[j++] = 92; escapedMsg[j++] = 'r'; }
            case 9: { escapedMsg[j++] = 92; escapedMsg[j++] = 't'; }
            default: {
                if (message[i] >= 32 || message[i] == 10 || message[i] == 13 || message[i] == 9) {
                    escapedMsg[j++] = message[i];
                }
            }
        }
    }
    escapedMsg[j] = 0;

    // Send to ALL configured audit channels
    for (new c = 0; c < g_auditChannelCount; c++) {
        if (!g_auditChannels[c][0]) continue;

        // Build JSON payload for this channel
        new payload[1024];
        formatex(payload, charsmax(payload),
            "{^"channelId^":^"%s^",^"content^":^"%s^"}",
            g_auditChannels[c], escapedMsg);

        // Create cURL handle
        new CURL:curl = curl_easy_init();
        if (curl) {
            curl_easy_setopt(curl, CURLOPT_URL, g_discordRelayUrl);
            curl_easy_setopt(curl, CURLOPT_POST, 1);
            curl_easy_setopt(curl, CURLOPT_POSTFIELDS, payload);
            curl_easy_setopt(curl, CURLOPT_TIMEOUT, 10);

            // Set headers
            new CURLHeaders:headers = curl_slist_append("Content-Type: application/json");
            new authHeader[192];
            formatex(authHeader, charsmax(authHeader), "X-Relay-Auth: %s", g_discordAuthSecret);
            headers = curl_slist_append(headers, authHeader);
            curl_easy_setopt(curl, CURLOPT_HTTPHEADER, headers);

            // Perform request
            curl_easy_perform(curl, "audit_discord_callback");

            log_amx("[KTP Admin Audit] Sent kick notification to audit channel #%d: %s", c + 1, g_auditChannels[c]);
        }
    }
}

public audit_discord_callback(CURL:curl, CURLcode:code) {
    if (code != CURLE_OK) {
        new error[128];
        curl_easy_strerror(code, error, charsmax(error));
        log_amx("[KTP Admin Audit] Discord error: %s", error);
    }
    curl_easy_cleanup(curl);
}
#endif
