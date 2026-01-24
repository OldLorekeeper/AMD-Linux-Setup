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
#    a) Sandwich numbered section separators (# ------) with 1 line padding before.
#    b) Purpose comment block (1 line padding) at start of every numbered section summarising code.
#    c) No inline/meta comments. Compact vertical layout (minimise blank lines)
#    d) Retain frequent context info markers (%F{cyan}) inside dense logic blocks to prevent 'frozen' UI state.
#    e) Code wrapped in '# BEGIN' and '# END' markers.
#    f) Kate modeline at EOF.
# 5. Idempotency: Re-runnable scripts. Check state before changes.
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
do_pull() {
    print -P "%K{yellow}%F{black} PULL %k%f\n"
    print -P "%F{cyan}ℹ Updating Main Repo...%f\n"
    git -C "$REPO_ROOT" pull
    if [[ -d "$REPO_ROOT/.secrets" ]]; then
        print -P "\n%F{cyan}ℹ Updating Secrets Repo...%f\n"
        git -C "$REPO_ROOT/.secrets" pull
    fi
    print -P "\nStatus: %F{green}Pull Complete%f"
}

do_commit() {
    local msg="$1"
    print -P "\n%K{yellow}%F{black} COMMIT %k%f\n"
    if [[ -d "$REPO_ROOT/.secrets" ]]; then
        print -P "%F{cyan}ℹ Committing Secrets...%f\n"
        git -C "$REPO_ROOT/.secrets" add .
        git -C "$REPO_ROOT/.secrets" commit -m "$msg" || true
    fi
    print -P "\n%F{cyan}ℹ Committing Main...%f\n"
    git -C "$REPO_ROOT" add .
    git -C "$REPO_ROOT" commit -m "$msg" || true
    print -P "\nStatus: %F{green}Commit Complete%f"
}

do_push() {
    print -P "\n%K{yellow}%F{black} PUSH %k%f\n"
    if [[ -d "$REPO_ROOT/.secrets" ]]; then
        print -P "%F{cyan}ℹ Pushing Secrets...%f\n"
        git -C "$REPO_ROOT/.secrets" push
    fi
    print -P "\n%F{cyan}ℹ Pushing Main...%f\n"
    git -C "$REPO_ROOT" push
    print -P "\nStatus: %F{green}Push Complete%f"
}
# END

# ------------------------------------------------------------------------------
# 3. Execution
# ------------------------------------------------------------------------------

# Purpose: Execute the requested command.

# BEGIN
print -P "\n%K{blue}%F{black} 2. EXECUTION %k%f\n"
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
