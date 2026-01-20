#!/bin/zsh
# ------------------------------------------------------------------------------
# 3. Utility. Sunshine HDR/Resolution Configurator
# Updates monitor and mode settings in local Sunshine helper scripts.
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
# 1. Paths
# ------------------------------------------------------------------------------

# Purpose: Locate target scripts relative to this script.

SCRIPT_DIR=${0:a:h}
HDR_SCRIPT="$SCRIPT_DIR/sunshine_hdr.zsh"
RES_SCRIPT="$SCRIPT_DIR/sunshine_res.zsh"
LAPTOP_SCRIPT="$SCRIPT_DIR/sunshine_laptop.zsh"
if [[ ! -f "$HDR_SCRIPT" || ! -f "$RES_SCRIPT" || ! -f "$LAPTOP_SCRIPT" ]]; then
    print -P "%F{red}Error: Target Sunshine scripts not found in $SCRIPT_DIR%f"
    exit 1
fi

# ------------------------------------------------------------------------------
# 2. Input
# ------------------------------------------------------------------------------

# Purpose: Gather monitor configuration from user.

print -P "%F{yellow}Current Output Configuration:%f"
kscreen-doctor -o
print ""
print "Enter the details for your configuration:"
read "MON_ID?1. Monitor ID (e.g. DP-1, HDMI-A-1): "
read "STREAM_IDX?2. Target Streaming Mode Index (e.g. 9): "
read "DEFAULT_IDX?3. Default Desktop Mode Index (e.g. 1): "

# ------------------------------------------------------------------------------
# 3. Configuration
# ------------------------------------------------------------------------------

# Purpose: Apply variables to target scripts using sed.

if [[ -n "$MON_ID" && -n "$STREAM_IDX" && -n "$DEFAULT_IDX" ]]; then
    print -P "\n%F{green}Applying settings...%f"
    for file in "$HDR_SCRIPT" "$RES_SCRIPT" "$LAPTOP_SCRIPT"; do
        sed -i 's/^MONITOR=.*/MONITOR="'"$MON_ID"'"/' "$file"
        sed -i 's/^STREAM_MODE=.*/STREAM_MODE="'"$STREAM_IDX"'"/' "$file"
        sed -i 's/^DEFAULT_MODE=.*/DEFAULT_MODE="'"$DEFAULT_IDX"'"/' "$file"
        print "Updated: ${file:t}"
    done
    print -P "%F{green}Configuration complete.%f"
else
    print -P "%F{red}Error: Missing input.%f"
    exit 1
fi

# ------------------------------------------------------------------------------
# End
# ------------------------------------------------------------------------------
