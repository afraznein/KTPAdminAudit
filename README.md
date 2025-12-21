# KTP Admin Audit Plugin

**Version:** 2.1.0
**Author:** Nein_
**Date:** December 21, 2025

## Overview

KTP Admin Audit provides secure, menu-based kick and ban functionality with full Discord audit logging. Unlike RCON-based commands, this plugin requires admins to be **connected to the server** and logs all actions for accountability.

Designed to work with KTP ReHLDS where kick/ban console commands are blocked at the engine level, ensuring all player removals go through this audited system.

## Features

- **Menu-Based Kick/Ban** - Interactive player selection menus
- **Admin Flag Permissions** - Requires ADMIN_KICK (c) or ADMIN_BAN (d) flags
- **Immunity Protection** - Players with ADMIN_IMMUNITY (a) cannot be kicked/banned
- **Ban Duration Selection** - 1 hour, 1 day, 1 week, or permanent
- **Discord Audit Logging** - Real-time notifications to configured channels
- **ReHLDS Integration** - Uses `ktp_drop_client` native to bypass blocked kick command
- **Full Accountability** - Logs admin name, SteamID, IP, target details

## Requirements

- **KTP AMX 2.5+** (or AMX Mod X 1.9+ with limitations)
- **KTP ReHLDS** (recommended - kick/ban commands blocked at engine level)
- **ktp_discord.inc** (shared Discord integration)

## Installation

1. Copy `KTPAdminAudit.amxx` to `addons/ktpamx/plugins/`
2. Add to `plugins.ini`:
   ```
   KTPAdminAudit.amxx
   ```
3. Configure Discord in `<configsdir>/discord.ini`
4. Configure admin users in `<configsdir>/users.ini`
5. Restart server

## Commands

| Command | Permission | Description |
|---------|------------|-------------|
| `.kick` or `/kick` | ADMIN_KICK (c) | Open kick menu |
| `.ban` or `/ban` | ADMIN_BAN (d) | Open ban menu |

## Admin Flags

| Flag | Name | Description |
|------|------|-------------|
| `a` | ADMIN_IMMUNITY | Protected from kick/ban |
| `c` | ADMIN_KICK | Can kick players |
| `d` | ADMIN_BAN | Can ban players |

### Example users.ini

```ini
; Full admin with kick and ban
"STEAM_0:1:12345678" "" "cd" "ce"

; Kick-only admin
"STEAM_0:1:87654321" "" "c" "ce"

; Admin with immunity (cannot be kicked/banned by others)
"STEAM_0:0:11111111" "" "acd" "ce"
```

**Connection Flags:**
- `c` = Steam ID authentication
- `e` = No password required

## Configuration

### Discord Configuration (`discord.ini`)

```ini
discord_relay_url=https://your-relay-endpoint.com/webhook
discord_channel_id=1234567890123456789
discord_auth_secret=your_secret_key_here

# Audit channels (notifications sent to ALL matching channels)
discord_channel_id_audit=1111111111111111111
discord_channel_id_admin=2222222222222222222
```

## How It Works

1. Admin types `.kick` or `.ban` in chat
2. Plugin verifies admin has required flag
3. Player selection menu is displayed
4. Admin selects target player
5. For bans, duration selection menu appears
6. Action is logged to server and Discord
7. `ktp_drop_client` native kicks the player via ReHLDS API

### Why ktp_drop_client?

KTP ReHLDS blocks the `kick` console command to prevent remote/untraceable kicks via HLSW or RCON. The `ktp_drop_client` native calls ReHLDS's `DropClient` API directly, bypassing the blocked command while still going through the audited plugin.

## Discord Notification Format

**Kick:**
```
Admin KICK
Admin: PlayerName (STEAM_0:1:12345678)
Target: TargetName (STEAM_0:1:87654321)
```

**Ban:**
```
Admin BAN
Admin: PlayerName (STEAM_0:1:12345678)
Target: TargetName (STEAM_0:1:87654321)
Duration: 1 day
```

## Troubleshooting

### "You don't have permission to kick players"
- Check `users.ini` - ensure SteamID is correct
- Verify connection flags are `ce` (steam auth + no password)
- Confirm admin flags include `c` for kick or `d` for ban

### Kick executes but player stays connected
- Ensure `ktpamx_i386.so` has the `ktp_drop_client` native (KTP AMX 2.5+)
- Restart server to load new module

### Discord messages not sending
- Check `discord.ini` configuration
- Verify relay endpoint is accessible
- Check server logs for cURL errors

## Building

```batch
compile.bat
```

Uses WSL with KTPAMXX compiler. Output is staged to `N:\Nein_\KTP DoD Server\dod\addons\ktpamx\plugins\`.

## Changelog

See [CHANGELOG.md](CHANGELOG.md) for full version history.

## License

Part of the KTP project. See LICENSE for details.
