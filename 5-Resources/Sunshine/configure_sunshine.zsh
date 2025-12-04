#!/bin/zsh
# ------------------------------------------------------------------------------
# Sunshine HDR/Resolution Configurator
# Updates monitor and mode settings in local Sunshine helper scripts.
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

# Load Colours
autoload -Uz colors && colors
GREEN="${fg[green]}"
YELLOW="${fg[yellow]}"
RED="${fg[red]}"
NC="${reset_color}"

# Path Resolution
# SCRIPT_DIR is the directory where this script resides (5-Resources/Sunshine)
SCRIPT_DIR=${0:a:h}
HDR_SCRIPT="$SCRIPT_DIR/sunshine_hdr.zsh"
RES_SCRIPT="$SCRIPT_DIR/sunshine_res.zsh"

print "${GREEN}--- Sunshine Configuration Helper ---${NC}"

# ------------------------------------------------------------------------------
# ------------------------------------------------------------------------------

# 1. Prerequisite Checks
if ! (( $+commands[kscreen-doctor] )); then
    print "${RED}Error: kscreen-doctor is not installed. Cannot detect displays.${NC}"
    exit 1
fi

if [[ ! -f "$HDR_SCRIPT" || ! -f "$RES_SCRIPT" ]]; then
    print "${RED}Error: Target Sunshine scripts not found in $SCRIPT_DIR${NC}"
    exit 1
fi

# ------------------------------------------------------------------------------
# ------------------------------------------------------------------------------

# 2. Display Info & Gather Input
print "${YELLOW}Current Output Configuration:${NC}"
kscreen-doctor -o
print ""

print "Enter the details for your configuration:"
read "MON_ID?1. Monitor ID (e.g. DP-1, HDMI-A-1): "
read "STREAM_IDX?2. Target Streaming Mode Index (e.g. 9): "
read "DEFAULT_IDX?3. Default Desktop Mode Index (e.g. 1): "

# ------------------------------------------------------------------------------
# ------------------------------------------------------------------------------

# 3. Apply Configuration
if [[ -n "$MON_ID" && -n "$STREAM_IDX" && -n "$DEFAULT_IDX" ]]; then
    print "\n${GREEN}Applying settings...${NC}"
    for file in "$HDR_SCRIPT" "$RES_SCRIPT"; do
        sed -i 's/^MONITOR=.*/MONITOR="'"$MON_ID"'"/' "$file"
        sed -i 's/^STREAM_MODE=.*/STREAM_MODE="'"$STREAM_IDX"'"/' "$file"
        sed -i 's/^DEFAULT_MODE=.*/DEFAULT_MODE="'"$DEFAULT_IDX"'"/' "$file"
        print "Updated: ${file:t}"
    done
    print "${GREEN}Configuration complete.${NC}"
    print "Note: You must re-run 'desktop_setup.zsh' or manually copy these scripts to /usr/local/bin/ for changes to take effect system-wide."
else
    print "${RED}Error: Invalid input. All fields are required.${NC}"
    exit 1
fi
