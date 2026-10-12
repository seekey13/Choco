# Choco

Ashita v4 (4.16) addon. Shows the Raptor mount as a chocobo, in the color and look you pick. Only your client sees it. Everyone else still sees a Raptor.

## Install

Drop `Choco.lua` in `Ashita/addons/Choco/`, then `/addon load Choco`.

## Usage

Load it and ride your Raptor (`/mount Raptor`, or `/ride Raptor`). By default it's Random: a new look every ride.

| Command | Does |
| --- | --- |
| `/choco` | Opens or closes the settings window. |
| `/choco yellow` / `black` / `blue` / `red` / `green` | Sets the color. |
| `/choco pink` | Yellow, with a pink/white beak and tail. They show only with the large beak and full tail on. |
| `/choco noble` | Picks the armored Noble Chocobo. Picking a color switches back. |
| `/choco random` | Rolls a look (any color, Pink or Noble, plus beak, talons and tail) for every ride: yours, and each other Raptor rider's. Picking a color switches back. |
| `/choco beak` / `talons` / `tail` | Turns the large beak, large talons or full tail on or off. With Noble or Random picked, it's saved for when you pick a color. |
| `/choco raw <n>` / `raw off` | For testing: forces look bits `n` (hex like `0x0C3`, or decimal) on every chocobo, until `off` or a reload. Picking Random or Noble skips it. |

The window has the same settings: a row of buttons (Random, the colors, Pink, Noble), then the beak, talons and tail checkboxes. The picked button has the normal color and the rest are gray. With Noble or Random picked, the checkboxes are greyed out, and hovering one says why. Hovering Pink says which checkboxes it needs. At the bottom, a button runs `/mount Raptor` when you're on foot and `/dismount` when you're mounted.

Your look is saved per character. A change shows on your Raptor from your next mount or zone, and on other riders from their next update.

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

Pink uses two bits the server never sets, found by testing: bit 1 turns a large beak pink/white and bit 7 a full tail. They only work on a yellow body, and do nothing on their own. Colors 5-7 have no model, so the chocobo doesn't show at all.

It rewrites four packets:

- `0x00D` (player update): any player riding a Raptor, including you.
- `0x037` (your status): you.
- `0x00A` (zone-in): you, when you zone while riding. This packet has no mount id, so the addon uses the one it saw in your last `0x037`.
- `0x067` (your sync): your own chocobo's look. The server only sends this at zone-in, so Choco keeps the last one and sends your client a copy with your look when you mount.

## Notes

- **Every Raptor changes, not just yours.** Other players riding a Raptor show as a chocobo on your screen too, in your look (or their own roll with Random). Your own mount doesn't change for anyone else.
- **It starts on the next update.** A Raptor that is already out when you load the addon stays a Raptor until it remounts, zones or comes back into range.
- **Your own look needs one zone after loading.** Choco only gets the `0x067` copy it resends at zone-in. If you load it mid-session, zone once.
- **Your client thinks you're on a chocobo.** Status reads `5` (Chocobo) instead of `85` (Mount), so another addon that checks for status `85` won't see you as mounted. The Mounted buff, which `Ride` uses, is unchanged.
- **The music isn't changed.** You still hear the mount theme, not the chocobo theme. `NoMount` still mutes it.
- **Random rolls once per ride.** Each Raptor rider, you included, keeps one look until they get off or you zone.
- **The Noble ignores beak, talons, tail and color.** It's a fixed model, and the server never sends a look for it.
- **If you still see a Raptor:** this server may number Raptor differently. With `PacketLogger`, mount up and read byte `0x5B` of your `0x037`. If it isn't `2`, change `RAPTOR` at the top of `Choco.lua` to that number.
- Packet layouts: [atom0s/XiPackets](https://github.com/atom0s/XiPackets). Mount and look values: LandSandBoat `mountutils.h`, `mountutils.cpp`, `scripts/enum/mount.lua` and `scripts/enum/chocobo_raising.lua`.
