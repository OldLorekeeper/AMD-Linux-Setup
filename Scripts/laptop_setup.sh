#!/bin/bash
#
# This script installs laptop-specific packages and enables services.
# Run this *after* core_setup.sh
#

set -e
echo "--- Starting Laptop-Specific Setup ---"

# Install laptop packages from list
echo "--- Installing laptop packages from laptop_pkg.txt ---"
SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
yay -S --needed --noconfirm - < "$SCRIPT_DIR/laptop_pkg.txt"

# Enable laptop services
echo "--- Enabling laptop services ---"
sudo systemctl enable --now power-profiles-daemon.service

# Apply Laptop Kernel Parameters
echo "--- Applying laptop-specific kernel parameters ---"
# --- ROBUST SED COMMAND ---
# This command captures the existing parameters and appends the new ones before the final quote
sudo sed -i 's/^\(GRUB_CMDLINE_LINUX_DEFAULT=".*\)"$/\1 amdgpu.ppfeaturemask=0xffffffff hugepages=512 video=2560x1600@60 amd_pstate=active"/' /etc/default/grub

echo "--- Rebuilding GRUB configuration ---"
sudo grub-mkconfig -o /boot/grub/grub.cfg

# End
echo "--- Laptop-Specific Setup Complete ---"
echo "Please complete any remaining manual steps, then REBOOT."
