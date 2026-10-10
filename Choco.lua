-- Choco - see the Raptor mount as a standard chocobo (client-side only)

addon.name    = 'Choco'
addon.author  = 'Seekey'
addon.version = '1.0'
addon.desc    = 'Shows the Raptor mount as a standard chocobo. Only your client sees it.'
addon.link    = 'https://github.com/seekey13/Choco'

require('common')
local bit = require('bit')
local ffi = require('ffi')
local chat = require('chat')

-- Packet mount ids are the /mount list index + 1 (Raptor is list index 1); chocobo is 0.
local RAPTOR, CHOCOBO = 2, 0
-- server_status (entity animation): a real chocobo rides as 5, every other mount as 85.
local STATUS_MOUNT, STATUS_CHOCOBO = 85, 5

-- 0x00A (zone-in) carries our status but no mount id, so remember it from 0x037.
local on_raptor = false
local last_mount = nil -- last mount id the server sent for us, for /choco

-- Swaps rewrite a raptor into exactly what the server sends for a regular chocobo:
-- status 5, ChocoboIndex 1, mount id 0. They edit a 0-based byte view in place
-- (ffi uint8_t* in game, plain table in the self-check).
-- Offsets: https://github.com/atom0s/XiPackets world/server/0x000A, 0x000D, 0x0037

-- ChocoboIndex is the top 3 bits of a byte; 1 = regular chocobo.
local function set_chocobo_index(p, offset)
    p[offset] = bit.bor(bit.band(p[offset], 0x1F), 0x20)
end

-- 0x00D player update: status 0x1F, ChocoboIndex 0x20 bits 5-7, MountIndex 0x44 bits 4-11.
local function swap_pc(p)
    if bit.band(p[0x0A], 0x04) == 0 then return end -- no General block; client ignores these fields
    local mount = bit.bor(bit.rshift(p[0x44], 4), bit.lshift(bit.band(p[0x45], 0x0F), 4))
    if mount ~= RAPTOR then return end
    -- Server keeps sending the id after dismount; make it chocobo (0) so the client never loads a raptor.
    p[0x44] = bit.band(p[0x44], 0x0F)
    p[0x45] = bit.band(p[0x45], 0xF0)
    if p[0x1F] == STATUS_MOUNT then
        p[0x1F] = STATUS_CHOCOBO
        set_chocobo_index(p, 0x20)
    end
end

-- 0x037 our status: Chocobo_Index 0x29 bits 5-7, status 0x30, mount id 0x5B (0 unless mounted).
local function swap_self(p)
    last_mount = p[0x5B]
    on_raptor = last_mount == RAPTOR
    if not on_raptor then return end
    p[0x5B] = CHOCOBO
    if p[0x30] == STATUS_MOUNT then
        p[0x30] = STATUS_CHOCOBO
        set_chocobo_index(p, 0x29)
    end
end

-- 0x00A zone-in: status 0x1F. Mounts survive zoning, and this lands before the next 0x037.
local function swap_zone_in(p)
    if on_raptor and p[0x1F] == STATUS_MOUNT then p[0x1F] = STATUS_CHOCOBO end
end

-- ponytail: self-check at load; fake packets, 0-based like the ffi view.
do
    local function pkt(bytes)
        local p = {}
        for i = 0, 0x5F do p[i] = bytes[i] or 0 end
        return p
    end
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
    -- Us on raptor, then zoning.
    p = pkt{ [0x29] = 0x65, [0x30] = 85, [0x5B] = 2 }
    swap_self(p)
    assert(p[0x29] == 0x25 and p[0x30] == 5 and p[0x5B] == 0, 'swap_self: raptor not swapped')
    p = pkt{ [0x1F] = 85 }
    swap_zone_in(p)
    assert(p[0x1F] == 5, 'swap_zone_in: raptor not swapped')
    on_raptor, last_mount = false, nil
end

ashita.events.register('packet_in', 'packet_in_cb', function (e)
    if e.blocked then return end
    if e.id == 0x00D and e.size >= 0x48 then
        swap_pc(ffi.cast('uint8_t*', e.data_modified_raw))
    elseif e.id == 0x037 and e.size >= 0x5C then
        swap_self(ffi.cast('uint8_t*', e.data_modified_raw))
    elseif e.id == 0x00A and e.size >= 0x20 then
        swap_zone_in(ffi.cast('uint8_t*', e.data_modified_raw))
    end
end)

-- /choco: shows what the server last sent for us, to confirm the Raptor id if the swap ever misses.
ashita.events.register('command', 'command_cb', function (e)
    local args = e.command:args()
    if #args == 0 or args[1]:lower() ~= '/choco' then return end
    e.blocked = true
    local msg = 'No status from the server yet. Mount up, then try again.'
    if last_mount ~= nil then
        msg = ('Server mount id: %d (Raptor = %d)%s'):format(last_mount, RAPTOR, on_raptor and ' - showing chocobo' or '')
    end
    print(chat.header(addon.name):append(chat.message(msg)))
end)

ashita.events.register('load', 'load_cb', function ()
    print(chat.header(addon.name):append(chat.message('Loaded. Raptors show as chocobos from the next mount or zone.')))
end)
