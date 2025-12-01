#!/bin/bash
# ------------------------------------------------------------------------------
# 2. User Environment Setup
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
ROOT_DEVICE=$(findmnt -n -o SOURCE / | sed 's/\[.*\]//')
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
    sudo mount "$MOUNT_POINT" 2>/dev/null || true
    sudo chown -R "$USER:$(id -gn "$USER")" "$MOUNT_POINT"
fi

# ------------------------------------------------------------------------------
# ------------------------------------------------------------------------------

# 5. ZSH & Oh-My-Zsh
echo -e "${GREEN}--- Configuring Shell ---${NC}"
if [ ! -d "$HOME/.oh-my-zsh" ]; then
    sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
fi

# Plugins
ZSH_CUSTOM=${ZSH_CUSTOM:-~/.oh-my-zsh/custom}
PLUGINS=(
    "zsh-users/zsh-autosuggestions"
    "zsh-users/zsh-syntax-highlighting"
    "MichaelAquilina/zsh-you-should-use"
)
for repo in "${PLUGINS[@]}"; do
    plugin_name=$(basename "$repo")
    if [ ! -d "$ZSH_CUSTOM/plugins/$plugin_name" ]; then
        git clone "https://github.com/$repo" "$ZSH_CUSTOM/plugins/$plugin_name"
    fi
done

# .zshrc Customisation
sed -i 's/^plugins=(git)$/plugins=(git archlinux zsh-autosuggestions zsh-syntax-highlighting you-should-use)/' "$HOME/.zshrc"
if ! grep -q "Custom Aliases" "$HOME/.zshrc"; then
    cat << 'EOF' >> "$HOME/.zshrc"

# --- Custom Aliases ---
alias mkinit="sudo mkinitcpio -P"
alias mkgrub="sudo grub-mkconfig -o /boot/grub/grub.cfg"
function git() {
    if [[ "$1" == "clone" && -n "$2" && -z "$3" && "$(pwd)" == "$HOME" ]]; then
        command git clone "$2" "$HOME/Make/$(basename "$2" .git)"
    else
        command git "$@"
    fi
}
EOF
fi

# ------------------------------------------------------------------------------
# ------------------------------------------------------------------------------

# 6. Konsole Profiles
echo -e "${GREEN}--- Installing Konsole Profiles ---${NC}"
mkdir -p "$HOME/.local/share/konsole"
if [ -d "$REPO_DIR/5-Resources/Konsole" ]; then
    cp -f "$REPO_DIR/5-Resources/Konsole"/* "$HOME/.local/share/konsole/" 2>/dev/null
else
    echo -e "${YELLOW}Warning: Konsole resources not found.${NC}"
fi

echo -e "${GREEN}--- Home Setup Complete. Relogin to apply ZSH changes. ---${NC}"
