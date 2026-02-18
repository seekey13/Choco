# Choco

An Ashita 4 addon for Final Fantasy XI that visually overrides your mount to always appear as a chocobo with selectable colors.

## Features

- **Visual-only override**: Changes how your mount appears on your client without modifying DAT files or affecting server state
- **Multiple chocobo colors**: Choose from yellow, black, red, blue, or green chocobos
- **Automatic detection**: Automatically detects when you mount (status effect 85) and applies the chocobo model
- **Configurable model IDs**: Model IDs are user-configurable to match your specific client DAT files
- **Toggle support**: Enable/disable the addon on-the-fly without unloading
- **Persistent settings**: Your color choice and settings are saved between sessions

## Installation

1. Download or clone this repository
2. Copy the `choco.lua` file to your Ashita 4 addons directory:
   ```
   <Ashita Install>/addons/choco/choco.lua
   ```
3. Load the addon in-game with: `/addon load choco`

## Usage

### Commands

- `/choco <color>` - Set your chocobo color
  - Available colors: `yellow`, `black`, `red`, `blue`, `green`
  - Example: `/choco red`

- `/choco toggle` - Toggle the addon on/off
  - When disabled, your mount will appear normally
  - When re-enabled while mounted, the chocobo model will be applied immediately

- `/choco reload` - Reload settings from the configuration file

- `/choco setid <color> <id>` - Set a custom model ID for a specific color
  - Example: `/choco setid yellow 284`
  - Use this to configure model IDs that match your client

- `/choco help` - Display help information and current settings

### Default Model IDs

The addon comes with default model IDs that may need adjustment based on your client's DAT files:

- Yellow: 284
- Black: 285
- Red: 286
- Blue: 287
- Green: 288

### Verifying Model IDs

Since model IDs are client-DAT dependent, you may need to verify or find the correct IDs for your client:

#### Method 1: Using FFXiDATExplorer
1. Download and run [FFXiDATExplorer](https://github.com/Windower/FFXIDATExplorer)
2. Open your FFXI ROM directory
3. Search for "chocobo" in the model files
4. Note the model IDs for each chocobo color

#### Method 2: In-game Testing
1. Use the `/setmodel self <id>` command in-game to test different IDs
2. Try IDs around the default values (280-290 range)
3. When you find a chocobo model, note the ID
4. Use `/choco setid <color> <id>` to save it

Example testing process:
```
/setmodel self 284
/setmodel self 285
/setmodel self 286
```

When you find the correct IDs:
```
/choco setid yellow 284
/choco setid black 285
/choco setid red 286
```

## Configuration

Settings are automatically saved to:
```
<Ashita Install>/config/addons/choco/settings.json
```

The configuration file stores:
- Whether the addon is enabled
- Your selected chocobo color
- Custom model IDs for each color

You can manually edit this file if needed. The format is:
```json
{
  "enabled": true,
  "current_color": "yellow",
  "model_ids": {
    "yellow": 284,
    "black": 285,
    "red": 286,
    "blue": 287,
    "green": 288
  }
}
```

## How It Works

1. **Mount Detection**: The addon monitors your character's status effects (buffs) for status ID 85, which indicates you are mounted
2. **Model Application**: When mounting is detected, the addon executes `/setmodel self <id>` using the model ID for your selected color
3. **Model Reset**: When dismounting is detected, the addon executes `/setmodel self 0` to reset your model to default
4. **Visual Only**: The `/setmodel` command only changes how your character appears on your client - it does not modify files or affect what other players see

## Important Notes

- **Visual only**: This addon only affects how mounts appear on YOUR screen. Other players will see your normal mount.
- **Safe to use**: Does not modify DAT files or send any data to the server
- **Client-dependent**: Model IDs may vary between different client versions or configurations
- **Mount-only**: Only applies when you are on a mount (status 85). Does not affect your normal character model.

## Troubleshooting

### The model doesn't change when I mount
1. Verify that the addon is enabled: `/choco toggle` (should say "enabled")
2. Check your model IDs are correct for your client using in-game testing
3. Ensure you're actually mounting (you should have the "Chocobo" status effect)

### Wrong model appears
1. Your model IDs may not match your client's DAT files
2. Use the verification methods above to find the correct IDs
3. Update the IDs using `/choco setid <color> <id>`

### Settings don't save
1. Ensure Ashita has write permissions to the config directory
2. Check that the config directory exists: `<Ashita Install>/config/addons/choco/`
3. Try manually creating the directory if it doesn't exist

## License

This project is released under the MIT License. See the [LICENSE](LICENSE) file for details.

## Contributing

Contributions are welcome! Please feel free to submit issues or pull requests.

## Credits

- Created for the Ashita 4 framework
- Inspired by the FFXI community's love of chocobos

## Disclaimer

This addon is provided as-is for educational and entertainment purposes. Use at your own discretion.