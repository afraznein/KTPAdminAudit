# KTP Admin Audit Plugin

**Version:** 1.2.0
**Author:** Nein_
**Date:** December 3, 2025

## Overview

KTP Admin Audit is a lightweight administrative action monitoring plugin that logs RCON kicks and other admin actions to Discord for accountability and audit trail purposes. It supports **multiple audit channels** to send the same notification to different Discord channels (e.g., competitive audit log, 12man audit log, etc.).

## Features

- ✅ **RCON Kick Monitoring** - Detects and logs all kick commands
- ✅ **Admin Identity Tracking** - Records SteamID, name, and IP of admin
- ✅ **Target Player Tracking** - Records SteamID, name, and IP of kicked player
- ✅ **Discord Notifications** - Real-time alerts to Discord webhook
- ✅ **Multi-Channel Support** - Sends to ALL configured audit channels
- ✅ **Per-Match-Type Channels** - Separate channels for competitive, 12man, and scrim
- ✅ **Comprehensive Logging** - Full details logged to AMX logs

## Requirements

- **AMX ModX 1.9+** or **KTP AMX 2.0+**
- **ReHLDS** (recommended for better hook support)
- **cURL extension** (for Discord notifications)

## Installation

1. Copy `KTPAdminAudit.amxx` to your plugins directory:
   - AMX Mod X: `addons/amxmodx/plugins/`
   - KTP AMX: `addons/ktpamx/plugins/`
2. Add to your `plugins.ini`:
   ```
   KTPAdminAudit.amxx
   ```
3. Configure Discord settings in `<configsdir>/discord.ini` (see below)
4. Restart server or change map

> **Note:** The plugin automatically detects the correct configs directory using `get_configsdir()`, so it works with both AMX Mod X and KTP AMX without modification.

## Configuration

### Discord Configuration (`discord.ini`)

KTP Admin Audit uses the same `discord.ini` file as KTPMatchHandler:

```ini
# Required settings
discord_relay_url=https://your-relay-endpoint.com/webhook
discord_channel_id=1234567890123456789
discord_auth_secret=your_secret_key_here

# Optional: Audit channel configurations (can configure multiple)
discord_channel_id_audit_competitive=1111111111111111111  # Competitive match audit log
discord_channel_id_audit_12man=2222222222222222222       # 12man/draft audit log
discord_channel_id_audit_scrim=3333333333333333333       # Scrim audit log
discord_channel_id_admin=9999999999999999999             # Legacy general admin channel
```

**Important Notes:**
- The plugin sends notifications to **ALL** configured audit channels
- Any key containing `discord_channel_id_audit` OR exactly matching `discord_channel_id_admin` will be registered as an audit channel
- You can configure as many audit channels as you want (up to 10)
- This allows you to mirror the same admin action to multiple Discord servers/channels
- Useful for having separate audit logs per match type (competitive, 12man, scrim)

### CVARs

```
ktp_audit_discord_ini "<configsdir>/discord.ini"  // Path to Discord config (auto-detected)
ktp_audit_log "1"                                  // Enable/disable logging (1=on, 0=off)
```

> **Note:** The `<configsdir>` path is automatically resolved at runtime (e.g., `addons/ktpamx/configs/` for KTP AMX or `addons/amxmodx/configs/` for standard AMX Mod X).

## Discord Message Format

When an RCON kick is detected, the following message is sent to Discord:

```
🚨 **ADMIN ACTION: KICK**
**Admin:** PlayerName [STEAM_0:1:12345678 | 192.168.1.100]
**Target:** TargetName [STEAM_0:1:87654321 | 192.168.1.101]
**Reason:** Cheating
**Server:** Your Server Name
```

## How It Works

1. **Command Interception** - The plugin uses `register_concmd()` to intercept the `kick` command before the engine processes it
2. **Identity Resolution** - Attempts to identify both the admin and target player
3. **Data Collection** - Gathers name, SteamID, and IP for both parties
4. **Logging** - Writes to AMX logs and sends to Discord (if configured)

### Admin Detection

The plugin attempts to identify the admin who executed the kick:
- Checks for players with ADMIN_KICK flag
- Falls back to "Console/RCON" if no admin is found

### Target Detection

The plugin attempts to find the target player by:
1. Exact name match
2. Partial name match (containi)
3. User ID match
4. SteamID match

If the target cannot be found (already disconnected), the plugin logs the raw target string provided to the kick command.

## AMX Log Format

```
L 11/24/2025 - 14:30:45: [KTP Admin Audit] KICK | Admin: AdminName [STEAM_0:1:12345678 | 192.168.1.100] | Target: PlayerName [STEAM_0:1:87654321 | 192.168.1.101] | Reason: Cheating
```

## Future Enhancements

Planned features for future versions:
- Ban command monitoring
- Map change tracking
- CVAR change auditing
- Admin command history
- Configurable action filters

## Troubleshooting

### Discord messages not sending

1. **Check Discord config** - Verify `discord.ini` exists and has correct settings
2. **Test cURL** - Ensure cURL extension is loaded (`amxx modules` in console)
3. **Check logs** - Look for Discord errors in AMX logs
4. **Verify relay** - Test your Discord relay endpoint manually

### Admin not detected correctly

- Ensure the admin has the ADMIN_KICK flag
- Console/RCON commands will show as "Console/RCON" (this is expected)

### Target player shows as "Unknown"

- This happens if the player was already kicked/disconnected before the hook runs
- The plugin will still log the raw target string provided to the kick command

## Security Notes

- **Auth Secret** - Keep your `discord_auth_secret` private
- **IP Logging** - Player IPs are logged for audit purposes (ensure compliance with local laws)
- **Access Control** - This plugin does NOT restrict admin commands, only logs them

## Support

For issues, feature requests, or questions:
- Check AMX logs for detailed error messages
- Verify Discord configuration
- Test with `ktp_audit_log 1` to ensure logging is enabled

## Changelog

See [CHANGELOG.md](CHANGELOG.md) for full version history.

### v1.2.0 (2025-12-03)
- **Fixed:** Changed from `register_srvcmd` to `register_concmd` for kick command interception
  - `register_srvcmd` cannot hook built-in engine commands like `kick`
  - Now properly intercepts kick commands before engine processes them
- **Fixed:** Use `get_configsdir()` for dynamic config path resolution
- **Improved:** Now works properly with both KTP AMX and standard AMX Mod X
- **Updated:** Documentation to reflect dynamic path handling

### v1.1.0 (2025-11-24)
- **Added:** Multi-channel support - sends to ALL configured audit channels
- **Added:** Per-match-type audit channels (competitive, 12man, scrim)
- **Changed:** Now collects any key containing `discord_channel_id_audit` or `discord_channel_id_admin`
- **Improved:** Better configuration flexibility with up to 10 audit channels
- **Improved:** Detailed logging shows which channels received notifications

### v1.0.0 (2025-11-24)
- Initial release
- RCON kick detection and logging
- Discord notification with admin and target details
- SteamID, name, and IP logging
- Separate admin audit Discord channel support
