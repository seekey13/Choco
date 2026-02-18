--[[
* Addons - Choco
* Copyright (c) 2026 Choco Development Team
* 
* Ashita 4 addon that visually overrides player mounts to appear as a chocobo
* with selectable colors. This is a visual-only modification that uses the
* /setmodel command - it does not modify DAT files or affect server state.
--]]

addon.name      = 'choco';
addon.author    = 'Choco Development Team';
addon.version   = '1.0.0';
addon.desc      = 'Visual chocobo mount override with color selection';
addon.link      = 'https://github.com/seekey13/Choco';

require('common');

-- Default chocobo model IDs (client-DAT dependent, user-configurable)
-- These IDs should be verified using FFXiDATExplorer or in-game /setmodel
local default_models = {
    yellow  = 284,  -- Default yellow chocobo
    black   = 285,  -- Black chocobo
    red     = 286,  -- Red chocobo
    blue    = 287,  -- Blue chocobo
    green   = 288,  -- Green chocobo
};

-- Addon state
local choco = {
    enabled = true,                 -- Whether the addon is active
    current_color = 'yellow',       -- Current selected color
    is_mounted = false,             -- Current mount state
    model_ids = default_models,     -- Model IDs (can be customized)
    settings_path = nil,            -- Path to settings file
};

-- Mount status effect ID (85 = Chocobo mount)
local MOUNT_STATUS_ID = 85;

--[[
* Loads addon settings from file
--]]
local function load_settings()
    local settings_file = ('%s/config/addons/%s/settings.json'):fmt(AshitaCore:GetInstallPath(), addon.name);
    choco.settings_path = settings_file;
    
    -- Check if settings file exists
    if (not ashita.fs.exists(settings_file)) then
        return;
    end
    
    -- Load and parse settings
    local f = io.open(settings_file, 'r');
    if (f == nil) then
        return;
    end
    
    local content = f:read('*all');
    f:close();
    
    if (content == nil or #content == 0) then
        return;
    end
    
    local s = json.decode(content);
    if (s ~= nil) then
        if (s.enabled ~= nil) then choco.enabled = s.enabled; end
        if (s.current_color ~= nil) then choco.current_color = s.current_color; end
        if (s.model_ids ~= nil) then
            for color, id in pairs(s.model_ids) do
                choco.model_ids[color] = id;
            end
        end
    end
end

--[[
* Saves addon settings to file
--]]
local function save_settings()
    -- Ensure config directory exists
    local config_dir = ('%s/config/addons/%s'):fmt(AshitaCore:GetInstallPath(), addon.name);
    if (not ashita.fs.exists(config_dir)) then
        ashita.fs.create_dir(config_dir);
    end
    
    -- Prepare settings table
    local settings = {
        enabled = choco.enabled,
        current_color = choco.current_color,
        model_ids = choco.model_ids,
    };
    
    -- Save to file
    local f = io.open(choco.settings_path, 'w');
    if (f ~= nil) then
        f:write(json.encode(settings, { indent = true }));
        f:close();
    end
end

--[[
* Checks if the player has a specific buff
* @param {number} buff_id - The buff ID to check for
* @return {boolean} True if player has the buff
--]]
local function has_buff(buff_id)
    local player = AshitaCore:GetMemoryManager():GetPlayer();
    if (player == nil) then
        return false;
    end
    
    for i = 0, 31 do
        local buff = player:GetBuff(i);
        if (buff == buff_id) then
            return true;
        end
    end
    
    return false;
end

--[[
* Applies the chocobo model override
--]]
local function apply_model()
    if (not choco.enabled) then
        return;
    end
    
    local model_id = choco.model_ids[choco.current_color];
    if (model_id == nil) then
        print(chat.header(addon.name):append(chat.error('Invalid color selection!')));
        return;
    end
    
    -- Execute setmodel command
    local cmd = ('/setmodel self %d'):fmt(model_id);
    AshitaCore:GetChatManager():QueueCommand(1, cmd);
end

--[[
* Resets the player model to default
--]]
local function reset_model()
    AshitaCore:GetChatManager():QueueCommand(1, '/setmodel self 0');
end

--[[
* Updates mount state and applies/removes model override
--]]
local function update_mount_state()
    local mounted = has_buff(MOUNT_STATUS_ID);
    
    -- Mount state changed
    if (mounted ~= choco.is_mounted) then
        choco.is_mounted = mounted;
        
        if (mounted) then
            -- Player just mounted
            apply_model();
        else
            -- Player just dismounted
            reset_model();
        end
    end
end

--[[
* Displays help information
--]]
local function display_help()
    print(chat.header(addon.name):append(chat.message('Available commands:')));
    print(chat.message('  /choco <color>  - Set chocobo color (yellow/black/red/blue/green)'));
    print(chat.message('  /choco toggle   - Toggle addon on/off'));
    print(chat.message('  /choco reload   - Reload addon settings'));
    print(chat.message('  /choco setid <color> <id> - Set custom model ID for a color'));
    print(chat.message('  /choco help     - Display this help'));
    print(chat.message(' '));
    print(chat.message('Current settings:'));
    print(chat.message(('  Enabled: %s'):fmt(choco.enabled and 'Yes' or 'No')));
    print(chat.message(('  Color: %s'):fmt(choco.current_color)));
    print(chat.message('  Model IDs:'));
    for color, id in pairs(choco.model_ids) do
        print(chat.message(('    %s: %d'):fmt(color, id)));
    end
end

--[[
* Event: load
* Called when the addon is loaded
--]]
ashita.events.register('load', 'load_cb', function ()
    -- Load settings
    load_settings();
    
    print(chat.header(addon.name):append(chat.message('v')):append(chat.success(addon.version)):append(chat.message(' loaded!')));
    print(chat.header(addon.name):append(chat.message('Type /choco help for available commands.')));
end);

--[[
* Event: unload
* Called when the addon is unloaded
--]]
ashita.events.register('unload', 'unload_cb', function ()
    -- Reset model on unload if mounted
    if (choco.is_mounted) then
        reset_model();
    end
    
    -- Save settings
    save_settings();
    
    print(chat.header(addon.name):append(chat.message(' unloaded!')));
end);

--[[
* Event: command
* Called when a command is entered
--]]
ashita.events.register('command', 'command_cb', function (e)
    -- Parse command arguments
    local args = e.command:args();
    if (#args == 0 or args[1] ~= '/choco') then
        return;
    end
    
    -- Block the command from being sent to server
    e.blocked = true;
    
    -- No arguments - display help
    if (#args == 1) then
        display_help();
        return;
    end
    
    local subcmd = args[2]:lower();
    
    -- Handle toggle command
    if (subcmd == 'toggle') then
        choco.enabled = not choco.enabled;
        save_settings();
        
        local status = choco.enabled and 'enabled' or 'disabled';
        print(chat.header(addon.name):append(chat.message(('Addon %s'):fmt(status))));
        
        -- If disabled while mounted, reset model
        if (not choco.enabled and choco.is_mounted) then
            reset_model();
        -- If enabled while mounted, apply model
        elseif (choco.enabled and choco.is_mounted) then
            apply_model();
        end
        
        return;
    end
    
    -- Handle help command
    if (subcmd == 'help') then
        display_help();
        return;
    end
    
    -- Handle reload command
    if (subcmd == 'reload') then
        load_settings();
        print(chat.header(addon.name):append(chat.success('Settings reloaded!')));
        return;
    end
    
    -- Handle setid command
    if (subcmd == 'setid') then
        if (#args < 4) then
            print(chat.header(addon.name):append(chat.error('Usage: /choco setid <color> <id>')));
            return;
        end
        
        local color = args[3]:lower();
        local id = tonumber(args[4]);
        
        if (id == nil or id < 0) then
            print(chat.header(addon.name):append(chat.error('Invalid model ID!')));
            return;
        end
        
        if (choco.model_ids[color] == nil) then
            print(chat.header(addon.name):append(chat.error(('Unknown color: %s'):fmt(color))));
            print(chat.header(addon.name):append(chat.message('Valid colors: yellow, black, red, blue, green')));
            return;
        end
        
        choco.model_ids[color] = id;
        save_settings();
        print(chat.header(addon.name):append(chat.success(('Set %s chocobo model ID to %d'):fmt(color, id))));
        
        return;
    end
    
    -- Handle color selection
    local color = subcmd;
    if (choco.model_ids[color] == nil) then
        print(chat.header(addon.name):append(chat.error(('Unknown color: %s'):fmt(color))));
        print(chat.header(addon.name):append(chat.message('Valid colors: yellow, black, red, blue, green')));
        return;
    end
    
    choco.current_color = color;
    save_settings();
    print(chat.header(addon.name):append(chat.success(('Chocobo color set to %s'):fmt(color))));
    
    -- If currently mounted, apply the new model immediately
    if (choco.is_mounted) then
        apply_model();
    end
end);

--[[
* Event: d3d_present
* Called every frame when the scene is being rendered
--]]
ashita.events.register('d3d_present', 'present_cb', function ()
    -- Check mount state periodically
    update_mount_state();
end);
