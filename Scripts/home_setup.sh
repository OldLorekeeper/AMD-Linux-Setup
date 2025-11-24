#!/bin/bash
#
# This script automates Section 2.1 of the setup guide:
# 1. Creates standard home directories (Games, Make, Obsidian)
# 2. Clones the AMD-Linux-Setup repository
# 3. Automatically detects Btrfs root, creates @games subvolume, and mounts it
# 4. Installs and configures Oh-My-Zsh, plugins, and custom aliases
#

set -e

# Colour Codes
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# 0. Root user check
if [[ $EUID -eq 0 ]]; then
   echo -e "${RED}Error: This script must NOT be run as root/sudo.${NC}"
   echo "It relies on \$HOME and \$USER to configure your personal environment."
   echo "Please run it as your normal user:"
   echo "  ./home_setup.sh"
   exit 1
fi

echo -e "${GREEN}--- Starting Home Folder Setup ---${NC}"

# ------------------------------------------------------------------------------
# ------------------------------------------------------------------------------

# 1. Create Folders
echo -e "${GREEN}--- Creating standard directories ---${NC}"
mkdir -p ~/{Games,Make,Obsidian}

# ------------------------------------------------------------------------------
# ------------------------------------------------------------------------------

# 2. Git Identity Setup
echo -e "${GREEN}--- Configuring Git Identity ---${NC}"
if git config --global user.name > /dev/null; then
    echo -e "${YELLOW}Git identity already configured. Skipping.${NC}"
else
    read -p "Enter GitHub Email: " git_email
    read -s -p "Enter GitHub Personal Access Token (PAT): " git_pat
    echo ""
    read -p "Enter GitHub Username: " git_user

    # Apply configuration in requested order
    git config --global credential.helper libsecret
    git config --global user.email "$git_email"
    git config --global user.password "$git_pat"
    git config --global user.name "$git_user"

    echo "Git identity configured."
fi

# 2a. Clone Repo
echo -e "${GREEN}--- Cloning AMD-Linux-Setup repository ---${NC}"
if [ -d "$HOME/Obsidian/AMD-Linux-Setup" ]; then
    echo -e "${YELLOW}Repo already exists. Skipping clone.${NC}"
else
    git clone https://github.com/OldLorekeeper/AMD-Linux-Setup "$HOME/Obsidian/AMD-Linux-Setup"
fi

# ------------------------------------------------------------------------------
# ------------------------------------------------------------------------------

# 3. Setup @games Subvolume
echo -e "${GREEN}--- Setting up @games Btrfs subvolume ---${NC}"
MOUNT_POINT="$HOME/Games"
FSTAB_FILE="/etc/fstab"
# Identify Root Device (Source of /)
ROOT_DEVICE=$(findmnt -n -o SOURCE / | sed 's/\[.*\]//')
DEVICE_UUID=$(blkid -s UUID -o value "$ROOT_DEVICE")
if [ -z "$DEVICE_UUID" ]; then
    echo -e "${YELLOW}Error: Could not detect root device UUID. Skipping games subvolume setup.${NC}"
else
    # Mount Top-Level Subvolume (ID 5) to temp path
    TEMP_MNT=$(mktemp -d)
    echo "Mounting Btrfs root ($ROOT_DEVICE) to temporary path..."
    sudo mount -o subvolid=5 "$ROOT_DEVICE" "$TEMP_MNT"
    # Create @games Subvolume
    if [ -d "$TEMP_MNT/@games" ]; then
        echo -e "${YELLOW}Subvolume @games already exists. Skipping creation.${NC}"
    else
        echo "Creating @games subvolume..."
        sudo btrfs subvolume create "$TEMP_MNT/@games"
    fi
    # Unmount temp
    sudo umount "$TEMP_MNT"
    rmdir "$TEMP_MNT"
    # Configure fstab
    FSTAB_LINE="UUID=$DEVICE_UUID $MOUNT_POINT btrfs rw,noatime,compress=zstd:3,ssd,discard=async,space_cache=v2,subvol=/@games 0 0"
    if grep -Fq "$MOUNT_POINT" "$FSTAB_FILE"; then
        echo -e "${YELLOW}Entry for $MOUNT_POINT already exists in fstab. Skipping edit.${NC}"
    else
        echo "Adding entry to $FSTAB_FILE..."
        echo "$FSTAB_LINE" | sudo tee -a "$FSTAB_FILE"
    fi
    # Mount and Fix Permissions
    echo "Mounting games library..."
    sudo systemctl daemon-reload
    sudo mount "$MOUNT_POINT" 2>/dev/null || echo -e "${YELLOW}Mount attempted (it may already be mounted).${NC}"
    echo "Setting ownership of $MOUNT_POINT to $USER..."
    sudo chown -R "$USER:$(id -gn "$USER")" "$MOUNT_POINT"
fi

# ------------------------------------------------------------------------------
# ------------------------------------------------------------------------------

# 4. Install Oh-My-Zsh
echo -e "${GREEN}--- Installing Oh-My-Zsh for User and Root ---${NC}"
# Install for User
if [ -d "$HOME/.oh-my-zsh" ]; then
    echo -e "${YELLOW}Oh-My-Zsh already installed for user. Skipping.${NC}"
else
    echo "Installing for user $USER..."
    sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
fi
# Install for Root (and symlink)
echo "Setting up Oh-My-Zsh for root (via symlinks)..."
if [ ! -d "/root/.oh-my-zsh" ]; then
    sudo sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
fi
# Remove default root files and symlink to user's config
sudo rm -f /root/.zshrc
sudo rm -rf /root/.oh-my-zsh
sudo ln -sf "$HOME/.oh-my-zsh" /root/.oh-my-zsh
sudo ln -sf "$HOME/.zshrc" /root/.zshrc

# ------------------------------------------------------------------------------
# ------------------------------------------------------------------------------

# 5. Install ZSH Plugins
echo -e "${GREEN}--- Installing ZSH plugins ---${NC}"
ZSH_CUSTOM="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}"
PLUGINS_DIR="$ZSH_CUSTOM/plugins"
mkdir -p "$PLUGINS_DIR"
# List of plugins to clone
declare -A plugins
plugins=(
    ["zsh-autosuggestions"]="https://github.com/zsh-users/zsh-autosuggestions"
    ["zsh-syntax-highlighting"]="https://github.com/zsh-users/zsh-syntax-highlighting.git"
    ["you-should-use"]="https://github.com/MichaelAquilina/zsh-you-should-use.git"
)
for plugin_name in "${!plugins[@]}"; do
    if [ ! -d "$PLUGINS_DIR/$plugin_name" ]; then
        echo "Cloning $plugin_name..."
        git clone "${plugins[$plugin_name]}" "$PLUGINS_DIR/$plugin_name"
    else
        echo -e "${YELLOW}$plugin_name already exists.${NC}"
    fi
done

# ------------------------------------------------------------------------------
# ------------------------------------------------------------------------------

# 6. Configure .zshrc
echo -e "${GREEN}--- Customising .zshrc ---${NC}"
# Set the correct plugin list
sed -i 's/^plugins=(git)$/plugins=(git archlinux zsh-autosuggestions zsh-syntax-highlighting you-should-use)/' "$HOME/.zshrc"
# Add custom aliases and git function if not already present
if ! grep -q "Custom Aliases and Functions" "$HOME/.zshrc"; then
    echo -e "\n# --- Custom Aliases and Functions ---" >> "$HOME/.zshrc"
    cat << 'EOF' >> "$HOME/.zshrc"

alias mkinit="sudo mkinitcpio -P"
alias mkgrub="sudo grub-mkconfig -o /boot/grub/grub.cfg"

function git() {
    # Colour Codes
    YELLOW='\033[1;33m'
    NC='\033[0m'

    if [[ "$EUID" -eq 0 ]]; then
        # If running as root (e.g., sudo git), use system git without modification
        command git "$@"
        return
    fi

    # Only intercept if:
    # 1. Command is 'clone' ($1)
    # 2. URL is provided ($2)
    # 3. NO target directory is provided ($3 is empty)
    if [[ "$1" == "clone" && -n "$2" && -z "$3" ]]; then
        target_dir=$(pwd)
        default_dir=~/Make

        # Clone into ~/Make ONLY if the current directory is $HOME
        if [[ "$target_dir" == "$HOME" ]]; then
            echo -e "${YELLOW}Auto-cloning to ~/Make...${NC}"
            command git clone "$2" "$default_dir/$(basename "$2" .git)"
        else
            command git clone "$2"
        fi
    else
        command git "$@"
    fi
}
EOF
    echo "Custom configuration appended to .zshrc."
else
    echo -e "${YELLOW}Custom aliases already exist in .zshrc. Skipping append.${NC}"
fi

# ------------------------------------------------------------------------------
# ------------------------------------------------------------------------------

# End
echo -e "${GREEN}--- Home Folder & ZSH Setup Complete ---${NC}"
echo "Please restart your terminal or log out/in to see ZSH changes (new Konsole profile required)."
