#!/bin/zsh
# ------------------------------------------------------------------------------
# 6. Utility. Sunshine Resolution Switcher (Laptop)
# Toggles resolution and specific scaling (1.2) for remote laptop clients.
# ------------------------------------------------------------------------------

# region Init
setopt ERR_EXIT NO_UNSET PIPE_FAIL EXTENDED_GLOB
SCRIPT_DIR=${0:a:h}
print -P "\n%K{green}%F{black} STARTING LAPTOP RES SWITCHER %k%f\n"
# endregion

# ------------------------------------------------------------------------------
# 1. Configuration
# ------------------------------------------------------------------------------

# Purpose: Define target monitor and mode indices. Note: Updated programmatically.

# region 1. Configuration
print -P "%K{blue}%F{black} 1. CONFIGURATION %k%f\n"
MONITOR="DP-2"
STREAM_MODE="6"
DEFAULT_MODE="1"
print -P "Monitor: %F{cyan}$MONITOR%f"
print -P "Stream Mode: %F{cyan}$STREAM_MODE%f"
print -P "Default Mode: %F{cyan}$DEFAULT_MODE%f"
# endregion

# ------------------------------------------------------------------------------
# 2. Logic
# ------------------------------------------------------------------------------

# Purpose: Toggle display settings via kscreen-doctor with 1.2 scaling.

# region 2. Logic
print -P "\n%K{blue}%F{black} 2. LOGIC %k%f\n"
case "$1" in
    enable)
        kscreen-doctor output.$MONITOR.mode.$STREAM_MODE output.$MONITOR.scale.1.2
        print -P "Status: %F{green}Laptop Mode Enabled (Scale 1.2)%f"
        ;;
    disable)
        kscreen-doctor output.$MONITOR.mode.$DEFAULT_MODE output.$MONITOR.scale.1.0
        print -P "Status: %F{green}Laptop Mode Disabled (Scale 1.0)%f"
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
