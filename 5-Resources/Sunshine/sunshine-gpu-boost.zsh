#!/bin/zsh
# ------------------------------------------------------------------------------
# Sunshine GPU Boost (AMD Power DPM)
# ------------------------------------------------------------------------------

setopt ERR_EXIT
setopt NO_UNSET
setopt PIPE_FAIL

# Dynamic Detection: Find the card path for the RX 7900 XT (Navi 31)
# 0x744c = 7900 XT
CARD_PATH=$(grep -lE "0x744(c|d)" /sys/class/drm/card*/device/device 2>/dev/null | head -n 1)

if [[ -z "$CARD_PATH" ]]; then
    print -u2 "Error: AMD RX 7900 XT not found."
    exit 1
fi

# Construct Sysfs Path (strip /device/device, append power path)
GPU_SYSFS="${CARD_PATH%/device/device}/device/power_dpm_force_performance_level"
LOG_FILE="/tmp/sunshine_gpu_boost.log"

# ------------------------------------------------------------------------------
# ------------------------------------------------------------------------------

# Validation
if [[ ! -w "$GPU_SYSFS" ]]; then
    print -u2 "Error: Cannot write to $GPU_SYSFS. Check permissions/card ID."
    exit 1
fi

# Logic
case "$1" in
    start)
        print "high" > "$GPU_SYSFS"
        print "[$(date)] GPU set to HIGH performance ($GPU_SYSFS)" >> "$LOG_FILE"
        ;;
    stop)
        print "auto" > "$GPU_SYSFS"
        print "[$(date)] GPU set to AUTO performance ($GPU_SYSFS)" >> "$LOG_FILE"
        ;;
    *)
        print "Usage: $0 {start|stop}"
        exit 1
        ;;
esac
