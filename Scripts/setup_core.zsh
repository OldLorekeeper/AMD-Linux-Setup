#!/bin/zsh
# ------------------------------------------------------------------------------
# 3. Core System Setup
# Establishes the build environment, CachyOS kernels, and shared system services.
# ------------------------------------------------------------------------------
#
# DEVELOPMENT RULES (Read before editing):
# 1. Formatting: Keep layout compact. No vertical whitespace inside blocks.
# 2. Separators: Use 'Sandwich' headers (# ------) with strict spacing (1 line before, 0 lines after).
# 3. Idempotency: Scripts must be safe to re-run. Check state before changes.
# 4. Safety: Use 'setopt ERR_EXIT NO_UNSET PIPE_FAIL'.
# 5. Context: Hardcoded for AMD Ryzen 7000/Radeon 7000. No hardcoded secrets.
# 6. Syntax: Use Zsh native modifiers (e.g. ${VAR:h}) over subshells.
# 7. Output: Use 'print'. Do NOT use 'echo'.
# 8. Documentation: Precede sections with 'Purpose'/'Rationale'. No meta-comments inside code blocks.
#
# ------------------------------------------------------------------------------

setopt ERR_EXIT NO_UNSET PIPE_FAIL

sudo -v
( while true; do sudo -v; sleep 60; done; ) &
SUDO_PID=$!
trap 'kill $SUDO_PID' EXIT

SCRIPT_DIR=${0:a:h}
REPO_ROOT=${SCRIPT_DIR:h}

print -P "%F{green}--- Starting Core Setup ---%f"

# ------------------------------------------------------------------------------
# 1. Device Selection
# ------------------------------------------------------------------------------

# Purpose: Identify hardware form factor to determine subsequent setup logic.
# - Logic: Prompts user to select Desktop or Laptop.
# - Outcome: Sets DEVICE_SCRIPT path for the next stage.

print -P "%F{yellow}Select Device Type:%f"
print "1) Desktop"
print "2) Laptop"
read "device_choice?Choice [1-2]: "

case $device_choice in
    1) DEVICE_SCRIPT="$SCRIPT_DIR/setup_desktop.zsh"; DEVICE_NAME="Desktop" ;;
    2) DEVICE_SCRIPT="$SCRIPT_DIR/setup_laptop.zsh"; DEVICE_NAME="Laptop" ;;
    *) print -P "%F{red}Invalid selection. Core only.%f"; DEVICE_SCRIPT="" ;;
esac

# ------------------------------------------------------------------------------
# 2. Build Environment
# ------------------------------------------------------------------------------

# Purpose: Optimize compilation settings for Ryzen 7000 series.
# - Tooling: Installs yay (AUR helper) if missing.
# - Makepkg: Configures parallel builds (-j$(nproc)), native architecture, and tmpfs usage.
# - Rust: Injects target-cpu=native flags.

print -P "%F{green}--- Optimising Build Settings ---%f"
if (( $+commands[yay] )); then
    print -P "%F{yellow}yay already installed.%f"
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
if ! grep -q "RUSTFLAGS" /etc/makepkg.conf; then
    print 'RUSTFLAGS="-C target-cpu=native"' | sudo tee -a /etc/makepkg.conf > /dev/null
fi

# ------------------------------------------------------------------------------
# 3. Mirrors
# ------------------------------------------------------------------------------

# Purpose: Optimize package download speeds.
# - Action: Uses reflector to find fastest HTTPS mirrors.
# - Regions: GB, IE, NL, DE, FR, EU.

print -P "%F{green}--- Updating Mirrors ---%f"
sudo reflector --country GB,IE,NL,DE,FR,EU --age 6 --protocol https --sort rate --fastest 10 --save /etc/pacman.d/mirrorlist

# ------------------------------------------------------------------------------
# 5. Kernel & Packages
# ------------------------------------------------------------------------------

# Purpose: Replace stock kernel with CachyOS and install baseline software.
# - Kernel: Swaps linux for linux-cachyos (SCHED_EXT, etc.).
# - Packages: Installs essential tools defined in core_pkg.txt.

print -P "%F{green}--- Configuring CachyOS (Zen 4) ---%f"
sudo pacman-key --recv-keys F3B607488DB35A47 --keyserver keyserver.ubuntu.com
sudo pacman-key --lsign-key F3B607488DB35A47
sudo pacman -U --noconfirm \
'https://mirror.cachyos.org/repo/x86_64/cachyos/cachyos-keyring-20240331-1-any.pkg.tar.zst' \
'https://mirror.cachyos.org/repo/x86_64/cachyos/cachyos-mirrorlist-22-1-any.pkg.tar.zst' \
'https://mirror.cachyos.org/repo/x86_64/cachyos/cachyos-v4-mirrorlist-22-1-any.pkg.tar.zst'

if ! grep -q "Architecture = auto x86_64_v4" /etc/pacman.conf; then
    sudo sed -i 's/^Architecture = auto/Architecture = auto x86_64_v4/' /etc/pacman.conf
fi

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

print -P "%F{green}--- Installing Kernel & Packages ---%f"
sudo pacman -S --noconfirm linux-cachyos linux-cachyos-headers

for pkg in linux linux-headers; do
    pacman -Qq "$pkg" &>/dev/null && sudo pacman -Rns --noconfirm "$pkg"
done
sudo pacman -Rdd --noconfirm discover || true
yay -S --needed --noconfirm - < "$REPO_ROOT/Resources/Packages/core_pkg.txt"

# ------------------------------------------------------------------------------
# 6. Services & Configs
# ------------------------------------------------------------------------------

# Purpose: Configure system daemon and low-level tuning.
# - Btrfs: Sets up maintenance timers (scrub/balance) and grub-btrfsd.
# - Network: Optimizes TCP (BBR) and queue discipline (Cake).
# - ZRAM: Configures swap-on-ram with lz4 compression.
# - Initramfs: Sets compression to lz4 for faster boot.

print -P "%F{green}--- Applying System Configs ---%f"
sudo systemctl enable --now transmission bluetooth timeshift-hourly.timer btrfs-scrub@-.timer fwupd.service
fwupdmgr refresh --force || print -P "%F{yellow}Warning: Firmware refresh failed.%f"

if [[ -f /usr/lib/systemd/system/grub-btrfsd.service ]]; then
    sudo cp /usr/lib/systemd/system/grub-btrfsd.service /etc/systemd/system/grub-btrfsd.service
    sudo sed -i 's|^ExecStart=.*|ExecStart=/usr/bin/grub-btrfsd --syslog --timeshift-auto|' /etc/systemd/system/grub-btrfsd.service
    sudo systemctl daemon-reload
    sudo systemctl enable --now grub-btrfsd
fi

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

sudo sed -i 's/^#*\(Experimental = \).*/\1true/' /etc/bluetooth/main.conf

sudo tee /etc/xdg/reflector/reflector.conf > /dev/null << 'EOF'
--country GB,IE,NL,DE,FR,EU
--age 6
--protocol https
--sort rate
--fastest 10
--save /etc/pacman.d/mirrorlist
EOF
sudo systemctl enable --now reflector.timer

sudo sed -i 's/^#*\(en_US\.UTF-8\)/\1/' /etc/locale.gen
sudo locale-gen

if ! grep -q "LIBVA_DRIVER_NAME" /etc/environment; then
    print "\nLIBVA_DRIVER_NAME=radeonsi\nVDPAU_DRIVER=radeonsi\nWINEFSYNC=1" | sudo tee -a /etc/environment > /dev/null
fi

print "[zram0]\nzram-size = ram / 2\ncompression-algorithm = lz4\nswap-priority = 100" | sudo tee /etc/systemd/zram-generator.conf > /dev/null
print "vm.swappiness = 150\nvm.page-cluster = 0" | sudo tee /etc/sysctl.d/99-swappiness.conf > /dev/null
print "net.core.default_qdisc = cake\nnet.ipv4.tcp_congestion_control = bbr" | sudo tee /etc/sysctl.d/99-bbr.conf > /dev/null
print "net.ipv4.ip_forward = 1\nnet.ipv6.conf.all.forwarding = 1" | sudo tee /etc/sysctl.d/99-tailscale.conf > /dev/null
sudo mkdir -p /etc/NetworkManager/dispatcher.d
sudo tee /etc/NetworkManager/dispatcher.d/99-tailscale-gro > /dev/null << 'EOF'
#!/bin/zsh
[[ "$2" == "up" ]] && /usr/bin/ethtool -K "$1" rx-udp-gro-forwarding on rx-gro-list off 2>/dev/null || true
EOF
sudo chmod +x /etc/NetworkManager/dispatcher.d/99-tailscale-gro

sudo sed -i 's|^MODULES=.*|MODULES=(amdgpu nvme)|' /etc/mkinitcpio.conf
sudo sed -i 's/^#COMPRESSION="zstd"/COMPRESSION="lz4"/' /etc/mkinitcpio.conf
sudo sed -i 's|^HOOKS=.*|HOOKS=(base udev autodetect modconf kms keyboard keymap consolefont block btrfs filesystems)|' /etc/mkinitcpio.conf
sudo mkinitcpio -P

# ------------------------------------------------------------------------------
# 7. Pacman Hooks
# ------------------------------------------------------------------------------

# Purpose: Automate bootloader and initramfs updates.
# - Initramfs: Triggers rebuild on kernel/firmware updates.
# - Grub: Triggers config update on kernel install/remove.

print -P "%F{green}--- Installing Hooks ---%f"
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
# 8. Gemini Configuration
# ------------------------------------------------------------------------------

# Purpose: Configure the Gemini CLI environment and MCP servers.
# - Gemini: Sets up ~/.gemini/settings.json.
# - MCP: Registers 'arch-ops' via uvx.

print -P "%F{green}--- Configuring Gemini Environment ---%f"
GEMINI_SETTINGS="$HOME/.gemini/settings.json"
mkdir -p "${GEMINI_SETTINGS:h}"
[[ -f "$GEMINI_SETTINGS" ]] || print "{}" > "$GEMINI_SETTINGS"

# Upsert arch-ops configuration
if jq -e . "$GEMINI_SETTINGS" >/dev/null 2>&1; then
    jq '.mcpServers."arch-ops" = {"command": "uvx", "args": ["arch-ops-server"]}' "$GEMINI_SETTINGS" > "${GEMINI_SETTINGS}.tmp" && mv "${GEMINI_SETTINGS}.tmp" "$GEMINI_SETTINGS"
else
    print "{}" > "$GEMINI_SETTINGS"
    jq '.mcpServers."arch-ops" = {"command": "uvx", "args": ["arch-ops-server"]}' "$GEMINI_SETTINGS" > "${GEMINI_SETTINGS}.tmp" && mv "${GEMINI_SETTINGS}.tmp" "$GEMINI_SETTINGS"
fi

# ------------------------------------------------------------------------------
# 9. UI & Visuals
# ------------------------------------------------------------------------------

# Purpose: Apply aesthetics and desktop integration tools.
# - Theme: Sets Papirus-Dark.
# - Gemini: Installs/Configures Google Gemini widget.
# - KWin: Injects rule syncing scripts into .zshrc.

print -P "%F{green}--- Configuring UI & Visuals ---%f"
sudo papirus-folders -C breeze --theme Papirus-Dark

GEMINI_DIR="$HOME/.local/share/plasma/plasmoids/com.samirgaire10.google_gemini-plasma6"
if [[ ! -d "$GEMINI_DIR" ]]; then
    git clone https://github.com/samirgaire10/com.samirgaire10.google_gemini-plasma6.git "$HOME/Make/gemini"
    mkdir -p "${GEMINI_DIR:h}"
    mv "$HOME/Make/gemini" "$GEMINI_DIR"
    QML="$GEMINI_DIR/contents/ui/main.qml"
    sed -i '/Component.onCompleted: url = plasmoid.configuration.url;/c\                Timer { id: sT; interval: 3000; repeat: false; onTriggered: geminiwebview.url = plasmoid.configuration.url } Component.onCompleted: sT.start()' "$QML"
    sed -i '/profile: geminiProfile/a \                onFeaturePermissionRequested: { if (feature === WebEngineView.ClipboardReadWrite) { geminiwebview.grantFeaturePermission(securityOrigin, feature, true); } else { geminiwebview.grantFeaturePermission(securityOrigin, feature, false); } }' "$QML"
fi

TRANS_WIDGET_DIR="$HOME/.local/share/plasma/plasmoids/com.oldlorekeeper.transmission"
TRANS_ARCHIVE="$REPO_ROOT/Resources/Plasmoids/transmission-plasmoid.tar.gz"

if [[ ! -d "$TRANS_WIDGET_DIR" ]]; then
    if [[ -f "$TRANS_ARCHIVE" ]]; then
        print "Installing Transmission Monitor Plasmoid..."
        mkdir -p "${TRANS_WIDGET_DIR:h}"
        tar -xf "$TRANS_ARCHIVE" -C "${TRANS_WIDGET_DIR:h}"
    else
        print -P "%F{yellow}Warning: Transmission Plasmoid archive not found at $TRANS_ARCHIVE%f"
    fi
fi

print -P "%F{green}--- Configuring KWin Management ---%f"
if [[ -z "${DEVICE_NAME:-}" ]]; then
    TARGET_PROFILE=""
else
    TARGET_PROFILE="${DEVICE_NAME:l}"
fi

ZSHRC="$HOME/.zshrc"
START_MARKER="# Start KWin Management"
END_MARKER="# End KWin Management"

if [[ -f "$ZSHRC" ]]; then
    sed -i '/# \Start KWin Management/,/# \End KWin Management/d' "$ZSHRC"
fi

cat <<EOF >> "$ZSHRC"
$START_MARKER

export KWIN_PROFILE="$TARGET_PROFILE"

update-kwin() {
    local target="\${1:-\$KWIN_PROFILE}"
    if [[ -z "\$target" ]]; then
        print -u2 "Error: No profile specified and KWIN_PROFILE not set."
        return 1
    fi

    print -P "%F{green}--- Syncing and Updating for Profile: \$target ---%f"
    local current_dir=\$PWD
    cd "$REPO_ROOT" || return

    if git status --porcelain Resources/Kwin/common.kwinrule.fragment | grep -q '^ M'; then
        print -P "%F{yellow}Committing changes to common.kwinrule.fragment...%f"
        git add Resources/Kwin/common.kwinrule.fragment
        git commit -m "AUTOSYNC: KWin common fragment update from \${HOST}"
    fi

    if ! git pull; then
        print -P "%F{red}Error: Git pull failed.%f"
        cd "\$current_dir"
        return 1
    fi

    ./Scripts/kwin_apply_rules.zsh "\$target"
    cd "\$current_dir"
}

edit-kwin() {
    local target="\${1:-\$KWIN_PROFILE}"
    local repo_dir="$REPO_ROOT/Resources/Kwin"
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
$END_MARKER
EOF
print "KWin management functions injected into $ZSHRC"

# ------------------------------------------------------------------------------
# 10. Finalisation & Deferred Setup (Interactive Console)
# ------------------------------------------------------------------------------

# Purpose: Prepare for the device-specific stage.
# - Bootloader: Updates GRUB configuration.
# - Autostart: Creates a self-destructing wrapper to run the device script (Laptop/Desktop) on next login.

print -P "%F{green}--- Finalisation & Deferred Setup - Interactive ---%f"
sudo grub-mkconfig -o /boot/grub/grub.cfg

if [[ -f "$DEVICE_SCRIPT" ]]; then
    WRAPPER_SCRIPT="$HOME/.local/bin/run_device_setup_once.zsh"
    AUTOSTART_FILE="$HOME/.config/autostart/device-setup-once.desktop"

    cat << EOF > "$WRAPPER_SCRIPT"
#!/usr/bin/zsh
# ------------------------------------------------------------------------------
# INTERACTIVE DEVICE SETUP WRAPPER (Self-Deleting)
# ------------------------------------------------------------------------------
autoload -Uz colors && colors
zsh '$DEVICE_SCRIPT:A'
print -P "\n\n%F{yellow}--- Setup Complete. Press any key to initiate final reboot. ---%f"
read -k1
rm -f '$AUTOSTART_FILE'
rm -f "\$0"
print -P "%F{red}--- Initiating System Reboot ---%f"
sudo reboot
EOF
    chmod +x "$WRAPPER_SCRIPT"

    mkdir -p "$HOME/.config/autostart"
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
    print -P "%F{green}Configured to launch '$DEVICE_NAME Setup' interactively on next login.%f"
fi

# ------------------------------------------------------------------------------
# End - Reboot
# ------------------------------------------------------------------------------

print -P "%F{red}New kernel installed. Rebooting now to complete device setup...%f"
sleep 5
sudo reboot
