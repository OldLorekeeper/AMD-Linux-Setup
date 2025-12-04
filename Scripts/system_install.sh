#!/bin/bash
# ------------------------------------------------------------------------------
# 1. System Bootstrap (Arch ISO)
# Initial environment configuration and installer launch
# ------------------------------------------------------------------------------
#
# DEVELOPMENT RULES (Read before editing):
# 1. Formatting: Keep layout compact. Remove vertical whitespace within logical blocks.
# 2. Separators: Use double dotted lines (# ------) to separate major stages.
# 3. Idempotency: Scripts must be safe to re-run. Check state before destructive actions.
# 4. Safety: Always use 'set -e'.
# 5. Context: Hardcoded for AMD Ryzen 7000/Radeon 7000. No hardcoded secrets.
# 6. Tooling: Use 'echo -e'. Prefer native bash expansion (${VAR%/*}) over sed/awk.
#
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
curl -sL -o /root/setup_config.json "https://raw.githubusercontent.com/OldLorekeeper/AMD-Linux-Setup/main/Scripts/setup_config.json"
pacman -Sy --noconfirm archlinux-keyring
pacman -S --noconfirm archinstall

# ------------------------------------------------------------------------------
# ------------------------------------------------------------------------------

# 4. Launch
echo -e "${YELLOW}--- Launching archinstall ---${NC}"
archinstall --config /root/setup_config.json
