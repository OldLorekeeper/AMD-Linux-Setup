#!/bin/zsh
# ------------------------------------------------------------------------------
# 7. Utility. Sunshine HDR Switcher
# Toggles HDR, resolution, and scaling modes using kscreen-doctor.
# ------------------------------------------------------------------------------
#
# DEVELOPMENT RULES (Read before editing):
# 1. Formatting: Keep layout compact. No vertical whitespace inside blocks.
# 2. Separators: Use 'Sandwich' headers (# ------) with strict spacing (1 line before, 0 lines after).
# 3. Idempotency: Scripts must be safe to re-run. Check state before changes.
# 4. Safety: Use 'setopt ERR_EXIT NO_UNSET PIPE_FAIL'.
# 5. Context: Hardcoded for AMD Ryzen 7000/Radeon 7000. No hardcoded secrets.
# 6. Syntax: Use Zsh native modifiers (e.g. ${VAR:h}) over subshells.
# 7. Output: Use 'print'. Do NOT use 'echo'.
# 8. Documentation: Precede sections with 'Purpose'/'Rationale'. No meta-comments inside code blocks.
#
# ------------------------------------------------------------------------------

setopt ERR_EXIT NO_UNSET PIPE_FAIL

# ------------------------------------------------------------------------------
# 1. Configuration
# ------------------------------------------------------------------------------

# Purpose: Define target monitor and mode indices.
# Note: These values are updated programmatically by sunshine_configure.zsh.

MONITOR="DP-2"
STREAM_MODE="8"
DEFAULT_MODE="1"

# ------------------------------------------------------------------------------
# 2. Logic
# ------------------------------------------------------------------------------

# Purpose: Toggle HDR and display settings via kscreen-doctor.

case "$1" in
    enable)
        kscreen-doctor output.$MONITOR.mode.$STREAM_MODE output.$MONITOR.hdr.enable output.$MONITOR.scale.1.2
        ;;
    disable)
        kscreen-doctor output.$MONITOR.hdr.disable output.$MONITOR.mode.$DEFAULT_MODE output.$MONITOR.scale.1.0
        ;;
esac

# ------------------------------------------------------------------------------
# End
# ------------------------------------------------------------------------------
