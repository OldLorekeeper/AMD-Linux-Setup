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
if [[ -f "$SCRIPT_DIR/update_kwin_rules.sh" && -f "$SCRIPT_DIR/sync_kwin_rules.sh" ]]; then
    # 1a. SYNCHRONISE: Generate the final kwinrule file from the common fragment
    bash "$SCRIPT_DIR/sync_kwin_rules.sh" laptop
    # 1b. UPDATE: Convert the generated file and apply to kwinrulesrc
    bash "$SCRIPT_DIR/update_kwin_rules.sh" laptop

    # 2. Install 'update-kwin' function into .zshrc
    echo -e "${GREEN}--- Installing 'update-kwin' auto-sync command to .zshrc ---${NC}"
    if ! grep -q "function update-kwin" "$HOME/.zshrc"; then
        cat << 'EOF' >> "$HOME/.zshrc"

# --- Added by laptop_setup.sh ---
# Syncs repo, generates final rules, and reapplies Laptop rules
function update-kwin() {
    echo -e "\033[0;32m--- Entering Git Synchronization Phase ---\033[0m"
    current_dir=$(pwd)
    cd ~/Obsidian/AMD-Linux-Setup || return

    # Check for modified common fragment and automatically commit it
    if git status --porcelain 5-Resources/Window-Rules/common.kwinrule.fragment | grep -q '^ M'; then
        echo -e "\033[1;33mUncommitted changes detected in common.kwinrule.fragment. Committing automatically...\033[0m"
        git add 5-Resources/Window-Rules/common.kwinrule.fragment
        git commit -m "AUTOSYNC: KWin common fragment update from $(hostname)"
    fi

    echo -e "\033[0;32m--- Pulling latest changes from remote ---\033[0m"
    if ! git pull; then
        echo -e "\033[0;31mError: Git pull failed. Cannot continue.\033[0m"
        cd "$current_dir"
        return 1
    fi

    echo -e "\033[0;32m--- Generating and Applying Laptop Window Rules ---\033[0m"
    ./Scripts/sync_kwin_rules.sh laptop
    ./Scripts/update_kwin_rules.sh laptop

    cd "$current_dir"
}

# Opens common.kwinrule.fragment in Kate for editing
function edit-kwin() {
    local repo_dir=~/Obsidian/AMD-Linux-Setup
    local file_path="$repo_dir/5-Resources/Window-Rules/common.kwinrule.fragment"
    if [[ -f "$file_path" ]]; then
        kate "$file_path" &
    else
        echo "File not found: $file_path"
    fi
}
EOF
        echo "Command 'update-kwin' installed."
    else
        echo "Command 'update-kwin' already exists in .zshrc."
    fi
else
    echo -e "${YELLOW}Warning: Required rule utilities not found. Skipping rules import.${NC}"
fi

# ------------------------------------------------------------------------------
# ------------------------------------------------------------------------------

# 4. End
echo -e "${YELLOW}--- Laptop-Specific Setup Complete ---${NC}"
echo "Please complete any remaining manual steps, then REBOOT."
