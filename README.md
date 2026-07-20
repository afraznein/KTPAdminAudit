# KTP Admin Audit Plugin

**Version:** 2.7.18
**Author:** Nein_
**Date:** July 2026

## Overview

KTP Admin Audit provides secure, menu-based admin commands (kick, ban, changemap) with full Discord audit logging. Unlike RCON-based commands, this plugin requires admins to be **connected to the server** and logs all actions for accountability.

Designed to work with KTP ReHLDS where kick/ban console commands are blocked at the engine level, ensuring all player removals go through this audited system.

## Features

- **Menu-Based Kick/Ban** - Interactive player selection menus with pagination
- **Menu-Based Map Change** - Map selection from `ktp_maps.ini` with 5-second countdown
- **RCON Quit/Exit Blocking** - RCON quit/exit commands are BLOCKED; must use `.quit` in-game for accountability (v2.7.1+)
- **Admin Flag Permissions** - Requires ADMIN_KICK (c) or ADMIN_BAN (d) flags
- **Immunity Protection** - Players with ADMIN_IMMUNITY (a) cannot be kicked/banned
- **Ban Duration Selection** - 1 hour, 1 day, 1 week, or permanent
- **Timed-Ban Persistence** - Timed bans survive server restarts via `ktp_timed_bans.ini` (v2.7.16+); `.unban <steamid>` lifts one cleanly (v2.7.17+)
- **Discord Audit Logging** - Real-time notifications to all configured audit channels
- **RCON Audit Logging** - Logs restart commands with source IP (v2.2.0+); failed RCON auth attempts batched into per-minute Discord summaries (v2.7.16+, ReHLDS .928+)
- **Console Command Audit** - Catches all console commands including LinuxGSM (v2.3.0+)
- **Admin Server Commands** - `.restart` / `.quit` with ADMIN_RCON flag (v2.3.0+)
- **Match Protection** - `.changemap` blocked during active matches (requires KTPMatchHandler)
- **HLTV Kick Support** - HLTV proxies appear in kick menu (v2.3.0+)
- **Changelevel Countdown** - 5-second HUD countdown before map changes (v2.6.0+)
- **ReHLDS Integration** - Uses `ktp_drop_client` native to bypass blocked kick command
- **Full Accountability** - Logs admin name, SteamID, IP, target details
- **Admin Version Display** - Shows plugin version to admins with KICK/BAN flags on connect

## Requirements

- **KTP AMX 2.6+** (for ktp_discord.inc curl module and ktp_drop_client native)
- **KTP ReHLDS 3.20+** (for RH_SV_Rcon and RH_Host_Changelevel_f hooks)
- **KTP ReAPI 5.29+** (for hookchain registration)
- **KTPMatchHandler** (**required**) — supplies the `ktp_is_match_active()`
  native used for match-active detection on `.changemap`. This plugin declares
  it without a native filter, so AMXX resolves it at load: if KTPMatchHandler
  is absent or loads later, **KTPAdminAudit fails to load entirely** — it does
  not degrade to "no match detection". Order it after KTPMatchHandler in
  `plugins.ini`.
- **ktp_discord.inc** (shared Discord integration)

## Installation

1. Build the plugin — `bash compile.sh` — then copy `compiled/KTPAdminAudit.amxx`
   to `addons/ktpamx/plugins/`. The repo ships no prebuilt `.amxx`; build output is
   gitignored so a stale binary can't be mistaken for the current one.
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
| `.unban <steamid>` or `/unban` | ADMIN_BAN (d) | Lift a ban — removeid + writeid + timed-ban record removal |
| `.changemap` or `/changemap` | All players | Open map selection menu (blocked during matches) |
| `.restart` or `/restart` | ADMIN_RCON (l) | Restart server |
| `.quit` or `/quit` | ADMIN_RCON (l) | Shutdown server |
| `ktp_kick` | ADMIN_KICK (c) | Console command for kick menu |
| `ktp_ban` | ADMIN_BAN (d) | Console command for ban menu |
| `ktp_unban` | ADMIN_BAN (d) | Console command for unban |
| `ktp_changemap` | All players | Console command for map menu |

**Note:** All chat commands also work via team chat (`say_team`).

## Admin Flags

| Flag | Name | Description |
|------|------|-------------|
| `a` | ADMIN_IMMUNITY | Protected from kick/ban |
| `c` | ADMIN_KICK | Can kick players |
| `d` | ADMIN_BAN | Can ban and unban players |
| `l` | ADMIN_RCON | Can use .restart / .quit commands |

### Example users.ini

```ini
; Full admin with kick, ban, restart/quit
"STEAM_0:1:12345678" "" "cdl" "ce"

; Kick-only admin
"STEAM_0:1:87654321" "" "c" "ce"

; Admin with immunity (cannot be kicked/banned by others)
"STEAM_0:0:11111111" "" "acdl" "ce"
```

**Connection Flags:**
- `c` = Steam ID authentication
- `e` = No password required

## Configuration

### Map List (`ktp_maps.ini`)

Maps available in `.changemap` menu are loaded from `<configsdir>/ktp_maps.ini`. This file is shared with KTPMatchHandler.

```ini
[dod_anzio]
name = Anzio

[dod_avalanche]
name = Avalanche

[dod_charlie]
name = Charlie
```

Only maps that exist on the server (verified via `maps/<mapname>.bsp`) are shown in the menu.

**Limits:** Maximum 64 maps can be loaded from ktp_maps.ini.

### Timed-Ban Persistence (`ktp_timed_bans.ini`)

The engine's `writeid` only saves **permanent** ban filters — a timed `banid` is gone after a server restart (the fleet restarts nightly at 03:00 ET). The plugin owns timed-ban persistence instead:

- Every timed ban appends a record to `<configsdir>/ktp_timed_bans.ini`:
  ```
  steamid|unban_epoch|admin_steamid|target_name|admin_name
  ```
  `unban_epoch` is a Unix timestamp (`get_systime()` + duration). The names are informational only.
- At boot the plugin reads the file, **drops expired entries** (rewriting the file without them, logged as `TIMED_BAN_EXPIRED`), dedups duplicate SteamIDs (latest line wins), skips malformed lines (content logged), and re-applies each remaining entry with `banid <remaining_minutes> <steamid>` — logged as `TIMED_BAN_REAPPLY sid=... remaining_min=...`.
- No `writeid` is issued for these — re-application at every boot carries the persistence. Re-apply runs once per process (not on every map change).
- **To lift a timed ban early: use `.unban <steamid>`** (v2.7.17+) — it runs `removeid` + `writeid` AND removes the SteamID's lines from `ktp_timed_bans.ini` in one step. A bare `removeid` alone is NOT enough: the persisted record re-applies the ban at the next restart.
- The file is created on the first timed ban; a missing file is normal.

### Failed-RCON Audit Batching (ReHLDS .928+)

On engines where `SV_Rcon` fires for **failed** auth attempts too (KTP-ReHLDS 3.22.0.928+), the plugin consumes them:

- Every failure is logged locally immediately: `RCON AUTH FAIL from <ip:port> (cmd: '<name>')`. Passwords are stripped engine-side before the hook fires.
- Discord sees **one summary embed per 60-second window**, and only when the window saw failures — per source IP: attempt count, first/last timestamp, last command name (up to 16 IPs per window, extra attempts counted in an overflow line). The relay has no queue, and brute-force storms can exceed Discord rate limits — never one embed per failure.
- Valid RCON handling (quit/exit block, restart audit) is unchanged. On .927 engines the failure path never fires; the code is inert.

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

Audit alerts are Discord embeds: the title carries the KTP emoji and the description
uses markdown. The two samples below are illustrative, not literal.

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

The plugin emits eleven audit embed types in total: Admin KICK, Admin KICK (invalid
SteamID), Admin BAN, Admin UNBAN, Admin Map Change, Admin Server Restart, Admin Server
Shutdown, Console Server Control, RCON Server Control, RCON Quit BLOCKED, and RCON Auth
Failures.

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

```bash
wsl bash -c "cd '/mnt/n/Nein_/KTP Git Projects/KTPAdminAudit' && bash compile.sh"
```

Uses WSL with KTPAMXX compiler. Output is staged to `N:\Nein_\KTP Git Projects\KTP DoD Server\serverfiles\dod\addons\ktpamx\plugins\`.

## Changelog

See [CHANGELOG.md](CHANGELOG.md) for full version history.

## License

Part of the KTP project. See LICENSE for details.
