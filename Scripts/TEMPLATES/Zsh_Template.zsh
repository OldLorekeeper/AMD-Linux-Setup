#!/bin/zsh
# ------------------------------------------------------------------------------
# [Script Title]
# [Brief description of what this script does]
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

# Path Resolution (Zsh Native)
SCRIPT_DIR=${0:a:h}

print "${GREEN}--- Starting [Process Name] ---${NC}"

# ------------------------------------------------------------------------------
# ------------------------------------------------------------------------------

# 1. Prerequisite Checks
# Example: Check for binary in path
if ! (( $+commands[dependency] )); then
    print "${RED}Error: dependency is not installed.${NC}"
    exit 1
fi

# ------------------------------------------------------------------------------
# ------------------------------------------------------------------------------

# 2. Main Logic
print "${GREEN}--- Section Title ---${NC}"

# Example: Idempotent Check
TARGET_FILE="/path/to/config"

if [[ ! -f "$TARGET_FILE" ]]; then
    print "Creating configuration..."
    # Command here
else
    print "${YELLOW}Configuration exists at $TARGET_FILE. Skipping.${NC}"
fi

# ------------------------------------------------------------------------------
# ------------------------------------------------------------------------------

print "${GREEN}--- [Process Name] Complete ---${NC}"
