#!/bin/zsh
# ------------------------------------------------------------------------------
# 3. Core System Setup
# ------------------------------------------------------------------------------
#
# DEVELOPMENT RULES:
# 1. Formatting: Keep layout compact. No vertical whitespace inside blocks.
# 2. Separators: Use double dotted lines (# ------) for major sections.
# 3. Safety: Use 'setopt ERR_EXIT NO_UNSET PIPE_FAIL'.
# 4. Syntax: Use Zsh native modifiers (e.g. ${VAR:h}) instead of subshells.
# 5. Output: Use 'print' instead of 'echo'.
#
# ------------------------------------------------------------------------------

# Safety Options
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

# Optimize Rust builds for Zen 4 / Native Arch
if ! grep -q "RUSTFLAGS" /etc/makepkg.conf; then
    print 'RUSTFLAGS="-C target-cpu=native"' | sudo tee -a /etc/makepkg.conf > /dev/null
fi

# ------------------------------------------------------------------------------
# ------------------------------------------------------------------------------

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

# Append Repos (must always be at bottom of pacman.conf)
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

# ------------------------------------------------------------------------------
# ------------------------------------------------------------------------------

# 5. Kernel & Packages
print "${GREEN}--- Installing Kernel & Packages ---${NC}"
sudo pacman -S --noconfirm linux-cachyos linux-cachyos-headers

# Clean loop without subshells
for pkg in linux linux-headers; do
    pacman -Qq "$pkg" &>/dev/null && sudo pacman -Rns --noconfirm "$pkg"
done

# Remove Discover (Cleanup)
sudo pacman -Rdd --noconfirm discover || true

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

# Btrfs Maintenance: Monthly Balance to prevent metadata full errors
if ! systemctl list-timers | grep -q "btrfs-balance"; then
    print "Configuring monthly Btrfs balance..."
    sudo tee /etc/systemd/system/btrfs-balance.service > /dev/null << EOF
[Unit]
Description=Btrfs Balance
[Service]
Type=oneshot
ExecStart=/usr/bin/btrfs balance start -dusage=50 -musage=50 /
EOF
    sudo tee /etc/systemd/system/btrfs-balance.timer > /dev/null << EOF
[Unit]
Description=Run Btrfs Balance Monthly
[Timer]
OnCalendar=monthly
Persistent=true
[Install]
WantedBy=timers.target
EOF
    sudo systemctl enable --now btrfs-balance.timer
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
# NOTE: The execution of 'sudo sysctl --system' is DEFERRED to the device_setup scripts
print "[zram0]\nzram-size = ram / 2\ncompression-algorithm = lz4\nswap-priority = 100" | sudo tee /etc/systemd/zram-generator.conf > /dev/null
print "vm.swappiness = 150\nvm.page-cluster = 0" | sudo tee /etc/sysctl.d/99-swappiness.conf > /dev/null
print "net.core.default_qdisc = cake\nnet.ipv4.tcp_congestion_control = bbr" | sudo tee /etc/sysctl.d/99-bbr.conf > /dev/null

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
Target = linux-cachyos-headers
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

# 8. UI & Visuals
print "${GREEN}--- Configuring UI & Visuals ---${NC}"
papirus-folders -C breeze --theme Papirus-Dark

# Gemini Plasmoid (Idempotent)
GEMINI_DIR="$HOME/.local/share/plasma/plasmoids/com.samirgaire10.google_gemini-plasma6"
if [[ ! -d "$GEMINI_DIR" ]]; then
    git clone https://github.com/samirgaire10/com.samirgaire10.google_gemini-plasma6.git "$HOME/Make/gemini"
    mkdir -p "${GEMINI_DIR:h}"
    mv "$HOME/Make/gemini" "$GEMINI_DIR"
    QML="$GEMINI_DIR/contents/ui/main.qml"
    sed -i '/Component.onCompleted: url = plasmoid.configuration.url;/c\                Timer { id: sT; interval: 3000; repeat: false; onTriggered: geminiwebview.url = plasmoid.configuration.url } Component.onCompleted: sT.start()' "$QML"
    sed -i '/profile: geminiProfile/a \                onFeaturePermissionRequested: { if (feature === WebEngineView.ClipboardReadWrite) { geminiwebview.grantFeaturePermission(securityOrigin, feature, true); } else { geminiwebview.grantFeaturePermission(securityOrigin, feature, false); } }' "$QML"
fi

# Transmission Monitor Plasmoid
TRANS_WIDGET_DIR="$HOME/.local/share/plasma/plasmoids/com.oldlorekeeper.transmission"
TRANS_ARCHIVE="${SCRIPT_DIR:h}/5-Resources/Transmission-Plasmoid/transmission-plasmoid.tar.gz"

if [[ ! -d "$TRANS_WIDGET_DIR" ]]; then
    if [[ -f "$TRANS_ARCHIVE" ]]; then
        print "Installing Transmission Monitor Plasmoid..."
        # Extract into the parent 'plasmoids' folder because archive already contains the widget folder
        mkdir -p "${TRANS_WIDGET_DIR:h}"
        tar -xf "$TRANS_ARCHIVE" -C "${TRANS_WIDGET_DIR:h}"
    else
        print "${YELLOW}Warning: Transmission Plasmoid archive not found at $TRANS_ARCHIVE${NC}"
    fi
fi

# --- KWin Functions Injection ---
print "${GREEN}--- Configuring KWin Management ---${NC}"

# Convert DEVICE_NAME to lowercase (Zsh modifier :l) for the profile
TARGET_PROFILE="${DEVICE_NAME:l}"

# Append functions to .zshrc using a heredoc
# Note: Variables like $HOST and $1 are escaped (\$) to prevent expansion during script run
cat <<EOF >> "$HOME/.zshrc"

#Shortcuts to manage custom KWIN rules

export KWIN_PROFILE="$TARGET_PROFILE"

update-kwin() {
    # Default to KWIN_PROFILE if set, otherwise require argument
    local target="\${1:-\$KWIN_PROFILE}"

    if [[ -z "\$target" ]]; then
        print -u2 "Error: No profile specified and KWIN_PROFILE not set."
        return 1
    fi

    print -P "%F{green}--- Syncing and Updating for Profile: \$target ---%f"
    local current_dir=\$PWD
    cd "\$HOME/Obsidian/AMD-Linux-Setup" || return

    # Auto-commit common fragment changes
    if git status --porcelain 5-Resources/Window-Rules/common.kwinrule.fragment | grep -q '^ M'; then
        print -P "%F{yellow}Committing changes to common.kwinrule.fragment...%f"
        git add 5-Resources/Window-Rules/common.kwinrule.fragment
        git commit -m "AUTOSYNC: KWin common fragment update from \${HOST}"
    fi

    if ! git pull; then
        print -P "%F{red}Error: Git pull failed.%f"
        cd "\$current_dir"
        return 1
    fi

    # Run Zsh script (corrected extension)
    ./Scripts/apply_kwin_rules.zsh "\$target"
    cd "\$current_dir"
}

edit-kwin() {
    local target="\${1:-\$KWIN_PROFILE}"
    local repo_dir="\$HOME/Obsidian/AMD-Linux-Setup/5-Resources/Window-Rules"
    local file_path=""

    case "\$target" in
        "desktop") file_path="\$repo_dir/desktop.rule.template" ;;
        "laptop")  file_path="\$repo_dir/laptop.rule.template" ;;
        "common")  file_path="\$repo_dir/common.kwinrule.fragment" ;;
        *)         file_path="\$repo_dir/common.kwinrule.fragment" ;;
    esac

    if [[ -f "\$file_path" ]]; then
        print "Opening template for: \$target"
        kate "\$file_path" &!
    else
        print -u2 "Error: File not found: \$file_path"
    fi
}
EOF

# ------------------------------------------------------------------------------
# ------------------------------------------------------------------------------

# 9. Finalisation & Deferred Setup (Interactive Console)
print "${GREEN}--- Finalisation & Deferred Setup - Interactive ---${NC}"
sudo grub-mkconfig -o /boot/grub/grub.cfg

if [[ -f "$DEVICE_SCRIPT" ]]; then

WRAPPER_SCRIPT="$HOME/.local/bin/run_device_setup_once.zsh"
AUTOSTART_FILE="$HOME/.config/autostart/device-setup-once.desktop"

# Create a self-deleting wrapper script.
cat << EOF > "$WRAPPER_SCRIPT"
#!/usr/bin/zsh
# ------------------------------------------------------------------------------
# INTERACTIVE DEVICE SETUP WRAPPER (Self-Deleting)
# ------------------------------------------------------------------------------
# This script runs the final setup, waits for user input, performs cleanup, and reboots.

# Load colours again for wrapper visibility
autoload -Uz colors && colors
YELLOW="${fg[yellow]}"
RED="${fg[red]}"
NC="${reset_color}"

# Run the final device-specific script (needs absolute path :A)
zsh '$DEVICE_SCRIPT:A'

# Wait for user input to confirm completion and signal cleanup
print "\n\n${YELLOW}--- Setup Complete. Press any key to initiate final reboot. ---${NC}"
read -k1

# Cleanup: Delete the autostart file and this wrapper, then reboot the system.
rm -f '$AUTOSTART_FILE'
rm -f "\$0"
print "${RED}--- Initiating System Reboot ---${NC}"
sudo reboot
EOF

chmod +x "$WRAPPER_SCRIPT"

# Create the simplified autostart .desktop file
mkdir -p "$HOME/.config/autostart"

# Exec now only calls konsole to run the simple wrapper script.
cat << EOF > "$AUTOSTART_FILE"
[Desktop Entry]
Type=Application
Exec=konsole --separate --hide-tabbar -e "$WRAPPER_SCRIPT"
Hidden=false
NoDisplay=false
Name=Initial Device Setup
Comment=Runs device-specific setup script on first login.
Terminal=false
X-KDE-Autostart-Phase=Desktop
X-GNOME-Autostart-enabled=true
EOF

    print "${GREEN}Configured to launch '$DEVICE_NAME Setup' interactively on next login.${NC}"
fi

# ------------------------------------------------------------------------------
# ------------------------------------------------------------------------------

# 10. Reboot
print "${RED}New kernel installed. Rebooting now to complete device setup...${NC}"
sleep 5
sudo reboot
