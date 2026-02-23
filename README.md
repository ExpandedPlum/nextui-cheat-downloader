# Cheat Downloader

A NextUI/MinUI pak for downloading cheat files directly to your device from the [Libretro cheat database](https://github.com/libretro/libretro-database/tree/master/cht). No computer required — browse your ROM library, pick a cheat, and it downloads and saves automatically.

---

## Requirements

- **Device:** Trimui Brick or Trimui Smart Pro (platform: `tg5040`)
- **Firmware:** NextUI or MinUI
- **Network:** Wi-Fi must be connected on the device

---

## Installation

1. Mount your MinUI SD card.
2. Download the latest `Cheat Downloader.pak.zip` from [GitHub Releases](https://github.com/mikecosentino/nextui-cheat-downloader/releases).
3. Create the folder `/Tools/tg5040/Cheat Downloader.pak/` on your SD card.
4. Extract the contents of the zip into that folder.
5. Confirm `/Tools/tg5040/Cheat Downloader.pak/launch.sh` exists.
6. Unmount the SD card and insert it into your device.

---

## Usage

Navigate to **Tools → Cheat Downloader** and press **A**.

### Step 1 — Select a System

The pak scans your `/Roms` folder and shows only systems that:
- Have a recognized folder short-code (e.g. `MGBA`, `SFC`, `PS`)
- Contain at least one ROM file with a supported extension

Select a system and press **A**.

### Step 2 — Select a ROM

Your ROM files for that system are listed. Select the game you want cheats for and press **A**.

### Step 3 — Select a Cheat

The pak fetches the cheat list for your system from GitHub and shows entries that fuzzy-match your ROM's filename. If no close match is found, the full cheat list is shown instead.

Cheat entries are displayed in the format:

```
[TOOL|REGION] Game Title
```

| Prefix example | Meaning |
|----------------|---------|
| `[CB\|US]` | Code Breaker, USA |
| `[AR\|US,EU]` | Action Replay, USA + Europe |
| `[GS\|JP]` | GameShark, Japan |
| `[PAR\|EU]` | Pro Action Replay, Europe |
| `[GG\|WD]` | Game Genie, World |

**Tool abbreviations:**

| Code | Full name |
|------|-----------|
| `CB` | Code Breaker |
| `AR` | Action Replay |
| `PAR` | Pro Action Replay |
| `GS` | GameShark |
| `GG` | Game Genie |

**Region abbreviations:**

| Code | Region |
|------|--------|
| `US` | USA |
| `EU` | Europe |
| `JP` | Japan |
| `WD` | World |
| `AU` | Australia |
| `KR` | Korea |
| `DE` | Germany |
| `FR` | France |
| `??` | Unknown |

Select the appropriate cheat and press **A**. The file downloads and saves automatically.

---

## Supported Systems

The following ROM folder short-codes are recognized:

| Folder code(s) | System |
|----------------|--------|
| `GBA`, `MGBA` | Game Boy Advance |
| `GBC` | Game Boy Color |
| `GB`, `GB0`, `SGB` | Game Boy |
| `FC`, `NES` | Nintendo Entertainment System |
| `SFC`, `SNES` | Super Nintendo Entertainment System |
| `N64` | Nintendo 64 |
| `NDS`, `NDS2` | Nintendo DS |
| `FDS` | Famicom Disk System |
| `MD`, `GEN`, `GENESIS` | Sega Mega Drive / Genesis |
| `GG` | Sega Game Gear |
| `SMS`, `SMSGG` | Sega Master System |
| `32X` | Sega 32X |
| `SS`, `SAT` | Sega Saturn |
| `DC` | Sega Dreamcast |
| `MCD`, `SCD` | Sega CD |
| `PS`, `PSX`, `PS1` | PlayStation |
| `PSP` | PlayStation Portable |
| `PCE`, `TG16` | PC Engine / TurboGrafx-16 |
| `PCECD` | PC Engine CD |
| `SGFX` | PC Engine SuperGrafx |
| `ATARI`, `A26` | Atari 2600 |
| `LYNX` | Atari Lynx |
| `A7800` | Atari 7800 |
| `ARCADE`, `FBN` | FBNeo Arcade |

Your ROM folders must follow the NextUI/MinUI naming convention: `System Name (CODE)` — for example, `Game Boy Advance (MGBA)` or `PlayStation (PS)`.

---

## Where Cheats Are Saved

Downloaded cheat files are saved to:

```
/mnt/SDCARD/Cheats/<SYSTEM_CODE>/<ROM_NAME>.cht
```

For example, a cheat for `Castlevania - Aria of Sorrow.gba` on the MGBA system saves to:

```
/mnt/SDCARD/Cheats/MGBA/Castlevania - Aria of Sorrow.cht
```

The cheat file is named after the ROM (without its original extension) so that the emulator can automatically detect and load it.

---

## Caching

Cheat lists fetched from GitHub are cached locally for **24 hours** to avoid hitting API rate limits and speed up repeat use. To force a refresh before the 24-hour window:

1. SSH into the device (or use a file manager)
2. Delete the cache files at `/mnt/SDCARD/.userdata/tg5040/Cheat Downloader/cheats_*.json`
3. Relaunch the pak

---

## Troubleshooting

**No systems appear in the list**
- Make sure your ROM folders use the `System Name (CODE)` naming convention
- Ensure ROM files have a supported extension (`.gba`, `.sfc`, `.iso`, etc.)

**"Network error loading cheats"**
- Verify Wi-Fi is connected on the device
- GitHub's unauthenticated API allows 60 requests/hour. If you've browsed many systems in quick succession, wait a few minutes

**"No close matches" shown for my ROM**
- The fuzzy matcher strips region/version tags and compares core game names. If the match still fails, the full cheat list for the system is displayed so you can pick manually

**A system I own is missing from the list**
- Its folder short-code may not be in the supported list above. Check the folder name on your SD card and open an issue if the code should be added

---

## Acknowledgements

- Original author: [Mike Cosentino](https://github.com/mikecosentino)
- [minui-list](https://github.com/josegonzalez/minui-list) by Jose Diaz-Gonzalez
- [minui-presenter](https://github.com/josegonzalez/minui-presenter) by Jose Diaz-Gonzalez
- Cheat data sourced from the [Libretro cheat database](https://github.com/libretro/libretro-database/tree/master/cht)
