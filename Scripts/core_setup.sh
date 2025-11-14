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
# Run this script first, then run a device-specific script.
#

set -e
echo "--- Starting Core System Setup ---"

#
# --- 1. Package Compilation and Mirrors ---
#
echo "--- Optimising /etc/makepkg.conf for native builds ---"
# ROBUST: This command will work even if CFLAGS is commented out or if you run the script more than once.
sudo sed -i 's/^#*\(CFLAGS=".*-march=\)x86-64 -mtune=generic/\1native/' /etc/makepkg.conf
# ROBUST: This command will work if MAKEFLAGS is commented or uncommented.
sudo sed -i "s/^#*MAKEFLAGS=.*/MAKEFLAGS=\"-j$(nproc)\"/" /etc/makepkg.conf
echo "makepkg.conf optimised."

echo "--- Updating mirror list ---"
sudo reflector --country GB,IE,NL,DE,FR,EU --age 6 --protocol https --sort rate --fastest 10 --save /etc/pacman.d/mirrorlist

#
# --- 2. Install yay and Core Packages ---
#
echo "--- Installing yay (AUR Helper) ---"
sudo pacman -S --needed --noconfirm git base-devel
if [ ! -d "$HOME/Make/yay" ]; then
    git clone https://aur.archlinux.org/yay.git "$HOME/Make/yay"
else
    echo "yay repository already exists in ~/Make."
fi
(cd "$HOME/Make/yay" && makepkg -si --noconfirm)

echo "--- Installing core packages from core_pkg.txt ---"
SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
yay -S --needed --noconfirm - < "$SCRIPT_DIR/core_pkg.txt"

#
# --- 3. Enable Core Services ---
#
echo "--- Enabling core services ---"
sudo systemctl enable --now transmission bluetooth timeshift-hourly.timer lactd btrfs-scrub@-.timer

#
# --- 4. NEW: Automated System Configurations (sudo) ---
#
echo "--- Applying system-wide configurations ---"

# 2.5.1 - Add US locale
echo "--- Setting up en_US locale ---"
# ROBUST: This command will work if the locale is commented or uncommented.
sudo sed -i 's/^#*\(en_US.UTF-8\)/\1/' /etc/locale.gen
sudo locale-gen

# 2.5.2 - Add environment variables
echo "--- Setting environment variables for AMD VA-API and Wine ---"
echo -e "\n# Added by core_setup.sh\nLIBVA_DRIVER_NAME=radeonsi\nVDPAU_DRIVER=radeonsi\nWINEFSYNC=1" | sudo tee -a /etc/environment

# 2.5.4 - Configure zram swap
echo "--- Configuring zram swap ---"
sudo tee /etc/systemd/zram-generator.conf > /dev/null << 'EOF'
[zram0]
zram-size = ram / 2
compression-algorithm = zstd
swap-priority = 100
EOF

# 2.5.5 - Add pacman hooks
echo "--- Adding pacman hooks for initramfs and GRUB ---"
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

# 2.5.8 - Enable experimental Bluetooth features
echo "--- Enabling experimental Bluetooth features ---"
# ROBUST: This command will work if the line is commented or uncommented.
sudo sed -i 's/^#*\(Experimental = \).*/\1true/' /etc/bluetooth/main.conf

# 2.5.9 - Remove KDE discover
echo "--- Removing Discover ---"
sudo pacman -Rdd --noconfirm discover

# 2.5.14 - Configure Reflector Service and Timer
echo "--- Configuring and enabling Reflector timer ---"
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

#
# --- 5. NEW: Automated User Configurations (non-sudo) ---
#
echo "--- Applying user-specific configurations ---"

# 2.5.6 - Change papirus dark's folder colours
echo "--- Setting Papirus folder colours ---"
papirus-folders -C breeze --theme Papirus-Dark

# 2.5.12 - Add Gemini plasmoid
echo "--- Installing and patching Gemini plasmoid ---"
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

# 2.5.13 - Create Steam autostart script
echo "--- Creating Steam delay script ---"
echo -e '#!/bin/bash\nsleep 15\n/usr/bin/steam -silent "$@"' > ~/Make/steam-delay.sh
chmod +x ~/Make/steam-delay.sh


echo "--- Core System Setup Complete ---"
echo "---"
echo "--- MANUAL STEPS REQUIRED ---"
echo "Please reboot, then review the *new* '2.5 - Miscellaneous steps' file for manual tasks."

# Restart plasma shell to apply plasmoid and icon changes
echo "Restarting Plasma shell in 5 seconds..."
sleep 5
kquitapp6 plasmashell && kstart plasmashell
