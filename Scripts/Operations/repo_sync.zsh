#!/bin/zsh
# ------------------------------------------------------------------------------
# 8. Utility. Repository Sync Manager
# Manages git operations (pull, commit, push) for the nested repository structure.
# ------------------------------------------------------------------------------

# region Init
setopt ERR_EXIT NO_UNSET PIPE_FAIL EXTENDED_GLOB
SCRIPT_DIR=${0:a:h}
REPO_ROOT=${SCRIPT_DIR:h:h}
print -P "\n%K{green}%F{black} REPO MANAGEMENT %k%f\n"
# endregion

# ------------------------------------------------------------------------------
# 1. Configuration
# ------------------------------------------------------------------------------

# Purpose: Validate input arguments and establish paths.

# region 1. Configuration
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
# endregion

# ------------------------------------------------------------------------------
# 2. Functions
# ------------------------------------------------------------------------------

# Purpose: Define the core git operations and Antigravity helper.

# region 2. Functions

safe_pull() {
    local repo_path="$1"
    
    local has_changes=false
    if ! git -C "$repo_path" diff --ignore-submodules --quiet || ! git -C "$repo_path" diff --ignore-submodules --cached --quiet; then
        has_changes=true
    fi
    
    if [[ "$has_changes" == "true" ]]; then
        git -C "$repo_path" stash push -q -m "Auto-stash before pull" >/dev/null 2>&1
    fi
    
    if ! git -C "$repo_path" pull; then
        print -P "\n%F{red}Error: Pull failed in ${repo_path:t}. Aborting to protect state.%f\n"
        if [[ "$has_changes" == "true" ]]; then
            git -C "$repo_path" stash pop -q >/dev/null 2>&1 || true
        fi
        exit 1
    fi
    
    if [[ "$has_changes" == "true" ]]; then
        if ! git -C "$repo_path" stash pop -q >/dev/null 2>&1; then
            print -P "\n%F{red}Error: Merge conflict during stash pop in ${repo_path:t}.%f\n"
            print -P "%F{yellow}Please resolve conflicts manually, then re-run the sync command.%f\n"
            exit 1
        fi
    fi
}

do_pull() {
    print -P "\n%K{blue}%F{black} 2. PULL %k%f"
    print -P "\n%K{yellow}%F{black} MAIN %k%f"
    print -P "\n%F{cyan}ℹ Pulling Main & Syncing Submodules...%f\n"
    safe_pull "$REPO_ROOT"
    
    local secrets_branch=""
    if [[ -d "$REPO_ROOT/Secrets" ]]; then
        secrets_branch=$(git -C "$REPO_ROOT/Secrets" symbolic-ref --short -q HEAD || true)
    fi

    if ! git -C "$REPO_ROOT" submodule update --init --recursive -q; then
        print -P "\n%F{red}Error: Submodule sync failed.%f\n"
        exit 1
    fi
    
    if [[ -n "$secrets_branch" ]]; then
        git -C "$REPO_ROOT/Secrets" checkout "$secrets_branch" -q 2>/dev/null || true
    fi

    if [[ -d "$REPO_ROOT/Secrets" ]]; then
        print -P "\n%K{yellow}%F{black} SECRETS %k%f"
        print -P "\n%F{cyan}ℹ Updating Secrets Repo...%f\n"
        if git -C "$REPO_ROOT/Secrets" symbolic-ref -q HEAD >/dev/null 2>&1; then
            safe_pull "$REPO_ROOT/Secrets"
        else
            print -P "\n%F{yellow}Warning: Secrets is in a detached HEAD state. Skipping pull.%f\n"
        fi
        

    fi
    
    if [[ -d "$PRIVACY_ROOT" ]]; then
        print -P "\n%K{yellow}%F{black} PRIVACY %k%f"
        print -P "\n%F{cyan}ℹ Updating Privacy Repo...%f\n"
        safe_pull "$PRIVACY_ROOT"
    fi
    print -P "\nStatus: %F{green}Pull Complete%f\n"
}

generate_agy_msg() {
    local repo_path="$1"
    
    if ! (( $+commands[agy] )); then
        return 1
    fi

    local diff_cmd=(git -C "$repo_path" diff --cached)

    local diff_stat=$("${diff_cmd[@]}" --stat 2>/dev/null)
    if [[ -z "$diff_stat" ]]; then
        return 1
    fi

    local diff_ctx=$("${diff_cmd[@]}" | head -n 500)
    local gen_msg=$(agy -p "Generate a concise, conventional git commit message (max 72 chars) that summarises all of these changes. 
Return ONLY the raw message text without any markdown or backticks.

Overview:
$diff_stat

Details:
$diff_ctx" 2>/dev/null)
    
    if [[ -n "$gen_msg" ]]; then
        echo "${${gen_msg#[\"\']}%[\"\']}"
        return 0
    fi
    return 1
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

    local current_date=$(date +%Y-%m-%d)
    local wip_msg="chore: daily incremental changes ($current_date)"

    for repo in Secrets Privacy Main; do
        if [[ -n "${repo_paths[$repo]:-}" ]]; then
            local repo_dir="${repo_paths[$repo]}"
            print -P "%K{yellow}%F{black} ${repo:u} %k%f\n"
            [[ "$repo" == "Main" && -d "$REPO_ROOT/Secrets" ]] && git -C "$REPO_ROOT" add Secrets
            
            # Skip if no changes are staged
            if git -C "$repo_dir" diff --cached --quiet; then
                print -P "  > %F{cyan}No changes to commit.%f\n"
                continue
            fi
            
            if [[ "$msg" == "System update" ]]; then
                local current_date=$(date +%Y-%m-%d)
                local wip_fallback="chore: daily incremental changes ($current_date)"

                print -P "  > %F{cyan}Antigravity: Analyzing changes...%f"
                local agy_msg=$(generate_agy_msg "$repo_dir")
                local final_msg="${agy_msg:-$wip_fallback}"

                print -P "  > %F{cyan}Creating new daily commit...%f"
                [[ -n "$agy_msg" ]] && print -P "  > Generated: %F{green}$agy_msg%f"
                git -C "$repo_dir" commit -m "$final_msg" -q || true
            else
                git -C "$repo_dir" commit -m "$msg" -q || true
            fi
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
        if git -C "$REPO_ROOT/Secrets" symbolic-ref -q HEAD >/dev/null; then
            git -C "$REPO_ROOT/Secrets" push
        else
            print -P "%F{yellow}Warning: Secrets is in a detached HEAD state. Skipping push.%f"
        fi
    fi
    if [[ -d "$PRIVACY_ROOT" ]]; then
        print -P "\n%K{yellow}%F{black} PRIVACY %k%f\n"
        print -P "%F{cyan}ℹ Pushing Privacy...%f\n"
        if git -C "$PRIVACY_ROOT" symbolic-ref -q HEAD >/dev/null; then
            git -C "$PRIVACY_ROOT" push
        else
            print -P "%F{yellow}Warning: Privacy is in a detached HEAD state. Skipping push.%f"
        fi
    fi
    print -P "\n%K{yellow}%F{black} MAIN %k%f\n"
    print -P "%F{cyan}ℹ Pushing Main...%f\n"
    git -C "$REPO_ROOT" push
    print -P "\nStatus: %F{green}Push Complete%f"
}
# endregion

# ------------------------------------------------------------------------------
# 3. Execution
# ------------------------------------------------------------------------------

# Purpose: Execute the requested command.

# region 3. Execution
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
# endregion

# ------------------------------------------------------------------------------
# End
# ------------------------------------------------------------------------------

# region End
print -P "\n%K{green}%F{black} PROCESS COMPLETE %k%f\n"
# endregion
