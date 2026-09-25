#!/usr/bin/env bash
set -eo pipefail

export WAYLAND_DISPLAY="${WAYLAND_DISPLAY:-wayland-1}"
export XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:-/run/user/1000}"

CLIP_URL=$(wl-paste 2>/dev/null | grep -E "^(http|https)://" | head -n1 || echo "")

PROMPT_LABEL="󰎆  Fetch Music URL › "

# Inherits SSOT colors and geometry directly from fuzzel.nix
if [[ -n "$CLIP_URL" ]]; then
    TARGET_URL=$(printf "%s\n" "$CLIP_URL" | fuzzel --dmenu --prompt="$PROMPT_LABEL" --width=54 --lines=1)
else
    TARGET_URL=$(echo "" | fuzzel --dmenu --prompt="$PROMPT_LABEL" --width=54 --lines=0)
fi

[[ -z "$TARGET_URL" ]] && exit 0

DEST_DIR="/home/ducson/Music"
mkdir -p "$DEST_DIR"

notify-send -a "Music Fetcher" -i "audio-x-generic" \
    "Downloading Track..." \
    "Extracting audio stream and high-res cover art..."

TMP_LOG=$(mktemp)
set +e
yt-dlp \
    --extractor-args "youtube:player_client=mweb,web" \
    -x --audio-format mp3 \
    --add-metadata \
    --embed-thumbnail \
    -o "${DEST_DIR}/%(title)s.%(ext)s" \
    "$TARGET_URL" > "$TMP_LOG" 2>&1

EXIT_CODE=$?
set -e

if [ $EXIT_CODE -eq 0 ]; then
    SONG_TITLE=$(grep -oP '(?<=\[ExtractAudio\] Destination: ).*' "$TMP_LOG" | head -n1 | xargs -0 -I {} basename "{}" .mp3 || echo "")
    [[ -z "$SONG_TITLE" ]] && SONG_TITLE="New Track"
    notify-send -a "Music Fetcher" -i "audio-headphones" \
        "Download Complete! 🎵" \
        "\"${SONG_TITLE}\" is now in ~/Music"
else
    notify-send -a "Music Fetcher" -u critical -i "dialog-error" \
        "Download Failed!" \
        "Audio extraction failed. Check connection or URL."
fi

rm -f "$TMP_LOG"
