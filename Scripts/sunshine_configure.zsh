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

print -P "\n%K{green}%F{black} STARTING SUNSHINE CONFIGURATION %k%f\n"

# ------------------------------------------------------------------------------
# 1. Paths
# ------------------------------------------------------------------------------

# Purpose: Locate target scripts relative to this script.

print -P "\n%K{blue}%F{black} 1. PATHS %k%f\n"
HDR_SCRIPT="$SCRIPT_DIR/sunshine_hdr.zsh"
RES_SCRIPT="$SCRIPT_DIR/sunshine_res.zsh"
LAPTOP_SCRIPT="$SCRIPT_DIR/sunshine_laptop.zsh"

if [[ ! -f "$HDR_SCRIPT" || ! -f "$RES_SCRIPT" || ! -f "$LAPTOP_SCRIPT" ]]; then
    print -P "%F{red}Error: Target Sunshine scripts not found in $SCRIPT_DIR%f"
    exit 1
fi
print -P "Scripts: %F{green}Found all target scripts%f"

# ------------------------------------------------------------------------------
# 2. Input
# ------------------------------------------------------------------------------

# Purpose: Gather monitor configuration from user.

print -P "\n%K{blue}%F{black} 2. INPUT %k%f\n"
print -P "%K{yellow}%F{black} CURRENT CONFIGURATION %k%f\n"
kscreen-doctor -o
print ""

print -P "%K{yellow}%F{black} USER ENTRY %k%f\n"

print -P "%F{yellow}Enter Monitor ID:%f"
print -P "%F{cyan}ℹ e.g. DP-1, HDMI-A-1%f"
read "MON_ID?Value: "

print -P "%F{yellow}Enter Target Streaming Mode Index:%f"
print -P "%F{cyan}ℹ e.g. 9%f"
read "STREAM_IDX?Value: "

print -P "%F{yellow}Enter Default Desktop Mode Index:%f"
print -P "%F{cyan}ℹ e.g. 1%f"
read "DEFAULT_IDX?Value: "

# ------------------------------------------------------------------------------
# 3. Configuration
# ------------------------------------------------------------------------------

# Purpose: Apply variables to target scripts using sed.

print -P "\n%K{blue}%F{black} 3. CONFIGURATION %k%f\n"
if [[ -n "$MON_ID" && -n "$STREAM_IDX" && -n "$DEFAULT_IDX" ]]; then
    for file in "$HDR_SCRIPT" "$RES_SCRIPT" "$LAPTOP_SCRIPT"; do
        sed -i 's/^MONITOR=.*/MONITOR="'"$MON_ID"'"/' "$file"
        sed -i 's/^STREAM_MODE=.*/STREAM_MODE="'"$STREAM_IDX"'"/' "$file"
        sed -i 's/^DEFAULT_MODE=.*/DEFAULT_MODE="'"$DEFAULT_IDX"'"/' "$file"
        print "Updated: ${file:t}"
    done
    print -P "Status: %F{green}Configuration complete%f"
else
    print -P "%F{red}Error: Missing input.%f"
    exit 1
fi

# ------------------------------------------------------------------------------
# End
# ------------------------------------------------------------------------------

print -P "\n%K{green}%F{black} PROCESS COMPLETE %k%f\n"
