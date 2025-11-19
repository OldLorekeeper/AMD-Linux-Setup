#!/bin/bash
#
# This script automates Section 2.1 of the setup guide:
# 1. Creates standard home directories (Games, Make, Obsidian)
# 2. Clones the AMD-Linux-Setup repository
# 3. Automatically detects Btrfs root, creates @games subvolume, and mounts it
#

set -e

# Colour Codes
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}--- Starting Home Folder Setup ---${NC}"

# 1.  Create Folders & Clone Repo
echo -e "${GREEN}--- Creating standard directories... ---${NC}"
mkdir -p ~/{Games,Make,Obsidian}

echo -e "${GREEN}--- Cloning AMD-Linux-Setup repository... ---${NC}"
if [ -d "$HOME/Obsidian/AMD-Linux-Setup" ]; then
    echo -e "${YELLOW}Repo already exists. Skipping clone.${NC}"
else
    git clone https://github.com/OldLorekeeper/AMD-Linux-Setup "$HOME/Obsidian/AMD-Linux-Setup"
fi

# 2. Setup @games Btrfs Subvolume
echo -e "${GREEN}--- Setting up @games Btrfs subvolume ---${NC}"

# Define Variables
MOUNT_POINT="$HOME/Games"
FSTAB_FILE="/etc/fstab"

# Identify Root Device
# Finding the source device of / and stripping any subvolume info like [/@]
ROOT_DEVICE=$(findmnt -n -o SOURCE / | sed 's/\[.*\]//')
DEVICE_UUID=$(blkid -s UUID -o value "$ROOT_DEVICE")

if [ -z "$DEVICE_UUID" ]; then
    echo -e "${YELLOW}Error: Could not detect root device UUID. Aborting games subvolume setup.${NC}"
    exit 1
fi

# Mount Top-Level Subvolume (ID 5) to create subvolume
# We use a temporary directory to avoid messing with /mnt if it's in use
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
# We construct the fstab line using the literal home path to be safe
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
sudo mount "$MOUNT_POINT"

echo "Setting ownership of $MOUNT_POINT to $USER..."
sudo chown -R "$USER:$(id -gn "$USER")" "$MOUNT_POINT"

echo -e "${YELLOW}--- Home Folder Setup Complete ---${NC}"
