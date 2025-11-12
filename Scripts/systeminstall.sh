#!/bin/bash
#
# This script automates the initial Arch ISO setup steps
# and immediately launches the archinstall process.
#
# It should be run *after* connecting to the internet.
#

set -e # Exit immediately if a command exits with a non-zero status.

echo "--- Setting keyboard layout to UK ---"
loadkeys uk

echo "--- Enabling parallel downloads in pacman.conf ---"
# Note: sudo is not needed as we are root on the ISO
sed -i 's/^#\(ParallelDownloads = \).*/\1100/' /etc/pacman.conf

echo "--- Updating mirrorlist (UK/EU) ---"
reflector --latest 20 --age 12 --protocol https --country GB,IE,NL,DE,FR,EU --sort rate --save /etc/pacman.d/mirrorlist

echo "--- Syncing pacman and updating archinstall ---"
pacman -Sy archinstall

echo "--- Preparation complete. Launching archinstall... ---"
archinstall --config-url https://raw.githubusercontent.com/OldLorekeeper/AMD-Linux-Setup/main/Scripts/archinstall_config.json
