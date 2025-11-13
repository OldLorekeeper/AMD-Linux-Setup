#!/bin/bash
#
# This script automates the core setup:
# 1. Optimises makepkg.conf
# 2. Updates mirror list
# 3. Installs yay
# 4. Installs core packages from core_pkg.txt
# 5. Enables core services
#
# Run this script first, then run a device-specific script.
#

set -e
echo "--- Starting Core System Setup ---"

# Step 2.4.1: Optimise makepkg.conf
echo "--- Optimising /etc/makepkg.conf for native builds ---"
sudo sed -i 's/^\(CFLAGS="-march=\)x86-64 -mtune=generic/\1native/' /etc/makepkg.conf
sudo sed -i 's/^#\(MAKEFLAGS=\).*/\1="-j$(nproc)"/' /etc/makepkg.conf
echo "makepkg.conf optimised."

# Step 2.4.2: Update mirror list
echo "--- Updating mirror list ---"
sudo reflector -c GB -p https --download-timeout 2 --age 6 --fastest 10 --sort rate --save /etc/pacman.d/mirrorlist

# Step 2.4.3: Install yay
echo "--- Installing yay (AUR Helper) ---"
sudo pacman -S --needed --noconfirm git base-devel
if [ ! -d "$HOME/Make/yay" ]; then
    git clone https://aur.archlinux.org/yay.git "$HOME/Make/yay"
else
    echo "yay repository already exists in ~/Make."
fi
(cd "$HOME/Make/yay" && makepkg -si --noconfirm)

# Step 2.4.4: Install core packages from list
echo "--- Installing core packages from core_pkg.txt ---"
SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
yay -S --needed --noconfirm - < "$SCRIPT_DIR/core_pkg.txt"

# Step 2.4.5: Enable core services
echo "--- Enabling core services ---"
sudo systemctl enable --now transmission bluetooth timeshift-hourly.timer lactd btrfs-scrub@-.timer

echo "--- Core System Setup Complete ---"
echo "You can now run your device-specific script (desktop_setup.sh or laptop_setup.sh)."
