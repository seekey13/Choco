# Choco

Ashita v4 (4.16) addon. Shows the Raptor mount as a chocobo, in the color and look you pick. Only your client sees it. Everyone else still sees a Raptor.

## Install

Drop `Choco.lua` in `Ashita/addons/Choco/`, then `/addon load Choco`.

## Usage

Load it and ride your Raptor (`/mount Raptor`, or `/ride Raptor`). By default it's Random: a new look every update.

| Command | Does |
| --- | --- |
| `/choco` | Opens or closes the settings window. |
| `/choco yellow` / `black` / `blue` / `red` / `green` | Sets the color. |
| `/choco noble` | Picks the armored Noble Chocobo. Picking a color switches back. |
| `/choco random` | Rolls a new look (any color or Noble, plus beak, talons and tail) for every packet. Picking a color switches back. |
| `/choco beak` / `talons` / `tail` | Turns the large beak, large talons or full tail on or off. |

The window has the same settings: a row of buttons (Random, the colors, Noble), then the beak, talons and tail checkboxes. The picked button has the normal color and the rest are gray. With Noble or Random picked, the checkboxes are greyed out, and hovering one says why. At the bottom, a button runs `/mount Raptor` when you're on foot and `/dismount` when you're mounted.

Your look is saved per character. A change shows from your next mount or zone.

## How it works

Nothing on the server changes. The addon only edits what your client receives, so the swap is on your screen only.

The server describes a mount with these values. Choco rewrites a Raptor's values into the ones the server sends for a chocobo with your look:

| Value | Raptor | Rental chocobo | Raised chocobo (color, beak, talons, tail) | Noble Chocobo |
| --- | --- | --- | --- | --- |
| Status | `85` (mount) | `5` | `5` | `5` |
| ChocoboIndex | `3` | `1` | `2` | `4` |
| Mount id | `2` | `0` | `0` | `34` |
| CustomProperties | | | look bits | `[1] = 1` |

The look bits are the ones the server uses for a raised chocobo: bit 0 large beak, bit 3 large talons, bit 6 full tail, bits 9-11 color (0 yellow, 1 black, 2 blue, 3 red, 4 green).

It rewrites four packets:

- `0x00D` (player update): any player riding a Raptor, including you.
- `0x037` (your status): you.
- `0x00A` (zone-in): you, when you zone while riding. This packet has no mount id, so the addon uses the one it saw in your last `0x037`.
- `0x067` (your sync): your own chocobo's look. The server only sends this at zone-in, so Choco keeps the last one and sends your client a copy with your look when you mount.

## Notes

- **Every Raptor changes, not just yours.** Other players riding a Raptor show as your chocobo on your screen too. Your own mount doesn't change for anyone else.
- **It starts on the next update.** A Raptor that is already out when you load the addon stays a Raptor until it remounts, zones or comes back into range.
- **Your own look needs one zone after loading.** Choco only gets the `0x067` copy it resends at zone-in. If you load it mid-session, zone once.
- **Your client thinks you're on a chocobo.** Status reads `5` (Chocobo) instead of `85` (Mount), so another addon that checks for status `85` won't see you as mounted. The Mounted buff, which `Ride` uses, is unchanged.
- **The music isn't changed.** You still hear the mount theme, not the chocobo theme. `NoMount` still mutes it.
- **Random can switch looks mid-ride.** Every update the server sends for a Raptor rider, including you when your buffs change, gets a fresh roll.
- **The Noble ignores beak, talons, tail and color.** It's a fixed model, and the server never sends a look for it.
- **If you still see a Raptor:** this server may number Raptor differently. With `PacketLogger`, mount up and read byte `0x5B` of your `0x037`. If it isn't `2`, change `RAPTOR` at the top of `Choco.lua` to that number.
- Packet layouts: [atom0s/XiPackets](https://github.com/atom0s/XiPackets). Mount and look values: LandSandBoat `mountutils.h`, `mountutils.cpp`, `scripts/enum/mount.lua` and `scripts/enum/chocobo_raising.lua`.
