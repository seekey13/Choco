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
-- Pink is a yellow body; look_props adds its pink/white beak and tail bits.
local COLORS = { yellow = 0, black = 1, blue = 2, red = 3, green = 4, pink = 0 }
-- Window's top row: Random, which rolls one of the seven looks after it (Noble is its own fixed model).
local SWATCHES = { 'random', 'yellow', 'black', 'blue', 'red', 'green', 'pink', 'noble' }
local PARTS = { { 'beak', 'Large beak' }, { 'talons', 'Large talons' }, { 'tail', 'Full tail' } }
local MOUNTED_BUFF = 252
local GRAY = { 0.3, 0.3, 0.3, 1.0 } -- unpicked swatches; the picked one keeps the default button color
local LOCKED = {
    noble  = 'The Noble Chocobo has one fixed look.\nThe game ignores beak, talons and tail on it.',
    random = 'Random rolls the color, beak, talons and tail\nfresh for every ride.',
}

-- color is the top-row pick: a color, 'noble' or 'random'.
local look = settings.load(T{ color = 'random', beak = false, talons = false, tail = false })
settings.register('settings', 'settings_update', function (s) look = s end)

-- 0x00A (zone-in) carries our status but no mount id, so remember it from 0x037.
local on_raptor = false
local sync = nil       -- this zone's real 0x067 about us, replayed on mount (server only sends it at zone-in)
-- Looks are set once per ride, so a rider never changes look partway.
local ride = nil       -- ours: 0x037 and 0x067 both use it
local rides = {}       -- Random only: each other rider's roll, by server id
local ui_open = { false }
local raw = nil        -- /choco raw: forces the look bits on every swapped chocobo, for testing (not saved)

-- LuaJIT starts every session on the same seed.
math.randomseed(os.time())

-- A look for one ride: a copy of the saved one, or a fresh roll when Random is on.
local function new_look()
    if look.color ~= 'random' then
        return { color = look.color, beak = look.beak, talons = look.talons, tail = look.tail }
    end
    return { color = SWATCHES[math.random(2, #SWATCHES)],
        beak = math.random(2) == 1, talons = math.random(2) == 1, tail = math.random(2) == 1 }
end

-- Look as the server sends it for a raised chocobo (LandSandBoat mountutils.h ChocoboCustomProperties):
-- bit 0 large beak, bit 3 large talons, bit 6 full tail, bits 9-11 color. The server sends none for Noble.
-- Found by testing: bit 1 turns a large beak pink/white and bit 7 a full tail, on yellow only
-- (alone, or on other colors, they do nothing). Colors 5-7 have no model.
local function look_props(l)
    if l.color == 'noble' then return 0 end
    if raw then return raw end
    return bit.bor(l.beak and 0x01 or 0, l.talons and 0x08 or 0, l.tail and 0x40 or 0,
        bit.lshift(COLORS[l.color] or 0, 9), l.color == 'pink' and 0x82 or 0)
end

-- Swaps rewrite a raptor into what the server sends for a chocobo with look l.
-- They edit a 0-based byte view in place (ffi uint8_t* in game, plain table in the self-check).
-- Offsets: https://github.com/atom0s/XiPackets world/server/0x000A, 0x000D, 0x0037, 0x0067

local function get32(p, offset)
    return p[offset] + p[offset + 1] * 0x100 + p[offset + 2] * 0x10000 + p[offset + 3] * 0x1000000
end

local function put32(p, offset, v)
    for i = 0, 3 do p[offset + i] = bit.band(bit.rshift(v, 8 * i), 0xFF) end
end

-- ChocoboIndex is the top 3 bits of a byte: 1 rental, 2 raised (reads CustomProperties[0]),
-- 4 Noble (CustomProperties[1] = 1).
local function set_chocobo_index(p, offset, l)
    local i = l.color == 'noble' and 4 or look_props(l) == 0 and 1 or 2
    p[offset] = bit.bor(bit.band(p[offset], 0x1F), bit.lshift(i, 5))
end

-- CustomProperties: the look, then the Noble flag.
local function put_look(p, offset, l)
    put32(p, offset, look_props(l))
    put32(p, offset + 4, l.color == 'noble' and 1 or 0)
end

-- 0x00D player update: status 0x1F, ChocoboIndex 0x20 bits 5-7, CustomProperties 0x34/0x38,
-- MountIndex 0x44 bits 4-11.
local function swap_pc(p, l)
    if bit.band(p[0x0A], 0x04) == 0 then return end -- no General block; client ignores these fields
    local mount = bit.bor(bit.rshift(p[0x44], 4), bit.lshift(bit.band(p[0x45], 0x0F), 4))
    if mount ~= RAPTOR then return end
    -- Server keeps sending the id after dismount; replace it so the client never loads a raptor.
    local m = l.color == 'noble' and NOBLE or CHOCOBO
    p[0x44] = bit.bor(bit.band(p[0x44], 0x0F), bit.lshift(bit.band(m, 0x0F), 4))
    p[0x45] = bit.bor(bit.band(p[0x45], 0xF0), bit.rshift(m, 4))
    if p[0x1F] == STATUS_MOUNT then
        p[0x1F] = STATUS_CHOCOBO
        set_chocobo_index(p, 0x20, l)
        put_look(p, 0x34, l)
    end
end

-- 0x037 our status: Chocobo_Index 0x29 bits 5-7, status 0x30, mount id 0x5B (0 unless mounted).
local function swap_self(p, l)
    on_raptor = p[0x5B] == RAPTOR
    if not on_raptor then return end
    p[0x5B] = l.color == 'noble' and NOBLE or CHOCOBO
    if p[0x30] == STATUS_MOUNT then
        p[0x30] = STATUS_CHOCOBO
        set_chocobo_index(p, 0x29, l)
    end
end

-- 0x00A zone-in: status 0x1F. Mounts survive zoning, and this lands before the next 0x037.
-- A new zone starts every ride over, and the old zone's 0x067 must not be replayed into it.
local function swap_zone_in(p)
    if on_raptor and p[0x1F] == STATUS_MOUNT then p[0x1F] = STATUS_CHOCOBO end
    ride, rides, sync = nil, {}, nil
end

-- 0x00D: the look for this rider. Under Random each rider (server id 0x04) keeps one roll
-- until a General update shows them off the mount.
local function rider_look(p)
    if look.color ~= 'random' or bit.band(p[0x0A], 0x04) == 0 then return look end
    local id = get32(p, 0x04)
    if p[0x1F] ~= STATUS_MOUNT then
        rides[id] = nil
        return look
    end
    rides[id] = rides[id] or new_look()
    return rides[id]
end

-- 0x037 with our ride's look. Returns true when a ride just started, so its look needs replaying.
local function ride_self(p)
    local fresh = ride == nil
    ride = ride or new_look()
    swap_self(p, ride)
    if not on_raptor then ride = nil end
    return on_raptor and fresh
end

-- ponytail: self-check at load; fake packets, 0-based like the ffi view.
do
    local function pkt(bytes)
        local p = {}
        for i = 0, 0x5F do p[i] = bytes[i] or 0 end
        return p
    end
    local yellow = { color = 'yellow' }
    -- Raptor rider: General flag, status 85, ChocoboIndex 3 + bit 0, GateId 3, MountIndex 2.
    local p = pkt{ [0x0A] = 0x04, [0x1F] = 85, [0x20] = 0x61, [0x44] = 0x23 }
    swap_pc(p, yellow)
    assert(p[0x1F] == 5 and p[0x20] == 0x21 and p[0x44] == 0x03 and p[0x45] == 0, 'swap_pc: raptor not swapped')
    -- Mount 18 shares raptor's low nibble; must be left alone.
    p = pkt{ [0x0A] = 0x04, [0x1F] = 85, [0x44] = 0x20, [0x45] = 0x01 }
    swap_pc(p, yellow)
    assert(p[0x1F] == 85 and p[0x44] == 0x20 and p[0x45] == 0x01, 'swap_pc: touched a non-raptor')
    -- Position-only update: client ignores status/mount, so do we.
    p = pkt{ [0x0A] = 0x01, [0x1F] = 85, [0x44] = 0x20 }
    swap_pc(p, yellow)
    assert(p[0x1F] == 85 and p[0x44] == 0x20, 'swap_pc: touched a packet without General')
    -- Raised look: black (1 << 9) + beak + tail = 0x241, ChocoboIndex 2.
    p = pkt{ [0x0A] = 0x04, [0x1F] = 85, [0x20] = 0x61, [0x44] = 0x23 }
    swap_pc(p, { color = 'black', beak = true, tail = true })
    assert(p[0x20] == 0x41 and p[0x34] == 0x41 and p[0x35] == 0x02 and p[0x38] == 0, 'swap_pc: look not applied')
    -- Pink: yellow body, beak + tail with their pink bits = 0xC3.
    p = pkt{ [0x0A] = 0x04, [0x1F] = 85, [0x20] = 0x61, [0x44] = 0x23 }
    swap_pc(p, { color = 'pink', beak = true, tail = true })
    assert(p[0x34] == 0xC3 and p[0x35] == 0, 'swap_pc: pink not applied')
    -- Noble: mount 34 (0x22) split across 0x44/0x45, ChocoboIndex 4, CustomProperties { 0, 1 } even with parts set.
    local noble = { color = 'noble', beak = true }
    p = pkt{ [0x0A] = 0x04, [0x1F] = 85, [0x20] = 0x61, [0x44] = 0x23 }
    swap_pc(p, noble)
    assert(p[0x1F] == 5 and p[0x20] == 0x81 and p[0x44] == 0x23 and p[0x45] == 0x02
        and p[0x34] == 0 and p[0x38] == 1, 'swap_pc: noble not applied')
    p = pkt{ [0x29] = 0x65, [0x30] = 85, [0x5B] = 2 }
    swap_self(p, noble)
    assert(p[0x29] == 0x85 and p[0x30] == 5 and p[0x5B] == NOBLE, 'swap_self: noble not applied')
    -- Us on raptor, then zoning.
    p = pkt{ [0x29] = 0x65, [0x30] = 85, [0x5B] = 2 }
    swap_self(p, yellow)
    assert(p[0x29] == 0x25 and p[0x30] == 5 and p[0x5B] == 0, 'swap_self: raptor not swapped')
    p = pkt{ [0x1F] = 85 }
    swap_zone_in(p)
    assert(p[0x1F] == 5, 'swap_zone_in: raptor not swapped')
    -- Random: rolls stay valid and cover both Noble and plain looks.
    local saved, seen = look, {}
    look = { color = 'random' }
    for _ = 1, 200 do
        local l = new_look()
        assert(COLORS[l.color] or l.color == 'noble', 'new_look: bad roll')
        seen[l.color] = true
    end
    assert(seen.noble and seen.yellow and seen.green, 'new_look: rolls not spread')
    -- Our ride keeps the look it mounted with, even when the saved one changes mid-ride.
    look = { color = 'black' }
    assert(ride_self(pkt{ [0x29] = 0x65, [0x30] = 85, [0x5B] = 2 }), 'ride_self: mount not replayed')
    look.color = 'noble'
    p = pkt{ [0x29] = 0x65, [0x30] = 85, [0x5B] = 2 }
    assert(not ride_self(p) and p[0x5B] == CHOCOBO and p[0x29] == 0x45, 'ride_self: look changed mid-ride')
    ride_self(pkt{})
    assert(ride == nil, 'ride_self: dismount kept the ride')
    -- Random: each other rider keeps one roll until they get off.
    look = { color = 'random' }
    local a = pkt{ [0x04] = 1, [0x0A] = 0x04, [0x1F] = 85 }
    local ra = rider_look(a)
    assert(rider_look(a) == ra and rider_look(pkt{ [0x04] = 2, [0x0A] = 0x04, [0x1F] = 85 }) ~= ra,
        'rider_look: not one roll per rider')
    a[0x1F] = 0
    rider_look(a)
    a[0x1F] = 85
    assert(rider_look(a) ~= ra, 'rider_look: dismount kept the roll')
    -- Zoning starts every ride over and drops the old zone's 0x067.
    ride, sync = {}, ''
    swap_zone_in(pkt{})
    assert(ride == nil and sync == nil and next(rides) == nil, 'swap_zone_in: rides kept')
    look, on_raptor = saved, false
end

local function my_id()
    return AshitaCore:GetMemoryManager():GetParty():GetMemberServerId(0)
end

-- Our chocobo's look only arrives in 0x067, which the server doesn't send on mount: replay the last one.
local function replay_sync(l)
    if sync == nil then return end
    local buf = ffi.new('uint8_t[?]', #sync)
    ffi.copy(buf, sync, #sync)
    put_look(buf, 0x18, l)
    AshitaCore:GetPacketManager():AddIncomingPacket(0x067, ffi.string(buf, #sync):totable())
end

ashita.events.register('packet_in', 'packet_in_cb', function (e)
    if e.blocked then return end
    if e.id == 0x00D and e.size >= 0x48 then
        local p = ffi.cast('uint8_t*', e.data_modified_raw)
        swap_pc(p, rider_look(p))
    elseif e.id == 0x037 and e.size >= 0x5C then
        if ride_self(ffi.cast('uint8_t*', e.data_modified_raw)) then replay_sync(ride) end
    elseif e.id == 0x00A and e.size >= 0x20 then
        swap_zone_in(ffi.cast('uint8_t*', e.data_modified_raw))
    elseif e.id == 0x067 and e.size >= 0x20 then
        -- Mode 2 about us: CustomProperties 0x18/0x1C is our own chocobo's look
        -- (0x037 has no such field; the client ignores these for other players).
        local p = ffi.cast('uint8_t*', e.data_modified_raw)
        if e.injected or bit.band(p[0x04], 0x3F) ~= 2 or ffi.cast('uint32_t*', p + 0x08)[0] ~= my_id() then return end
        sync = ffi.string(e.data_raw, e.size)
        if on_raptor then
            ride = ride or new_look() -- zone-in can land before the 0x037 that would set it
            put_look(p, 0x18, ride)
        end
    end
end)

local function look_text()
    if not COLORS[look.color] then return look.color end
    local t = { look.color }
    for _, part in ipairs(PARTS) do
        if look[part[1]] then t[#t + 1] = part[1] end
    end
    return table.concat(t, ', ')
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
        -- CalcTextSize returns width and height; the parentheses keep only the width.
        for _, s in ipairs(SWATCHES) do w = math.max(w, (imgui.CalcTextSize(label(s)))) end
        local sel = look.color
        for i, s in ipairs(SWATCHES) do
            if i > 1 then imgui.SameLine() end
            if s ~= sel then imgui.PushStyleColor(ImGuiCol_Button, GRAY) end
            if imgui.Button(label(s), { w + 16, 0 }) then
                look.color = s
                settings.save()
            end
            if s ~= sel then imgui.PopStyleColor() end
            if s == 'pink' and imgui.IsItemHovered() then
                imgui.SetTooltip('Yellow, with a pink/white beak and tail.\nTurn on Large beak and Full tail to see them.')
            end
        end
        -- ImGui 1.80 has no BeginDisabled: fade each checkbox and drop its clicks instead.
        -- The fade is popped before the tooltip so the tooltip draws normally.
        local lock = LOCKED[sel]
        for i, part in ipairs(PARTS) do
            if i > 1 then imgui.SameLine() end
            local v = { look[part[1]] == true }
            if lock then imgui.PushStyleVar(ImGuiStyleVar_Alpha, 0.5) end
            local changed = imgui.Checkbox(part[2], v)
            if lock then imgui.PopStyleVar() end
            if changed and not lock then
                look[part[1]] = v[1]
                settings.save()
            end
            if lock and imgui.IsItemHovered() then imgui.SetTooltip(lock) end
        end
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

-- /choco toggles the window. /choco <color|noble|random> picks the look; /choco beak|talons|tail toggles that part.
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
    if COLORS[arg] or arg == 'noble' or arg == 'random' then
        look.color = arg
        settings.save()
    elseif arg == 'beak' or arg == 'talons' or arg == 'tail' then
        look[arg] = not look[arg]
        settings.save()
        -- Noble and Random ignore parts; the window locks them, so say where this one went.
        if not COLORS[look.color] then
            msg = ('%s %s, saved for when you pick a color.'):format(label(arg), look[arg] and 'on' or 'off')
        end
    elseif arg == 'raw' then
        -- '/choco raw 0x080' (hex or decimal); '/choco raw off' clears it.
        raw = tonumber(args[3] or '')
        msg = raw and ('Raw 0x%03X: head %d, feet %d, tail %d, color %d. Remount to see it.'):format(raw,
            bit.band(raw, 7), bit.band(bit.rshift(raw, 3), 7), bit.band(bit.rshift(raw, 6), 7),
            bit.band(bit.rshift(raw, 9), 7)) or 'Raw off.'
    else
        msg = 'Usage: /choco [yellow|black|blue|red|green|pink|noble|random|beak|talons|tail|raw <n>]'
    end
    msg = msg or ('Look: %s. Shows from the next mount or zone.'):format(look_text())
    print(chat.header(addon.name):append(chat.message(msg)))
end)

ashita.events.register('load', 'load_cb', function ()
    print(chat.header(addon.name):append(chat.message(('Loaded. Look: %s. /choco opens the settings.'):format(look_text()))))
end)
