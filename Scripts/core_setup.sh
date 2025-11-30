#!/bin/bash
#
# This script automates the core setup:
# 1. Optimises makepkg.conf
# 2. Updates mirror list
# 3. Installs yay
# 4. Installs core packages from core_pkg.txt
# 5. Enables core services
# 6. Applies miscellaneous system-wide configurations
#
# Run this script first. It will ask for device type and automatically
# chain into desktop_setup.sh or laptop_setup.sh at the end.
#

set -e

# Colour Codes
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Define script directory early to locate other scripts
SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )

echo -e "${GREEN}--- Starting Core System Setup ---${NC}"

# ------------------------------------------------------------------------------
# ------------------------------------------------------------------------------

# 0. Select Device Type
echo -e "${YELLOW}--- Select Installation Type ---${NC}"
echo "1) Desktop"
echo "2) Laptop"
read -p "Enter choice [1-2]: " device_choice
case $device_choice in
    1)
        DEVICE_SCRIPT="$SCRIPT_DIR/desktop_setup.sh"
        DEVICE_NAME="Desktop"
        ;;
    2)
        DEVICE_SCRIPT="$SCRIPT_DIR/laptop_setup.sh"
        DEVICE_NAME="Laptop"
        ;;
    *)
        echo -e "${RED}Invalid selection. Proceeding with Core Setup only.${NC}"
        DEVICE_SCRIPT=""
        ;;
esac

# ------------------------------------------------------------------------------
# ------------------------------------------------------------------------------

# 1. Optimise makepkg
echo -e "${GREEN}--- Optimising /etc/makepkg.conf for native builds ---${NC}"
# ROBUST: This command will work even if CFLAGS is commented out or if you run the script more than once.
sudo sed -i 's/^#*\(CFLAGS=".*-march=\)x86-64 -mtune=generic/\1native/' /etc/makepkg.conf
# ROBUST: This command will work if MAKEFLAGS is commented or uncommented.
sudo sed -i "s/^#*MAKEFLAGS=.*/MAKEFLAGS=\"-j$(nproc)\"/" /etc/makepkg.conf
# OPTIMISATION: Build in RAM if /tmp is tmpfs
if [[ "$(findmnt -n -o FSTYPE /tmp)" == "tmpfs" ]]; then
    echo -e "${GREEN}--- /tmp is tmpfs. Enabling memory-based builds... ---${NC}"
    sudo sed -i 's/^#*\(BUILDDIR=\/tmp\/makepkg\)/\1/' /etc/makepkg.conf
else
    echo -e "${YELLOW}--- /tmp is not tmpfs. Skipping BUILDDIR optimization. ---${NC}"
fi
echo "makepkg.conf optimised."

# ------------------------------------------------------------------------------
# ------------------------------------------------------------------------------

# 2. Update mirrors
echo -e "${GREEN}--- Updating mirror list ---${NC}"
sudo reflector --country GB,IE,NL,DE,FR,EU --age 6 --protocol https --sort rate --fastest 10 --save /etc/pacman.d/mirrorlist

# ------------------------------------------------------------------------------
# ------------------------------------------------------------------------------

# 3. Install yay
echo -e "${GREEN}--- Installing yay (AUR Helper) ---${NC}"
sudo pacman -S --needed --noconfirm git base-devel
if [ ! -d "$HOME/Make/yay" ]; then
    git clone https://aur.archlinux.org/yay.git "$HOME/Make/yay"
else
    echo "yay repository already exists in ~/Make."
fi
(cd "$HOME/Make/yay" && makepkg -si --noconfirm)

# ------------------------------------------------------------------------------
# ------------------------------------------------------------------------------

# 4. Install core packages
echo -e "${GREEN}--- Installing core packages from core_pkg.txt ---${NC}"
# SCRIPT_DIR is already defined at top
yay -S --needed --noconfirm - < "$SCRIPT_DIR/core_pkg.txt"

# ------------------------------------------------------------------------------
# ------------------------------------------------------------------------------

# 5. Enable core services
echo -e "${GREEN}--- Enabling core services ---${NC}"
sudo systemctl enable --now transmission bluetooth timeshift-hourly.timer lactd btrfs-scrub@-.timer
# 5a. Configure grub-btrfsd (Timeshift automation)
echo -e "${GREEN}--- Configuring grub-btrfsd for Timeshift ---${NC}"
# Install dependency required for the daemon to watch filesystem events
yay -S --needed --noconfirm inotify-tools
# Edit the service to watch Timeshift (equivalent to systemctl edit --full)
# We copy the default unit to /etc to create a persistent override
if [ -f /usr/lib/systemd/system/grub-btrfsd.service ]; then
    sudo cp /usr/lib/systemd/system/grub-btrfsd.service /etc/systemd/system/grub-btrfsd.service
    # Modify the ExecStart command to use --timeshift-auto
    sudo sed -i 's|^ExecStart=.*|ExecStart=/usr/bin/grub-btrfsd --syslog --timeshift-auto|' /etc/systemd/system/grub-btrfsd.service
    # Reload daemon to pick up the new file in /etc and enable the service
    sudo systemctl daemon-reload
    sudo systemctl enable --now grub-btrfsd
else
    echo -e "${YELLOW}Warning: grub-btrfsd.service not found. Is grub-btrfs installed?${NC}"
fi

# ------------------------------------------------------------------------------
# ------------------------------------------------------------------------------

# 6. System-wide configurations (Header)
echo -e "${GREEN}--- Applying system-wide configurations ---${NC}"

# 7. Setup Locale
echo -e "${GREEN}--- Setting up en_US locale ---${NC}"
# ROBUST: This command will work if the locale is commented or uncommented.
sudo sed -i 's/^#*\(en_US.UTF-8\)/\1/' /etc/locale.gen
sudo locale-gen

# ------------------------------------------------------------------------------
# ------------------------------------------------------------------------------

# 8. Environment variables
echo -e "${GREEN}--- Setting environment variables for AMD VA-API and Wine ---${NC}"
echo -e "\n# Added by core_setup.sh\nLIBVA_DRIVER_NAME=radeonsi\nVDPAU_DRIVER=radeonsi\nWINEFSYNC=1" | sudo tee -a /etc/environment

# ------------------------------------------------------------------------------
# ------------------------------------------------------------------------------

# 9. Zram swap
echo -e "${GREEN}--- Configuring zram swap ---${NC}"
sudo tee /etc/systemd/zram-generator.conf > /dev/null << 'EOF'
[zram0]
zram-size = ram / 2
compression-algorithm = lz4
swap-priority = 100
EOF

# ------------------------------------------------------------------------------
# ------------------------------------------------------------------------------

# 10. Configure Swappiness
echo -e "${GREEN}--- Configuring swappiness to 10 (optimal for zram) ---${NC}"
sudo tee /etc/sysctl.d/99-swappiness.conf > /dev/null <<'EOF'
vm.swappiness = 10
EOF
# Apply immediately so it's active for the rest of the setup
sudo sysctl --system

# ------------------------------------------------------------------------------
# ------------------------------------------------------------------------------

# 10.5. Optimise mkinitcpio
echo -e "${GREEN}--- Optimising mkinitcpio (Boot Speed) ---${NC}"

# 1. Modules: amdgpu (Early KMS) + nvme (Fast Storage)
#    Replaces any existing MODULES line
sudo sed -i 's|^MODULES=.*|MODULES=(amdgpu nvme)|' /etc/mkinitcpio.conf

# 2. Compression: lz4 (High Performance Decompression)
#    Uncomment the lz4 option (explicitly enables it, overriding implicit default)
sudo sed -i 's/^#COMPRESSION="lz4"/COMPRESSION="lz4"/' /etc/mkinitcpio.conf

# 3. Hooks: Remove fsck, ensure btrfs
#    Replaces the entire HOOKS line to ensure clean state for Btrfs
sudo sed -i 's|^HOOKS=.*|HOOKS=(base udev autodetect modconf kms keyboard keymap consolefont block btrfs filesystems)|' /etc/mkinitcpio.conf

# 4. Regenerate initramfs
echo -e "${GREEN}--- Regenerating initramfs ---${NC}"
# Ensure lz4 package is present (Safety check)
yay -S --needed --noconfirm lz4
sudo mkinitcpio -P

# ------------------------------------------------------------------------------
# ------------------------------------------------------------------------------

# 11. Pacman hooks
echo -e "${GREEN}--- Adding pacman hooks for initramfs and GRUB ---${NC}"
sudo mkdir -p /etc/pacman.d/hooks
sudo tee /etc/pacman.d/hooks/98-rebuild-initramfs.hook > /dev/null << 'EOF'
[Trigger]
Operation = Install
Operation = Upgrade
Type = Package
Target = amd-ucode
Target = btrfs-progs
Target = mkinitcpio-firmware

[Action]
Description = Rebuilding initramfs for critical package updates...
When = PostTransaction
Exec = /usr/bin/mkinitcpio -P
EOF
sudo tee /etc/pacman.d/hooks/99-update-grub.hook > /dev/null << 'EOF'
[Trigger]
Operation = Install
Operation = Upgrade
Operation = Remove
Type = Package
Target = linux-zen

[Action]
Description = Updating GRUB configuration...
When = PostTransaction
Exec = /usr/bin/grub-mkconfig -o /boot/grub/grub.cfg
EOF

# ------------------------------------------------------------------------------
# ------------------------------------------------------------------------------

# 12. Bluetooth features
echo -e "${GREEN}--- Enabling experimental Bluetooth features ---${NC}"
# ROBUST: This command will work if the line is commented or uncommented.
sudo sed -i 's/^#*\(Experimental = \).*/\1true/' /etc/bluetooth/main.conf

# ------------------------------------------------------------------------------
# ------------------------------------------------------------------------------

# 13. Remove Discover
echo -e "${GREEN}--- Removing Discover ---${NC}"
sudo pacman -Rdd --noconfirm discover

# ------------------------------------------------------------------------------
# ------------------------------------------------------------------------------

# 14. Reflector Timer
echo -e "${GREEN}--- Configuring and enabling Reflector timer ---${NC}"
sudo tee /etc/xdg/reflector/reflector.conf > /dev/null << 'EOF'
# Added by core_setup.sh
--country GB,IE,NL,DE,FR,EU
--age 6
--protocol https
--sort rate
--fastest 10
--save /etc/pacman.d/mirrorlist
EOF
# Create the systemd timer override
sudo mkdir -p /etc/systemd/system/reflector.timer.d
sudo tee /etc/systemd/system/reflector.timer.d/override.conf > /dev/null << 'EOF'
[Timer]
# clear any existing calendar from the unit
OnCalendar=
# run at 00:00, 03:00, 06:00, ... 21:00
OnCalendar=00/3:00:00
Persistent=true
RandomizedDelaySec=15m
EOF
sudo systemctl daemon-reload
sudo systemctl enable --now reflector.timer

# ------------------------------------------------------------------------------
# ------------------------------------------------------------------------------

# 15. User-specific configurations (Header)
echo -e "${GREEN}--- Applying user-specific configurations ---${NC}"

# 16. Papirus folder colours
echo -e "${GREEN}--- Setting Papirus folder colours ---${NC}"
papirus-folders -C breeze --theme Papirus-Dark

# ------------------------------------------------------------------------------
# ------------------------------------------------------------------------------

# 17. Gemini plasmoid
echo -e "${GREEN}--- Installing and patching Gemini plasmoid ---${NC}"
if [ ! -d "$HOME/.local/share/plasma/plasmoids/com.samirgaire10.google_gemini-plasma6" ]; then
    git clone https://github.com/samirgaire10/com.samirgaire10.google_gemini-plasma6.git "$HOME/Make/com.samirgaire10.google_gemini-plasma6"
    mkdir -p ~/.local/share/plasma/plasmoids/
    mv "$HOME/Make/com.samirgaire10.google_gemini-plasma6" ~/.local/share/plasma/plasmoids/
    # Define file path
    QML_FILE="$HOME/.local/share/plasma/plasmoids/com.samirgaire10.google_gemini-plasma6/contents/ui/main.qml"
    # 1. Fix startup delay
    sed -i '/Component.onCompleted: url = plasmoid.configuration.url;/c\
                    Timer {\
                        id: startupTimer\
                        interval: 3000 // 3-second delay\
                        repeat: false\
                        onTriggered: geminiwebview.url = plasmoid.configuration.url\
                    }\
    \
                    Component.onCompleted: startupTimer.start()' "$QML_FILE"
    # 2. Fix clipboard access
    sed -i '/profile: geminiProfile/a \
    \
                    // --- Handle Clipboard Permission Request ---\
                    onFeaturePermissionRequested: {\
                        if (feature === WebEngineView.ClipboardReadWrite) {\
                            geminiwebview.grantFeaturePermission(securityOrigin, feature, true);\
                        } else {\
                            geminiwebview.grantFeaturePermission(securityOrigin, feature, false);\
                        }\
                    }\
                    // --- End Permission Handler ---' "$QML_FILE"
else
    echo "Gemini plasmoid already installed, skipping."
fi

# ------------------------------------------------------------------------------
# ------------------------------------------------------------------------------

# 18. End
echo -e "${YELLOW}--- MANUAL STEPS REQUIRED ---${NC}"
echo "Review '2.3-Manual' for further instruction."
# Restart plasma shell to apply plasmoid and icon changes
echo -e "${YELLOW}Restarting Plasma shell in 5 seconds...${NC}"
sleep 5
kquitapp6 plasmashell && kstart plasmashell
