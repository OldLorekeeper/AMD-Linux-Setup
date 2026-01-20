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
# 6. Syntax: Use Zsh native modifiers and tooling
# 8. Documentation: Start section with 'Purpose' comment block (1 line before and after). No meta or inline comments within code.
#
# ------------------------------------------------------------------------------

setopt ERR_EXIT NO_UNSET PIPE_FAIL

zmodload zsh/datetime

# ------------------------------------------------------------------------------
# 1. Configuration
# ------------------------------------------------------------------------------

# Purpose: Define sysfs path for GPU power control - hardcoded to 'card1' because dynamic enumeration proved unreliable on this specific hardware config.

GPU_SYSFS="/sys/class/drm/card1/device/power_dpm_force_performance_level"
LOG_FILE="/tmp/sunshine_gpu_boost.log"

# ------------------------------------------------------------------------------
# 2. Logic
# ------------------------------------------------------------------------------

# Purpose: Toggle GPU performance level based on argument.

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
esac

# ------------------------------------------------------------------------------
# End
# ------------------------------------------------------------------------------
