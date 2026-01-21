#!/bin/zsh
# ------------------------------------------------------------------------------
# 5. System Maintenance & Backup
# Updates system, firmware, cleans cache, checks services, and backups Konsave profile.
# ------------------------------------------------------------------------------
#
# DEVELOPMENT RULES (Read before editing):
# 1. Formatting: Keep layout compact. No vertical whitespace inside blocks.
# 2. Separators: Use 'Sandwich' headers (# ------) with strict spacing (1 line before).
# 3. Idempotency: Scripts must be safe to re-run. Check state before changes.
# 4. Safety: Use 'setopt ERR_EXIT NO_UNSET PIPE_FAIL'.
# 5. Context: No hardcoded secrets.
# 6. Syntax: Use Zsh native modifiers and tooling.
# 7. Documentation: Start section with 'Purpose' comment block (1 line before and after). No meta or inline comments within code.
# 8. UI & Theming:
#    - Headers: Blue (%K{blue}%F{black}) for sections, Yellow (%K{yellow}%F{black}) for sub-sections.
#    - Spacing: One empty line before and after headers. Use embedded \n to save lines.
#      * Exception: If a header follows another header immediately, omit the leading \n to avoid double gaps.
#    - Inputs: Yellow description line (%F{yellow}) followed by minimal prompt (read "VAR?Prompt: ").
#    - Context: Cyan (%F{cyan}) for info/metadata (prefixed with ℹ).
#    - Status: Green (%F{green}) for success/loaded, Red (%F{red}) for errors/warnings.
#    - Silence: Do not repeat/confirm manual user input. Only print confirmation (%F{green}) if the value was pre-loaded from secrets.
#
# ------------------------------------------------------------------------------

setopt ERR_EXIT NO_UNSET PIPE_FAIL

SCRIPT_DIR=${0:a:h}

sudo -v
( while true; do sudo -v; sleep 60; done; ) &
SUDO_PID=$!
trap 'kill $SUDO_PID' EXIT

print -P "\n%K{green}%F{black} STARTING SYSTEM MAINTENANCE %k%f\n"

# ------------------------------------------------------------------------------
# 1. Environment & Profile
# ------------------------------------------------------------------------------

# Purpose: Detect or prompt for the device profile to ensure correct backup labeling.

print -P "\n%K{blue}%F{black} 1. ENVIRONMENT & PROFILE %k%f\n"
if [[ -f "$HOME/.zshrc" ]]; then
    unsetopt ERR_EXIT
    ZSH_SKIP_OMZ_CHECK=1 source "$HOME/.zshrc" >/dev/null 2>&1
    setopt ERR_EXIT
fi
if [[ -n "${KWIN_PROFILE:-}" ]]; then
    PROFILE_TYPE="${(C)KWIN_PROFILE}"
    print -P "Profile: %F{green}Loaded ($PROFILE_TYPE)%f"
else
    print -P "%F{yellow}Select Device Type for Backup:%f"
    print -P "%F{cyan}ℹ 1) Desktop, 2) Laptop%f"
    read "kwin_choice?Choice [1-2]: "
    case $kwin_choice in
        1) PROFILE_TYPE="Desktop" ;;
        2) PROFILE_TYPE="Laptop" ;;
        *) print -P "%F{red}Invalid selection. Exiting.%f"; exit 1 ;;
    esac
fi

# ------------------------------------------------------------------------------
# 2. Updates (System & Firmware)
# ------------------------------------------------------------------------------

# Purpose: Upgrade all software layers and firmware.

print -P "\n%K{blue}%F{black} 2. UPDATES (SYSTEM & FIRMWARE) %k%f\n"
print -P "%K{yellow}%F{black} SYSTEM UPDATES %k%f"
print ""
yay -Syu --noconfirm
if (( $+commands[npm] )); then
    print -P "%F{cyan}ℹ Updating Gemini CLI...%f"
    sudo npm update -g @google/gemini-cli
fi
print -P "\n%K{yellow}%F{black} FIRMWARE UPDATES %k%f"
print ""
fwupdmgr refresh --force
if fwupdmgr get-updates | grep -q "Devices with updates"; then
    fwupdmgr update -y
else
    print -P "%F{yellow}No firmware updates available.%f"
fi

# ------------------------------------------------------------------------------
# 3. Cleanup
# ------------------------------------------------------------------------------

# Purpose: Reclaim disk space and manage package cache.

print -P "\n%K{blue}%F{black} 3. CLEANUP %k%f\n"
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

print -P "\n%K{blue}%F{black} 4. MEDIA INTEGRITY CHECKS %k%f\n"
if [[ "$PROFILE_TYPE" == "Desktop" ]]; then
    SERVICES=("sonarr" "radarr" "lidarr" "prowlarr" "jellyfin" "transmission" "slskd")
    print -P "%F{cyan}ℹ Verifying service group memberships...%f"
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
        print -P "%F{cyan}ℹ Enforcing Access Control Lists (ACLs)...%f"
        sudo setfacl -R -m g:media:rwX "$TARGET"
        sudo setfacl -R -m d:g:media:rwX "$TARGET"
        print -P "ACLs Enforced: %F{green}OK%f"
    else
        print -P "%F{yellow}Media drive not mounted. Skipping ACL checks.%f"
    fi
else
    print -P "%F{yellow}Skipped (Not Desktop).%f"
fi

# ------------------------------------------------------------------------------
# 5. Service Health Check
# ------------------------------------------------------------------------------

# Purpose: Ensure critical system services are enabled and running based on profile.

print -P "\n%K{blue}%F{black} 5. SERVICE HEALTH CHECK %k%f\n"
typeset -a TARGET_SERVICES
TARGET_SERVICES=(
    "NetworkManager" "bluetooth" "sshd" "sddm" "fwupd"
    "reflector.timer" "btrfs-balance.timer" "btrfs-scrub@-.timer" "timeshift-hourly.timer"
)

if [[ "$PROFILE_TYPE" == "Desktop" ]]; then
    TARGET_SERVICES+=(
        "jellyfin" "transmission" "sonarr" "radarr"
        "lidarr" "prowlarr" "slskd" "soularr.timer"
    )
    [[ -f /usr/lib/systemd/system/grub-btrfsd.service ]] && TARGET_SERVICES+=("grub-btrfsd")
elif [[ "$PROFILE_TYPE" == "Laptop" ]]; then
    TARGET_SERVICES+=("power-profiles-daemon")
fi

for svc in "${TARGET_SERVICES[@]}"; do
    if ! systemctl is-enabled "$svc" &>/dev/null; then
        print -P "%F{yellow}Enabling service: $svc%f"
        sudo systemctl enable "$svc"
    fi
    if ! systemctl is-active "$svc" &>/dev/null; then
        print -P "%F{yellow}Starting service: $svc%f"
        sudo systemctl start "$svc"
    fi
done
print -P "Service Status: %F{green}OK%f"

# ------------------------------------------------------------------------------
# 6. Visual Backup (Konsave)
# ------------------------------------------------------------------------------

# Purpose: Export and version control the current KDE Plasma configuration.

print -P "\n%K{blue}%F{black} 6. VISUAL BACKUP (KONSAVE) %k%f\n"
zmodload zsh/datetime; strftime -s DATE_STR '%Y-%m-%d' $EPOCHSECONDS
PROFILE_NAME="$PROFILE_TYPE Dock $DATE_STR"
REPO_ROOT=${SCRIPT_DIR:h}
EXPORT_DIR="$REPO_ROOT/Resources/Konsave"

if (( $+commands[konsave] )); then
    print -P "%F{cyan}ℹ Saving profile internally: $PROFILE_NAME%f"
    PYTHONWARNINGS="ignore" konsave -s "$PROFILE_NAME" -f
    if [[ -d "$EXPORT_DIR" ]]; then
        print -P "%F{cyan}ℹ Exporting to repo: $EXPORT_DIR%f"
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

print -P "\n%K{green}%F{black} SYSTEM MAINTENANCE COMPLETE %k%f\n"
