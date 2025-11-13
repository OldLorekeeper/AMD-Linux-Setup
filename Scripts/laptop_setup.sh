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

echo "--- Laptop-Specific Setup Complete ---"
