#!/bin/zsh
# ------------------------------------------------------------------------------
# ZSH Development Standards Test
# Validates adherence to strict project coding conventions without system impact.
# ------------------------------------------------------------------------------

# region Init
setopt ERR_EXIT NO_UNSET PIPE_FAIL EXTENDED_GLOB
SCRIPT_DIR=${0:a:h}
print -P "\n%K{green}%F{black} STARTING ZSH COMPLIANCE TEST %k%f\n"
# endregion

# ------------------------------------------------------------------------------
# 1. Dependency Verification
# ------------------------------------------------------------------------------

# Purpose: Checks for the existence of standard system utilities to demonstrate dependency validation logic and proper error handling within the UI hierarchy.

# region 1. Dependency Verification
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
# endregion

# ------------------------------------------------------------------------------
# 2. Temporary File Operations
# ------------------------------------------------------------------------------

# Purpose: Generates a temporary configuration file using a Heredoc to demonstrate file creation, variable expansion, and strict cleanup procedures.

# region 2. Temporary File Operations
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
# endregion

# ------------------------------------------------------------------------------
# 3. Cleanup & Finalization
# ------------------------------------------------------------------------------

# Purpose: Removes the temporary file created in the previous step, ensuring the system is returned to its original state and demonstrating idempotency.

# region 3. Cleanup & Finalization
print -P "\n%K{blue}%F{black} 3. CLEANUP %k%f\n"
if [[ -f "$TEMP_FILE" ]]; then
    print -P "%F{cyan}ℹ Removing $TEMP_FILE...%f\n"
    rm "$TEMP_FILE"
    print -P "%F{green}Cleanup complete.%f"
else
    print -P "%F{yellow}File already removed or missing.%f"
fi
# endregion

# ------------------------------------------------------------------------------
# End
# ------------------------------------------------------------------------------

# region End
print -P "\n%K{green}%F{black} TEST COMPLETE %k%f\n"
# endregion
