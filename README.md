# KTP Admin Audit Plugin

**Version:** 2.6.0
**Author:** Nein_
**Date:** January 2026

## Overview

KTP Admin Audit provides secure, menu-based admin commands (kick, ban, changemap) with full Discord audit logging. Unlike RCON-based commands, this plugin requires admins to be **connected to the server** and logs all actions for accountability.

Designed to work with KTP ReHLDS where kick/ban console commands are blocked at the engine level, ensuring all player removals go through this audited system.

## Features

- **Menu-Based Kick/Ban** - Interactive player selection menus
- **Menu-Based Map Change** - Map selection from ktp_maps.ini (v2.4.0+)
- **Admin Flag Permissions** - Requires ADMIN_KICK (c), ADMIN_BAN (d), or ADMIN_MAP (f) flags
- **Immunity Protection** - Players with ADMIN_IMMUNITY (a) cannot be kicked/banned
- **Ban Duration Selection** - 1 hour, 1 day, 1 week, or permanent
- **Discord Audit Logging** - Real-time notifications to configured channels
- **RCON Audit Logging** - Logs quit/restart commands with source IP (v2.2.0+)
- **Console Command Audit** - Catches all console commands including LinuxGSM (v2.3.0+)
- **Admin Server Commands** - `.restart` / `.quit` with ADMIN_RCON flag (v2.3.0+)
- **HLTV Kick Support** - HLTV proxies appear in kick menu (v2.3.0+)
- **ReHLDS Integration** - Uses `ktp_drop_client` native to bypass blocked kick command
- **Full Accountability** - Logs admin name, SteamID, IP, target details

## Requirements

- **KTP AMX 2.6+** (for ktp_discord.inc curl module)
- **KTP ReHLDS 3.20+** (for RH_SV_Rcon hook - RCON audit)
- **KTP ReAPI 5.29+** (for RH_SV_Rcon hookchain registration)
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
| `.changemap` or `/changemap` | ADMIN_MAP (f) | Open map selection menu |
| `.restart` or `/restart` | ADMIN_RCON (l) | Restart server |
| `.quit` or `/quit` | ADMIN_RCON (l) | Shutdown server |
| `ktp_kick` | ADMIN_KICK (c) | Console command for kick menu |
| `ktp_ban` | ADMIN_BAN (d) | Console command for ban menu |
| `ktp_changemap` | ADMIN_MAP (f) | Console command for map menu |

## Admin Flags

| Flag | Name | Description |
|------|------|-------------|
| `a` | ADMIN_IMMUNITY | Protected from kick/ban |
| `c` | ADMIN_KICK | Can kick players |
| `d` | ADMIN_BAN | Can ban players |
| `f` | ADMIN_MAP | Can change maps |
| `l` | ADMIN_RCON | Can use .restart / .quit commands |

### Example users.ini

```ini
; Full admin with kick, ban, and changemap
"STEAM_0:1:12345678" "" "cdf" "ce"

; Full admin with server restart/quit
"STEAM_0:1:12345678" "" "cdfl" "ce"

; Kick-only admin
"STEAM_0:1:87654321" "" "c" "ce"

; Admin with immunity (cannot be kicked/banned by others)
"STEAM_0:0:11111111" "" "acdfl" "ce"
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
