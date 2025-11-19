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

# Install laptop packages from list
echo -e "${GREEN}--- Installing laptop packages from laptop_pkg.txt ---${NC}"
SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
yay -S --needed --noconfirm - < "$SCRIPT_DIR/laptop_pkg.txt"

# Enable laptop services
echo -e "${GREEN}--- Enabling laptop services ---${NC}"
sudo systemctl enable --now power-profiles-daemon.service

# Apply Laptop Kernel Parameters
echo -e "${GREEN}--- Applying laptop-specific kernel parameters ---${NC}"
# This command captures the existing parameters and appends the new ones before the final quote
sudo sed -i 's/^\(GRUB_CMDLINE_LINUX_DEFAULT=".*\)"$/\1 amdgpu.ppfeaturemask=0xffffffff hugepages=512 video=2560x1600@60 amd_pstate=active"/' /etc/default/grub

echo -e "${GREEN}--- Rebuilding GRUB configuration ---${NC}"
sudo grub-mkconfig -o /boot/grub/grub.cfg

# End
echo -e "${YELLOW}--- Laptop-Specific Setup Complete ---${NC}"
echo "Please complete any remaining manual steps, then REBOOT."
