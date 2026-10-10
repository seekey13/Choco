-- Choco - see the Raptor mount as a chocobo you pick the look of (client-side only)

addon.name    = 'Choco'
addon.author  = 'Seekey'
addon.version = '1.1'
addon.desc    = 'Shows the Raptor mount as a chocobo, in the color and look you pick. Only your client sees it.'
addon.link    = 'https://github.com/seekey13/Choco'

require('common')
local bit = require('bit')
local ffi = require('ffi')
local chat = require('chat')
local imgui = require('imgui')
local settings = require('settings')

-- Packet mount ids are the /mount list index + 1 (Raptor is list index 1); chocobo is 0.
local RAPTOR, CHOCOBO, NOBLE = 2, 0, 34
-- server_status (entity animation): chocobos (Noble too) ride as 5, every other mount as 85.
local STATUS_MOUNT, STATUS_CHOCOBO = 85, 5
-- Personal chocobo color, CustomProperties bits 9-11 (LandSandBoat xi.chocoboRaising.color).
local COLORS = { yellow = 0, black = 1, blue = 2, red = 3, green = 4 }
-- Window's top row: the colors, then Noble (its own fixed model, so it sits with the colors).
local SWATCHES = { 'yellow', 'black', 'blue', 'red', 'green', 'noble' }
local PARTS = { { 'beak', 'Large beak' }, { 'talons', 'Large talons' }, { 'tail', 'Full tail' } }
local MOUNTED_BUFF = 252
-- ponytail: hardcoded highlight (ImGui dark ButtonActive); read the style if a theme ever matters.
local SELECTED = { 0.06, 0.53, 0.98, 1.0 }

local look = settings.load(T{ color = 'yellow', beak = false, talons = false, tail = false, noble = false })
settings.register('settings', 'settings_update', function (s) look = s end)

-- 0x00A (zone-in) carries our status but no mount id, so remember it from 0x037.
local on_raptor = false
local sync = nil       -- last real 0x067 about us, replayed on mount (server only sends it at zone-in)
local ui_open = { false }

-- Look as the server sends it for a raised chocobo (LandSandBoat mountutils.h ChocoboCustomProperties):
-- bit 0 large beak, bit 3 large talons, bit 6 full tail, bits 9-11 color.
local function look_props()
    return bit.bor(look.beak and 0x01 or 0, look.talons and 0x08 or 0, look.tail and 0x40 or 0,
        bit.lshift(COLORS[look.color] or 0, 9))
end

-- ChocoboIndex: 1 rental, 2 raised (reads CustomProperties[0]), 4 Noble (CustomProperties[1] = 1).
local function chocobo_index()
    if look.noble then return 4 end
    return look_props() == 0 and 1 or 2
end

-- Swaps rewrite a raptor into what the server sends for a chocobo with that look.
-- They edit a 0-based byte view in place (ffi uint8_t* in game, plain table in the self-check).
-- Offsets: https://github.com/atom0s/XiPackets world/server/0x000A, 0x000D, 0x0037, 0x0067

local function put32(p, offset, v)
    for i = 0, 3 do p[offset + i] = bit.band(bit.rshift(v, 8 * i), 0xFF) end
end

-- ChocoboIndex is the top 3 bits of a byte.
local function set_chocobo_index(p, offset)
    p[offset] = bit.bor(bit.band(p[offset], 0x1F), bit.lshift(chocobo_index(), 5))
end

-- 0x00D player update: status 0x1F, ChocoboIndex 0x20 bits 5-7, CustomProperties 0x34/0x38,
-- MountIndex 0x44 bits 4-11.
local function swap_pc(p)
    if bit.band(p[0x0A], 0x04) == 0 then return end -- no General block; client ignores these fields
    local mount = bit.bor(bit.rshift(p[0x44], 4), bit.lshift(bit.band(p[0x45], 0x0F), 4))
    if mount ~= RAPTOR then return end
    -- Server keeps sending the id after dismount; replace it so the client never loads a raptor.
    local m = look.noble and NOBLE or CHOCOBO
    p[0x44] = bit.bor(bit.band(p[0x44], 0x0F), bit.lshift(bit.band(m, 0x0F), 4))
    p[0x45] = bit.bor(bit.band(p[0x45], 0xF0), bit.rshift(m, 4))
    if p[0x1F] == STATUS_MOUNT then
        p[0x1F] = STATUS_CHOCOBO
        set_chocobo_index(p, 0x20)
        put32(p, 0x34, look_props())
        put32(p, 0x38, look.noble and 1 or 0)
    end
end

-- 0x037 our status: Chocobo_Index 0x29 bits 5-7, status 0x30, mount id 0x5B (0 unless mounted).
local function swap_self(p)
    on_raptor = p[0x5B] == RAPTOR
    if not on_raptor then return end
    p[0x5B] = look.noble and NOBLE or CHOCOBO
    if p[0x30] == STATUS_MOUNT then
        p[0x30] = STATUS_CHOCOBO
        set_chocobo_index(p, 0x29)
    end
end

-- 0x00A zone-in: status 0x1F. Mounts survive zoning, and this lands before the next 0x037.
local function swap_zone_in(p)
    if on_raptor and p[0x1F] == STATUS_MOUNT then p[0x1F] = STATUS_CHOCOBO end
end

-- 0x067 mode 2 about us: CustomProperties 0x18/0x1C is the look of our own chocobo
-- (0x037 has no such field; the client ignores these for other players).
local function swap_sync(p)
    put32(p, 0x18, look_props())
    put32(p, 0x1C, look.noble and 1 or 0)
end

-- ponytail: self-check at load; fake packets, 0-based like the ffi view.
do
    local saved = look
    local function pkt(bytes)
        local p = {}
        for i = 0, 0x5F do p[i] = bytes[i] or 0 end
        return p
    end
    look = { color = 'yellow' }
    -- Raptor rider: General flag, status 85, ChocoboIndex 3 + bit 0, GateId 3, MountIndex 2.
    local p = pkt{ [0x0A] = 0x04, [0x1F] = 85, [0x20] = 0x61, [0x44] = 0x23 }
    swap_pc(p)
    assert(p[0x1F] == 5 and p[0x20] == 0x21 and p[0x44] == 0x03 and p[0x45] == 0, 'swap_pc: raptor not swapped')
    -- Mount 18 shares raptor's low nibble; must be left alone.
    p = pkt{ [0x0A] = 0x04, [0x1F] = 85, [0x44] = 0x20, [0x45] = 0x01 }
    swap_pc(p)
    assert(p[0x1F] == 85 and p[0x44] == 0x20 and p[0x45] == 0x01, 'swap_pc: touched a non-raptor')
    -- Position-only update: client ignores status/mount, so do we.
    p = pkt{ [0x0A] = 0x01, [0x1F] = 85, [0x44] = 0x20 }
    swap_pc(p)
    assert(p[0x1F] == 85 and p[0x44] == 0x20, 'swap_pc: touched a packet without General')
    -- Raised look: black (1 << 9) + beak + tail = 0x241, ChocoboIndex 2.
    look = { color = 'black', beak = true, tail = true }
    p = pkt{ [0x0A] = 0x04, [0x1F] = 85, [0x20] = 0x61, [0x44] = 0x23 }
    swap_pc(p)
    assert(p[0x20] == 0x41 and p[0x34] == 0x41 and p[0x35] == 0x02 and p[0x38] == 0, 'swap_pc: look not applied')
    -- Noble: mount 34 (0x22) split across 0x44/0x45, ChocoboIndex 4, CustomProperties[1] = 1.
    look = { color = 'yellow', noble = true }
    p = pkt{ [0x0A] = 0x04, [0x1F] = 85, [0x20] = 0x61, [0x44] = 0x23 }
    swap_pc(p)
    assert(p[0x1F] == 5 and p[0x20] == 0x81 and p[0x44] == 0x23 and p[0x45] == 0x02 and p[0x38] == 1, 'swap_pc: noble not applied')
    p = pkt{ [0x29] = 0x65, [0x30] = 85, [0x5B] = 2 }
    swap_self(p)
    assert(p[0x29] == 0x85 and p[0x30] == 5 and p[0x5B] == NOBLE, 'swap_self: noble not applied')
    look = { color = 'yellow' }
    -- Us on raptor, then zoning.
    p = pkt{ [0x29] = 0x65, [0x30] = 85, [0x5B] = 2 }
    swap_self(p)
    assert(p[0x29] == 0x25 and p[0x30] == 5 and p[0x5B] == 0, 'swap_self: raptor not swapped')
    p = pkt{ [0x1F] = 85 }
    swap_zone_in(p)
    assert(p[0x1F] == 5, 'swap_zone_in: raptor not swapped')
    look, on_raptor = saved, false
end

local function my_id()
    return AshitaCore:GetMemoryManager():GetParty():GetMemberServerId(0)
end

-- Our chocobo's look only arrives in 0x067, which the server doesn't send on mount: replay the last one.
local function replay_sync()
    if sync == nil then return end
    local buf = ffi.new('uint8_t[?]', #sync)
    ffi.copy(buf, sync, #sync)
    swap_sync(buf)
    AshitaCore:GetPacketManager():AddIncomingPacket(0x067, ffi.string(buf, #sync):totable())
end

ashita.events.register('packet_in', 'packet_in_cb', function (e)
    if e.blocked then return end
    if e.id == 0x00D and e.size >= 0x48 then
        swap_pc(ffi.cast('uint8_t*', e.data_modified_raw))
    elseif e.id == 0x037 and e.size >= 0x5C then
        local was = on_raptor
        swap_self(ffi.cast('uint8_t*', e.data_modified_raw))
        if on_raptor and not was then replay_sync() end
    elseif e.id == 0x00A and e.size >= 0x20 then
        swap_zone_in(ffi.cast('uint8_t*', e.data_modified_raw))
    elseif e.id == 0x067 and e.size >= 0x20 then
        local p = ffi.cast('uint8_t*', e.data_modified_raw)
        if bit.band(p[0x04], 0x3F) ~= 2 or ffi.cast('uint32_t*', p + 0x08)[0] ~= my_id() then return end
        if not e.injected then sync = ffi.string(e.data_raw, e.size) end
        if on_raptor then swap_sync(p) end
    end
end)

local function look_text()
    if look.noble then return 'noble' end
    local t = { look.color }
    for _, part in ipairs(PARTS) do
        if look[part[1]] then t[#t + 1] = part[1] end
    end
    return table.concat(t, ', ')
end

-- Colors and Noble are one choice: picking a color turns Noble off.
local function pick(swatch)
    if swatch == 'noble' then
        look.noble = true
    else
        look.color, look.noble = swatch, false
    end
    settings.save()
end

-- ponytail: buff array is fixed at 32 slots; same check as the Ride addon.
local function is_mounted()
    local buffs = AshitaCore:GetMemoryManager():GetPlayer():GetBuffs()
    if not buffs then return false end
    for i = 1, 32 do
        if buffs[i] == MOUNTED_BUFF then return true end
    end
    return false
end

local function label(s) return s:sub(1, 1):upper() .. s:sub(2) end

ashita.events.register('d3d_present', 'present_cb', function ()
    if not ui_open[1] then return end
    if imgui.Begin('Choco', ui_open, ImGuiWindowFlags_AlwaysAutoResize) then
        -- Every swatch button is as wide as the longest label.
        local w = 0
        for _, s in ipairs(SWATCHES) do w = math.max(w, imgui.CalcTextSize(label(s))) end
        local selected = look.noble and 'noble' or look.color
        for i, s in ipairs(SWATCHES) do
            if i > 1 then imgui.SameLine() end
            if s == selected then imgui.PushStyleColor(ImGuiCol_Button, SELECTED) end
            if imgui.Button(label(s), { w + 16, 0 }) then pick(s) end
            if s == selected then imgui.PopStyleColor() end
        end
        -- ImGui 1.80 has no BeginDisabled: fade the checkboxes and drop their clicks instead.
        if look.noble then imgui.PushStyleVar(ImGuiStyleVar_Alpha, 0.5) end
        for i, part in ipairs(PARTS) do
            if i > 1 then imgui.SameLine() end
            local v = { look[part[1]] == true }
            if imgui.Checkbox(part[2], v) and not look.noble then
                look[part[1]] = v[1]
                settings.save()
            end
            if look.noble and imgui.IsItemHovered() then
                imgui.SetTooltip('The Noble Chocobo has one fixed look.\nThe game ignores beak, talons and tail on it.')
            end
        end
        if look.noble then imgui.PopStyleVar() end
        imgui.TextDisabled('Changes show from the next mount or zone.')
        -- Both labels share the /dismount width so the button doesn't jump when it flips.
        local cmd = is_mounted() and '/dismount' or '/mount'
        local bw = imgui.CalcTextSize('/dismount') + 16
        imgui.SetCursorPosX((imgui.GetWindowWidth() - bw) * 0.5)
        if imgui.Button(cmd, { bw, 0 }) then
            AshitaCore:GetChatManager():QueueCommand(1, cmd == '/mount' and '/mount Raptor' or cmd)
        end
    end
    imgui.End()
end)

-- /choco toggles the window. /choco <color|noble> picks the look; /choco beak|talons|tail toggles that part.
ashita.events.register('command', 'command_cb', function (e)
    local args = e.command:args()
    if #args == 0 or args[1]:lower() ~= '/choco' then return end
    e.blocked = true
    local arg = (args[2] or ''):lower()
    if arg == '' then
        ui_open[1] = not ui_open[1]
        return
    end
    local msg
    if COLORS[arg] or arg == 'noble' then
        pick(arg)
    elseif arg == 'beak' or arg == 'talons' or arg == 'tail' then
        look[arg] = not look[arg]
        settings.save()
    else
        msg = 'Usage: /choco [yellow|black|blue|red|green|noble|beak|talons|tail]'
    end
    msg = msg or ('Look: %s. Shows from the next mount or zone.'):format(look_text())
    print(chat.header(addon.name):append(chat.message(msg)))
end)

ashita.events.register('load', 'load_cb', function ()
    print(chat.header(addon.name):append(chat.message(('Loaded. Look: %s. /choco opens the settings.'):format(look_text()))))
end)
