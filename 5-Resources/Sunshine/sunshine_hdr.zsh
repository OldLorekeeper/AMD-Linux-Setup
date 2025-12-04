#!/bin/zsh
# ------------------------------------------------------------------------------
# Sunshine HDR & Resolution Switcher
# Toggles HDR, resolution, and scaling modes using kscreen-doctor.
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

# Configuration (Targeted by configure_sunshine.zsh - Do NOT change variable names)
MONITOR="DP-2"
STREAM_MODE="7"
DEFAULT_MODE="1"

# ------------------------------------------------------------------------------
# ------------------------------------------------------------------------------

case "$1" in
    enable)
        # Set Stream Mode, Enable HDR and Scale to 120%
        kscreen-doctor output.$MONITOR.mode.$STREAM_MODE output.$MONITOR.hdr.enable output.$MONITOR.scale.1.2
        ;;
    disable)
        # Disable HDR, Revert Mode and Scale to 100%
        kscreen-doctor output.$MONITOR.hdr.disable output.$MONITOR.mode.$DEFAULT_MODE output.$MONITOR.scale.1.0
        ;;
    *)
        exit 1
        ;;
esac
