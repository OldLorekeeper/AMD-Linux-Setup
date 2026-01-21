#!/bin/zsh
# ------------------------------------------------------------------------------
# 4. Utility. Sunshine GPU Boost
# Forces AMD RX 7900 XT into high performance mode during Sunshine streaming.
# ------------------------------------------------------------------------------
#
# DEVELOPMENT RULES (Read before editing):
# 1. Formatting: Keep layout compact. No vertical whitespace inside blocks.
# 2. Separators: Use 'Sandwich' headers (# ------) with strict spacing (1 line before).
# 3. Idempotency: Scripts must be safe to re-run. Check state before changes.
# 4. Safety: Use 'setopt ERR_EXIT NO_UNSET PIPE_FAIL'.
# 5. Context: No hardcoded secrets.
# 6. Syntax: Use Zsh native modifiers and tooling.
# 7. Documentation: Start section with 'Purpose' comment block (1 line before and after). No meta or inline comments within code.
# 8. UI & Theming:
#    - Headers: Blue (%K{blue}%F{black}) for sections, Yellow (%K{yellow}%F{black}) for sub-sections.
#    - Spacing: One empty line before and after headers. Use embedded \n to save lines.
#      * Exception: If a header follows another header immediately, omit the leading \n to avoid double gaps.
#    - Inputs: Yellow description line (%F{yellow}) followed by minimal prompt (read "VAR?Prompt: ").
#    - Context: Cyan (%F{cyan}) for info/metadata (prefixed with ℹ).
#    - Status: Green (%F{green}) for success/loaded, Red (%F{red}) for errors/warnings.
#    - Silence: Do not repeat/confirm manual user input. Only print confirmation (%F{green}) if the value was pre-loaded from secrets.
#
# ------------------------------------------------------------------------------

setopt ERR_EXIT NO_UNSET PIPE_FAIL

zmodload zsh/datetime
SCRIPT_DIR=${0:a:h}

print -P "\n%K{green}%F{black} STARTING GPU BOOST %k%f\n"

# ------------------------------------------------------------------------------
# 1. Configuration
# ------------------------------------------------------------------------------

# Purpose: Define sysfs path for GPU power control.

print -P "\n%K{blue}%F{black} 1. CONFIGURATION %k%f\n"
GPU_SYSFS="/sys/class/drm/card1/device/power_dpm_force_performance_level"
LOG_FILE="/tmp/sunshine_gpu_boost.log"
print -P "Target: %F{cyan}$GPU_SYSFS%f"

# ------------------------------------------------------------------------------
# 2. Logic
# ------------------------------------------------------------------------------

# Purpose: Toggle GPU performance level based on argument.

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

# ------------------------------------------------------------------------------
# End
# ------------------------------------------------------------------------------

print -P "\n%K{green}%F{black} PROCESS COMPLETE %k%f\n"
