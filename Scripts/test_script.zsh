#!/bin/zsh
# ------------------------------------------------------------------------------
# ZSH Development Standards Test
# Validates adherence to strict project coding conventions without system impact.
# ------------------------------------------------------------------------------
#
# DEVELOPMENT RULES:
#
# 1. Safety: `setopt ERR_EXIT NO_UNSET PIPE_FAIL EXTENDED_GLOB`.
# 2. Syntax: Native Zsh modifiers (e.g. ${VAR:t}).
# 3. Heredocs: Use language ID (e.g. <<ZSH, <<INI), unique IDs for nesting, and quote 'ID' to disable expansion.
# 4. Idempotency: Re-runnable scripts. Check state before changes.
# 5. Structure:
#    a) Sandwich numbered section separators (# ------) with 1 line padding before.
#    b) Purpose comment block (1 line padding) at start of every numbered section summarising code.
#    c) No inline/meta comments. Compact vertical layout (minimise blank lines)
#    d) Retain frequent context info markers (%F{cyan}) inside dense logic blocks to prevent 'frozen' UI state.
#    e) Code wrapped in '# BEGIN' and '# END' markers.
#    f) Kate modeline at EOF.
# 6. UI Hierarchy Print -P
#    a) Process marker:          Green Block (%K{green}%F{black}). Used at Start/End.
#    b) Section marker:          Blue Block  (%K{blue}%F{black}). Numbered.
#    c) Sub-section marker:      Yellow Block (%K{yellow}%F{black}).
#    d) Interaction:             Yellow description (%F{yellow}) + minimal `read` prompt.
#    e) Context/Status:          Cyan (Info ℹ), Green (Success), Red (Error/Warning).
#    f) Marker spacing:          i)  Use `\n...%k%f\n`.
#                                ii) Context (Cyan) markers MUST start and end with `\n`.
#                                iii) Omit top `\n` on consecutive markers.
#
# ------------------------------------------------------------------------------

# BEGIN
setopt ERR_EXIT NO_UNSET PIPE_FAIL EXTENDED_GLOB
SCRIPT_DIR=${0:a:h}
print -P "\n%K{green}%F{black} STARTING ZSH COMPLIANCE TEST %k%f\n"
# END

# ------------------------------------------------------------------------------
# 1. Dependency Verification
# ------------------------------------------------------------------------------

# Purpose: Checks for the existence of standard system utilities to demonstrate dependency validation logic and proper error handling within the UI hierarchy.

# BEGIN
print -P "%K{blue}%F{black} 1. CHECKING DEPENDENCIES %k%f\n"
REQUIRED_TOOLS=("grep" "ls" "cat")
for tool in "${REQUIRED_TOOLS[@]}"; do
    if ! (( $+commands[$tool] )); then
        print -P "%F{red}Error: Missing required tool '$tool'.%f"
        exit 1
    fi
    print -P "%F{cyan}ℹ Verified '$tool' presence.%f\n"
done
print -P "%F{green}All dependencies met.%f"
# END

# ------------------------------------------------------------------------------
# 2. Temporary File Operations
# ------------------------------------------------------------------------------

# Purpose: Generates a temporary configuration file using a Heredoc to demonstrate file creation, variable expansion, and strict cleanup procedures.

# BEGIN
print -P "\n%K{blue}%F{black} 2. FILE SYSTEM OPERATIONS %k%f\n"
TEMP_FILE="/tmp/gemini_test_${USER}.conf"
print -P "%F{cyan}ℹ Creating temporary config at $TEMP_FILE...%f\n"
cat <<CONF > "$TEMP_FILE"
# Test Configuration
user = $USER
timestamp = $(date +%s)
mode = test
CONF
if [[ -f "$TEMP_FILE" ]]; then
    print -P "%F{green}File created successfully.%f"
    print -P "\n%K{yellow}%F{black} FILE CONTENT VERIFICATION %k%f\n"
    print -P "%F{cyan}ℹ Reading file content...%f\n"
    cat "$TEMP_FILE"
else
    print -P "%F{red}Failed to create temporary file.%f"
    exit 1
fi
# END

# ------------------------------------------------------------------------------
# 3. Cleanup & Finalization
# ------------------------------------------------------------------------------

# Purpose: Removes the temporary file created in the previous step, ensuring the system is returned to its original state and demonstrating idempotency.

# BEGIN
print -P "\n%K{blue}%F{black} 3. CLEANUP %k%f\n"
if [[ -f "$TEMP_FILE" ]]; then
    print -P "%F{cyan}ℹ Removing $TEMP_FILE...%f\n"
    rm "$TEMP_FILE"
    print -P "%F{green}Cleanup complete.%f"
else
    print -P "%F{yellow}File already removed or missing.%f"
fi
# END

# ------------------------------------------------------------------------------
# End
# ------------------------------------------------------------------------------

# BEGIN
print -P "\n%K{green}%F{black} TEST COMPLETE %k%f\n"
# END

# kate: hl Zsh; folding-markers on;
