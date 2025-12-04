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

# 4. Media Integrity Checks (Desktop Only)
if [[ "$PROFILE_TYPE" == "Desktop" ]]; then
    print "${GREEN}--- Media Integrity Checks ---${NC}"

    # A. Transmission Config Check
    # Updated: Casts value to int() to handle "2" (string) vs 2 (integer) mismatch.
    TRANS_CONFIG="/var/lib/transmission/.config/transmission-daemon/settings.json"
    if sudo test -f "$TRANS_CONFIG"; then
        if ! sudo python3 -c "import json, sys; sys.exit(0 if int(json.load(open('$TRANS_CONFIG')).get('umask', 18)) == 2 else 1)"; then
            print "${YELLOW}Detected incorrect Transmission umask. Fixing...${NC}"
            sudo systemctl stop transmission
            sudo python - <<EOF
import json
path = '$TRANS_CONFIG'
try:
    with open(path, 'r') as f:
        data = json.load(f)

    # Force integer 2
    data['umask'] = 2

    with open(path, 'w') as f:
        json.dump(data, f, indent=4)
    print("Success: Updated Transmission umask to 2")
except Exception as e:
    print(f"Error patching JSON: {e}")
EOF
            sudo systemctl start transmission
            print "Fixed Transmission settings."
        else
            print "Transmission Settings: ${GREEN}OK${NC}"
        fi
    else
        print "${YELLOW}Transmission config not found (Skipping check).${NC}"
    fi

    # B. Service Group Membership (Anti-Drift)
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

    # C. Filesystem Permissions
    TARGET="/mnt/Media"
    if grep -q "$TARGET" /proc/mounts; then
        print "Verifying Media Drive permissions..."

        # 1. Fix Group Ownership
        if sudo find "$TARGET" -not -group media -print -quit | grep -q .; then
            print "${YELLOW}Fixing group ownership on $TARGET...${NC}"
            sudo chown -R :media "$TARGET"
        fi

        # 2. Fix Directory Permissions (SetGID)
        if sudo find "$TARGET" -type d -not -perm -2775 -print -quit | grep -q .; then
            print "${YELLOW}Fixing directory permissions (SetGID)...${NC}"
            sudo find "$TARGET" -type d -not -perm -2775 -exec chmod 2775 {} +
        fi

        # 3. Fix File Permissions
        DOWNLOADS="$TARGET/Downloads"
        if [[ -d "$DOWNLOADS" ]]; then
            if sudo find "$DOWNLOADS" -type f -not -perm -0664 -print -quit | grep -q .; then
                print "${YELLOW}Fixing file permissions in Downloads...${NC}"
                sudo find "$DOWNLOADS" -type f -not -perm -0664 -exec chmod 0664 {} +
            fi
        fi
        print "Filesystem Permissions: ${GREEN}OK${NC}"
    else
        print "${YELLOW}Media drive not mounted. Skipping filesystem checks.${NC}"
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
            for path in "${internal_profiles[@][4,-1]}"; do
                PYTHONWARNINGS="ignore" konsave -r "${path:t}" -f
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
