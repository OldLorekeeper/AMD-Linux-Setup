#!/bin/zsh
# ------------------------------------------------------------------------------
# 8. Utility. Repository Sync Manager
# Manages git operations (pull, commit, push) for the nested repository structure.
# ------------------------------------------------------------------------------
#
# DEVELOPMENT RULES:
#
# 1. Safety: `setopt ERR_EXIT NO_UNSET PIPE_FAIL EXTENDED_GLOB`.
# 2. Syntax: Native Zsh modifiers (e.g. ${VAR:t}).
# 3. Heredocs: Use language ID (e.g. <<ZSH, <<INI), unique IDs for nesting, and quote 'ID' to disable expansion.
# 4. Structure:
#    - Sandwich numbered section separators (# ------) with 1 line padding before.
#    - Purpose comment block (1 line padding) at start of every numbered section summarising code.
#    - No inline/meta comments. Compact vertical layout (minimise blank lines)
#    - Retain frequent context info markers (%F{cyan}) inside dense logic blocks to prevent 'frozen' UI state.
#    - Code wrapped in '# BEGIN' and '# END' markers.
#    - Kate modeline at EOF.
# 5. Idempotency: Re-runnable scripts. Check state before changes.
# 6. UI Hierarchy Print -P
#    - Process marker:          Green Block (%K{green}%F{black}). Used at Start/End.
#    - Section marker:          Blue Block  (%K{blue}%F{black}). Numbered.
#    - Sub-section marker:      Yellow Block (%K{yellow}%F{black}).
#    - Interaction:             Yellow description (%F{yellow}) + minimal `read` prompt.
#    - Context/Status:          Cyan (Info ℹ), Green (Success), Red (Error/Warning).
#    - Marker spacing:          Use `\n...%k%f\n`. Omit top `\n` on consecutive markers.
#
# ------------------------------------------------------------------------------

# BEGIN
setopt ERR_EXIT NO_UNSET PIPE_FAIL EXTENDED_GLOB
SCRIPT_DIR=${0:a:h}
REPO_ROOT=${SCRIPT_DIR:h}
print -P "\n%K{green}%F{black} REPO MANAGEMENT %k%f\n"
# END

# ------------------------------------------------------------------------------
# 1. Configuration
# ------------------------------------------------------------------------------

# Purpose: Validate input arguments and establish paths.

# BEGIN
print -P "%K{blue}%F{black} 1. CONFIGURATION %k%f\n"
COMMAND="${1:-}"
MESSAGE="${2:-System update}"
if [[ -z "$COMMAND" ]]; then
    print -P "%F{red}Error: No command specified. Use pull, commit, push, or sync.%f"
    exit 1
fi
print -P "Action:       %F{green}${(C)COMMAND}%f"
print -P "Root:         %F{cyan}$REPO_ROOT%f"
# END

# ------------------------------------------------------------------------------
# 2. Functions
# ------------------------------------------------------------------------------

# Purpose: Define the core git operations for Main and Secrets repositories.

# BEGIN
print -P "\n%K{blue}%F{black} 2. FUNCTIONS %k%f\n"

do_pull() {
    print -P "%K{yellow}%F{black} PULL %k%f\n"
    print -P "%F{cyan}ℹ Updating Main Repo...%f"
    git -C "$REPO_ROOT" pull
    if [[ -d "$REPO_ROOT/.secrets" ]]; then
        print -P "%F{cyan}ℹ Updating Secrets Repo...%f"
        git -C "$REPO_ROOT/.secrets" pull
    fi
    print -P "Status: %F{green}Pull Complete%f"
}

do_commit() {
    local msg="$1"
    print -P "\n%K{yellow}%F{black} COMMIT %k%f\n"
    if [[ -d "$REPO_ROOT/.secrets" ]]; then
        print -P "%F{cyan}ℹ Committing Secrets...%f"
        git -C "$REPO_ROOT/.secrets" add .
        git -C "$REPO_ROOT/.secrets" commit -m "$msg" || true
    fi
    print -P "%F{cyan}ℹ Committing Main...%f"
    git -C "$REPO_ROOT" add .
    git -C "$REPO_ROOT" commit -m "$msg" || true
    print -P "Status: %F{green}Commit Complete%f"
}

do_push() {
    print -P "\n%K{yellow}%F{black} PUSH %k%f\n"
    if [[ -d "$REPO_ROOT/.secrets" ]]; then
        print -P "%F{cyan}ℹ Pushing Secrets...%f"
        git -C "$REPO_ROOT/.secrets" push
    fi
    print -P "%F{cyan}ℹ Pushing Main...%f"
    git -C "$REPO_ROOT" push
    print -P "Status: %F{green}Push Complete%f"
}
# END

# ------------------------------------------------------------------------------
# 3. Execution
# ------------------------------------------------------------------------------

# Purpose: Execute the requested command.

# BEGIN
print -P "\n%K{blue}%F{black} 3. EXECUTION %k%f\n"
case "$COMMAND" in
    pull)
        do_pull
        ;;
    commit)
        do_commit "$MESSAGE"
        ;;
    push)
        do_push
        ;;
    sync)
        do_pull
        do_commit "$MESSAGE"
        do_push
        ;;
    *)
        print -P "%F{red}Error: Invalid command '$COMMAND'.%f"
        exit 1
        ;;
esac
# END

# ------------------------------------------------------------------------------
# End
# ------------------------------------------------------------------------------

# BEGIN
print -P "\n%K{green}%F{black} PROCESS COMPLETE %k%f\n"
# END

# kate: hl Zsh; folding-markers on;
