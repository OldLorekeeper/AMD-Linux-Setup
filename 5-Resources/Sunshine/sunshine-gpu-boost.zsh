#!/bin/zsh
# ------------------------------------------------------------------------------
# Sunshine GPU Boost (AMD Power DPM)
# Forces AMD RX 7900 XT into high performance mode during Sunshine streaming.
# ------------------------------------------------------------------------------
#
# DEVELOPMENT RULES (Read before editing):
# 1. Formatting: Keep layout compact. No vertical whitespace inside blocks.
# 2. Separators: Use double dotted lines (# ------) for major sections.
# 3. Idempotency: Scripts must be safe to re-run. Check state before changes.
# 4. Safety: Use 'setopt ERR_EXIT NO_UNSET PIPE_FAIL'.
# 5. Context: Hardcoded for AMD Ryzen 7000/Radeon 7000. No hardcoded secrets.
# 6. Syntax: Use Zsh native modifiers (e.g. ${VAR:h}) over subshells.
# 7. Output: Use 'print'. Do NOT use 'echo'.
#
# ------------------------------------------------------------------------------

# Safety Options
setopt ERR_EXIT     # Exit on error
setopt NO_UNSET     # Error on unset variables
setopt PIPE_FAIL    # Fail if any part of a pipe fails

# Load Colours
autoload -Uz colors && colors
GREEN="${fg[green]}"
YELLOW="${fg[yellow]}"
RED="${fg[red]}"
NC="${reset_color}"

# Load Date Module
zmodload zsh/datetime

# Dynamic Detection: Find the card path for the RX 7900 XT (Navi 31)
# 0x744c = 7900 XT, 0x744d = 7900 XTX (Cover both variants)
CARD_PATH=$(grep -lE "0x744(c|d)" /sys/class/drm/card*/device/device 2>/dev/null | head -n 1)

if [[ -z "$CARD_PATH" ]]; then
    print "${RED}Error: AMD RX 7900 XT/XTX not found.${NC}"
    exit 1
fi

# Construct Sysfs Path (strip /device/device, append power path)
GPU_SYSFS="${CARD_PATH%/device/device}/device/power_dpm_force_performance_level"
LOG_FILE="/tmp/sunshine_gpu_boost.log"

# ------------------------------------------------------------------------------
# ------------------------------------------------------------------------------

# Validation
if [[ ! -w "$GPU_SYSFS" ]]; then
    print "${RED}Error: Cannot write to $GPU_SYSFS. Check permissions/card ID.${NC}"
    exit 1
fi

# Logic
strftime -s DATE_STR '%Y-%m-%d %H:%M:%S' $EPOCHSECONDS

case "$1" in
    start)
        print "high" > "$GPU_SYSFS"
        print "[$DATE_STR] GPU set to HIGH performance ($GPU_SYSFS)" >> "$LOG_FILE"
        ;;
    stop)
        print "auto" > "$GPU_SYSFS"
        print "[$DATE_STR] GPU set to AUTO performance ($GPU_SYSFS)" >> "$LOG_FILE"
        ;;
    *)
        print "Usage: $0 {start|stop}"
        exit 1
        ;;
esac
