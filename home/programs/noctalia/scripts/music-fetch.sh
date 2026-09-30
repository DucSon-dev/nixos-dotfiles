#!/usr/bin/env bash
set -eo pipefail

export WAYLAND_DISPLAY="${WAYLAND_DISPLAY:-wayland-1}"
export XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:-/run/user/1000}"

# Entrypoint logic: Launch in floating Kitty modal (Zero scrollbar, clean geometry)
if [[ "$1" != "--run-interactive" ]]; then
    exec kitty --class "music-fetch-float" \
               --title "Noctalia Audio Fetcher" \
               -o scrollback_lines=0 \
               -o scrollbar_style=none \
               -o window_padding_width=18 \
               bash "$0" --run-interactive
fi

# ==============================================================================
# UI COLOR SYSTEM (shadcn Dark Zinc Monochrome & Apple Liquid Glass)
# ==============================================================================
C_RESET="\033[0m"
C_BOLD="\033[1m"
C_DIM="\033[2m"

# Pure Dark Zinc Palette
C_WHITE="\033[38;2;250;250;250m"      # Zinc-50: Crisp headings & active titles
C_LIGHT="\033[38;2;212;212;216m"      # Zinc-300: Metadata text & details
C_MUTED="\033[38;2;113;113;122m"      # Zinc-500: Borders, dividers & hints

# Functional Status Accents
C_BLUE="\033[38;2;96;165;250m"        # Blue-400: Active fetching stream
C_GREEN="\033[38;2;74;222;128m"       # Green-400: Completed / Saved
C_YELLOW="\033[38;2;250;204;21m"      # Yellow-400: Paused stream
C_RED="\033[38;2;248;113;113m"        # Red-400: Error or Canceled

JOB_DIR="/dev/shm/noctalia-music-${UID}"
mkdir -p "$JOB_DIR"

cleanup() {
    tput cnorm 2>/dev/null || true
}
trap cleanup EXIT INT TERM

# Helper: Clear visible screen and purge scrollback buffer to prevent ghosting
clear_screen_buffer() {
    printf "\033[2J\033[3J\033[H"
}

send_notification() {
    if command -v notify-send >/dev/null 2>&1; then
        notify-send "$@" || true
    fi
}

# Function: Clean and sanitize raw album & track strings from YouTube
sanitize_title() {
    local raw="$1"
    local cleaned
    cleaned=$(echo "$raw" | sed -E \
        -e 's/[\|｜\-\–\—].*(the album|album|full album|audio|visualizer).*$//I' \
        -e 's/\((the album|album|full album|audio|visualizer|official).*\)//I' \
        -e 's/\[(the album|album|full album|audio|visualizer|official).*\]//I' \
        -e 's/(the album|album|full album)//Ig' \
        -e 's/["'\''“”＂„‟]+//g' \
        -e 's/^[[:space:]]+//' \
        -e 's/[[:space:]]+$//')
    [[ -z "$cleaned" ]] && cleaned="$raw"
    echo "$cleaned"
}

# Function: Truncate string gracefully
truncate_string() {
    local text="$1"
    local max_len="$2"
    if [[ ${#text} -gt $max_len ]]; then
        echo "${text:0:$((max_len - 2))}.."
    else
        printf "%-${max_len}s" "$text"
    fi
}

# Worker: Spawn background download task
spawn_download_job() {
    local task_type="$1"
    local raw_url="$2"
    local task_id
    task_id="$(date +%s%N | cut -b1-13)"
    local task_state_file="${JOB_DIR}/${task_id}.state"
    local task_log_file="${JOB_DIR}/${task_id}.log"
    local base_music_dir="/home/ducson/Music"

    local extra_flags=()
    local output_template=""
    local display_label=""

    if [[ "$task_type" == "album" ]]; then
        local raw_title
        raw_title=$(yt-dlp --flat-playlist --print "%(playlist_title)s" "$raw_url" 2>/dev/null | head -n1 || echo "")
        [[ -z "$raw_title" || "$raw_title" == "NA" ]] && raw_title=$(yt-dlp --print "%(playlist_title,title)s" "$raw_url" 2>/dev/null | head -n1 || echo "Album")
        
        local clean_title
        clean_title=$(sanitize_title "$raw_title")
        display_label="[Album] ${clean_title}"
        local target_dir="${base_music_dir}/${clean_title}"
        mkdir -p "$target_dir"

        extra_flags=(
            "--yes-playlist"
            "--postprocessor-args" "ExtractAudio:-metadata album=${clean_title}"
        )
        output_template="${target_dir}/%(playlist_index|01)02d - %(title)s.%(ext)s"
    else
        local track_title
        track_title=$(yt-dlp --print "%(title)s" "$raw_url" 2>/dev/null | head -n1 || echo "Single Track")
        display_label="[Single] $(sanitize_title "$track_title")"
        extra_flags=(
            "--no-playlist"
            "--postprocessor-args" "ExtractAudio:-metadata album=Single"
        )
        output_template="${base_music_dir}/%(title)s.%(ext)s"
    fi

    echo "LABEL=${display_label}" > "$task_state_file"
    echo "STATUS=RUNNING" >> "$task_state_file"
    echo "URL=${raw_url}" >> "$task_state_file"

    (
        yt-dlp \
            --extractor-args "youtube:player_client=mweb,web" \
            -x --audio-format mp3 \
            --add-metadata \
            --embed-thumbnail \
            --newline \
            "${extra_flags[@]}" \
            -o "$output_template" \
            "$raw_url" > "$task_log_file" 2>&1
        local ret=$?
        if [[ $ret -eq 0 ]]; then
            sed -i 's/^STATUS=.*/STATUS=COMPLETED/' "$task_state_file"
            send_notification -a "Music Fetcher" "✔ Complete" "${display_label}"
        else
            sed -i 's/^STATUS=.*/STATUS=FAILED/' "$task_state_file"
            send_notification -a "Music Fetcher" -u critical "✖ Error" "${display_label}"
        fi
    ) &
    local job_pid=$!
    echo "PID=${job_pid}" >> "$task_state_file"
    echo "TASK_ID=${task_id}" >> "$task_state_file"
}

# Screen: Task Queue & Real-time Stream Monitor
manage_jobs_screen() {
    while true; do
        clear_screen_buffer
        echo -e " ${C_BOLD}${C_WHITE}󰎆 Noctalia Task Monitor${C_RESET} ${C_DIM}• Queue & Concurrency Stream${C_RESET}"
        echo -e " ${C_MUTED}──────────────────────────────────────────────────────────────────────────────${C_RESET}"

        local task_files=("${JOB_DIR}"/*.state)
        local valid_tasks=()
        for tf in "${task_files[@]}"; do
            [[ -f "$tf" ]] && valid_tasks+=("$tf")
        done

        if [[ ${#valid_tasks[@]} -eq 0 ]]; then
            echo -e "\n   ${C_DIM}Queue is currently empty. No active downloads.${C_RESET}\n"
            echo -e " ${C_MUTED}──────────────────────────────────────────────────────────────────────────────${C_RESET}"
            read -rp "$(echo -e "   ${C_BOLD}${C_WHITE}Press [b] or [Enter] to return Home: ${C_RESET}")" nav_choice
            return 0
        fi

        echo -e "   ${C_DIM}#    TARGET NAME                             STATE          PROGRESS${C_RESET}"
        echo -e "   ${C_MUTED}──────────────────────────────────────────────────────────────────────────${C_RESET}"

        local idx=1
        declare -A task_map
        for tf in "${valid_tasks[@]}"; do
            local label status pid
            label=$(grep '^LABEL=' "$tf" | cut -d= -f2-)
            status=$(grep '^STATUS=' "$tf" | cut -d= -f2-)
            pid=$(grep '^PID=' "$tf" | cut -d= -f2-)
            local tid
            tid=$(basename "$tf" .state)
            local log_f="${JOB_DIR}/${tid}.log"

            if [[ "$status" == "RUNNING" || "$status" == "PAUSED" ]]; then
                if ! kill -0 "$pid" 2>/dev/null; then
                    status="COMPLETED"
                    sed -i 's/^STATUS=.*/STATUS=COMPLETED/' "$tf"
                fi
            fi

            local progress="Queued"
            if [[ -f "$log_f" ]]; then
                local last_line
                last_line=$(tail -n 6 "$log_f" 2>/dev/null | tr '\r' '\n' | grep -v '^$' | tail -n 1 || echo "")
                if [[ "$last_line" =~ ([0-9.]+\%) ]]; then
                    progress="${BASH_REMATCH[1]}"
                elif [[ "$last_line" =~ \[download\][[:space:]]+Downloading[[:space:]]+item[[:space:]]+([0-9]+)[[:space:]]+of[[:space:]]+([0-9]+) ]]; then
                    progress="Item ${BASH_REMATCH[1]}/${BASH_REMATCH[2]}"
                elif [[ "$last_line" =~ \[ExtractAudio\] ]]; then
                    progress="Converting"
                elif [[ "$last_line" =~ Embedding ]]; then
                    progress="Artwork"
                elif [[ "$status" == "COMPLETED" ]]; then
                    progress="Done 100%"
                fi
            fi

            local badge="${C_BLUE}▶ FETCHING${C_RESET} "
            [[ "$status" == "COMPLETED" ]] && badge="${C_GREEN}✔ COMPLETED${C_RESET}"
            [[ "$status" == "PAUSED" ]]    && badge="${C_YELLOW}⏸ PAUSED   ${C_RESET}"
            [[ "$status" == "FAILED" ]]    && badge="${C_RED}✖ FAILED   ${C_RESET}"

            local truncated_title
            truncated_title=$(truncate_string "$label" 36)

            printf "   ${C_WHITE}%02d${C_RESET}   %-36s   %b   ${C_LIGHT}%-14s${C_RESET}\n" "$idx" "$truncated_title" "$badge" "$progress"
            task_map["$idx"]="$tf"
            ((idx++))
        done

        echo -e " ${C_MUTED}──────────────────────────────────────────────────────────────────────────────${C_RESET}"
        echo -e "   ${C_DIM}Controls: ${C_WHITE}[p ID]${C_DIM} Pause • ${C_WHITE}[r ID]${C_DIM} Resume • ${C_WHITE}[c ID]${C_DIM} Cancel • ${C_WHITE}[b]${C_DIM} Home • ${C_WHITE}[Enter]${C_DIM} Sync${C_RESET}"
        read -rp "$(echo -e "   ${C_BOLD}${C_WHITE}Action › ${C_RESET}")" action_cmd

        [[ -z "$action_cmd" ]] && continue
        [[ "$action_cmd" == "b" || "$action_cmd" == "B" ]] && return 0

        local action_type arg_id
        action_type=$(echo "$action_cmd" | awk '{print $1}')
        arg_id=$(echo "$action_cmd" | awk '{print $2}')

        if [[ -n "${task_map[$arg_id]}" ]]; then
            local selected_file="${task_map[$arg_id]}"
            local selected_pid
            selected_pid=$(grep '^PID=' "$selected_file" | cut -d= -f2-)
            
            case "$action_type" in
                p|P)
                    kill -STOP "$selected_pid" 2>/dev/null && sed -i 's/^STATUS=.*/STATUS=PAUSED/' "$selected_file"
                    ;;
                r|R)
                    kill -CONT "$selected_pid" 2>/dev/null && sed -i 's/^STATUS=.*/STATUS=RUNNING/' "$selected_file"
                    ;;
                c|C)
                    pkill -P "$selected_pid" 2>/dev/null || true
                    kill -TERM "$selected_pid" 2>/dev/null || true
                    sed -i 's/^STATUS=.*/STATUS=FAILED/' "$selected_file"
                    ;;
            esac
        fi
    done
}

# ==============================================================================
# MAIN EVENT LOOP (Compact Home Dashboard - Zero Scrollbar, Zero Overlap)
# ==============================================================================
while true; do
    clear_screen_buffer
    echo -e " ${C_BOLD}${C_WHITE}󰎆 Noctalia Audio Fetcher${C_RESET} ${C_DIM}• Ingestion Pipeline${C_RESET}"
    echo -e " ${C_MUTED}──────────────────────────────────────────────────────────────────────────────${C_RESET}\n"

    CLIP_URL=$(wl-paste 2>/dev/null | grep -E "^(http|https)://" | head -n1 || echo "")
    if [[ -n "$CLIP_URL" ]]; then
        local_display_clip=$(truncate_string "$CLIP_URL" 52)
        echo -e "   ${C_DIM}󰅍 Clipboard:${C_RESET} ${C_BLUE}${local_display_clip}${C_RESET}\n"
    fi

    # Compact High-Contrast Options (Fits within any window height)
    echo -e "   ${C_BOLD}${C_WHITE}Target Modes:${C_RESET}"
    echo -e "     ${C_BLUE}[1]${C_RESET} ${C_WHITE}Single Track${C_RESET}       ${C_LIGHT}› Save to ~/Music/<Track>.mp3 [Tag: Single]${C_RESET}"
    echo -e "     ${C_YELLOW}[2]${C_RESET} ${C_WHITE}Full Album / Set${C_RESET}   ${C_LIGHT}› Auto-sanitize folder name & album tag${C_RESET}"
    echo -e "     ${C_WHITE}[3]${C_RESET} ${C_WHITE}Task Monitor${C_RESET}       ${C_LIGHT}› Background queue, Pause/Resume/Cancel jobs${C_RESET}"
    echo -e "     ${C_RED}[q]${C_RESET} ${C_LIGHT}Quit Fetcher${C_RESET}\n"
    echo -e " ${C_MUTED}──────────────────────────────────────────────────────────────────────────────${C_RESET}"

    read -rp "$(echo -e "   ${C_BOLD}${C_WHITE}Action [1/2/3/q] › ${C_RESET}")" MENU_CHOICE

    case "$MENU_CHOICE" in
        1)
            echo ""
            if [[ -n "$CLIP_URL" ]]; then
                read -rp "$(echo -e "   ${C_WHITE}Press [Enter] for clipboard URL, or paste new: ${C_RESET}")" URL_INPUT
                TARGET_URL="${URL_INPUT:-$CLIP_URL}"
            else
                read -rp "$(echo -e "   ${C_WHITE}Paste Audio URL: ${C_RESET}")" TARGET_URL
            fi
            TARGET_URL=$(echo "$TARGET_URL" | xargs)
            if [[ -n "$TARGET_URL" ]]; then
                spawn_download_job "single" "$TARGET_URL"
                manage_jobs_screen
            fi
            ;;
        2)
            echo ""
            if [[ -n "$CLIP_URL" ]]; then
                read -rp "$(echo -e "   ${C_WHITE}Press [Enter] for clipboard URL, or paste new: ${C_RESET}")" URL_INPUT
                TARGET_URL="${URL_INPUT:-$CLIP_URL}"
            else
                read -rp "$(echo -e "   ${C_WHITE}Paste Album / Playlist URL: ${C_RESET}")" TARGET_URL
            fi
            TARGET_URL=$(echo "$TARGET_URL" | xargs)
            if [[ -n "$TARGET_URL" ]]; then
                spawn_download_job "album" "$TARGET_URL"
                manage_jobs_screen
            fi
            ;;
        3)
            manage_jobs_screen
            ;;
        q|Q|exit)
            clear_screen_buffer
            exit 0
            ;;
        *)
            continue
            ;;
    esac
done
