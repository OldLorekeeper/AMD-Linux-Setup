#!/bin/bash
#
# This script installs laptop-specific packages and enables services.
# Run this *after* core_setup.sh
#

set -e

# Colour Codes
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}--- Starting Laptop-Specific Setup ---${NC}"

# ------------------------------------------------------------------------------
# ------------------------------------------------------------------------------

# 1. Install laptop packages from list
echo -e "${GREEN}--- Installing laptop packages from laptop_pkg.txt ---${NC}"
SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
yay -S --needed --noconfirm - < "$SCRIPT_DIR/laptop_pkg.txt"

# ------------------------------------------------------------------------------
# ------------------------------------------------------------------------------

# 2. Enable laptop services
echo -e "${GREEN}--- Enabling laptop services ---${NC}"
sudo systemctl enable --now power-profiles-daemon.service

# 2.1 Enable Numlock Hook
echo -e "${GREEN}--- enabling numlock in mkinitcpio ---${NC}"
if ! grep -q "numlock" /etc/mkinitcpio.conf; then
    # Insert 'numlock' before 'autodetect' hook for early activation
    sudo sed -i 's/\(HOOKS=.*\) autodetect/\1 numlock autodetect/' /etc/mkinitcpio.conf
    # Trigger rebuild (handled by pacman hook usually, but good to force here if changing config)
    sudo mkinitcpio -P
else
    echo "Numlock hook already present."
fi

# ------------------------------------------------------------------------------
# ------------------------------------------------------------------------------

# 3. Apply Laptop Kernel Parameters
echo -e "${GREEN}--- Applying laptop-specific kernel parameters ---${NC}"
# Define laptop-specific parameters (GPU Features, Power features, Hugepages, Resolution, Active P-State)
PARAMS="amdgpu.ppfeaturemask=0xffffffff hugepages=512 video=2560x1600@60 amd_pstate=active"
# Check if parameters already exist to prevent duplication
if grep -q "amdgpu.ppfeaturemask" /etc/default/grub; then
    echo -e "${YELLOW}Kernel parameters appear to be already set. Skipping append.${NC}"
else
    # Appends PARAMS to the GRUB_CMDLINE_LINUX_DEFAULT line
    sudo sed -i "s/^\(GRUB_CMDLINE_LINUX_DEFAULT=\"[^\"]*\)\"$/\1 $PARAMS\"/" /etc/default/grub

    echo -e "${GREEN}--- Rebuilding GRUB configuration ---${NC}"
    sudo grub-mkconfig -o /boot/grub/grub.cfg
fi

# ------------------------------------------------------------------------------
# ------------------------------------------------------------------------------

# 4. Import KWin Rules & Install Alias
echo -e "${GREEN}--- Importing Laptop Window Rules ---${NC}"
# A. Set Persistent Profile Variable (Fixes "No profile specified" error)
echo -e "${GREEN}--- Setting KWIN_PROFILE to 'laptop' in .zshrc ---${NC}"
# Check if variable is already exported to prevent duplicate lines
if ! grep -q "export KWIN_PROFILE=" "$HOME/.zshrc"; then
    echo 'export KWIN_PROFILE="laptop"' >> "$HOME/.zshrc"
    # Export immediately for the current script's session
    export KWIN_PROFILE="laptop"
fi
# B. Apply Rules Immediately
if [[ -f "$SCRIPT_DIR/apply_kwin_rules.sh" ]]; then
    chmod +x "$SCRIPT_DIR/apply_kwin_rules.sh"
    "$SCRIPT_DIR/apply_kwin_rules.sh" laptop
else
    echo -e "${YELLOW}Warning: apply_kwin_rules.sh not found. Skipping immediate application.${NC}"
fi
# C. Install Smart 'update-kwin' and 'edit-kwin' functions
echo -e "${GREEN}--- Installing smart KWin functions to .zshrc ---${NC}"
if ! grep -q "function update-kwin" "$HOME/.zshrc"; then
    cat << 'EOF' >> "$HOME/.zshrc"

function update-kwin() {
    # Default to KWIN_PROFILE if set, otherwise require argument
    local target="${1:-$KWIN_PROFILE}"

    if [[ -z "$target" ]]; then
        echo "Error: No profile specified and KWIN_PROFILE not set."
        return 1
    fi

    echo -e "\033[0;32m--- Syncing and Updating for Profile: $target ---\033[0m"
    current_dir=$(pwd)
    cd ~/Obsidian/AMD-Linux-Setup || return

    # Auto-commit common fragment changes
    if git status --porcelain 5-Resources/Window-Rules/common.kwinrule.fragment | grep -q '^ M'; then
        echo -e "\033[1;33mCommitting changes to common.kwinrule.fragment...\033[0m"
        # FIX: Use ${HOST} (Zsh built-in) instead of missing 'hostname' binary
        git add 5-Resources/Window-Rules/common.kwinrule.fragment
        git commit -m "AUTOSYNC: KWin common fragment update from ${HOST}"
    fi

    if ! git pull; then
        echo -e "\033[0;31mError: Git pull failed.\033[0m"
        cd "$current_dir"
        return 1
    fi

    ./Scripts/apply_kwin_rules.sh "$target"
    cd "$current_dir"
}

function edit-kwin() {
    local target="${1:-$KWIN_PROFILE}"
    local repo_dir=~/Obsidian/AMD-Linux-Setup/5-Resources/Window-Rules
    local file_path=""

    case "$target" in
        "desktop") file_path="$repo_dir/desktop.rule.template" ;;
        "laptop")  file_path="$repo_dir/laptop.rule.template" ;;
        "common")  file_path="$repo_dir/common.kwinrule.fragment" ;;
        *)         file_path="$repo_dir/common.kwinrule.fragment" ;;
    esac

    if [[ -f "$file_path" ]]; then
        echo "Opening template for: $target"
        kate "$file_path" &
    else
        echo "Error: File not found: $file_path"
    fi
}
EOF
    echo "Smart KWin functions installed."
else
    echo "Functions already exist in .zshrc."
fi

# ------------------------------------------------------------------------------
# ------------------------------------------------------------------------------

# 4. End
echo -e "${YELLOW}--- Laptop-Specific Setup Complete ---${NC}"
echo "Please complete any remaining manual steps, then REBOOT."
