#!/bin/zsh
# ------------------------------------------------------------------------------
# 4. Utility. Sunshine GPU Boost
# Forces AMD RX 7900 XT into high performance mode during Sunshine streaming.
# ------------------------------------------------------------------------------
#
# DEVELOPMENT RULES:
#
# 1. Safety: `setopt ERR_EXIT NO_UNSET PIPE_FAIL EXTENDED_GLOB`.
# 2. Syntax: Native Zsh modifiers (e.g. ${VAR:t}).
# 3. Heredocs: Use language ID (e.g. <<ZSH, <<INI), unique IDs for nesting, and quote 'ID' to disable expansion.
# 4. Structure:
#    a) Sandwich numbered section separators (# ------) with 1 line padding before.
#    b) Purpose comment block (1 line padding) at start of every numbered section summarising code.
#    c) No inline/meta comments. Compact vertical layout (minimise blank lines)
#    d) Retain frequent context info markers (%F{cyan}) inside dense logic blocks to prevent 'frozen' UI state.
#    e) Code wrapped in '# BEGIN' and '# END' markers.
#    f) Kate modeline at EOF.
# 5. Idempotency: Re-runnable scripts. Check state before changes.
# 6. UI Hierarchy Print -P
#    a) Process marker:          Green Block (%K{green}%F{black}). Used at Start/End.
#    b) Section marker:          Blue Block  (%K{blue}%F{black}). Numbered.
#    c) Sub-section marker:      Yellow Block (%K{yellow}%F{black}).
#    d) Interaction:             Yellow description (%F{yellow}) + minimal `read` prompt.
#    e) Context/Status:          Cyan (Info ℹ), Green (Success), Red (Error/Warning).
#    f) Marker spacing:          i)  Use `\n...%k%f\n`.
#                                ii) Omit top `\n` on consecutive markers.
#                                ii) Context (Cyan) markers MUST include a trailing `\n`.
#
# ------------------------------------------------------------------------------

# BEGIN
setopt ERR_EXIT NO_UNSET PIPE_FAIL EXTENDED_GLOB
zmodload zsh/datetime
SCRIPT_DIR=${0:a:h}
print -P "\n%K{green}%F{black} STARTING GPU BOOST %k%f\n"
# END

# ------------------------------------------------------------------------------
# 1. Configuration
# ------------------------------------------------------------------------------

# Purpose: Define sysfs path for GPU power control.

# BEGIN
print -P "%K{blue}%F{black} 1. CONFIGURATION %k%f\n"
GPU_SYSFS="/sys/class/drm/card1/device/power_dpm_force_performance_level"
LOG_FILE="/tmp/sunshine_gpu_boost.log"
print -P "Target: %F{cyan}$GPU_SYSFS%f"
# END

# ------------------------------------------------------------------------------
# 2. Logic
# ------------------------------------------------------------------------------

# Purpose: Toggle GPU performance level based on argument.

# BEGIN
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
# END

# ------------------------------------------------------------------------------
# End
# ------------------------------------------------------------------------------

# BEGIN
print -P "\n%K{green}%F{black} PROCESS COMPLETE %k%f\n"
# END

# kate: hl Zsh; folding-markers on;
