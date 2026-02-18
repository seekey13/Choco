# Changelog

All notable changes to the Choco addon will be documented in this file.

## [1.0.0] - 2026-02-18

### Added
- Initial release of Choco addon for Ashita 4
- Visual chocobo mount override with 5 selectable colors (yellow, black, red, blue, green)
- Automatic mount detection using status effect ID 85
- Model application on mount using `/setmodel self <id>`
- Automatic model reset on dismount
- User-configurable model IDs for client compatibility
- Persistent settings saved to JSON configuration file
- Command: `/choco <color>` - Select chocobo color
- Command: `/choco toggle` - Enable/disable addon
- Command: `/choco reload` - Reload settings from file
- Command: `/choco setid <color> <id>` - Configure custom model IDs
- Command: `/choco help` - Display help and current settings
- Comprehensive documentation (README.md, INSTALL.md)
- Example configuration file (settings.example.json)
- Error handling for JSON parsing failures
- Throttled mount state checking (10 checks per second) to reduce CPU usage
- MIT License

### Technical Details
- Event-driven architecture using Ashita 4's event system
- Mount state monitoring via d3d_present event with throttling
- Safe command execution using format strings to prevent injection
- Input validation for all user commands
- Automatic config directory creation
- Settings persistence between sessions

### Notes
- Visual-only modification - does not modify DAT files
- Does not affect server state or what other players see
- Safe to use - no game file modifications
- Model IDs are client-DAT dependent and may need customization
