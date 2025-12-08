#!/bin/zsh
# ------------------------------------------------------------------------------
# System Maintenance & Backup
# Updates system, firmware, cleans cache, and backups Konsave profile.
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

# Sudo Keep-Alive
sudo -v
( while true; do sudo -v; sleep 60; done; ) &
SUDO_PID=$!
trap 'kill $SUDO_PID' EXIT

print "${GREEN}--- Starting System Maintenance ---${NC}"

# ------------------------------------------------------------------------------
# ------------------------------------------------------------------------------

# 1. Environment & Profile
print "${GREEN}--- Environment Check ---${NC}"

# Safely source .zshrc (ignore errors from plugins/aliases)
if [[ -f "$HOME/.zshrc" ]]; then
    unsetopt ERR_EXIT
    ZSH_SKIP_OMZ_CHECK=1 source "$HOME/.zshrc" >/dev/null 2>&1
    setopt ERR_EXIT
fi

if [[ -n "${KWIN_PROFILE:-}" ]]; then
    PROFILE_TYPE="${(C)KWIN_PROFILE}"
    print "Detected Profile: ${GREEN}$PROFILE_TYPE${NC}"
else
    print "${YELLOW}KWIN_PROFILE not detected.${NC}"
    print "Select Device Type for Backup:"
    print "1) Desktop"
    print "2) Laptop"
    read "kwin_choice?Choice [1-2]: "
    case $kwin_choice in
        1) PROFILE_TYPE="Desktop" ;;
        2) PROFILE_TYPE="Laptop" ;;
        *) print "${RED}Invalid selection. Exiting.${NC}"; exit 1 ;;
    esac
    print "Selected Profile: ${GREEN}$PROFILE_TYPE${NC}"
fi

# ------------------------------------------------------------------------------
# ------------------------------------------------------------------------------

# 2. Updates (System & Firmware)
print "${GREEN}--- System Updates ---${NC}"
yay -Syu --noconfirm

print "${GREEN}--- Firmware Updates ---${NC}"
fwupdmgr refresh --force
if fwupdmgr get-updates | grep -q "Devices with updates"; then
    fwupdmgr update -y
else
    print "${YELLOW}No firmware updates available.${NC}"
fi

# ------------------------------------------------------------------------------
# ------------------------------------------------------------------------------

# 3. Cleanup
print "${GREEN}--- Cleanup ---${NC}"
if pacman -Qdtq >/dev/null 2>&1; then
    print "Removing orphans..."
    yay -Yc --noconfirm
else
    print "${YELLOW}No orphans to remove.${NC}"
fi

print "Cleaning package cache (keeping last 3)..."
if (( $+commands[paccache] )); then
    paccache -rk3
else
    print "${RED}Error: paccache not found. Install pacman-contrib.${NC}"
fi

# ------------------------------------------------------------------------------
# ------------------------------------------------------------------------------

if [[ "$PROFILE_TYPE" == "Desktop" ]]; then
    print "${GREEN}--- Media Integrity Checks ---${NC}"

    SERVICES=("sonarr" "radarr" "lidarr" "prowlarr" "jellyfin" "transmission" "slskd")
    print "Verifying service group memberships..."

    for svc in $SERVICES; do
        if id "$svc" &>/dev/null; then
            if ! id -nG "$svc" | grep -qw "media"; then
                print "${YELLOW}Fixing missing 'media' group for $svc...${NC}"
                sudo usermod -aG media "$svc"
            fi
        fi
    done
    print "Service Memberships: ${GREEN}OK${NC}"

    TARGET="/mnt/Media"
    if grep -q "$TARGET" /proc/mounts; then
        print "Enforcing Access Control Lists (ACLs)..."
        sudo setfacl -R -m g:media:rwX "$TARGET"
        sudo setfacl -R -m d:g:media:rwX "$TARGET"
        print "ACLs Enforced: ${GREEN}OK${NC}"
    else
        print "${YELLOW}Media drive not mounted. Skipping ACL checks.${NC}"
    fi
fi

# ------------------------------------------------------------------------------
# ------------------------------------------------------------------------------

# 5. Visual Backup (Konsave)
print "${GREEN}--- Visual Backup (Konsave) ---${NC}"
zmodload zsh/datetime; strftime -s DATE_STR '%Y-%m-%d' $EPOCHSECONDS

# LINKAGE: Naming convention ("$PROFILE_TYPE Dock...") is matched by regex in setup_desktop.zsh / setup_laptop.zsh.
PROFILE_NAME="$PROFILE_TYPE Dock $DATE_STR"

# Define Repo Export Path (Relative to Script Location)
REPO_ROOT=${SCRIPT_DIR:h}
EXPORT_DIR="$REPO_ROOT/Resources/Konsave"

if (( $+commands[konsave] )); then
    print "Saving profile internally: $PROFILE_NAME"
    # Suppress Python warnings (pkg_resources deprecated)
    PYTHONWARNINGS="ignore" konsave -s "$PROFILE_NAME" -f

    # Export to Repository
    if [[ -d "$EXPORT_DIR" ]]; then
        print "Exporting to repo: $EXPORT_DIR"
        PYTHONWARNINGS="ignore" konsave -e "$PROFILE_NAME" -d "$EXPORT_DIR" -f
    else
        print "${YELLOW}Warning: Export directory not found at $EXPORT_DIR${NC}"
    fi

    # Prune old profiles (Internal & Repo)
    # 1. Prune Internal (~/.config/konsave/profiles)
    KONSAVE_CONFIG="$HOME/.config/konsave/profiles"
    if [[ -d "$KONSAVE_CONFIG" ]]; then
        local -a internal_profiles
        internal_profiles=( "$KONSAVE_CONFIG"/"$PROFILE_TYPE Dock "*(-/On) )
        if (( ${#internal_profiles} > 3 )); then
            print "Pruning internal profiles (keeping newest 3)..."
            for profile_path in "${internal_profiles[@][4,-1]}"; do
                PYTHONWARNINGS="ignore" konsave -r "${profile_path:t}" -f
            done
        fi
    fi

    # 2. Prune Repo Exports (.knsv files)
    if [[ -d "$EXPORT_DIR" ]]; then
        local -a repo_files
        repo_files=( "$EXPORT_DIR"/"$PROFILE_TYPE Dock "*.knsv(.om) )
        if (( ${#repo_files} > 3 )); then
            print "Pruning repo exports (keeping newest 3)..."
            for file in "${repo_files[@][4,-1]}"; do
                rm -f "$file"
                print "Removed old export: ${file:t}"
            done
        fi
    fi
else
    print "${RED}Error: Konsave not installed. Skipping backup.${NC}"
fi

# ------------------------------------------------------------------------------
# ------------------------------------------------------------------------------

print "${GREEN}--- System Maintenance Complete ---${NC}"
