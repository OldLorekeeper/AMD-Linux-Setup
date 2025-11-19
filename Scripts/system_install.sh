#!/bin/bash
#
# This script automates the initial Arch ISO setup steps
# and immediately launches the archinstall process.
#
# It should be run *after* connecting to the internet.
#

set -e

# Colour Codes
GREEN='\033[0;32m'
NC='\033[0m' # No Color

# 1. Set Keyboard
echo -e "${GREEN}--- Setting keyboard layout to UK ---${NC}"
loadkeys uk

# 2. Optimise Pacman
echo -e "${GREEN}--- Enabling parallel downloads in pacman.conf ---${NC}"
sed -i 's/^#*\(ParallelDownloads = \).*/\1100/' /etc/pacman.conf

# 3. Update Mirrors
echo -e "${GREEN}--- Updating mirror list (UK/EU) ---${NC}"
reflector --country GB,IE,NL,DE,FR,EU --age 12 --protocol https --sort rate --fastest 10 --save /etc/pacman.d/mirrorlist

# 4. Download Config
echo -e "${GREEN}--- Downloading archinstall configuration... ---${NC}"
curl -sL -o /root/archinstall_config.json "https://raw.githubusercontent.com/OldLorekeeper/AMD-Linux-Setup/main/Scripts/archinstall_config.json"

# 5. Sync & Update
echo -e "${GREEN}--- Syncing pacman and updating archinstall ---${NC}"
pacman -Sy archinstall

# 6. Launch Installer
echo -e "${GREEN}--- Preparation complete. Launching archinstall... ---${NC}"
archinstall --config /root/archinstall_config.json
