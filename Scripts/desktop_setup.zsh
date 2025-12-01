#!/bin/zsh
# ------------------------------------------------------------------------------
# 4. Desktop Profile Setup
# ------------------------------------------------------------------------------

setopt ERR_EXIT
setopt NO_UNSET
setopt PIPE_FAIL

autoload -Uz colors && colors
GREEN="${fg[green]}"
YELLOW="${fg[yellow]}"
NC="${reset_color}"

# Sudo Keep-Alive
sudo -v
( while true; do sudo -v; sleep 60; done; ) &
SUDO_PID=$!
trap 'kill $SUDO_PID' EXIT

SCRIPT_DIR=${0:a:h}
REPO_ROOT=${SCRIPT_DIR:h}

print "${GREEN}--- Starting Desktop Setup ---${NC}"

# ------------------------------------------------------------------------------
# ------------------------------------------------------------------------------

# 1. Repos & Hooks
print "${GREEN}--- Configuring Sunshine & Repos ---${NC}"

# Sunshine Icons
sudo tee /usr/local/bin/replace-sunshine-icons.sh > /dev/null << EOF
#!/bin/bash
DEST="/usr/share/icons/hicolor/scalable/status"
SRC="$REPO_ROOT/5-Resources/Icons/Sunshine-Tray-Icons"
[[ -d "\$SRC" ]] && cp "\$SRC"/*.svg "\$DEST/"
[[ -f "/usr/bin/sunshine" ]] && setcap cap_sys_admin+p "${${:-=sunshine}:A}"
EOF
sudo chmod +x /usr/local/bin/replace-sunshine-icons.sh

sudo tee /etc/pacman.d/hooks/sunshine-icons.hook > /dev/null << 'EOF'
[Trigger]
Operation = Install
Operation = Upgrade
Type = Package
Target = sunshine
[Action]
Description = Replacing Sunshine tray icons...
When = PostTransaction
Exec = /usr/local/bin/replace-sunshine-icons.sh
EOF

# LizardByte Repo
if ! grep -q "\[lizardbyte\]" /etc/pacman.conf; then
    print "Injecting [lizardbyte] repository..."
    if grep -q "\[cachyos-znver4\]" /etc/pacman.conf; then
        sudo sed -i '/\[cachyos-znver4\]/i \
[lizardbyte]\
SigLevel = Optional\
Server = https://github.com/LizardByte/pacman-repo/releases/latest/download' /etc/pacman.conf
    else
        print "\n[lizardbyte]\nSigLevel = Optional\nServer = https://github.com/LizardByte/pacman-repo/releases/latest/download" | sudo tee -a /etc/pacman.conf
    fi
    sudo pacman -Syu
fi

# ------------------------------------------------------------------------------
# ------------------------------------------------------------------------------

# 2. Packages & Services
print "${GREEN}--- Packages & Services ---${NC}"
yay -S --needed --noconfirm - < "$SCRIPT_DIR/desktop_pkg.txt"

SERVICES=("sonarr" "radarr" "lidarr" "prowlarr" "jellyfin" "transmission")
sudo systemctl enable --now $SERVICES

# Shutdown Safety
for service in $SERVICES; do
    sudo mkdir -p "/etc/systemd/system/$service.service.d"
    print "[Unit]\nRequiresMountsFor=/mnt/Media" | sudo tee "/etc/systemd/system/$service.service.d/media-mount.conf" > /dev/null
done
sudo systemctl daemon-reload

# Sunshine User Service
sudo setcap cap_sys_admin+p "${${:-=sunshine}:A}"
systemctl --user enable --now sunshine

# Solaar
sudo wget -O /etc/udev/rules.d/42-solaar-uinput.rules https://raw.githubusercontent.com/pwr-Solaar/Solaar/refs/heads/master/rules.d-uinput/42-logitech-unify-permissions.rules
sudo udevadm control --reload-rules && sudo udevadm trigger

# ------------------------------------------------------------------------------
# ------------------------------------------------------------------------------

# 3. Custom Tools
print "${GREEN}--- Configuring Tools ---${NC}"

# HideMe Script
tee "$HOME/Make/hideme_tag.py" > /dev/null << 'EOF'
#!/usr/bin/env python3
import requests
# Placeholder: User must populate this file manually from backups or documentation
EOF
chmod +x "$HOME/Make/hideme_tag.py"

mkdir -p "$HOME/.config/systemd/user"
tee "$HOME/.config/systemd/user/hideme_tag.service" > /dev/null << EOF
[Unit]
Description=Run Jellyfin HideMe
[Service]
Type=oneshot
ExecStart=$HOME/Make/hideme_tag.py
EOF
tee "$HOME/.config/systemd/user/hideme_tag.timer" > /dev/null << 'EOF'
[Unit]
Description=Timer for HideMe
[Timer]
OnBootSec=1min
OnUnitActiveSec=10min
Persistent=true
[Install]
WantedBy=default.target
EOF
systemctl --user daemon-reload
systemctl --user enable --now hideme_tag.timer

# Slskd (Idempotent)
sudo mkdir -p /etc/slskd
if [[ ! -f /etc/slskd/slskd.yml ]]; then
    sudo tee /etc/slskd/slskd.yml > /dev/null << 'EOF'
web:
  port: 5030
  authentication:
    username: [admin]
    password: [password]
directories:
  downloads: /mnt/Media/Torrents/slskd/Complete
EOF
    print "Created placeholder slskd.yml"
else
    print "${YELLOW}slskd.yml exists. Skipping overwrite.${NC}"
fi
sudo mkdir -p /etc/systemd/system/slskd.service.d
print "[Unit]\nRequiresMountsFor=/mnt/Media\n[Service]\nExecStart=\nExecStart=/usr/lib/slskd/slskd --config /etc/slskd/slskd.yml" | sudo tee /etc/systemd/system/slskd.service.d/override.conf > /dev/null
sudo systemctl daemon-reload
sudo systemctl enable --now slskd

# Soularr
if [[ ! -d "/opt/soularr" ]]; then
    cd /opt && sudo git clone https://github.com/mrusse/soularr.git
    sudo chown -R "$USER:$(id -gn "$USER")" /opt/soularr
    sudo pip install --break-system-packages -r /opt/soularr/requirements.txt
    sudo cp /opt/soularr/config.ini /opt/soularr/config/config.ini
fi

# ------------------------------------------------------------------------------
# ------------------------------------------------------------------------------

# 4. Hardware & Kernel
print "${GREEN}--- Hardware Fixes ---${NC}"

# AMD 600 Series USB Fix
print 'SUBSYSTEM=="pci", ATTR{vendor}=="0x1022", ATTR{device}=="0x43f7", ATTR{power/control}="on"' | sudo tee /etc/udev/rules.d/99-xhci-fix.rules > /dev/null

# WiFi Power Save
sudo tee /etc/NetworkManager/dispatcher.d/disable-wifi-powersave > /dev/null << 'EOF'
#!/bin/sh
[[ "$1" == wl* ]] && [[ "$2" == "up" ]] && /usr/bin/iw dev "$1" set power_save off
EOF
sudo chmod +x /etc/NetworkManager/dispatcher.d/disable-wifi-powersave

# Kernel Params
NEW_CMDLINE='GRUB_CMDLINE_LINUX_DEFAULT="loglevel=3 quiet amdgpu.ppfeaturemask=0xffffffff hugepages=512 video=3440x1440@60 amd_pstate=active"'
sudo sed -i 's|^GRUB_CMDLINE_LINUX_DEFAULT=.*|'"$NEW_CMDLINE"'|' /etc/default/grub
sudo grub-mkconfig -o /boot/grub/grub.cfg

# Kyber I/O
print 'ACTION=="add|change", KERNEL=="nvme[0-9]n[0-9]", ATTR{queue/scheduler}="kyber"' | sudo tee /etc/udev/rules.d/60-iosched.rules > /dev/null
sudo udevadm control --reload-rules && sudo udevadm trigger

# ------------------------------------------------------------------------------
# ------------------------------------------------------------------------------

# 5. Sunshine Performance
print "${GREEN}--- Configuring Sunshine Performance ---${NC}"

BOOST_SCRIPT="$REPO_ROOT/5-Resources/Sunshine/sunshine-gpu-boost.zsh"

# Detect RX 7900 XT (Navi 31)
CARD_PATH=$(grep -lE "0x744(c|d)" /sys/class/drm/card*/device/device 2>/dev/null | head -n 1)

if [[ -n "$CARD_PATH" ]]; then
    # Extract card name (e.g. card0)
    CARD_NAME=${${CARD_PATH:h}:h:t}

    print "Detected RX 7900 XT at $CARD_NAME"

    if [[ -f "$BOOST_SCRIPT" ]]; then
        # Configure script in-place to use correct GPU
        sed -i "s/card[0-9]\+/$CARD_NAME/" "$BOOST_SCRIPT"
        chmod +x "$BOOST_SCRIPT"

        # Sudoers Rule pointing to REPO path
        print "$USER ALL=(ALL) NOPASSWD: $BOOST_SCRIPT" | sudo tee /etc/sudoers.d/90-sunshine-boost > /dev/null
        sudo chmod 440 /etc/sudoers.d/90-sunshine-boost

        print "Configured GPU Boost in repo: $BOOST_SCRIPT"
    else
        print "${YELLOW}Warning: Source script $BOOST_SCRIPT not found.${NC}"
    fi
else
    print "${YELLOW}Warning: RX 7900 XT not found. Skipping GPU Boost setup.${NC}"
fi

# ------------------------------------------------------------------------------
# ------------------------------------------------------------------------------

# 6. Local Binaries
print "${GREEN}--- Configuring Local Binaries ---${NC}"
mkdir -p "$HOME/.local/bin"
SOURCE_SCRIPT="$REPO_ROOT/5-Resources/Local-Scripts/fix-cover-art.zsh"
TARGET_LINK="$HOME/.local/bin/fix-cover-art"

if [[ -f "$SOURCE_SCRIPT" ]]; then
    ln -sf "$SOURCE_SCRIPT" "$TARGET_LINK"
    chmod +x "$TARGET_LINK"
    print "Symlinked fix-cover-art to ~/.local/bin."
else
    print "${YELLOW}Warning: $SOURCE_SCRIPT not found.${NC}"
fi

# ------------------------------------------------------------------------------
# ------------------------------------------------------------------------------

# 7. KDE Integration
print "${GREEN}--- KDE Rules ---${NC}"
grep -q 'export PATH="$HOME/.local/bin:$PATH"' "$HOME/.zshrc" || print 'export PATH="$HOME/.local/bin:$PATH"' >> "$HOME/.zshrc"
grep -q "export KWIN_PROFILE=" "$HOME/.zshrc" || print 'export KWIN_PROFILE="desktop"' >> "$HOME/.zshrc"
export KWIN_PROFILE="desktop"

[[ -f "$SCRIPT_DIR/apply_kwin_rules.zsh" ]] && chmod +x "$SCRIPT_DIR/apply_kwin_rules.zsh" && "$SCRIPT_DIR/apply_kwin_rules.zsh" desktop

print "${GREEN}--- Desktop Setup Complete. Reboot Required. ---${NC}"
