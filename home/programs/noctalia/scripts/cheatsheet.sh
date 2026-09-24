#!/usr/bin/env bash

# 1. Toggle: Đóng Fuzzel nếu đang hiển thị
if pidof fuzzel >/dev/null; then
    pkill -9 fuzzel
    exit 0
fi

# 2. Định vị file cấu hình nguồn
BINDS_FILE="/etc/nixos/home/desktop/binds.kdl"
[[ ! -f "$BINDS_FILE" ]] && BINDS_FILE="/etc/nixos/home/desktop/niri.kdl"
[[ ! -f "$BINDS_FILE" ]] && exit 1

CACHE_DIR="/dev/shm/niri_cheatsheet_${UID}"
CACHE_PAYLOAD="${CACHE_DIR}/menu.payload"
CACHE_ACTIONS="${CACHE_DIR}/actions.db"
CACHE_STAMP="${CACHE_DIR}/stamp"

mkdir -p "$CACHE_DIR"

# 3. Thuật toán State Checksum: Kiểm tra mtime/size của file KDL
CURRENT_STAMP=$(stat -c "%Y-%s" "$BINDS_FILE" 2>/dev/null)
CACHE_VALID=0

if [[ -f "$CACHE_STAMP" && -f "$CACHE_PAYLOAD" && -f "$CACHE_ACTIONS" ]]; then
    SAVED_STAMP=$(cat "$CACHE_STAMP" 2>/dev/null)
    if [[ "$CURRENT_STAMP" == "$SAVED_STAMP" && -s "$CACHE_PAYLOAD" ]]; then
        CACHE_VALID=1
    fi
fi

# 4. Khi Cache không hợp lệ: Biên dịch 1 lần duy nhất bằng AWK State Machine
if [[ "$CACHE_VALID" -eq 0 ]]; then
    awk '
    BEGIN { FS="\t"; }
    {
        line = $0
        sub(/^[ \t]+/, "", line)
        
        if (line ~ /^(Mod\+|Print)/ && line ~ /\{/ && line !~ /Slash/ && line !~ /XF86/) {
            match(line, /^[^ \{]+/)
            key = substr(line, RSTART, RLENGTH)
            gsub(/Mod/, "SUPER", key)

            desc = "Action"
            if (match(line, /\/\/[ \t]*/)) {
                desc = substr(line, RSTART + RLENGTH)
                sub(/[ \t]+$/, "", desc)
            }

            cmd = ""
            if (match(line, /spawn[ \t]+[^;\}]+/)) {
                spawn_part = substr(line, RSTART + 6, RLENGTH - 6)
                while (match(spawn_part, /"([^"]+)"/)) {
                    arg = substr(spawn_part, RSTART + 1, RLENGTH - 2)
                    cmd = (cmd == "") ? ("\"" arg "\"") : (cmd " \"" arg "\"")
                    spawn_part = substr(spawn_part, RSTART + RLENGTH)
                }
            } else if (match(line, /\{[ \t]*([^;\}]+);/)) {
                match(line, /\{[ \t]*([^;\}]+);/)
                action = substr(line, RSTART + 1, RLENGTH - 2)
                gsub(/[ \t]+/, "", action)
                cmd = "niri msg action " action
            }

            label = sprintf("󰌌  %-20s ›  %s", key, desc)
            print label > "'"$CACHE_PAYLOAD"'"
            print label "\t" cmd > "'"$CACHE_ACTIONS"'"
        }
    }' "$BINDS_FILE"
    
    echo "$CURRENT_STAMP" > "$CACHE_STAMP"
fi

# 5. Đẩy dữ liệu qua Stream Pipe (Tương thích 100% Wayland & Fuzzel)
SELECTED=$(cat "$CACHE_PAYLOAD" | fuzzel \
    --dmenu \
    --prompt="⌨ Hotkeys › " \
    --font="GeistMono Nerd Font:size=11" \
    --width=54 \
    --lines=15 \
    --horizontal-pad=24 \
    --vertical-pad=16 \
    --inner-pad=10 \
    --line-height=26 \
    --background-color=09090bee \
    --text-color=fafafaff \
    --match-color=60a5faff \
    --selection-color=27272ae6 \
    --selection-text-color=ffffffff \
    --selection-match-color=93c5fdff \
    --border-color=ffffff24 \
    --border-width=1 \
    --border-radius=18)

# 6. O(1) Action Dispatching
if [[ -n "$SELECTED" ]]; then
    EXEC_CMD=$(awk -F'\t' -v target="$SELECTED" '$1 == target { print $2; exit }' "$CACHE_ACTIONS")
    if [[ -n "$EXEC_CMD" ]]; then
        eval "${EXEC_CMD} &"
    fi
fi
