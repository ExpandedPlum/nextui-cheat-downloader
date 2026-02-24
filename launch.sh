#!/bin/sh
# Another Cheat Downloader. A MinUI pak for downloading cheat files from the Libretro database
# Mike Cosentino

# Setup
PAK_DIR="$(dirname "$0")"
PAK_NAME="$(basename "$PAK_DIR")"
PAK_NAME="${PAK_NAME%.*}"
set -x
rm -f "$LOGS_PATH/$PAK_NAME.txt"
exec >>"$LOGS_PATH/$PAK_NAME.txt"
exec 2>&1
export PATH="$PAK_DIR/bin/tg5040:$PATH"

# Constants
ROM_ROOT="/mnt/SDCARD/Roms"
CHEATS_ROOT="/mnt/SDCARD/Cheats"
CACHE_DIR="/mnt/SDCARD/.userdata/tg5040/$PAK_NAME"
GITHUB_API="https://api.github.com/repos/libretro/libretro-database/contents/cht"
CACHE_TTL_HOURS=24

# ROM extensions to include (pipe-separated for grep -E)
ROM_EXTENSIONS="gba|gbc|gb|nes|sfc|smc|n64|z64|v64|nds|fds|md|gen|smd|gg|sms|32x|cue|iso|pbp|chd|pce|psp|lnx|a78|a26|zip|7z|m3u"

mkdir -p "$CACHE_DIR"

# ── UI helpers ────────────────────────────────────────────────────────────────

show_status() {
  minui-presenter --message "$1" --timeout -1 &
}

hide_status() {
  killall -q minui-presenter 2>/dev/null || true
}

display_list() {
  local json_file="$1" title="$2" state_file="$3"
  minui-list --file "$json_file" --item-key "items" --title "$title" \
    --write-value state --write-location "$state_file"
  local r=$?
  [ $r -ne 0 ] && echo "User pressed Back at: $title"
  return $r
}

# ── Name normalization for fuzzy matching ─────────────────────────────────────

# Strip extension, parenthetical groups, lowercase, alphanumeric only
normalize_name() {
  printf '%s' "$1" \
    | sed 's/\.[^.]*$//; s/ *([^)]*)//g' \
    | tr 'A-Z' 'a-z' \
    | tr -cd 'a-z0-9'
}

# ── Cache helpers ─────────────────────────────────────────────────────────────

# Returns 0 (true) if file doesn't exist or is older than CACHE_TTL_HOURS
# Uses find -mtime which is supported by BusyBox (days, so TTL is in whole days)
cache_expired() {
  local file="$1"
  [ ! -f "$file" ] && return 0
  # CACHE_TTL_HOURS / 24, minimum 1 day
  local ttl_days=$(( CACHE_TTL_HOURS / 24 ))
  [ "$ttl_days" -lt 1 ] && ttl_days=1
  [ -n "$(find "$file" -mtime +"$ttl_days" 2>/dev/null)" ]
}

# ── System mappings ───────────────────────────────────────────────────────────

# Map MinUI ROM folder short code → Libretro system name
short_to_libretro() {
  case "$1" in
    GBA|MGBA)       echo "Nintendo - Game Boy Advance" ;;
    GBC)            echo "Nintendo - Game Boy Color" ;;
    GB|GB0|SGB)     echo "Nintendo - Game Boy" ;;
    FC|NES)         echo "Nintendo - Nintendo Entertainment System" ;;
    SFC|SNES)       echo "Nintendo - Super Nintendo Entertainment System" ;;
    N64)            echo "Nintendo - Nintendo 64" ;;
    NDS|NDS2)       echo "Nintendo - Nintendo DS" ;;
    FDS)            echo "Nintendo - Family Computer Disk System" ;;
    MD|GEN|GENESIS) echo "Sega - Mega Drive - Genesis" ;;
    GG)             echo "Sega - Game Gear" ;;
    SMS|SMSGG)      echo "Sega - Master System - Mark III" ;;
    32X)            echo "Sega - 32X" ;;
    SS|SAT)         echo "Sega - Saturn" ;;
    DC)             echo "Sega - Dreamcast" ;;
    MCD|SCD)        echo "Sega - Mega-CD - Sega CD" ;;
    PS|PSX|PS1)     echo "Sony - PlayStation" ;;
    PSP)            echo "Sony - PlayStation Portable" ;;
    PCE|TG16)       echo "NEC - PC Engine - TurboGrafx 16" ;;
    PCECD)          echo "NEC - PC Engine CD - TurboGrafx-CD" ;;
    SGFX)           echo "NEC - PC Engine SuperGrafx" ;;
    ATARI|A26)      echo "Atari - 2600" ;;
    LYNX)           echo "Atari - Lynx" ;;
    A7800)          echo "Atari - 7800" ;;
    ARCADE|FBN)     echo "FBNeo - Arcade Games" ;;
    *)              echo "" ;;
  esac
}

# ── Build data ────────────────────────────────────────────────────────────────

# Scan ROM_ROOT, build list of systems that have ROMs AND a known Libretro mapping
build_available_systems() {
  local out="$CACHE_DIR/available_systems.json"
  local tmp="$CACHE_DIR/avail_tmp.json"

  printf '{ "items": [] }' > "$tmp"

  for dir in "$ROM_ROOT"/*/; do
    [ -d "$dir" ] || continue
    folder=$(basename "$dir")

    # Extract short code from folder name like "Game Boy Advance (GBA)"
    case "$folder" in
      *\(*\)*)
        short=$(printf '%s\n' "$folder" | sed -n 's/.*(\(.*\)).*/\1/p')
        ;;
      *) continue ;;
    esac
    [ -z "$short" ] && continue

    libretro_name=$(short_to_libretro "$short")
    [ -z "$libretro_name" ] && continue

    # Check there are actual ROM files with known extensions (skip hidden/system files)
    find "${dir%/}" -maxdepth 1 -type f ! -name ".*" \
      | grep -qiE "\.(${ROM_EXTENSIONS})$" 2>/dev/null || continue

    # Safely append to JSON using jq
    jq --arg name "$libretro_name" --arg short "$short" --arg dir "${dir%/}" \
      '.items += [{ name: $name, short: $short, rom_dir: $dir }]' \
      "$tmp" > "$tmp.new" && mv "$tmp.new" "$tmp"
  done

  mv "$tmp" "$out"
}

# Build list of ROM files for a system, filtering to known extensions
build_roms_list() {
  local rom_dir="$1" system_short="$2"
  local roms_json="$CACHE_DIR/roms_${system_short}.json"

  find "$rom_dir" -maxdepth 1 -type f ! -name ".*" \
    | grep -iE "\.(${ROM_EXTENSIONS})$" \
    | sort \
    | jq -R -s '
        split("\n") | map(select(. != "")) |
        map({ name: (. | split("/") | last), file: . }) |
        { items: . }
      ' > "$roms_json"
}

# Fetch and cache the cheat list for a system from GitHub (cached for CACHE_TTL_HOURS)
cache_system_cheats() {
  local system_name="$1" system_short="$2"
  local cache_file="$CACHE_DIR/cheats_${system_short}.json"

  if ! cache_expired "$cache_file"; then
    echo "Using cached cheats for $system_name"
    return 0
  fi

  show_status "Loading cheats for $system_name..."

  local encoded
  encoded=$(printf '%s' "$system_name" | jq -Rr @uri)
  curl -sk "$GITHUB_API/$encoded" -o "$CACHE_DIR/cheats_raw.json"

  # Validate response is a JSON array before processing
  if ! jq -e 'type == "array"' "$CACHE_DIR/cheats_raw.json" > /dev/null 2>&1; then
    hide_status
    rm -f "$CACHE_DIR/cheats_raw.json"
    minui-presenter --message "Network error loading cheats. Check connection." --timeout 4
    return 1
  fi

  if ! jq '[.[] | select(.type == "file" and (.name | endswith(".cht"))) |
    (.name | gsub("\\.cht$"; "")) as $n |
    [($n | scan("\\(([^)]+)\\)")) | .[0]] as $parens |
    ($n | gsub(" *\\(.*$"; "")) as $game |
    ($parens | map(select(test("Code.?Breaker|Action.?Replay|GameShark|Game.?Genie"; "i"))) | first // "") as $tool_raw |
    ($parens | map(select(test("USA|Europe|Japan|World|Korea|Australia|France|Germany|Spain|Brazil|Unknown"; "i"))) | first // "") as $region_raw |
    (if ($tool_raw | test("Code.?Breaker"; "i")) then "CB"
     elif ($tool_raw | test("Pro.?Action.?Replay"; "i")) then "PAR"
     elif ($tool_raw | test("Action.?Replay"; "i")) then "AR"
     elif ($tool_raw | test("GameShark"; "i")) then "GS"
     elif ($tool_raw | test("Game.?Genie"; "i")) then "GG"
     else $tool_raw end) as $tool |
    ($region_raw |
     gsub("USA"; "US") | gsub("Europe"; "EU") | gsub("Japan"; "JP") |
     gsub("World"; "WD") | gsub("Australia"; "AU") | gsub("Unknown"; "??") |
     gsub(", "; ",")) as $region |
    (if ($tool != "" and $region != "") then "[" + $tool + "|" + $region + "] " + $game
     elif ($tool != "") then "[" + $tool + "] " + $game
     elif ($region != "") then "[" + $region + "] " + $game
     else $n end) as $display |
    { name: $display, url: .download_url }
  ] | { items: . }' "$CACHE_DIR/cheats_raw.json" > "$cache_file"; then
    hide_status
    rm -f "$CACHE_DIR/cheats_raw.json" "$cache_file"
    minui-presenter --message "Error processing cheat list. Try again." --timeout 4
    return 1
  fi

  rm -f "$CACHE_DIR/cheats_raw.json"
  hide_status
}

# Filter cached cheats to entries that fuzzy-match the given ROM filename
find_matching_cheats() {
  local rom_basename="$1" system_short="$2"
  local rn
  rn=$(normalize_name "$rom_basename")

  jq --arg rn "$rn" '
    .items | map(
      select(
        (.name | gsub("^\\[.*?\\] "; "") | gsub(" *\\(.*$"; "") | ascii_downcase | gsub("[^a-z0-9]"; "")) as $cn |
        ($rn | contains($cn)) or
        ($cn | contains($rn))
      )
    ) | { items: . }
  ' "$CACHE_DIR/cheats_${system_short}.json" > "$CACHE_DIR/matched_cheats.json"
}

# Download a cheat file from its raw GitHub URL
download_cheat() {
  rm -f "$CACHE_DIR/selected.cht"
  curl -sk -f "$1" -o "$CACHE_DIR/selected.cht"
}

# Save downloaded cheat named after the ROM file (without ROM extension)
save_cheat() {
  local system_short="$1" rom_file="$2"
  local rom_basename cheat_name
  rom_basename=$(basename "$rom_file")
  cheat_name="${rom_basename%.*}.cht"   # strip ROM ext, add .cht
  mkdir -p "$CHEATS_ROOT/$system_short"
  cp "$CACHE_DIR/selected.cht" "$CHEATS_ROOT/$system_short/$cheat_name"
  echo "Saved: $CHEATS_ROOT/$system_short/$cheat_name"
  minui-presenter --message "Cheat saved for $rom_basename!" --timeout 3
}

# ── Main ──────────────────────────────────────────────────────────────────────

main() {
  show_status "Scanning ROM library..."
  build_available_systems
  hide_status

  available_count=$(jq '.items | length' "$CACHE_DIR/available_systems.json")
  if [ "$available_count" -eq 0 ]; then
    minui-presenter --message "No supported ROM folders found in $ROM_ROOT" --timeout 5
    exit 0
  fi

  while true; do
    # ── Pick system ──────────────────────────────────────────────────────────
    if ! display_list "$CACHE_DIR/available_systems.json" "Select System" "$CACHE_DIR/sys_state.json"; then
      exit 0
    fi

    sel=$(jq -r '.selected' "$CACHE_DIR/sys_state.json")
    system_name=$(jq -r --argjson i "$sel" '.items[$i].name'    "$CACHE_DIR/available_systems.json")
    system_short=$(jq -r --argjson i "$sel" '.items[$i].short'  "$CACHE_DIR/available_systems.json")
    rom_dir=$(jq -r      --argjson i "$sel" '.items[$i].rom_dir' "$CACHE_DIR/available_systems.json")

    cache_system_cheats "$system_name" "$system_short" || continue

    build_roms_list "$rom_dir" "$system_short"

    while true; do
      # ── Pick ROM ───────────────────────────────────────────────────────────
      if ! display_list "$CACHE_DIR/roms_${system_short}.json" "$system_name" "$CACHE_DIR/rom_state.json"; then
        break
      fi

      sel=$(jq -r '.selected' "$CACHE_DIR/rom_state.json")
      rom_file=$(jq -r    --argjson i "$sel" '.items[$i].file' "$CACHE_DIR/roms_${system_short}.json")
      rom_basename=$(basename "$rom_file")

      find_matching_cheats "$rom_basename" "$system_short"
      match_count=$(jq '.items | length' "$CACHE_DIR/matched_cheats.json")

      if [ "$match_count" -eq 0 ]; then
        minui-presenter --message "No close matches. Showing all cheats." --timeout 2
        cp "$CACHE_DIR/cheats_${system_short}.json" "$CACHE_DIR/matched_cheats.json"
      fi

      # ── Pick cheat ─────────────────────────────────────────────────────────
      if ! display_list "$CACHE_DIR/matched_cheats.json" "$rom_basename" "$CACHE_DIR/cheat_state.json"; then
        continue
      fi

      sel=$(jq -r '.selected' "$CACHE_DIR/cheat_state.json")
      cheat_name=$(jq -r --argjson i "$sel" '.items[$i].name' "$CACHE_DIR/matched_cheats.json")
      cheat_url=$(jq -r  --argjson i "$sel" '.items[$i].url'  "$CACHE_DIR/matched_cheats.json")

      show_status "Downloading $cheat_name..."
      if ! download_cheat "$cheat_url"; then
        hide_status
        minui-presenter --message "Download failed. Check your connection." --timeout 4
        continue
      fi
      hide_status

      save_cheat "$system_short" "$rom_file"
    done
  done
}

main
