# Installation Guide for Choco Addon

This guide provides step-by-step instructions for installing and configuring the Choco addon for Ashita 4.

## Prerequisites

- Ashita 4 must be installed and working
- Final Fantasy XI client
- Basic knowledge of navigating directories

## Installation Steps

### Step 1: Locate Your Ashita Directory

Find your Ashita 4 installation directory. The default location is usually:
- `C:\Ashita\` on Windows

### Step 2: Create the Addon Directory

1. Navigate to the `addons` folder inside your Ashita installation
2. Create a new folder called `choco`
3. The full path should be: `<Ashita Install>\addons\choco\`

### Step 3: Copy the Addon File

1. Download or copy the `choco.lua` file
2. Place it in the `choco` folder you just created
3. The final location should be: `<Ashita Install>\addons\choco\choco.lua`

### Step 4: Load the Addon

Once you're in-game with Ashita:

1. Open the chat window
2. Type: `/addon load choco`
3. Press Enter

You should see a message: "choco v1.0.0 loaded!"

### Step 5: Configure Model IDs (Important!)

The default model IDs may not work for your specific client. You need to find the correct IDs:

#### Option A: Test Default IDs

1. Get on your chocobo mount in-game
2. The addon will try to apply the yellow chocobo model (ID 284)
3. If your model changes to a chocobo, the default IDs work!
4. If not, proceed to Option B

#### Option B: Find Your Model IDs

1. While mounted on a chocobo, test different model IDs:
   ```
   /setmodel self 280
   /setmodel self 281
   /setmodel self 282
   /setmodel self 283
   /setmodel self 284
   /setmodel self 285
   /setmodel self 286
   /setmodel self 287
   /setmodel self 288
   /setmodel self 289
   /setmodel self 290
   ```

2. When you see a chocobo model appear (any color), note that ID

3. Continue testing nearby IDs to find all chocobo colors

4. Configure the addon with your IDs:
   ```
   /choco setid yellow 284
   /choco setid black 285
   /choco setid red 286
   /choco setid blue 287
   /choco setid green 288
   ```

### Step 6: Select Your Chocobo Color

Choose which color you want:
```
/choco yellow
/choco black
/choco red
/choco blue
/choco green
```

### Step 7: Test It Out

1. Mount a chocobo
2. Your mount should now appear as the chocobo color you selected
3. Dismount - your character should return to normal
4. Mount again - the chocobo should reappear

## Auto-Load on Startup (Optional)

To make the addon load automatically when you start Ashita:

1. Navigate to: `<Ashita Install>\config\boot\`
2. Open `Default.txt` (or your character's boot configuration file)
3. Add this line at the end:
   ```
   /addon load choco
   ```
4. Save the file

The addon will now load automatically when you start Ashita with that configuration.

## Troubleshooting

### "Addon not found" Error
- Make sure the file is named exactly `choco.lua`
- Make sure it's in `<Ashita Install>\addons\choco\choco.lua`
- Check that the folder name matches the file name (both should be `choco`)

### Model Doesn't Change When Mounting
- Your model IDs may be wrong for your client
- Follow Step 5 Option B to find the correct IDs
- Make sure the addon is enabled: `/choco help` (check "Enabled: Yes")
- Try toggling: `/choco toggle` twice to disable then re-enable

### Chocobo Appears as Wrong Color
- You may have found a different chocobo color ID
- Try the IDs around the one you found (+/- 1 or 2)
- Use `/choco setid <color> <id>` to assign the correct ID to each color

### Settings Don't Save
- Make sure Ashita has permission to write to the config folder
- Check if `<Ashita Install>\config\addons\choco\settings.json` exists
- Try manually creating the folder if it doesn't exist

### Model Stays as Chocobo After Dismount
- Try: `/choco toggle` to disable the addon
- Try: `/setmodel self 0` to manually reset
- Reload the addon: `/addon reload choco`

## Uninstallation

To remove the addon:

1. In-game: `/addon unload choco`
2. Delete the folder: `<Ashita Install>\addons\choco\`
3. Optionally delete settings: `<Ashita Install>\config\addons\choco\`
4. Remove the load command from your boot config if you added it

## Getting Help

If you have issues:

1. Check `/choco help` to see current settings
2. Verify your model IDs are correct for your client
3. Make sure you're actually mounted (have "Chocobo" status effect)
4. Check the Ashita console for any error messages
5. Try reloading the addon: `/addon reload choco`

## Quick Reference

Common commands:
- `/addon load choco` - Load the addon
- `/choco <color>` - Set chocobo color
- `/choco toggle` - Enable/disable
- `/choco help` - Show all commands and current settings
- `/choco setid <color> <id>` - Set custom model ID
- `/addon reload choco` - Reload the addon
- `/addon unload choco` - Unload the addon
