#!/bin/zsh
# ------------------------------------------------------------------------------
# 5. Utility. Sunshine Resolution Switcher (SDR)
# Toggles resolution and scaling modes using kscreen-doctor (No HDR).
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

# Purpose: Toggle display settings via kscreen-doctor.

case "$1" in
    enable)
        kscreen-doctor output.$MONITOR.mode.$STREAM_MODE output.$MONITOR.scale.1.0
        ;;
    disable)
        kscreen-doctor output.$MONITOR.mode.$DEFAULT_MODE output.$MONITOR.scale.1.0
        ;;
esac

# ------------------------------------------------------------------------------
# End
# ------------------------------------------------------------------------------
