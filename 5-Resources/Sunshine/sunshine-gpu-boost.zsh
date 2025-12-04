#!/bin/zsh
# ------------------------------------------------------------------------------
# Sunshine GPU Boost (AMD Power DPM)
# ------------------------------------------------------------------------------

setopt ERR_EXIT
setopt NO_UNSET
setopt PIPE_FAIL

# Configuration
GPU_SYSFS="/sys/class/drm/card1/device/power_dpm_force_performance_level"
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
        print "[$(date)] GPU set to HIGH performance" >> "$LOG_FILE"
        ;;
    stop)
        print "auto" > "$GPU_SYSFS"
        print "[$(date)] GPU set to AUTO performance" >> "$LOG_FILE"
        ;;
    *)
        print "Usage: $0 {start|stop}"
        exit 1
        ;;
esac
