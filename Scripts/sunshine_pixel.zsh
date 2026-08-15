#!/bin/zsh
# ------------------------------------------------------------------------------
# 5. Utility. Sunshine Resolution Switcher (Pixel)
# Toggles resolution and scaling modes using kscreen-doctor for Pixel streaming.
# ------------------------------------------------------------------------------

# region Init
setopt ERR_EXIT NO_UNSET PIPE_FAIL EXTENDED_GLOB
SCRIPT_DIR=${0:a:h}
print -P "\n%K{green}%F{black} STARTING PIXEL RES SWITCHER %k%f\n"
# endregion

# ------------------------------------------------------------------------------
# 1. Configuration
# ------------------------------------------------------------------------------

# Purpose: Define target monitor and mode indices for the Pixel device.

# region 1. Configuration
print -P "%K{blue}%F{black} 1. CONFIGURATION %k%f\n"
MONITOR="DP-2"
# Note: Since 20:9 is not natively available, 1600x900 is the closest "Goldilocks" 
# equivalent for UI scale. It will have small black bars (16:9 aspect ratio)
# Alternatively, use 48 for 1920x1080@143.80Hz (smaller UI).
STREAM_MODE="14"
DEFAULT_MODE="1"
print -P "Monitor: %F{cyan}$MONITOR%f"
print -P "Stream Mode: %F{cyan}$STREAM_MODE%f"
print -P "Default Mode: %F{cyan}$DEFAULT_MODE%f"
# endregion

# ------------------------------------------------------------------------------
# 2. Logic
# ------------------------------------------------------------------------------

# Purpose: Toggle display settings via kscreen-doctor.

# region 2. Logic
print -P "\n%K{blue}%F{black} 2. LOGIC %k%f\n"
case "$1" in
    enable)
        kscreen-doctor output.$MONITOR.mode.$STREAM_MODE output.$MONITOR.scale.1.50
        print -P "Status: %F{green}Pixel Mode Enabled (Scale 1.0)%f"
        ;;
    disable)
        kscreen-doctor output.$MONITOR.mode.$DEFAULT_MODE output.$MONITOR.scale.1.0
        print -P "Status: %F{green}Pixel Mode Disabled (Scale 1.0)%f"
        ;;
    *)
        print -P "%F{red}Error: Invalid argument. Use 'enable' or 'disable'.%f"
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
