#!/usr/bin/env bash
set -eo pipefail

export WAYLAND_DISPLAY="${WAYLAND_DISPLAY:-wayland-1}"
export XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:-/run/user/1000}"

# Entrypoint logic: Launch in detached floating Kitty modal if not inside terminal
if [[ "$1" != "--run-interactive" ]]; then
    exec kitty --class "music-fetch-float" \
               --title "Music Fetcher" \
               -o initial_window_width=720 \
               -o initial_window_height=360 \
               bash "$0" --run-interactive
fi

# ==========================================
# UI PALETTE & STYLES (Dark Zinc / Glass)
# ==========================================
C_RESET="\033[0m"
C_BOLD="\033[1m"
C_DIM="\033[2m"
C_WHITE="\033[38;2;250;250;250m"
C_ZINC_MUTED="\033[38;2;113;113;122m"
C_BLUE="\033[38;2;96;165;250m"
C_GREEN="\033[38;2;74;222;128m"
C_RED="\033[38;2;248;113;113m"
C_CYAN="\033[38;2;34;211;238m"
C_YELLOW="\033[38;2;250;204;21m"

cleanup() {
    tput cnorm 2>/dev/null || true
}
trap cleanup EXIT INT TERM

send_notification() {
    if command -v notify-send >/dev/null 2>&1; then
        notify-send "$@" || true
    fi
}

# 1. Grab link from clipboard if valid
CLIP_URL=$(wl-paste 2>/dev/null | grep -E "^(http|https)://" | head -n1 || echo "")

clear
echo -e "${C_BOLD}${C_WHITE}󰎆 Noctalia Audio Fetcher${C_RESET}"
echo -e "${C_ZINC_MUTED}────────────────────────────────────────────────────────────${C_RESET}"

tput cnorm 2>/dev/null || true
if [[ -n "$CLIP_URL" ]]; then
    echo -e "${C_CYAN}󰅍 Detected URL in clipboard:${C_RESET}"
    echo -e "  ${C_DIM}${CLIP_URL}${C_RESET}\n"
    read -rp "$(echo -e "${C_BOLD}${C_WHITE}Press [Enter] to use this URL, or paste new URL: ${C_RESET}")" USER_INPUT
    TARGET_URL="${USER_INPUT:-$CLIP_URL}"
else
    read -rp "$(echo -e "${C_BOLD}${C_WHITE}Paste Audio / Video URL: ${C_RESET}")" TARGET_URL
fi

TARGET_URL=$(echo "$TARGET_URL" | xargs)

if [[ -z "$TARGET_URL" ]]; then
    echo -e "\n${C_RED}✖ Operation canceled. No URL provided.${C_RESET}"
    sleep 1
    exit 0
fi

# 2. Interactive Mode Selection (Single Track vs Full Album)
echo -e "\n${C_BOLD}${C_WHITE}Choose Download Target Mode:${C_RESET}"
echo -e "  ${C_BLUE}[1]${C_RESET} ${C_WHITE}Download Single Track${C_RESET}        ${C_ZINC_MUTED}› ~/Music/<Title>.mp3${C_RESET}"
echo -e "  ${C_YELLOW}[2]${C_RESET} ${C_WHITE}Download Full Album / Set${C_RESET}    ${C_ZINC_MUTED}› ~/Music/<Album>/<01> - <Title>.mp3${C_RESET}"
echo ""

read -rp "$(echo -e "${C_BOLD}${C_WHITE}Select mode [1/2, Default: 1]: ${C_RESET}")" MODE_CHOICE
MODE_CHOICE="${MODE_CHOICE:-1}"

BASE_DIR="/home/ducson/Music"
mkdir -p "$BASE_DIR"

if [[ "$MODE_CHOICE" == "2" ]]; then
    IS_ALBUM=1
    EXTRA_FLAGS=("--yes-playlist")
    OUTPUT_TEMPLATE="${BASE_DIR}/%(playlist_title|Album)s/%(playlist_index|01)02d - %(title)s.%(ext)s"
    START_MSG="Extracting album/playlist audio streams and cover arts..."
else
    IS_ALBUM=0
    EXTRA_FLAGS=("--no-playlist")
    OUTPUT_TEMPLATE="${BASE_DIR}/%(title)s.%(ext)s"
    START_MSG="Extracting single audio stream and high-res cover art..."
fi

send_notification -a "Music Fetcher" \
    "󰑮 Starting Download..." \
    "$START_MSG"

echo -e "\n${C_ZINC_MUTED}Connecting to audio endpoints...${C_RESET}"
tput civis 2>/dev/null || true

# 3. Background yt-dlp execution with live progress logging
TMP_LOG=$(mktemp)

set +e
yt-dlp \
    --extractor-args "youtube:player_client=mweb,web" \
    -x --audio-format mp3 \
    --add-metadata \
    --embed-thumbnail \
    --newline \
    "${EXTRA_FLAGS[@]}" \
    -o "$OUTPUT_TEMPLATE" \
    "$TARGET_URL" > "$TMP_LOG" 2>&1 &
YTDLP_PID=$!
set -e

SPINNER_CHARS=("⠋" "⠙" "⠹" "⠸" "⠼" "⠴" "⠦" "⠧" "⠇" "⠏")
SPIN_IDX=0
STATUS_MSG="Initializing stream"

while kill -0 "$YTDLP_PID" 2>/dev/null; do
    if [[ -f "$TMP_LOG" ]]; then
        LAST_LINE=$(tail -n 4 "$TMP_LOG" 2>/dev/null | tr '\r' '\n' | grep -v '^$' | tail -n 1 || echo "")
        
        if [[ "$LAST_LINE" =~ \[download\][[:space:]]+Downloading[[:space:]]+item[[:space:]]+([0-9]+)[[:space:]]+of[[:space:]]+([0-9]+) ]]; then
            STATUS_MSG="Item ${BASH_REMATCH[1]}/${BASH_REMATCH[2]}"
        elif [[ "$LAST_LINE" =~ ([0-9.]+\%) ]]; then
            STATUS_MSG="Downloading ${BASH_REMATCH[1]}"
        elif [[ "$LAST_LINE" =~ \[ExtractAudio\] ]]; then
            STATUS_MSG="Converting to MP3 & tagging"
        elif [[ "$LAST_LINE" =~ Embedding ]]; then
            STATUS_MSG="Embedding high-res cover art"
        fi
    fi

    SPIN_CHAR="${SPINNER_CHARS[$SPIN_IDX]}"
    printf "\r${C_BLUE}%s${C_RESET} ${C_WHITE}%-52s${C_RESET}" "$SPIN_CHAR" "$STATUS_MSG..."
    SPIN_IDX=$(( (SPIN_IDX + 1) % 10 ))
    sleep 0.08
done

wait "$YTDLP_PID"
EXIT_CODE=$?

# 4. Result Presentation
printf "\r%-56s\r" " "
tput cnorm 2>/dev/null || true

if [ $EXIT_CODE -eq 0 ]; then
    echo -e "${C_GREEN}✔ DOWNLOAD COMPLETE!${C_RESET}"
    echo -e "${C_DIM}────────────────────────────────────────────────────────────${C_RESET}"
    if [ "$IS_ALBUM" -eq 1 ]; then
        echo -e "  ${C_BOLD}${C_WHITE}📁 Album Saved:${C_RESET} ${C_CYAN}~/Music/<Album Name>/${C_RESET}"
        send_notification -a "Music Fetcher" \
            "🎵 Album Complete!" \
            "All album tracks have been downloaded to ~/Music"
    else
        SONG_TITLE=$(grep -oP '(?<=\[ExtractAudio\] Destination: ).*' "$TMP_LOG" | head -n1 | xargs -0 -I {} basename "{}" .mp3 || echo "")
        [[ -z "$SONG_TITLE" ]] && SONG_TITLE="Downloaded Track"
        echo -e "  ${C_BOLD}${C_WHITE}🎵 Track Name :${C_RESET} ${SONG_TITLE}"
        echo -e "  ${C_BOLD}${C_WHITE}📁 Destination:${C_RESET} ${C_CYAN}~/Music/${C_RESET}"
        send_notification -a "Music Fetcher" \
            "🎵 Track Complete!" \
            "\"${SONG_TITLE}\" is now ready in ~/Music"
    fi
    echo -e "${C_DIM}────────────────────────────────────────────────────────────${C_RESET}"
    sleep 2
else
    echo -e "${C_RED}✖ DOWNLOAD FAILED!${C_RESET}"
    echo -e "${C_DIM}────────────────────────────────────────────────────────────${C_RESET}"
    tail -n 6 "$TMP_LOG" | sed 's/^/  /'
    echo -e "${C_DIM}────────────────────────────────────────────────────────────${C_RESET}"

    send_notification -a "Music Fetcher" -u critical \
        "✖ Download Failed!" \
        "Extraction error. Check network or URL access."

    echo -e "\n${C_ZINC_MUTED}Press [Enter] to close...${C_RESET}"
    read -r
fi

rm -f "$TMP_LOG"
