#!/bin/bash
# ------------------------------------------------------------------------------
# 2. User Environment Setup
# Directory structure, Git identity, and initial dotfile configuration
# ------------------------------------------------------------------------------
#
# DEVELOPMENT RULES (Read before editing):
# 1. Formatting: Keep layout compact. Remove vertical whitespace within logical blocks.
# 2. Separators: Use 'Sandwich' headers (# ------) with strict spacing (1 line before, 0 lines after).
# 3. Idempotency: Scripts must be safe to re-run. Check state before destructive actions.
# 4. Safety: Always use 'set -e'.
# 5. Context: Hardcoded for AMD Ryzen 7000/Radeon 7000. No hardcoded secrets.
# 6. Tooling: Use 'echo -e'. Prefer native bash expansion (${VAR%/*}) over sed/awk.
# 7. Documentation: Precede sections with 'Purpose'/'Rationale'. No meta-comments inside code blocks.
#
# ------------------------------------------------------------------------------

set -e

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

if [[ $EUID -eq 0 ]]; then
   echo -e "${RED}Error: Run this as your normal user, NOT root/sudo.${NC}"
   exit 1
fi

echo -e "${GREEN}--- Starting Home Setup ---${NC}"

# ------------------------------------------------------------------------------
# 1. Directory Structure
# ------------------------------------------------------------------------------

# Purpose: Create bespoke home folder layout.
# - Games: Mount point for Btrfs @games subvolume.
# - Make: Default target for git auto-cloning.
# - Obsidian: Knowledge base and repo storage.

echo -e "${GREEN}--- Creating custom home directories ---${NC}"
mkdir -p ~/{Games,Make,Obsidian} ~/.local/bin

# ------------------------------------------------------------------------------
# 2. Git Identity
# ------------------------------------------------------------------------------

# Purpose: Bootstrap global git config and credentials.
# - Idempotency: Checks for existing user.name.
# - Auth: Prompts for GitHub PAT (required for HTTPS).
# - Helper: Uses libsecret for KWallet integration.

echo -e "${GREEN}--- Configuring git ---${NC}"
if git config --global user.name > /dev/null; then
    echo -e "${YELLOW}Git identity already configured.${NC}"
else
    read -p "Enter GitHub Email: " git_email
    read -s -p "Enter GitHub PAT: " git_pat; echo ""
    read -p "Enter GitHub Username: " git_user
    git config --global credential.helper libsecret
    git config --global user.email "$git_email"
    git config --global user.password "$git_pat"
    git config --global user.name "$git_user"
fi

# ------------------------------------------------------------------------------
# 3. Clone Repository
# ------------------------------------------------------------------------------

# Purpose: Ensure local availability of the config repo.
# - Location: ~/Obsidian/AMD-Linux-Setup.
# - Logic: Clone only if missing (safe re-run).

REPO_DIR="$HOME/Obsidian/AMD-Linux-Setup"
if [ ! -d "$REPO_DIR" ]; then
    echo -e "${GREEN}--- Cloning AMD-Linux-Setup repo ---${NC}"
    git clone https://github.com/OldLorekeeper/AMD-Linux-Setup "$REPO_DIR"
fi

# ------------------------------------------------------------------------------
# 4. Btrfs @games Subvolume
# ------------------------------------------------------------------------------

# Purpose: Optimise storage for gaming.
# - Setup: Mounts root (ID 5), creates @games, updates fstab.
# - Optimization: Applies +C (No-CoW) to reduce fragmentation.
# - Mounts: Uses discard=async and zstd:3.

echo -e "${GREEN}--- Setting up @games subvolume ---${NC}"
MOUNT_POINT="$HOME/Games"
ROOT_DEVICE=$(findmnt -n -o SOURCE /); ROOT_DEVICE=${ROOT_DEVICE%[*}
DEVICE_UUID=$(blkid -s UUID -o value "$ROOT_DEVICE")

if [ -z "$DEVICE_UUID" ]; then
    echo -e "${RED}Error: Could not detect root device UUID.${NC}"
else
    TEMP_MNT=$(mktemp -d)
    sudo mount -o subvolid=5 "$ROOT_DEVICE" "$TEMP_MNT"
    if [ ! -d "$TEMP_MNT/@games" ]; then
        sudo btrfs subvolume create "$TEMP_MNT/@games"
    fi
    sudo umount "$TEMP_MNT"
    rmdir "$TEMP_MNT"

    if ! grep -Fq "$MOUNT_POINT" /etc/fstab; then
        echo "UUID=$DEVICE_UUID $MOUNT_POINT btrfs rw,noatime,compress=zstd:3,ssd,discard=async,space_cache=v2,subvol=/@games 0 0" | sudo tee -a /etc/fstab
    fi

    sudo systemctl daemon-reload
    mountpoint -q "$MOUNT_POINT" || sudo mount "$MOUNT_POINT"
    sudo chown -R "$USER:$(id -gn "$USER")" "$MOUNT_POINT"

    if ! lsattr -d "$MOUNT_POINT" | awk '{print $1}' | grep -q 'C'; then
        sudo chattr +C "$MOUNT_POINT"
        echo -e "${GREEN}--- Applied No-CoW (+C) attribute to $MOUNT_POINT ---${NC}"
    else
        echo -e "${YELLOW}No-CoW (+C) attribute already set on $MOUNT_POINT.${NC}"
    fi
fi

# ------------------------------------------------------------------------------
# 5. ZSH & Oh-My-Zsh
# ------------------------------------------------------------------------------

# Purpose: Standardise user/root shell environment.
# - Install: OMZ, autosuggestions, syntax-highlighting.
# - Root: Symlinks user config to /root for consistency.
# - Aliases: Injects 'git' (auto-clone) and 'maintain' wrappers.

echo -e "${GREEN}--- Installing Oh-My-Zsh for user and root ---${NC}"
if [ -d "$HOME/.oh-my-zsh" ]; then
    echo -e "${YELLOW}Oh-My-Zsh already installed for user. Skipping.${NC}"
else
    echo "Installing for user $USER..."
    sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
fi

echo "Setting up Oh-My-Zsh for root (via symlinks)..."
sudo rm -f /root/.zshrc
sudo rm -rf /root/.oh-my-zsh
sudo ln -sf "$HOME/.oh-my-zsh" /root/.oh-my-zsh
sudo ln -sf "$HOME/.zshrc" /root/.zshrc

ZSH_CUSTOM=${ZSH_CUSTOM:-~/.oh-my-zsh/custom}
PLUGINS=(
    "zsh-users/zsh-autosuggestions"
    "zsh-users/zsh-syntax-highlighting"
)
for repo in "${PLUGINS[@]}"; do
    plugin_name=$(basename "$repo")
    if [ ! -d "$ZSH_CUSTOM/plugins/$plugin_name" ]; then
        git clone "https://github.com/$repo" "$ZSH_CUSTOM/plugins/$plugin_name"
    fi
done

sed -i 's/^plugins=(git)$/plugins=(git archlinux zsh-autosuggestions zsh-syntax-highlighting)/' "$HOME/.zshrc"

echo -e "${GREEN}--- Updating custom aliases ---${NC}"
START_MARKER="# Start Custom Aliases"
END_MARKER="# End Custom Aliases"
ZSHRC="$HOME/.zshrc"

if grep -qF "$START_MARKER" "$ZSHRC"; then
    sed -i "/$START_MARKER/,/$END_MARKER/d" "$ZSHRC"
fi

cat << 'EOF' >> "$ZSHRC"
# Start Custom Aliases
export PATH="$HOME/.local/bin:$PATH"

alias mkinit="sudo mkinitcpio -P"
alias mkgrub="sudo grub-mkconfig -o /boot/grub/grub.cfg"

git() {
    if (( EUID == 0 )); then
        command git "$@"
        return
    fi
    if [[ "$1" == "clone" && -n "$2" && -z "$3" ]]; then
        if [[ "$PWD" == "$HOME" ]]; then
            print -P "%F{yellow}Auto-cloning to ~/Make...%f"
            local repo_name="${${2:t}%.git}"
            command git clone "$2" "$HOME/Make/$repo_name"
        else
            command git clone "$2"
        fi
    else
        command git "$@"
    fi
}
EOF

cat << EOF >> "$ZSHRC"

maintain() {
    local script="$REPO_DIR/Scripts/system_maintain.zsh"
    if [[ -f "\$script" ]]; then
        [[ -x "\$script" ]] || chmod +x "\$script"
        "\$script"
    else
        print -P "%F{red}Error: Maintenance script not found at:%f\n\$script"
        return 1
    fi
}
# End Custom Aliases
EOF
echo -e "${GREEN}Aliases injected/updated in .zshrc${NC}"

# ------------------------------------------------------------------------------
# 6. Konsole Profiles
# ------------------------------------------------------------------------------

# Purpose: Apply visual consistency.
# - Action: Installs schemes/profiles to ~/.local/share/konsole.
# - Error Handling: Silently skips if resources missing.

echo -e "${GREEN}--- Installing Konsole profiles ---${NC}"
mkdir -p "$HOME/.local/share/konsole"
if [ -d "$REPO_DIR/Resources/Konsole" ]; then
    cp -f "$REPO_DIR/Resources/Konsole"/* "$HOME/.local/share/konsole/" 2>/dev/null
else
    echo -e "${YELLOW}Warning: Konsole resources not found.${NC}"
fi

# ------------------------------------------------------------------------------
# End
# ------------------------------------------------------------------------------

echo -e "${GREEN}--- Home setup complete. Relogin to apply ZSH changes. ---${NC}"
