# Changelog

All notable changes to KTP Admin Audit will be documented in this file.

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
