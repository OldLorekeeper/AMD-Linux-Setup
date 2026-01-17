#!/bin/zsh
# ------------------------------------------------------------------------------
# 5. System Maintenance & Backup
# Updates system, firmware, cleans cache, and backups Konsave profile.
# ------------------------------------------------------------------------------
#
# DEVELOPMENT RULES (Read before editing):
# 1. Formatting: Keep layout compact. No vertical whitespace inside blocks.
# 2. Separators: Use 'Sandwich' headers (# ------) with strict spacing (1 line before, 0 lines after).
# 3. Idempotency: Scripts must be safe to re-run. Check state before changes.
# 4. Safety: Use 'setopt ERR_EXIT NO_UNSET PIPE_FAIL'.
# 5. Context: Hardcoded for AMD Ryzen 7000/Radeon 7000. No hardcoded secrets.
# 6. Syntax: Use Zsh native modifiers (e.g. ${VAR:h}) over subshells.
# 7. Output: Use 'print'. Do NOT use 'echo'.
# 8. Documentation: Precede sections with 'Purpose'/'Rationale'. No meta-comments inside code blocks.
#
# ------------------------------------------------------------------------------

setopt ERR_EXIT NO_UNSET PIPE_FAIL

SCRIPT_DIR=${0:a:h}

sudo -v
( while true; do sudo -v; sleep 60; done; ) &
SUDO_PID=$!
trap 'kill $SUDO_PID' EXIT

print -P "%F{green}--- Starting System Maintenance ---%f"

# ------------------------------------------------------------------------------
# 1. Environment & Profile
# ------------------------------------------------------------------------------

# Purpose: Detect or prompt for the device profile to ensure correct backup labeling.
# - Action: Sources .zshrc to find KWIN_PROFILE; prompts user if missing.

print -P "%F{green}--- Environment Check ---%f"
if [[ -f "$HOME/.zshrc" ]]; then
    unsetopt ERR_EXIT
    ZSH_SKIP_OMZ_CHECK=1 source "$HOME/.zshrc" >/dev/null 2>&1
    setopt ERR_EXIT
fi

if [[ -n "${KWIN_PROFILE:-}" ]]; then
    PROFILE_TYPE="${(C)KWIN_PROFILE}"
    print -P "Detected Profile: %F{green}$PROFILE_TYPE%f"
else
    print -P "%F{yellow}KWIN_PROFILE not detected.%f"
    print "Select Device Type for Backup:"
    print "1) Desktop"
    print "2) Laptop"
    read "kwin_choice?Choice [1-2]: "
    case $kwin_choice in
        1) PROFILE_TYPE="Desktop" ;;
        2) PROFILE_TYPE="Laptop" ;;
        *) print -P "%F{red}Invalid selection. Exiting.%f"; exit 1 ;;
    esac
    print -P "Selected Profile: %F{green}$PROFILE_TYPE%f"
fi

# ------------------------------------------------------------------------------
# 2. Updates (System & Firmware)
# ------------------------------------------------------------------------------

# Purpose: Upgrade all software layers.
# - Packages: Updates official and AUR packages via yay.
# - Firmware: Checks lvfs for hardware updates using fwupdmgr.

print -P "%F{green}--- System Updates ---%f"
yay -Syu --noconfirm

print -P "%F{green}--- Firmware Updates ---%f"
fwupdmgr refresh --force
if fwupdmgr get-updates | grep -q "Devices with updates"; then
    fwupdmgr update -y
else
    print -P "%F{yellow}No firmware updates available.%f"
fi

# ------------------------------------------------------------------------------
# 3. Cleanup
# ------------------------------------------------------------------------------

# Purpose: Reclaim disk space.
# - Orphans: Removes unused dependencies.
# - Cache: Retains only the 3 most recent package versions for rollback safety.

print -P "%F{green}--- Cleanup ---%f"
if pacman -Qdtq >/dev/null 2>&1; then
    print "Removing orphans..."
    yay -Yc --noconfirm
else
    print -P "%F{yellow}No orphans to remove.%f"
fi

print "Cleaning package cache (keeping last 3)..."
if (( $+commands[paccache] )); then
    paccache -rk3
else
    print -P "%F{red}Error: paccache not found. Install pacman-contrib.%f"
fi

# ------------------------------------------------------------------------------
# 4. Media Integrity Checks (Desktop Only)
# ------------------------------------------------------------------------------

# Purpose: Prevent permission drift on the shared media drive.
# - Groups: Ensures media services belong to the 'media' group.
# - ACLs: Recursively enforces read/write permissions on /mnt/Media.

if [[ "$PROFILE_TYPE" == "Desktop" ]]; then
    print -P "%F{green}--- Media Integrity Checks ---%f"
    SERVICES=("sonarr" "radarr" "lidarr" "prowlarr" "jellyfin" "transmission" "slskd")
    print "Verifying service group memberships..."
    for svc in $SERVICES; do
        if id "$svc" &>/dev/null; then
            if ! id -nG "$svc" | grep -qw "media"; then
                print -P "%F{yellow}Fixing missing 'media' group for $svc...%f"
                sudo usermod -aG media "$svc"
            fi
        fi
    done
    print -P "Service Memberships: %F{green}OK%f"

    TARGET="/mnt/Media"
    if grep -q "$TARGET" /proc/mounts; then
        print "Enforcing Access Control Lists (ACLs)..."
        sudo setfacl -R -m g:media:rwX "$TARGET"
        sudo setfacl -R -m d:g:media:rwX "$TARGET"
        print -P "ACLs Enforced: %F{green}OK%f"
    else
        print -P "%F{yellow}Media drive not mounted. Skipping ACL checks.%f"
    fi
fi

# ------------------------------------------------------------------------------
# 5. Visual Backup (Konsave)
# ------------------------------------------------------------------------------

# Purpose: Export and version control the current KDE Plasma configuration.
# - Export: Saves current state as a 'Dock' profile.
# - Prune: Retains only the 3 most recent backups to prevent bloat.
# - Sorting: Uses Name Descending ('On') instead of Modification Time ('om') to survive Git cloning.

print -P "%F{green}--- Visual Backup (Konsave) ---%f"
zmodload zsh/datetime; strftime -s DATE_STR '%Y-%m-%d' $EPOCHSECONDS
PROFILE_NAME="$PROFILE_TYPE Dock $DATE_STR"
REPO_ROOT=${SCRIPT_DIR:h}
EXPORT_DIR="$REPO_ROOT/Resources/Konsave"

if (( $+commands[konsave] )); then
    print "Saving profile internally: $PROFILE_NAME"
    PYTHONWARNINGS="ignore" konsave -s "$PROFILE_NAME" -f
    if [[ -d "$EXPORT_DIR" ]]; then
        print "Exporting to repo: $EXPORT_DIR"
        PYTHONWARNINGS="ignore" konsave -e "$PROFILE_NAME" -d "$EXPORT_DIR" -f
    else
        print -P "%F{yellow}Warning: Export directory not found at $EXPORT_DIR%f"
    fi

    KONSAVE_CONFIG="$HOME/.config/konsave/profiles"
    if [[ -d "$KONSAVE_CONFIG" ]]; then
        local -a internal_profiles=( "$KONSAVE_CONFIG"/"$PROFILE_TYPE Dock "*(-/On) )
        if (( ${#internal_profiles} > 3 )); then
            print "Pruning internal profiles (keeping newest 3)..."
            for profile_path in "${internal_profiles[@][4,-1]}"; do
                PYTHONWARNINGS="ignore" konsave -r "${profile_path:t}" -f
            done
        fi
    fi

    if [[ -d "$EXPORT_DIR" ]]; then
        local -a repo_files=( "$EXPORT_DIR"/"$PROFILE_TYPE Dock "*.knsv(.On) )
        if (( ${#repo_files} > 3 )); then
            print "Pruning repo exports (keeping newest 3)..."
            for file in "${repo_files[@][4,-1]}"; do
                rm -f "$file"
                print "Removed old export: ${file:t}"
            done
        fi
    fi
else
    print -P "%F{red}Error: Konsave not installed. Skipping backup.%f"
fi

# ------------------------------------------------------------------------------
# End
# ------------------------------------------------------------------------------

print -P "%F{green}--- System Maintenance Complete ---%f"
