#!/bin/bash
# ------------------------------------------------------------------------------
# 2. User Environment Setup
# Directory structure, Git identity, and initial dotfile configuration
# ------------------------------------------------------------------------------
#
# DEVELOPMENT RULES (Read before editing):
# 1. Formatting: Keep layout compact. Remove vertical whitespace within logical blocks.
# 2. Separators: Use double dotted lines (# ------) to separate major stages.
# 3. Idempotency: Scripts must be safe to re-run. Check state before destructive actions.
# 4. Safety: Always use 'set -e'.
# 5. Context: Hardcoded for AMD Ryzen 7000/Radeon 7000. No hardcoded secrets.
# 6. Tooling: Use 'echo -e'. Prefer native bash expansion (${VAR%/*}) over sed/awk.
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
# ------------------------------------------------------------------------------

# 1. Directory Structure
echo -e "${GREEN}--- Creating Directories ---${NC}"
mkdir -p ~/{Games,Make,Obsidian} ~/.local/bin

# 2. Git Identity
echo -e "${GREEN}--- Configuring Git ---${NC}"
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

# 3. Clone Repository
REPO_DIR="$HOME/Obsidian/AMD-Linux-Setup"
if [ ! -d "$REPO_DIR" ]; then
    echo -e "${GREEN}--- Cloning Setup Repo ---${NC}"
    git clone https://github.com/OldLorekeeper/AMD-Linux-Setup "$REPO_DIR"
fi

# ------------------------------------------------------------------------------
# ------------------------------------------------------------------------------

# 4. Btrfs @games Subvolume
echo -e "${GREEN}--- Setting up @games Subvolume ---${NC}"
MOUNT_POINT="$HOME/Games"
ROOT_DEVICE=$(findmnt -n -o SOURCE /); ROOT_DEVICE=${ROOT_DEVICE%[*}
DEVICE_UUID=$(blkid -s UUID -o value "$ROOT_DEVICE")

if [ -z "$DEVICE_UUID" ]; then
    echo -e "${RED}Error: Could not detect root device UUID.${NC}"
else
    # Mount root (subvolid=5) temporarily
    TEMP_MNT=$(mktemp -d)
    sudo mount -o subvolid=5 "$ROOT_DEVICE" "$TEMP_MNT"

    # Create subvolume if missing
    if [ ! -d "$TEMP_MNT/@games" ]; then
        sudo btrfs subvolume create "$TEMP_MNT/@games"
    fi
    sudo umount "$TEMP_MNT"
    rmdir "$TEMP_MNT"

    # Add to fstab (Idempotent)
    if ! grep -Fq "$MOUNT_POINT" /etc/fstab; then
        echo "UUID=$DEVICE_UUID $MOUNT_POINT btrfs rw,noatime,compress=zstd:3,ssd,discard=async,space_cache=v2,subvol=/@games 0 0" | sudo tee -a /etc/fstab
    fi

    # Mount and set permissions
    sudo systemctl daemon-reload
    mountpoint -q "$MOUNT_POINT" || sudo mount "$MOUNT_POINT"
    sudo chown -R "$USER:$(id -gn "$USER")" "$MOUNT_POINT"

    # OPTIMISATION: Disable CoW for Games to prevent fragmentation/stuttering
    # FIX: Use awk to check attribute column specifically, avoiding 'grep' backslash warnings
    if ! lsattr -d "$MOUNT_POINT" | awk '{print $1}' | grep -q 'C'; then
        sudo chattr +C "$MOUNT_POINT"
        echo -e "${GREEN}--- Applied No-CoW (+C) attribute to $MOUNT_POINT ---${NC}"
    else
        echo -e "${YELLOW}No-CoW (+C) attribute already set on $MOUNT_POINT.${NC}"
    fi
fi

# ------------------------------------------------------------------------------
# ------------------------------------------------------------------------------

# 5. ZSH & Oh-My-Zsh
echo -e "${GREEN}--- Installing Oh-My-Zsh for User and Root ---${NC}"
# Install for User
if [ -d "$HOME/.oh-my-zsh" ]; then
    echo -e "${YELLOW}Oh-My-Zsh already installed for user. Skipping.${NC}"
else
    echo "Installing for user $USER..."
    sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
fi

# Link for Root
# FIX: Do NOT run installer for root. It fails if the folder exists, and we delete it anyway.
# We just force the symlinks directly.
echo "Setting up Oh-My-Zsh for root (via symlinks)..."
sudo rm -f /root/.zshrc
sudo rm -rf /root/.oh-my-zsh
sudo ln -sf "$HOME/.oh-my-zsh" /root/.oh-my-zsh
sudo ln -sf "$HOME/.zshrc" /root/.zshrc

# Plugins
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

# .zshrc Customisation
sed -i 's/^plugins=(git)$/plugins=(git archlinux zsh-autosuggestions zsh-syntax-highlighting)/' "$HOME/.zshrc"

echo -e "${GREEN}--- Updating Custom Aliases ---${NC}"

# Define Markers
START_MARKER="# Start Custom Aliases"
END_MARKER="# End Custom Aliases"
ZSHRC="$HOME/.zshrc"

# Clean up existing block (Idempotency)
if grep -qF "$START_MARKER" "$ZSHRC"; then
    sed -i "/$START_MARKER/,/$END_MARKER/d" "$ZSHRC"
fi

# Inject fresh block
# Note: We split this into two parts.
# Part 1: Quoted heredoc (<< 'EOF') for 'git' function to PROTECT Zsh variables (${2:t}) from Bash expansion.
# Part 2: Unquoted heredoc (<< EOF) for 'maintain' alias to EXPAND $REPO_DIR from this script.

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
# ------------------------------------------------------------------------------

# 6. Konsole Profiles
echo -e "${GREEN}--- Installing Konsole Profiles ---${NC}"
mkdir -p "$HOME/.local/share/konsole"
if [ -d "$REPO_DIR/Resources/Konsole" ]; then
    cp -f "$REPO_DIR/Resources/Konsole"/* "$HOME/.local/share/konsole/" 2>/dev/null
else
    echo -e "${YELLOW}Warning: Konsole resources not found.${NC}"
fi

# ------------------------------------------------------------------------------
# ------------------------------------------------------------------------------

echo -e "${GREEN}--- Home Setup Complete. Relogin to apply ZSH changes. ---${NC}"
