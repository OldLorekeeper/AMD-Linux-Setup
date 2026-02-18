#!/bin/zsh
# ------------------------------------------------------------------------------
# 4. Utility. Sunshine GPU Boost
# Forces AMD RX 7900 XT into high performance mode during Sunshine streaming.
# ------------------------------------------------------------------------------

# region Init
setopt ERR_EXIT NO_UNSET PIPE_FAIL EXTENDED_GLOB
zmodload zsh/datetime
SCRIPT_DIR=${0:a:h}
print -P "\n%K{green}%F{black} STARTING GPU BOOST %k%f\n"
# endregion

# ------------------------------------------------------------------------------
# 1. Configuration
# ------------------------------------------------------------------------------

# Purpose: Define sysfs path for GPU power control.

# region 1. Configuration
print -P "%K{blue}%F{black} 1. CONFIGURATION %k%f\n"
GPU_SYSFS="/sys/class/drm/card1/device/power_dpm_force_performance_level"
LOG_FILE="/tmp/sunshine_gpu_boost.log"
print -P "Target: %F{cyan}$GPU_SYSFS%f"
# endregion

# ------------------------------------------------------------------------------
# 2. Logic
# ------------------------------------------------------------------------------

# Purpose: Toggle GPU performance level based on argument.

# region 2. Logic
print -P "\n%K{blue}%F{black} 2. LOGIC %k%f\n"
strftime -s DATE_STR '%Y-%m-%d %H:%M:%S' $EPOCHSECONDS
case "$1" in
    start)
        print "high" > "$GPU_SYSFS"
        print "[$DATE_STR] GPU set to HIGH performance ($GPU_SYSFS)" >> "$LOG_FILE"
        print -P "Mode: %F{green}High Performance%f"
        ;;
    stop)
        print "auto" > "$GPU_SYSFS"
        print "[$DATE_STR] GPU set to AUTO performance ($GPU_SYSFS)" >> "$LOG_FILE"
        print -P "Mode: %F{green}Auto%f"
        ;;
    *)
        print -P "%F{red}Error: Invalid argument. Use 'start' or 'stop'.%f"
        exit 1
        ;;
esac
# endregion

# ------------------------------------------------------------------------------
# End
# ------------------------------------------------------------------------------

# region End
print -P "\n%K{green}%F{black} PROCESS COMPLETE %k%f\n"
# endregion
