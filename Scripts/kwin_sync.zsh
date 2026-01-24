#!/bin/zsh
# ------------------------------------------------------------------------------
# 9. Utility. KWin Sync Manager
# Syncs KWin rules with the repository, managing common fragments and updates.
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
print -P "\n%K{green}%F{black} KWIN SYNC & UPDATE %k%f\n"
# END

# ------------------------------------------------------------------------------
# 1. Configuration
# ------------------------------------------------------------------------------

# Purpose: Validate profile target and paths.

# BEGIN
print -P "%K{blue}%F{black} 1. CONFIGURATION %k%f\n"
PROFILE="${1:-${SYS_PROFILE:-}}"
if [[ -z "$PROFILE" ]]; then
    print -P "%F{red}Error: No profile specified and SYS_PROFILE not set.%f"
    exit 1
fi
print -P "Profile:      %F{green}$PROFILE%f"
print -P "Root:         %F{cyan}$REPO_ROOT%f"
# END

# ------------------------------------------------------------------------------
# 2. Fragment Check
# ------------------------------------------------------------------------------

# Purpose: Check for local changes in the common rule fragment and commit them if found.

# BEGIN
print -P "\n%K{blue}%F{black} 2. FRAGMENT CHECK %k%f\n"
FRAGMENT="Resources/Kwin/common.kwinrule.fragment"
if git -C "$REPO_ROOT" status --porcelain "$FRAGMENT" | grep -q '^ M'; then
    print -P "%F{yellow}Changes detected in common fragment. Committing...%f"
    git -C "$REPO_ROOT" add "$FRAGMENT"
    git -C "$REPO_ROOT" commit -m "AUTOSYNC: KWin common fragment update from ${HOST}"
    print -P "Status: %F{green}Committed changes%f"
else
    print -P "Status: %F{green}No changes in common fragment%f"
fi
# END

# ------------------------------------------------------------------------------
# 3. Repository Update
# ------------------------------------------------------------------------------

# Purpose: Pull the latest changes from the remote repository.

# BEGIN
print -P "\n%K{blue}%F{black} 3. REPOSITORY UPDATE %k%f\n"
print -P "%F{cyan}ℹ Pulling latest changes...%f"
if git -C "$REPO_ROOT" pull; then
    print -P "Status: %F{green}Pull Successful%f"
else
    print -P "%F{red}Error: Git pull failed.%f"
    exit 1
fi
# END

# ------------------------------------------------------------------------------
# 4. Apply Rules
# ------------------------------------------------------------------------------

# Purpose: Call the rule applicator script.

# BEGIN
print -P "\n%K{blue}%F{black} 4. APPLY RULES %k%f\n"
APPLY_SCRIPT="$SCRIPT_DIR/kwin_apply_rules.zsh"
if [[ -x "$APPLY_SCRIPT" ]]; then
    "$APPLY_SCRIPT" "$PROFILE"
else
    print -P "%F{red}Error: Apply script not found or not executable.%f"
    exit 1
fi
# END

# ------------------------------------------------------------------------------
# End
# ------------------------------------------------------------------------------

# BEGIN
print -P "\n%K{green}%F{black} PROCESS COMPLETE %k%f\n"
# END

# kate: hl Zsh; folding-markers on;
