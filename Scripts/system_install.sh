#!/bin/bash
# ------------------------------------------------------------------------------
# 1. System Bootstrap (Arch ISO)
# ------------------------------------------------------------------------------

set -e

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# ------------------------------------------------------------------------------
# ------------------------------------------------------------------------------

# 1. Keyboard & Pacman
echo -e "${GREEN}--- Configuring Environment ---${NC}"
loadkeys uk
sed -i 's/^#*\(ParallelDownloads = \).*/\1100/' /etc/pacman.conf
sed -i 's/^#Color/Color/' /etc/pacman.conf

# ------------------------------------------------------------------------------
# ------------------------------------------------------------------------------

# 2. Mirrors
echo -e "${GREEN}--- Updating Mirrors ---${NC}"
reflector --country GB,IE,NL,DE,FR,EU --age 12 --protocol https --sort rate --fastest 10 --save /etc/pacman.d/mirrorlist

# ------------------------------------------------------------------------------
# ------------------------------------------------------------------------------

# 3. Fetch Config & Update Installer
echo -e "${GREEN}--- Preparing Installer ---${NC}"
curl -sL -o /root/archinstall_config.json "https://raw.githubusercontent.com/OldLorekeeper/AMD-Linux-Setup/main/Scripts/archinstall_config.json"

# Update keyring first to prevent signature errors on older ISOs
pacman -Sy --noconfirm archlinux-keyring
pacman -S --noconfirm archinstall

# ------------------------------------------------------------------------------
# ------------------------------------------------------------------------------

# 4. Launch
echo -e "${YELLOW}--- Launching archinstall ---${NC}"
archinstall --config /root/archinstall_config.json
