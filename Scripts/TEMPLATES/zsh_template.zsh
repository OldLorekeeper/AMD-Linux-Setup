#!/bin/zsh
# ------------------------------------------------------------------------------
# [Script Title]
# [Brief description of what this script does]
# ------------------------------------------------------------------------------
#
# DEVELOPMENT RULES
# 1. Structure:
#    - Format: Compact (no inner gaps). 'Sandwich' headers (# ------) with 'Purpose' comment.
#    - Editor: Wrap logic in `# BEGIN` / `# END`. Kate modeline at EOF. Uppercase heredocs.
# 2. Safety & Logic:
#    - Options: `setopt ERR_EXIT NO_UNSET PIPE_FAIL`.
#    - Code: Idempotent (check-then-act). Native Zsh syntax. No hardcoded secrets.
# 3. UI Standards:
#    - Headers: Blue `%K{blue}%F{black}` (Main), Yellow `%K{yellow}%F{black}` (Sub).
#    - Spacing: Embed `\n` to save lines. 1 line gap around headers (collapse adjacent).
#    - Colors: Yellow `%F{yellow}` (Prompt), Cyan `%F{cyan}` (Info ℹ), Green (OK), Red (Err).
#    - Interaction: `read "VAR?Prompt: "`. No input echo. Only confirm secret loads.
#
# ------------------------------------------------------------------------------

# BEGIN
setopt ERR_EXIT NO_UNSET PIPE_FAIL

SCRIPT_DIR=${0:a:h}

print -P "\n%K{green}%F{black} STARTING [PROCESS NAME] %k%f\n"
# END

# ------------------------------------------------------------------------------
# 1. Section Header
# ------------------------------------------------------------------------------

# Purpose: [Description of the main task/actions]

# BEGIN
print -P "\n%K{blue}%F{black} 1. SECTION TITLE %k%f\n"
if ! (( $+commands[dependency] )); then
    print -P "%F{red}Error: dependency is not installed.%f"
    exit 1
fi
# END

# ------------------------------------------------------------------------------
# 2. Section Header
# ------------------------------------------------------------------------------

# Purpose: [Description of the main task/actions].

# BEGIN
print -P "\n%K{blue}%F{black} 2. USER INTERACTION %k%f\n"

# CASE A: Sub-section follows Header (No Leading \n)
print -P "%K{yellow}%F{black} CONFIGURATION %k%f\n"

# Example of conditional silence pattern
if [[ -z "${VAR_NAME:-}" ]]; then
    print -P "%F{yellow}Enter Configuration Value:%f"
    print -P "%F{cyan}ℹ Context: Explain why this input is needed if not obvious.%f"
    read "VAR_NAME?Value [default]: "
    VAR_NAME=${VAR_NAME:-default}
else
    print -P "Configuration: %F{green}Loaded from secrets%f"
fi

# CASE B: Sub-section follows Content (With Leading \n)
print -P "\n%K{yellow}%F{black} FILE OPERATIONS %k%f\n"

TARGET_FILE="/path/to/config"
if [[ ! -f "$TARGET_FILE" ]]; then
    print "Creating configuration..."
    cat <<INI > "$TARGET_FILE"
[Section]
Key=Value
INI
    print -P "%F{green}Configuration created.%f"
else
    print -P "%F{yellow}Configuration exists at $TARGET_FILE. Skipping.%f"
fi
# END

# ------------------------------------------------------------------------------
# End
# ------------------------------------------------------------------------------

# BEGIN
print -P "\n%K{green}%F{black} PROCESS COMPLETE %k%f\n"
# END

# kate: hl Zsh; folding-markers on;