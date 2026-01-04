# Changelog

All notable changes to KTP Admin Audit will be documented in this file.

## [2.6.0] - 2026-01

### Changed
- Version bump for live server deployment
- Tested with KTPMatchHandler v0.10.30 and KTP-ReHLDS 3.20

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
