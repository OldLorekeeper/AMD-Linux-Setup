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
PRIVACY_ROOT="${REPO_ROOT:h}/Privacy"
if [[ -z "$COMMAND" ]]; then
    print -P "%F{red}Error: No command specified. Use pull, commit, push, or sync.%f"
    exit 1
fi
print -P "Action:       %F{green}${(C)COMMAND}%f"
print -P "Root:         %F{cyan}$REPO_ROOT%f"
[[ -d "$PRIVACY_ROOT" ]] && print -P "Privacy:      %F{cyan}$PRIVACY_ROOT%f"
# END

# ------------------------------------------------------------------------------
# 2. Functions
# ------------------------------------------------------------------------------

# Purpose: Define the core git operations and Gemini helper.

# BEGIN
get_contextual_msg() {
    local repo_path="$1"
    local input_msg="$2"
    if [[ "$input_msg" == "System update" ]] && (( $+commands[gemini] )); then
        local diff_stat=$(git -C "$repo_path" diff --cached --stat 2>/dev/null)
        if [[ -n "$diff_stat" ]]; then
            # Use stat for overview and truncated diff for detail
            local diff_ctx=$(git -C "$repo_path" diff --cached | head -n 50)
            local gen_msg=$(gemini "Generate a concise git commit message (max 72 chars). 
Return ONLY the raw message text.

Overview:
$diff_stat

Details:
$diff_ctx" 2>/dev/null)
            if [[ -n "$gen_msg" ]]; then
                echo "${${gen_msg#[\"\']}%[\"\']}"
                return
            fi
        fi
    fi
    echo "$input_msg"
}

do_pull() {
# ... (rest of do_pull remains same)
    print -P "\n%K{blue}%F{black} 2. PULL %k%f\n"
    print -P "%K{yellow}%F{black} MAIN %k%f\n"
    print -P "%F{cyan}ℹ Updating Main Repo...%f\n"
    git -C "$REPO_ROOT" pull
    if [[ -d "$REPO_ROOT/Secrets" ]]; then
        print -P "\n%K{yellow}%F{black} SECRETS %k%f\n"
        print -P "%F{cyan}ℹ Updating Secrets Repo...%f\n"
        git -C "$REPO_ROOT/Secrets" pull
    fi
    if [[ -d "$PRIVACY_ROOT" ]]; then
        print -P "\n%K{yellow}%F{black} PRIVACY %k%f\n"
        print -P "%F{cyan}ℹ Updating Privacy Repo...%f\n"
        git -C "$PRIVACY_ROOT" pull
    fi
    print -P "\nStatus: %F{green}Pull Complete%f"
}

do_commit() {
    local msg="$1"
    print -P "\n%K{blue}%F{black} 3. COMMIT %k%f\n"
    
    local -a active_repos
    local -A repo_paths
    
    active_repos=(Main)
    repo_paths[Main]="$REPO_ROOT"
    
    if [[ -d "$REPO_ROOT/Secrets" ]]; then
        active_repos+=(Secrets)
        repo_paths[Secrets]="$REPO_ROOT/Secrets"
    fi
    
    if [[ -d "$PRIVACY_ROOT" ]]; then
        active_repos+=(Privacy)
        repo_paths[Privacy]="$PRIVACY_ROOT"
    fi

    for repo in $active_repos; do
        git -C "$repo_paths[$repo]" add .
    done

    local -A commit_msgs
    if [[ "$msg" == "System update" ]] && (( $+commands[gemini] )); then
        print -P "%F{cyan}ℹ Gemini: Analyzing changes in parallel...%f\n"
        local tmp_dir=$(mktemp -d)
        for repo in $active_repos; do
            ( get_contextual_msg "$repo_paths[$repo]" "$msg" > "$tmp_dir/$repo" ) &
        done
        wait
        for repo in $active_repos; do
            commit_msgs[$repo]=$(cat "$tmp_dir/$repo")
        done
        rm -rf "$tmp_dir"
    else
        for repo in $active_repos; do
            commit_msgs[$repo]="$msg"
        done
    fi

    for repo in Secrets Privacy Main; do
        if [[ -n "$repo_paths[$repo]" ]]; then
            print -P "%K{yellow}%F{black} ${repo:u} %k%f"
            local final_msg="$commit_msgs[$repo]"
            [[ "$final_msg" != "$msg" ]] && print -P "  > Generated: %F{green}$final_msg%f"
            git -C "$repo_paths[$repo]" commit -m "$final_msg" || true
            print ""
        fi
    done
    print -P "Status: %F{green}Commit Complete%f"
}

do_push() {
    print -P "\n%K{blue}%F{black} 4. PUSH %k%f\n"
    if [[ -d "$REPO_ROOT/Secrets" ]]; then
        print -P "%K{yellow}%F{black} SECRETS %k%f\n"
        print -P "%F{cyan}ℹ Pushing Secrets...%f\n"
        git -C "$REPO_ROOT/Secrets" push
    fi
    if [[ -d "$PRIVACY_ROOT" ]]; then
        print -P "\n%K{yellow}%F{black} PRIVACY %k%f\n"
        print -P "%F{cyan}ℹ Pushing Privacy...%f\n"
        git -C "$PRIVACY_ROOT" push
    fi
    print -P "\n%K{yellow}%F{black} MAIN %k%f\n"
    print -P "%F{cyan}ℹ Pushing Main...%f\n"
    git -C "$REPO_ROOT" push
    print -P "\nStatus: %F{green}Push Complete%f"
}
# END

# ------------------------------------------------------------------------------
# 3. Execution
# ------------------------------------------------------------------------------

# Purpose: Execute the requested command.

# BEGIN
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
