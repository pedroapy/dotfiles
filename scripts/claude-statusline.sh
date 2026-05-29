#!/bin/bash
export LC_NUMERIC=C
input=$(cat)

MODEL=$(echo "$input" | jq -r '.model.display_name')
DIR=$(echo "$input" | jq -r '.workspace.current_dir')
PCT=$(echo "$input" | jq -r '.context_window.used_percentage // 0' | cut -d. -f1)
COST=$(echo "$input" | jq -r '.cost.total_cost_usd // 0')
COST_FMT=$(printf '$%.4f' "$COST")

# Rate limits (Pro/Max only)
RL5H=$(echo "$input" | jq -r '.rate_limits.five_hour.used_percentage // empty' | cut -d. -f1)
RL5H_RESET=$(echo "$input" | jq -r '.rate_limits.five_hour.resets_at // empty')
RL7D=$(echo "$input" | jq -r '.rate_limits.seven_day.used_percentage // empty' | cut -d. -f1)
RL7D_RESET=$(echo "$input" | jq -r '.rate_limits.seven_day.resets_at // empty')

# Function to convert epoch to remaining time
time_remaining() {
    local reset_epoch="$1"
    local now=$(date +%s)
    local diff=$((reset_epoch - now))
    [ "$diff" -le 0 ] && echo "now" && return
    local h=$((diff / 3600))
    local m=$(((diff % 3600) / 60))
    local d=$((diff / 86400))
    if [ "$d" -gt 0 ] && [ "$2" = "days" ]; then
        local remaining_h=$(((diff % 86400) / 3600))
        echo "${d}d${remaining_h}h"
    elif [ "$h" -gt 0 ]; then
        echo "${h}h${m}m"
    else
        echo "${m}m"
    fi
}

# Lines added/removed
LINES_ADD=$(echo "$input" | jq -r '.cost.total_lines_added // 0')
LINES_DEL=$(echo "$input" | jq -r '.cost.total_lines_removed // 0')

# Session duration
DURATION_MS=$(echo "$input" | jq -r '.cost.total_duration_ms // 0')
DURATION_S=$((DURATION_MS / 1000))
MINS=$((DURATION_S / 60))
SECS=$((DURATION_S % 60))

GREEN='\033[32m'
YELLOW='\033[33m'
RED='\033[31m'
CYAN='\033[36m'
MAGENTA='\033[1;35m'
RESET='\033[0m'

# Session metrics from transcript: cache hit %, turns, files touched, errors.
# (cached 3s; transcript_path comes in the statusline stdin)
TRANSCRIPT=$(echo "$input" | jq -r '.transcript_path // empty')
SESSION=$(echo "$input" | jq -r '.session_id // "x"')
CACHE_PCT=""; TRN=0; FIL=0; ERR=0
if [ -n "$TRANSCRIPT" ] && [ -f "$TRANSCRIPT" ]; then
    MCACHE="/tmp/statusline-metrics-${SESSION}"
    if [ ! -f "$MCACHE" ] || [ $(($(date +%s) - $(stat -f %m "$MCACHE" 2>/dev/null || stat -c %Y "$MCACHE" 2>/dev/null || echo 0))) -gt 3 ]; then
        jq -nr '
          reduce inputs as $l (
            {trn:0, fil:{}, err:0, cr:0, cc:0, it:0};
            if $l.type=="assistant" then
              .trn += 1
              | (if $l.message.usage then
                   .cr = ($l.message.usage.cache_read_input_tokens // 0)
                   | .cc = ($l.message.usage.cache_creation_input_tokens // 0)
                   | .it = ($l.message.usage.input_tokens // 0)
                 else . end)
              | reduce ($l.message.content[]? | select(.type=="tool_use" and (.name|test("Edit|Write"))) | .input.file_path // empty) as $f (.; .fil[$f]=true)
            elif $l.type=="user" then
              .err += ([ $l.message.content[]? | select(type=="object" and .type=="tool_result" and .is_error==true) ] | length)
            else . end
          )
          | (.cr + .cc + .it) as $tot
          | "\(if $tot>0 then (.cr*100/$tot|floor) else -1 end)|\(.trn)|\(.fil|length)|\(.err)"
        ' "$TRANSCRIPT" > "$MCACHE" 2>/dev/null
    fi
    IFS='|' read -r CPCT TRN FIL ERR < "$MCACHE"
    [ "${CPCT:-(-1)}" -ge 0 ] 2>/dev/null && CACHE_PCT="$CPCT"
fi
: "${TRN:=0}" "${FIL:=0}" "${ERR:=0}"

# Cache hit color: más alto = mejor (más barato)
if [ -n "$CACHE_PCT" ]; then
    if [ "$CACHE_PCT" -ge 70 ]; then CACHE_COLOR="$GREEN"
    elif [ "$CACHE_PCT" -ge 40 ]; then CACHE_COLOR="$YELLOW"
    else CACHE_COLOR="$RED"; fi
fi

# Cost color: verde barato → amarillo → rojo
COST_TIER=$(awk -v c="$COST" 'BEGIN{ c+=0; if(c<1)print 0; else if(c<5)print 1; else print 2 }')
case "$COST_TIER" in 0) COST_COLOR="$GREEN";; 1) COST_COLOR="$YELLOW";; *) COST_COLOR="$RED";; esac

# Color-coded progress bar based on usage
if [ "$PCT" -ge 90 ]; then BAR_COLOR="$RED"
elif [ "$PCT" -ge 70 ]; then BAR_COLOR="$YELLOW"
else BAR_COLOR="$GREEN"; fi

BAR_WIDTH=10
FILLED=$((PCT * BAR_WIDTH / 100))
EMPTY=$((BAR_WIDTH - FILLED))
BAR=""
[ "$FILLED" -gt 0 ] && printf -v FILL "%${FILLED}s" && BAR="${FILL// /▓}"
[ "$EMPTY" -gt 0 ] && printf -v PAD "%${EMPTY}s" && BAR="${BAR}${PAD// /░}"

# Line 1: model, context bar (+aviso compactación), cache hit, cost, duration, lines changed
L1="[${MAGENTA}${MODEL}${RESET}] | ${BAR_COLOR}${BAR}${RESET} ${PCT}%"
[ "$PCT" -ge 80 ] && L1="${L1} ${RED}⚠compact${RESET}"
[ -n "$CACHE_PCT" ] && L1="${L1} | ${CACHE_COLOR}⇄${CACHE_PCT}%${RESET}"
L1="${L1} | ${COST_COLOR}${COST_FMT}${RESET} | ${MINS}m${SECS}s | ${GREEN}+${LINES_ADD}${RESET}/${RED}-${LINES_DEL}${RESET}"
echo -e "$L1"

# Line 2: rate limits (only if available)
if [ -n "$RL5H" ] || [ -n "$RL7D" ]; then
    RL_INFO=""
    if [ -n "$RL5H" ]; then
        if [ "$RL5H" -ge 90 ]; then RL5_COLOR="$RED"
        elif [ "$RL5H" -ge 70 ]; then RL5_COLOR="$YELLOW"
        else RL5_COLOR="$GREEN"; fi
        RL5_TTR=""
        [ -n "$RL5H_RESET" ] && RL5_TTR=" $(time_remaining "$RL5H_RESET")"
        RL_INFO="${RL5_COLOR}5h:${RL5H}%${RL5_TTR}${RESET}"
    fi
    if [ -n "$RL7D" ]; then
        if [ "$RL7D" -ge 90 ]; then RL7_COLOR="$RED"
        elif [ "$RL7D" -ge 70 ]; then RL7_COLOR="$YELLOW"
        else RL7_COLOR="$GREEN"; fi
        RL7_TTR=""
        [ -n "$RL7D_RESET" ] && RL7_TTR=" $(time_remaining "$RL7D_RESET" days)"
        [ -n "$RL_INFO" ] && RL_INFO="${RL_INFO} | "
        RL_INFO="${RL_INFO}${RL7_COLOR}7d:${RL7D}%${RL7_TTR}${RESET}"
    fi
    echo -e "Rate: ${RL_INFO}"
fi

# Line 3: directory and git info (cached)
CACHE_FILE="/tmp/statusline-git-cache"
CACHE_MAX_AGE=10

cache_is_stale() {
    [ ! -f "$CACHE_FILE" ] || \
    [ $(($(date +%s) - $(stat -f %m "$CACHE_FILE" 2>/dev/null || stat -c %Y "$CACHE_FILE" 2>/dev/null || echo 0))) -gt $CACHE_MAX_AGE ]
}

if cache_is_stale; then
    if git rev-parse --git-dir > /dev/null 2>&1; then
        BRANCH=$(git branch --show-current 2>/dev/null)
        STAGED=$(git diff --cached --numstat 2>/dev/null | wc -l | tr -d ' ')
        MODIFIED=$(git diff --numstat 2>/dev/null | wc -l | tr -d ' ')

        GIT_STATUS=""
        [ "$STAGED" -gt 0 ] && GIT_STATUS="${GREEN}+${STAGED}${RESET}"
        [ "$MODIFIED" -gt 0 ] && GIT_STATUS="${GIT_STATUS}${YELLOW}~${MODIFIED}${RESET}"
        echo "$BRANCH|$GIT_STATUS" > "$CACHE_FILE"
    else
        echo "|" > "$CACHE_FILE"
    fi
fi

IFS='|' read -r BRANCH GIT_STATUS < "$CACHE_FILE"

# Session counters: turnos, archivos tocados, errores
if [ "$ERR" -gt 0 ] 2>/dev/null; then ERR_FMT="${RED}E${ERR}${RESET}"; else ERR_FMT="${GREEN}E0${RESET}"; fi
COUNTS="${CYAN}T${TRN}${RESET} ${CYAN}F${FIL}${RESET} ${ERR_FMT}"

if [ -n "$BRANCH" ]; then
    echo -e "📁 ${DIR##*/} | 🌿 $BRANCH $GIT_STATUS | $COUNTS"
else
    echo -e "📁 ${DIR##*/} | $COUNTS"
fi