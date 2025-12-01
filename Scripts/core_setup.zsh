#!/bin/zsh
# ------------------------------------------------------------------------------
# 3. Core System Setup
# ------------------------------------------------------------------------------

# Zsh Options for Robustness
setopt ERR_EXIT     # Same as set -e
setopt NO_UNSET     # Same as set -u (Error on unset vars)
setopt PIPE_FAIL    # Fail if any part of a pipe fails

# Load Colours
autoload -Uz colors && colors
GREEN="${fg[green]}"
YELLOW="${fg[yellow]}"
RED="${fg[red]}"
NC="${reset_color}"

# Sudo Keep-Alive
sudo -v
( while true; do sudo -v; sleep 60; done; ) &
SUDO_PID=$!
trap 'kill $SUDO_PID' EXIT

# Path Modifier :a:h = absolute path : head (dirname)
SCRIPT_DIR=${0:a:h}

print "${GREEN}--- Starting Core Setup ---${NC}"

# ------------------------------------------------------------------------------
# ------------------------------------------------------------------------------

# 1. Device Selection
print "${YELLOW}Select Device Type:${NC}"
print "1) Desktop"
print "2) Laptop"
read "device_choice?Choice [1-2]: "

case $device_choice in
    1) DEVICE_SCRIPT="$SCRIPT_DIR/desktop_setup.zsh"; DEVICE_NAME="Desktop" ;;
    2) DEVICE_SCRIPT="$SCRIPT_DIR/laptop_setup.zsh"; DEVICE_NAME="Laptop" ;;
    *) print "${RED}Invalid selection. Core only.${NC}"; DEVICE_SCRIPT="" ;;
esac

# ------------------------------------------------------------------------------
# ------------------------------------------------------------------------------

# 2. Build Environment
print "${GREEN}--- Optimising Build Settings ---${NC}"
# Use Zsh to check if yay is in path without 'command -v'
if (( $+commands[yay] )); then
    print "${YELLOW}yay already installed.${NC}"
else
    sudo pacman -S --needed --noconfirm git base-devel
    rm -rf "$HOME/Make/yay"
    git clone https://aur.archlinux.org/yay.git "$HOME/Make/yay"
    (cd "$HOME/Make/yay" && makepkg -si --noconfirm)
fi

sudo sed -i 's/^#*\(CFLAGS=".*-march=\)x86-64 -mtune=generic/\1native/' /etc/makepkg.conf
sudo sed -i "s/^#*MAKEFLAGS=.*/MAKEFLAGS=\"-j$(nproc)\"/" /etc/makepkg.conf
if [[ "$(findmnt -n -o FSTYPE /tmp)" == "tmpfs" ]]; then
    sudo sed -i 's/^#*\(BUILDDIR=\/tmp\/makepkg\)/\1/' /etc/makepkg.conf
fi

# 3. Mirrors
print "${GREEN}--- Updating Mirrors ---${NC}"
sudo reflector --country GB,IE,NL,DE,FR,EU --age 6 --protocol https --sort rate --fastest 10 --save /etc/pacman.d/mirrorlist

# ------------------------------------------------------------------------------
# ------------------------------------------------------------------------------

# 4. CachyOS Repositories
print "${GREEN}--- Configuring CachyOS (Zen 4) ---${NC}"
sudo pacman-key --recv-keys F3B607488DB35A47 --keyserver keyserver.ubuntu.com
sudo pacman-key --lsign-key F3B607488DB35A47
sudo pacman -U --noconfirm \
'https://mirror.cachyos.org/repo/x86_64/cachyos/cachyos-keyring-20240331-1-any.pkg.tar.zst' \
'https://mirror.cachyos.org/repo/x86_64/cachyos/cachyos-mirrorlist-22-1-any.pkg.tar.zst' \
'https://mirror.cachyos.org/repo/x86_64/cachyos/cachyos-v4-mirrorlist-22-1-any.pkg.tar.zst'

# Enable Architecture (Idempotent)
if ! grep -q "Architecture = auto x86_64_v4" /etc/pacman.conf; then
    sudo sed -i 's/^Architecture = auto/Architecture = auto x86_64_v4/' /etc/pacman.conf
fi

# Append Repos (Idempotent)
if ! grep -q "\[cachyos-znver4\]" /etc/pacman.conf; then
    cat <<EOF | sudo tee -a /etc/pacman.conf > /dev/null

[cachyos-znver4]
Include = /etc/pacman.d/cachyos-v4-mirrorlist
[cachyos-core-znver4]
Include = /etc/pacman.d/cachyos-v4-mirrorlist
[cachyos-extra-znver4]
Include = /etc/pacman.d/cachyos-v4-mirrorlist
[cachyos]
Include = /etc/pacman.d/cachyos-mirrorlist
EOF
fi
sudo pacman -Syy --noconfirm

# 5. Kernel & Packages
print "${GREEN}--- Installing Kernel & Packages ---${NC}"
sudo pacman -S --noconfirm linux-cachyos linux-cachyos-headers

# Clean loop without subshells
for pkg in linux linux-headers; do
    pacman -Qq "$pkg" &>/dev/null && sudo pacman -Rns --noconfirm "$pkg"
done

yay -S --needed --noconfirm - < "$SCRIPT_DIR/core_pkg.txt"

# ------------------------------------------------------------------------------
# ------------------------------------------------------------------------------

# 6. Services & Configs
print "${GREEN}--- Applying System Configs ---${NC}"
sudo systemctl enable --now transmission bluetooth timeshift-hourly.timer lactd btrfs-scrub@-.timer fwupd.service

# Firmware Refresh
fwupdmgr refresh --force || print "${YELLOW}Warning: Firmware refresh failed.${NC}"

# Grub-Btrfsd
if [[ -f /usr/lib/systemd/system/grub-btrfsd.service ]]; then
    sudo cp /usr/lib/systemd/system/grub-btrfsd.service /etc/systemd/system/grub-btrfsd.service
    sudo sed -i 's|^ExecStart=.*|ExecStart=/usr/bin/grub-btrfsd --syslog --timeshift-auto|' /etc/systemd/system/grub-btrfsd.service
    sudo systemctl daemon-reload
    sudo systemctl enable --now grub-btrfsd
fi

# Bluetooth Experimental
sudo sed -i 's/^#*\(Experimental = \).*/\1true/' /etc/bluetooth/main.conf

# Reflector Timer
sudo tee /etc/xdg/reflector/reflector.conf > /dev/null << 'EOF'
--country GB,IE,NL,DE,FR,EU
--age 6
--protocol https
--sort rate
--fastest 10
--save /etc/pacman.d/mirrorlist
EOF
sudo systemctl enable --now reflector.timer

# Locale (Fixed Regex)
sudo sed -i 's/^#*\(en_US\.UTF-8\)/\1/' /etc/locale.gen
sudo locale-gen

# Env Vars
if ! grep -q "LIBVA_DRIVER_NAME" /etc/environment; then
    print "\nLIBVA_DRIVER_NAME=radeonsi\nVDPAU_DRIVER=radeonsi\nWINEFSYNC=1" | sudo tee -a /etc/environment > /dev/null
fi

# ZRAM & Sysctl
print "[zram0]\nzram-size = ram / 2\ncompression-algorithm = lz4\nswap-priority = 100" | sudo tee /etc/systemd/zram-generator.conf > /dev/null
print "vm.swappiness = 10" | sudo tee /etc/sysctl.d/99-swappiness.conf > /dev/null
print "net.core.default_qdisc = cake\nnet.ipv4.tcp_congestion_control = bbr" | sudo tee /etc/sysctl.d/99-bbr.conf > /dev/null
sudo sysctl --system

# Mkinitcpio
sudo sed -i 's|^MODULES=.*|MODULES=(amdgpu nvme)|' /etc/mkinitcpio.conf
sudo sed -i 's/^#COMPRESSION="lz4"/COMPRESSION="lz4"/' /etc/mkinitcpio.conf
sudo sed -i 's|^HOOKS=.*|HOOKS=(base udev autodetect modconf kms keyboard keymap consolefont block btrfs filesystems)|' /etc/mkinitcpio.conf
sudo mkinitcpio -P

# ------------------------------------------------------------------------------
# ------------------------------------------------------------------------------

# 7. Pacman Hooks
print "${GREEN}--- Installing Hooks ---${NC}"
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
Description = Rebuilding initramfs...
When = PostTransaction
Exec = /usr/bin/mkinitcpio -P
EOF

sudo tee /etc/pacman.d/hooks/99-update-grub.hook > /dev/null << 'EOF'
[Trigger]
Operation = Install
Operation = Upgrade
Operation = Remove
Type = Package
Target = linux-cachyos
[Action]
Description = Updating GRUB...
When = PostTransaction
Exec = /usr/bin/grub-mkconfig -o /boot/grub/grub.cfg
EOF

# ------------------------------------------------------------------------------
# ------------------------------------------------------------------------------

# 8. Finalisation
print "${GREEN}--- Finalising ---${NC}"
papirus-folders -C breeze --theme Papirus-Dark
sudo grub-mkconfig -o /boot/grub/grub.cfg

# Remove Discover (Cleanup)
sudo pacman -Rdd --noconfirm discover || true

# Gemini Plasmoid (Idempotent)
GEMINI_DIR="$HOME/.local/share/plasma/plasmoids/com.samirgaire10.google_gemini-plasma6"
if [[ ! -d "$GEMINI_DIR" ]]; then
    git clone https://github.com/samirgaire10/com.samirgaire10.google_gemini-plasma6.git "$HOME/Make/gemini"
    mkdir -p "${GEMINI_DIR:h}" # Modifer :h gets dirname
    mv "$HOME/Make/gemini" "$GEMINI_DIR"
    QML="$GEMINI_DIR/contents/ui/main.qml"
    sed -i '/Component.onCompleted: url = plasmoid.configuration.url;/c\                Timer { id: sT; interval: 3000; repeat: false; onTriggered: geminiwebview.url = plasmoid.configuration.url } Component.onCompleted: sT.start()' "$QML"
    sed -i '/profile: geminiProfile/a \                onFeaturePermissionRequested: { if (feature === WebEngineView.ClipboardReadWrite) { geminiwebview.grantFeaturePermission(securityOrigin, feature, true); } else { geminiwebview.grantFeaturePermission(securityOrigin, feature, false); } }' "$QML"
fi

print "${YELLOW}Restarting Plasma...${NC}"
sleep 5
kquitapp6 plasmashell && kstart plasmashell

if [[ -f "$DEVICE_SCRIPT" ]]; then
    print "${GREEN}--- Chaining to $DEVICE_NAME Setup ---${NC}"
    zsh "$DEVICE_SCRIPT"
fi
