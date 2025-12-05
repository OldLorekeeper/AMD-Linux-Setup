#!/bin/zsh
# ------------------------------------------------------------------------------
# 4. Desktop Profile Setup
# Configures the static workstation profile (Gaming, Media Hosting, Sunshine).
# ------------------------------------------------------------------------------
#
# DEVELOPMENT RULES (Read before editing):
# 1. Formatting: Keep layout compact. No vertical whitespace inside blocks.
# 2. Separators: Use double dotted lines (# ------) for major sections.
# 3. Idempotency: Scripts must be safe to re-run. Check state before changes.
# 4. Safety: Use 'setopt ERR_EXIT NO_UNSET PIPE_FAIL'.
# 5. Context: Hardcoded for AMD Ryzen 7000/Radeon 7000. No hardcoded secrets.
# 6. Syntax: Use Zsh native modifiers (e.g. ${VAR:h}) over subshells.
# 7. Output: Use 'print'. Do NOT use 'echo'.
#
# ------------------------------------------------------------------------------

# Safety Options
setopt ERR_EXIT     # Exit on error
setopt NO_UNSET     # Error on unset variables
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
SRC="$REPO_ROOT/Resources/Icons/Sunshine"
[[ -d "\$SRC" ]] && cp "\$SRC"/*.svg "\$DEST/"
SUNSHINE_PATH=\$(command -v sunshine)
[[ -n "\$SUNSHINE_PATH" ]] && setcap cap_sys_admin+p "\$SUNSHINE_PATH"
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

# 2. Packages & Services (Preparation)
print "${GREEN}--- Packages & Services ---${NC}"
yay -S --needed --noconfirm - < "$REPO_ROOT/Resources/Packages/desktop_pkg.txt"

# Media Group Setup
# Must run before ANY service starts so GID is inherited
print "Configuring 'media' group..."
sudo groupadd -f media
sudo usermod -aG media "$USER"

# Define Service List (Activation deferred to Sec 4b)
SERVICES=("sonarr" "radarr" "lidarr" "prowlarr" "jellyfin" "transmission")

# Add services to group
for svc in $SERVICES slskd; do
    id "$svc" &>/dev/null && sudo usermod -aG media "$svc"
done

# Transmission permission fix
print "Configuring Transmission Permissions..."

# 1. Stop service to release lock on settings.json
sudo systemctl stop transmission-daemon

# 2. Programmatically update umask in settings.json
# Usage: Reads file, sets 'umask' to integer 2, saves file.
sudo python -c "
import json
from pathlib import Path
path = Path('/var/lib/transmission/.config/transmission-daemon/settings.json')
if path.exists():
    data = json.loads(path.read_text())
    data['umask'] = 2
    path.write_text(json.dumps(data, indent=4))
"

# 4. Apply changes
sudo systemctl daemon-reload
sudo systemctl start transmission-daemon

# Sunshine User Service (Independent of Media Mount)
REAL_SUNSHINE_PATH=$(readlink -f "$(command -v sunshine)")
sudo setcap cap_sys_admin+p "$REAL_SUNSHINE_PATH"
systemctl --user enable --now sunshine

# Solaar
sudo wget -O /etc/udev/rules.d/42-solaar-uinput.rules https://raw.githubusercontent.com/pwr-Solaar/Solaar/refs/heads/master/rules.d-uinput/42-logitech-unify-permissions.rules
sudo udevadm control --reload-rules && sudo udevadm trigger

# ------------------------------------------------------------------------------
# ------------------------------------------------------------------------------

# 3. Custom Tools Configuration
print "${GREEN}--- Configuring Tools ---${NC}"

# Slskd (Idempotent)
print "Configuring Slskd..."
sudo mkdir -p /etc/slskd
if [[ ! -f /etc/slskd/slskd.yml ]]; then
    print "${GREEN}--- Configure Slskd Credentials ---${NC}"
    read "SLSKD_USER?Create Slskd WebUI Username: "
    read -s "SLSKD_PASS?Create Slskd WebUI Password: "; print
    read "SOULSEEK_USER?Create Soulseek Username: "
    read -s "SOULSEEK_PASS?Create Soulseek Password (no symbols): "; print

    print "Writing configuration..."
    sudo tee /etc/slskd/slskd.yml > /dev/null << EOF
web:
  port: 5030
  https:
    disabled: true
  authentication:
    disabled: false
    username: $SLSKD_USER
    password: $SLSKD_PASS
directories:
  downloads: /mnt/Media/Downloads/slskd/Complete
  incomplete: /mnt/Media/Downloads/slskd/Incomplete
soulseek:
  username: $SOULSEEK_USER
  password: $SOULSEEK_PASS
EOF
    print "Created configured slskd.yml"
else
    print "${YELLOW}slskd.yml exists. Skipping overwrite.${NC}"
fi

# Slskd Service Override (File creation only - Activation deferred)
sudo mkdir -p /etc/systemd/system/slskd.service.d
sudo tee /etc/systemd/system/slskd.service.d/override.conf > /dev/null << EOF
[Unit]
RequiresMountsFor=/mnt/Media
[Service]
UMask=0002
ExecStart=
ExecStart=/usr/lib/slskd/slskd --config /etc/slskd/slskd.yml
EOF

# Soularr (Idempotent)
print "Configuring Soularr..."
if [[ ! -d "/opt/soularr" ]]; then
    cd /opt && sudo git clone https://github.com/mrusse/soularr.git
    sudo chown -R "$USER:$(id -gn "$USER")" /opt/soularr
else
    print "${YELLOW}Soularr directory exists. Skipping clone.${NC}"
fi

# Dependencies & Config
sudo pip install --break-system-packages -r /opt/soularr/requirements.txt
sudo mkdir -p /opt/soularr/config
[[ ! -f /opt/soularr/config/config.ini ]] && sudo cp /opt/soularr/config.ini /opt/soularr/config/config.ini

# Soularr Service & Timer (Unit creation only - Activation deferred)
sudo tee /etc/systemd/system/soularr.service > /dev/null << EOF
[Unit]
Description=Soularr (Lidarr <-> Slskd automation)
Wants=network-online.target lidarr.service slskd.service
After=network-online.target lidarr.service slskd.service
Requires=lidarr.service slskd.service
RequiresMountsFor=/mnt/Media
[Service]
Type=oneshot
User=$USER
Group=$(id -gn "$USER")
UMask=0002
WorkingDirectory=/opt/soularr
ExecStart=/usr/bin/python /opt/soularr/soularr.py --config-dir /opt/soularr/config --no-lock-file
NoNewPrivileges=yes
PrivateTmp=yes
ProtectSystem=full
ProtectHome=read-only
ReadWritePaths=/opt/soularr /var/log /mnt/Media/Downloads/slskd/Complete/
EOF

sudo tee /etc/systemd/system/soularr.timer > /dev/null << EOF
[Unit]
Description=Run Soularr every 30 minutes
[Timer]
OnCalendar=*:0/30
Persistent=true
AccuracySec=1min
[Install]
WantedBy=timers.target
EOF

# ------------------------------------------------------------------------------
# ------------------------------------------------------------------------------

# 4. Hardware & Kernel
print "${GREEN}--- Hardware Fixes and Media Mount ---${NC}"

# Ensure Kernel Configs from Core Setup are applied now that new kernel is running
sudo sysctl --system

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

## Media drive setup
print "${YELLOW}--- Media Drive Setup ---${NC}"
MOUNT_OPTS="rw,nosuid,nodev,noatime,nofail,x-gvfs-hide,x-systemd.automount,compress=zstd:3,discard=async"

if grep -q "/mnt/Media" /etc/fstab; then
    print "${YELLOW}/mnt/Media already configured in fstab. Skipping mount injection.${NC}"
else
    # User interaction (option to skip)
    print "This step configures the dedicated media drive (NVMe/Btrfs)"
    print "Choosing 'Yes' will list partitions and prompt for a UUID."
    read "SETUP_MEDIA?Set up media drive now (Y)es/(N)o? "

    if [[ "$SETUP_MEDIA" =~ ^[Yy]$ ]]; then
        print "Available Partitions:"
        lsblk -o NAME,SIZE,FSTYPE,LABEL,UUID -e 7,11
        read "MEDIA_UUID?Enter UUID of Media Partition (copy from above): "

        if [[ -n "$MEDIA_UUID" ]]; then
            sudo mkdir -p /mnt/Media
            sudo cp /etc/fstab /etc/fstab.bak
            print "\n# Media Drive\nUUID=$MEDIA_UUID\t/mnt/Media\tbtrfs\t$MOUNT_OPTS\t0 0" | sudo tee -a /etc/fstab > /dev/null
            sudo systemctl daemon-reload
            if sudo mount /mnt/Media 2>/dev/null; then
                print "${GREEN}Drive mounted. Applying structure and ACLs...${NC}"

                sudo mkdir -p /mnt/Media/{Films,TV,Music/{Maintained,Manual},Downloads/{lidarr,radarr,slskd,sonarr,transmission}}

                if ! lsattr -d /mnt/Media/Downloads | grep -q "C"; then
                    sudo chattr +C /mnt/Media/Downloads
                    print "Applied No-CoW (+C) attribute to /mnt/Media/Downloads"
                fi

                print "Applying Access Control Lists..."
                sudo chown -R "$USER:media" /mnt/Media
                sudo chmod -R 775 /mnt/Media
                sudo setfacl -R -m g:media:rwX /mnt/Media
                sudo setfacl -R -m d:g:media:rwX /mnt/Media
            else
                print "${RED}Warning: Mount failed. Check UUID.${NC}"
            fi
        else
            print "${RED}Skipping Media drive setup (No UUID provided).${NC}"
        fi
    else
        print "${RED}Skipping Media drive setup as requested.${NC}"
    fi
fi

# ------------------------------------------------------------------------------
# ------------------------------------------------------------------------------

# 4b. Service Finalization
# Now that the drive is mounted, we can safely add mount dependencies and start services.
print "${GREEN}--- Finalizing Services ---${NC}"

# Apply Overrides to Standard Services
for service in $SERVICES; do
    sudo mkdir -p "/etc/systemd/system/$service.service.d"
    # Write overrides now that mount exists
    print "[Unit]\nRequiresMountsFor=/mnt/Media" | sudo tee "/etc/systemd/system/$service.service.d/media-mount.conf" > /dev/null
    print "[Service]\nUMask=0002" | sudo tee "/etc/systemd/system/$service.service.d/permissions.conf" > /dev/null
done

sudo systemctl daemon-reload

print "Enabling and starting media stack..."
# Enable Standard Services
sudo systemctl enable --now $SERVICES

# Enable Custom Tools (Configured in Sec 3)
sudo systemctl enable --now slskd
sudo systemctl enable --now soularr.timer

# ------------------------------------------------------------------------------
# ------------------------------------------------------------------------------

# 5. Sunshine Performance
print "${GREEN}--- Configuring Sunshine Performance ---${NC}"

BOOST_SCRIPT="$REPO_ROOT/Scripts/sunshine_gpu_boost.zsh"
HDR_SCRIPT="$REPO_ROOT/Scripts/sunshine_hdr.zsh"
RES_SCRIPT="$REPO_ROOT/Scripts/sunshine_res.zsh"
CARD_PATH="/sys/class/drm/card1/device/device"

if [[ -n "$CARD_PATH" ]]; then
    print "Detected RX 7900 XT at: ${CARD_PATH:h}"

    if [[ -f "$BOOST_SCRIPT" ]]; then
        chmod +x "$BOOST_SCRIPT"

        # Dynamically update the script to match this machine's card path
        # Uses :h to strip '/device' filename, leaving '.../card1/device'
        DETECTED_SYSFS="${CARD_PATH:h}/power_dpm_force_performance_level"
        print "Updating boost script with path: $DETECTED_SYSFS"
        sed -i 's|^GPU_SYSFS=.*|GPU_SYSFS="'"$DETECTED_SYSFS"'"|' "$BOOST_SCRIPT"

        # Sudoers Rule pointing to REPO path
        print "$USER ALL=(ALL) NOPASSWD: /usr/local/bin/sunshine_gpu_boost" | sudo tee /etc/sudoers.d/90-sunshine-boost > /dev/null
        sudo chmod 440 /etc/sudoers.d/90-sunshine-boost

        # Symlink to /usr/local/bin
        sudo ln -sf "$BOOST_SCRIPT" "/usr/local/bin/sunshine_gpu_boost"

        print "Configured GPU Boost in repo: $BOOST_SCRIPT"
    else
        print "${YELLOW}Warning: Source script $BOOST_SCRIPT not found.${NC}"
    fi
else
    print "${YELLOW}Warning: RX 7900 XT not found. Skipping GPU Boost setup.${NC}"
fi

# Install HDR/Resolution Scripts
for script in "$HDR_SCRIPT" "$RES_SCRIPT"; do
    if [[ -f "$script" ]]; then
        chmod +x "$script"
        # Symlink to /usr/local/bin without extension (e.g., sunshine_hdr)
        sudo ln -sf "$script" "/usr/local/bin/${${script:t}:r}"
        print "Symlinked ${${script:t}:r} to /usr/local/bin"
    fi
done

# Interactive Config for Resolution Scripts
if (( $+commands[kscreen-doctor] )); then
    print "\n${YELLOW}--- Sunshine Resolution/HDR Configuration ---${NC}"
    print "Current Output Configuration:"
    kscreen-doctor -o
    print ""
    read "CONFIRM?Configure Sunshine Monitor and Mode Indexes now? [Y/n]: "
    if [[ "$CONFIRM" =~ ^[Yy]$ ]]; then
        read "MON_ID?Enter Monitor ID (e.g. DP-1): "
        read "STREAM_IDX?Enter Target Stream Mode Index (e.g. 9): "
        read "DEFAULT_IDX?Enter Default Mode Index (e.g. 1): "

        if [[ -n "$MON_ID" && -n "$STREAM_IDX" && -n "$DEFAULT_IDX" ]]; then
            for file in "$HDR_SCRIPT" "$RES_SCRIPT"; do
                sed -i 's/^MONITOR=.*/MONITOR="'"$MON_ID"'"/' "$file"
                sed -i 's/^STREAM_MODE=.*/STREAM_MODE="'"$STREAM_IDX"'"/' "$file"
                sed -i 's/^DEFAULT_MODE=.*/DEFAULT_MODE="'"$DEFAULT_IDX"'"/' "$file"
                print "Updated variables in $file"
            done
        else
             print "${RED}Invalid input. Skipping configuration.${NC}"
        fi
    fi
fi

# ------------------------------------------------------------------------------
# ------------------------------------------------------------------------------

# 6. Local Binaries
print "${GREEN}--- Configuring Local Binaries ---${NC}"
mkdir -p "$HOME/.local/bin"
SOURCE_SCRIPT="$REPO_ROOT/Scripts/jellyfin_fix_cover_art.zsh"
TARGET_LINK="$HOME/.local/bin/fix_cover_art"

if [[ -f "$SOURCE_SCRIPT" ]]; then
    ln -sf "$SOURCE_SCRIPT" "$TARGET_LINK"
    chmod +x "$TARGET_LINK"
    print "Symlinked jellyfin_fix_cover_art to ~/.local/bin."
else
    print "${YELLOW}Warning: $SOURCE_SCRIPT not found.${NC}"
fi

# ------------------------------------------------------------------------------
# ------------------------------------------------------------------------------

# 7. KDE Integration
print "${GREEN}--- KDE Rules ---${NC}"
grep -q 'export PATH="$HOME/.local/bin:$PATH"' "$HOME/.zshrc" || print 'export PATH="$HOME/.local/bin:$PATH"' >> "$HOME/.zshrc"
[[ -f "$SCRIPT_DIR/kwin_apply_rules.zsh" ]] && chmod +x "$SCRIPT_DIR/kwin_apply_rules.zsh" && "$SCRIPT_DIR/kwin_apply_rules.zsh" desktop

# ------------------------------------------------------------------------------
# ------------------------------------------------------------------------------

# 8. Theming (Konsave)
print "${GREEN}--- Applying Visual Profile ---${NC}"
KONSAVE_DIR="$REPO_ROOT/Resources/Konsave"

# Find profile: Match "Desktop Dock*.knsv", Sort by Name Descending (.On), Pick 1st
PROFILE_FILE=( "$KONSAVE_DIR"/Desktop\ Dock*.knsv(.On[1]) )

if [[ -n "$PROFILE_FILE" && -f "$PROFILE_FILE" ]]; then
    PROFILE_NAME="${${PROFILE_FILE:t}:r}"
    print "Found profile: $PROFILE_NAME"
    # Remove existing profile to force update (suppress errors)
    konsave -r "$PROFILE_NAME" 2>/dev/null || true
    # Import and Apply (suppress deprecation warnings)
    if konsave -i "$PROFILE_FILE" >/dev/null 2>&1; then
        konsave -a "$PROFILE_NAME" >/dev/null 2>&1
        print "Successfully applied profile: $PROFILE_NAME"
    else
        print "${RED}Error: Failed to import profile.${NC}"
    fi
else
    print "${YELLOW}Warning: No 'Desktop Dock' profile found in $KONSAVE_DIR${NC}"
fi

# ------------------------------------------------------------------------------
# ------------------------------------------------------------------------------

print "${GREEN}--- Desktop Setup Complete. Reboot Required. ---${NC}"
