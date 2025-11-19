#!/bin/bash
#
# This script automates the initial Arch ISO setup steps
# and immediately launches the archinstall process.
#
# It should be run *after* connecting to the internet.
#

set -e # Exit immediately if a command exits with a non-zero status.

# Colour Codes
GREEN='\033[0;32m'
NC='\033[0m' # No Color

echo -e "${GREEN}--- Setting keyboard layout to UK ---${NC}"
loadkeys uk

echo -e "${GREEN}--- Enabling parallel downloads in pacman.conf ---${NC}"
# Note: sudo is not needed as we are root on the ISO
sed -i 's/^#*\(ParallelDownloads = \).*/\1100/' /etc/pacman.conf

echo -e "${GREEN}--- Updating mirrorlist (UK/EU) ---${NC}"
reflector --country GB,IE,NL,DE,FR,EU --age 12 --protocol https --sort rate --fastest 10 --save /etc/pacman.d/mirrorlist

echo -e "${GREEN}--- Downloading archinstall configuration... ---${NC}"
curl -sL -o /root/archinstall_config.json "https://raw.githubusercontent.com/OldLorekeeper/AMD-Linux-Setup/main/Scripts/archinstall_config.json"

echo -e "${GREEN}--- Syncing pacman and updating archinstall ---${NC}"
pacman -Sy archinstall

echo -e "${GREEN}--- Preparation complete. Launching archinstall... ---${NC}"
archinstall --config /root/archinstall_config.json
