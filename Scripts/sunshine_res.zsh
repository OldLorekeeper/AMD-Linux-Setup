#!/bin/zsh
# ------------------------------------------------------------------------------
# Sunshine Resolution Switcher (No HDR)
# Toggles resolution and scaling modes using kscreen-doctor (SDR only).
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
STREAM_MODE="8"
DEFAULT_MODE="1"

# ------------------------------------------------------------------------------
# ------------------------------------------------------------------------------

case "$1" in
    enable)
        # Set Stream Mode and Scale (Adjust scale if needed, e.g., 1.0 or 1.2)
        kscreen-doctor output.$MONITOR.mode.$STREAM_MODE output.$MONITOR.scale.1.0
        ;;
    disable)
        # Revert Mode and Scale
        kscreen-doctor output.$MONITOR.mode.$DEFAULT_MODE output.$MONITOR.scale.1.0
        ;;
    *)
        exit 1
        ;;
esac
