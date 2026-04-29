# KTPAdminAudit - Claude Code Context

## Compile Command
To compile this plugin, use:
```bash
wsl bash -c "cd '/mnt/n/Nein_/KTP Git Projects/KTPAdminAudit' && bash compile.sh"
```

This will:
1. Compile `KTPAdminAudit.sma` using KTPAMXX compiler
2. Output to `compiled/KTPAdminAudit.amxx`
3. Auto-stage to `N:\Nein_\KTP Git Projects\KTP DoD Server\serverfiles\dod\addons\ktpamx\plugins\`

## Project Structure
- `KTPAdminAudit.sma` - Main plugin source
- `compile.sh` - WSL compile script
- `compiled/` - Compiled .amxx output

## Purpose
Menu-based admin system with comprehensive audit logging:
- `.kick` / `.ban` - Player management with immunity support
- `.changemap` - Map selection from ktp_maps.ini (5-second countdown)
- `.restart` / `.quit` - Server control commands

All actions logged to Discord for accountability.

## Dependencies
- **KTP-ReHLDS 3.20+** - For `RH_SV_Rcon` and `RH_Host_Changelevel_f` hooks
- **KTP-ReAPI 5.29.0.362-ktp+** - Hook exposure to AMXX
- **KTPAMXX 2.6+** - For `ktp_drop_client` native
- **KTPMatchHandler** - For `ktp_is_match_active()` native (blocks .changemap during matches)

## Admin Flags
- `c` - ADMIN_KICK - kick players
- `d` - ADMIN_BAN - ban players
- `l` - ADMIN_RCON - restart/quit server
- `a` - ADMIN_IMMUNITY - protected from kick/ban

Note: `.changemap` is available to ALL players (no admin flag required) but blocked during active matches.

## Server Deployment

Deploy compiled plugin to production servers using Python/Paramiko.

**Remote Path:** `~/dod-{port}/serverfiles/dod/addons/ktpamx/plugins/KTPAdminAudit.amxx`

See `N:\Nein_\KTP Git Projects\CLAUDE.md` for paramiko SSH documentation.

## Related Projects
- `N:\Nein_\KTP Git Projects\KTPAMXX` - Custom AMX Mod X fork (compiler source)
- `N:\Nein_\KTP Git Projects\KTPMatchHandler` - Shares ktp_maps.ini for map list
- `N:\Nein_\KTP Git Projects\KTP DoD Server` - Test server with staged plugins

## Key Files to Update on Version Bump
1. `KTPAdminAudit.sma` - `#define VERSION` and header comment
2. `CHANGELOG.md` - Add new version section
3. `README.md` - Update version in header
