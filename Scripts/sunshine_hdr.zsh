#!/bin/zsh
# ------------------------------------------------------------------------------
# 7. Utility. Sunshine HDR Switcher
# Toggles HDR, resolution, and scaling modes using kscreen-doctor.
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

SCRIPT_DIR=${0:a:h}

print -P "\n%K{green}%F{black} STARTING HDR SWITCHER %k%f\n"

# ------------------------------------------------------------------------------
# 1. Configuration
# ------------------------------------------------------------------------------

# Purpose: Define target monitor and mode indices. Note: Updated programmatically.

print -P "\n%K{blue}%F{black} 1. CONFIGURATION %k%f\n"
MONITOR="DP-2"
STREAM_MODE="8"
DEFAULT_MODE="1"

print -P "Monitor: %F{cyan}$MONITOR%f"
print -P "Stream Mode: %F{cyan}$STREAM_MODE%f"
print -P "Default Mode: %F{cyan}$DEFAULT_MODE%f"

# ------------------------------------------------------------------------------
# 2. Logic
# ------------------------------------------------------------------------------

# Purpose: Toggle HDR and display settings via kscreen-doctor.

print -P "\n%K{blue}%F{black} 2. LOGIC %k%f\n"
case "$1" in
    enable)
        kscreen-doctor output.$MONITOR.mode.$STREAM_MODE output.$MONITOR.hdr.enable output.$MONITOR.scale.1.2
        print -P "Status: %F{green}HDR Enabled (Scale 1.2)%f"
        ;;
    disable)
        kscreen-doctor output.$MONITOR.hdr.disable output.$MONITOR.mode.$DEFAULT_MODE output.$MONITOR.scale.1.0
        print -P "Status: %F{green}HDR Disabled (Scale 1.0)%f"
        ;;
    *)
        print -P "%F{red}Error: Invalid argument. Use 'enable' or 'disable'.%f"
        exit 1
        ;;
esac

# ------------------------------------------------------------------------------
# End
# ------------------------------------------------------------------------------

print -P "\n%K{green}%F{black} PROCESS COMPLETE %k%f\n"
