#!/bin/zsh
# ------------------------------------------------------------------------------
# System Maintenance & Backup
# Updates system, firmware, cleans cache, checks services, and backups Konsave profile.
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
#                                ii) Omit top `\n` on consecutive markers.
#                                ii) Context (Cyan) markers MUST include a trailing `\n`.
#
# ------------------------------------------------------------------------------

# BEGIN
setopt ERR_EXIT NO_UNSET PIPE_FAIL EXTENDED_GLOB
SCRIPT_DIR=${0:a:h}
sudo -v
( while true; do sudo -v; sleep 60; done; ) &
SUDO_PID=$!
trap 'kill $SUDO_PID' EXIT
print -P "\n%K{green}%F{black} STARTING SYSTEM MAINTENANCE %k%f\n"
# END

# ------------------------------------------------------------------------------
# 1. Environment & Profile
# ------------------------------------------------------------------------------

# Purpose: Loads user shell configuration to ensure environment variables are present and detects the device profile (Desktop/Laptop). Prompts user if profile is missing.

# BEGIN
print -P "%K{blue}%F{black} 1. ENVIRONMENT & PROFILE %k%f\n"
if [[ -f "$HOME/.zshrc" ]]; then
    unsetopt ERR_EXIT
    ZSH_SKIP_OMZ_CHECK=1 source "$HOME/.zshrc" >/dev/null 2>&1
    setopt ERR_EXIT
fi
if [[ -n "${SYS_PROFILE:-}" ]]; then
    PROFILE_TYPE="${(C)SYS_PROFILE}"
    print -P "Profile:      %F{green}Loaded ($PROFILE_TYPE)%f"
else
    print -P "%F{yellow}Select Device Type for Backup:%f"
    print -P "%F{cyan}ℹ Context: Determines backup labeling and service checks.%f\n"
    read "kwin_choice?Choice [1=Desktop, 2=Laptop]: "
    case $kwin_choice in
        1) PROFILE_TYPE="Desktop" ;;
        2) PROFILE_TYPE="Laptop" ;;
        *) print -P "%F{red}Invalid selection. Exiting.%f"; exit 1 ;;
    esac
fi
# END

# ------------------------------------------------------------------------------
# 2. Updates (System & Firmware)
# ------------------------------------------------------------------------------

# Purpose: Performs a layered update: Zsh plugins, System packages (Yay), Gemini CLI, Firmware (fwupd), and Soularr application/dependencies.

# BEGIN
print -P "\n%K{blue}%F{black} 2. UPDATES (SYSTEM & FIRMWARE) %k%f\n"
print -P "%K{yellow}%F{black} ZSH PLUGIN UPDATES %k%f\n"
ZSH_CUSTOM="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}"
for plugin in "$ZSH_CUSTOM"/plugins/*/.git(N:h); do
    print -P "Updating plugin: %F{cyan}${plugin:t}%f"
    git -C "$plugin" pull
done
print -P "\n%K{yellow}%F{black} SYSTEM UPDATES %k%f\n"
yay -Syu --noconfirm
print -P "\n%K{yellow}%F{black} UPDATE GEMINI %k%f\n"
if (( $+commands[npm] )); then
    print -P "%F{cyan}ℹ Updating Gemini CLI...%f\n"
    sudo npm update -g @google/gemini-cli
fi
print -P "\n%K{yellow}%F{black} FIRMWARE UPDATES %k%f\n"
fwupdmgr refresh --force
if fwupdmgr get-updates | grep -q "Devices with updates"; then
    fwupdmgr update -y
else
    print -P "%F{yellow}No firmware updates available.%f"
fi
print -P "\n%K{yellow}%F{black} SOULARR UPDATES %k%f\n"
SOULARR_DIR="/opt/soularr"
if [[ -d "$SOULARR_DIR" ]]; then
    print -P "%F{cyan}ℹ Checking Soularr updates...%f\n"
    if git -C "$SOULARR_DIR" pull | grep -q "Already up to date"; then
         print -P "%F{green}Soularr is up to date.%f"
    else
         print -P "%F{green}Soularr updated. Refreshing Python dependencies...%f"
         uv pip install -U -r "$SOULARR_DIR/requirements.txt" --python "$SOULARR_DIR/.venv"
         print -P "%F{yellow}Restarting Soularr service...%f"
         sudo systemctl restart soularr.timer
    fi
else
    print -P "%F{yellow}Soularr directory not found. Skipping.%f"
fi
# END

# ------------------------------------------------------------------------------
# 3. Cleanup
# ------------------------------------------------------------------------------

# Purpose: Removes orphan packages and trims the pacman package cache to the latest 3 versions. Displays current Btrfs usage.

# BEGIN
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
print -P "\n%F{cyan}ℹ Btrfs Filesystem Usage:%f\n"
sudo btrfs filesystem usage / -h | grep -E "Device size:|Free \(estimated\):"
if mountpoint -q /mnt/Media; then
    print -P "%F{cyan}ℹ Media Drive Usage:%f\n"
    sudo btrfs filesystem usage /mnt/Media -h | grep -E "Device size:|Free \(estimated\):"
fi
# END

# ------------------------------------------------------------------------------
# 4. Media Integrity Checks (Desktop Only)
# ------------------------------------------------------------------------------

# Purpose: Enforces group membership and ACLs on the Media drive to prevent permission drift. Skips if not on Desktop profile.

# BEGIN
print -P "\n%K{blue}%F{black} 4. MEDIA INTEGRITY CHECKS %k%f\n"
if [[ "$PROFILE_TYPE" == "Desktop" ]]; then
    SERVICES=("sonarr" "radarr" "lidarr" "prowlarr" "jellyfin" "transmission" "slskd")
    print -P "%F{cyan}ℹ Verifying service group memberships...%f\n"
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
        print -P "%F{cyan}ℹ Enforcing Access Control Lists (ACLs)...%f\n"
        sudo setfacl -R -m g:media:rwX "$TARGET"
        sudo setfacl -R -m d:g:media:rwX "$TARGET"
        print -P "ACLs Enforced: %F{green}OK%f"
    else
        print -P "%F{yellow}Media drive not mounted. Skipping ACL checks.%f"
    fi
else
    print -P "%F{yellow}Skipped (Not Desktop).%f"
fi
# END

# ------------------------------------------------------------------------------
# 5. Service Health Check
# ------------------------------------------------------------------------------

# Purpose: Validates that critical services are enabled and active. Dynamically builds the service list based on the active Device Profile.

# BEGIN
print -P "\n%K{blue}%F{black} 5. SERVICE HEALTH CHECK %k%f\n"
typeset -a TARGET_SERVICES
TARGET_SERVICES=(
    "NetworkManager" "bluetooth" "sshd" "sddm" "fwupd"
    "reflector.timer" "btrfs-balance.timer" "btrfs-scrub@-.timer" "timeshift-hourly.timer"
)
if [[ "$PROFILE_TYPE" == "Desktop" ]]; then
    TARGET_SERVICES+=(
        "jellyfin" "transmission" "sonarr" "radarr"
        "lidarr" "prowlarr" "slskd" "soularr.timer" "lactd"
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
# END

# ------------------------------------------------------------------------------
# 6. Visual Backup (Konsave)
# ------------------------------------------------------------------------------

# Purpose: Exports the current KDE Plasma configuration via Konsave to the local repo and prunes old backups to maintain a history of 3.

# BEGIN
print -P "\n%K{blue}%F{black} 6. VISUAL BACKUP (KONSAVE) %k%f\n"
zmodload zsh/datetime; strftime -s DATE_STR '%Y-%m-%d' $EPOCHSECONDS
PROFILE_NAME="$PROFILE_TYPE Dock $DATE_STR"
REPO_ROOT=${SCRIPT_DIR:h}
EXPORT_DIR="$REPO_ROOT/Resources/Konsave"
if (( $+commands[konsave] )); then
    print -P "%F{cyan}ℹ Saving profile internally: $PROFILE_NAME%f\n"
    PYTHONWARNINGS="ignore" konsave -s "$PROFILE_NAME" -f
    if [[ -d "$EXPORT_DIR" ]]; then
        print -P "%F{cyan}ℹ Exporting to repo: $EXPORT_DIR%f\n"
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
# END

# ------------------------------------------------------------------------------
# End
# ------------------------------------------------------------------------------

# BEGIN
print -P "\n%K{green}%F{black} SYSTEM MAINTENANCE COMPLETE %k%f\n"
# END

# kate: hl Zsh; folding-markers on;
