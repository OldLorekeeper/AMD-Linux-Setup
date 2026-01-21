#!/bin/zsh
# ------------------------------------------------------------------------------
# [Script Title]
# [Brief description of what this script does]
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
#    - Spacing: One empty line before and after headers (avoid double empty lines between headers).
#    - Inputs: Yellow description line (%F{yellow}) followed by minimal prompt (read "VAR?Prompt: ").
#    - Context: Cyan (%F{cyan}) for info/metadata (prefixed with ℹ).
#    - Status: Green (%F{green}) for success/loaded, Red (%F{red}) for errors/warnings.
#    - Silence: Do not repeat/confirm manual user input. Only print confirmation (%F{green}) if the value was pre-loaded from secrets.
#
# ------------------------------------------------------------------------------

setopt ERR_EXIT NO_UNSET PIPE_FAIL

SCRIPT_DIR=${0:a:h}

print -P "\n%K{green}%F{black} STARTING [PROCESS NAME] %k%f\n"

# ------------------------------------------------------------------------------
# 1. Section Header
# ------------------------------------------------------------------------------

# Purpose: [Description of the main task/actions]

print -P "\n%K{blue}%F{black} 1. SECTION TITLE %k%f\n"
if ! (( $+commands[dependency] )); then
    print -P "%F{red}Error: dependency is not installed.%f"
    exit 1
fi

# ------------------------------------------------------------------------------
# 2. Section Header
# ------------------------------------------------------------------------------

# Purpose: [Description of the main task/actions].

print -P "\n%K{blue}%F{black} 2. USER INTERACTION %k%f\n"
print -P "%K{yellow}%F{black} SUB-SECTION TITLE %k%f"
print ""

# Example of conditional silence pattern
if [[ -z "${VAR_NAME:-}" ]]; then
    print -P "%F{yellow}Enter Configuration Value:%f"
    print -P "%F{cyan}ℹ Context: Explain why this input is needed if not obvious.%f"
    read "VAR_NAME?Value [default]: "
    VAR_NAME=${VAR_NAME:-default}
else
    print -P "Configuration: %F{green}Loaded from secrets%f"
fi

TARGET_FILE="/path/to/config"
if [[ ! -f "$TARGET_FILE" ]]; then
    print "Creating configuration..."
    print -P "%F{green}Configuration created.%f"
else
    print -P "%F{yellow}Configuration exists at $TARGET_FILE. Skipping.%f"
fi

# ------------------------------------------------------------------------------
# End
# ------------------------------------------------------------------------------

print -P "\n%K{green}%F{black} PROCESS COMPLETE %k%f\n"
