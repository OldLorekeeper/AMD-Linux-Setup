#!/bin/zsh
# ------------------------------------------------------------------------------
# 4. Desktop Profile Setup
# Configures the static workstation profile (Gaming, Media Hosting, Sunshine).
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

print -P "%F{green}--- Starting Desktop Setup ---%f"

# ------------------------------------------------------------------------------
# 1. Repos & Hooks
# ------------------------------------------------------------------------------

# Purpose: Enable Sunshine streaming and third-party tools.
# - Icons: Replaces tray icons with custom SVGs.
# - Repo: Injects LizardByte (Sunshine) repository.
# - Hook: Automates icon replacement on package updates.

print -P "%F{green}--- Configuring Sunshine & Repos ---%f"

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
# 2. Packages & Services (Preparation)
# ------------------------------------------------------------------------------

# Purpose: Deploy and configure the media hosting stack.
# - Packages: Installs desktop-specific software (Lutris, Sunshine, etc.).
# - Groups: Adds user and services to the 'media' group for shared access.
# - Jellyfin: Configures HW acceleration and RAM transcoding (prevents Btrfs CoW fragmentation)
# - Sunshine: Sets cap_sys_admin for robust KMS capture

print -P "%F{green}--- Packages & Services ---%f"
yay -S --needed --noconfirm - < "$REPO_ROOT/Resources/Packages/desktop_pkg.txt"

print "Configuring 'media' group..."
sudo groupadd -f media
sudo usermod -aG media "$USER"

print "Optimising Jellyfin for Btrfs..."
sudo mkdir -p /var/lib/jellyfin
if ! lsattr -d /var/lib/jellyfin | grep -q "C"; then
    sudo chattr +C /var/lib/jellyfin
    print "Applied No-CoW (+C) attribute to /var/lib/jellyfin"
fi
sudo chown -R jellyfin:jellyfin /var/lib/jellyfin

SERVICES=("sonarr" "radarr" "lidarr" "prowlarr" "jellyfin" "transmission")
for svc in $SERVICES slskd; do
    id "$svc" &>/dev/null && sudo usermod -aG media "$svc"
done

print "Configuring Jellyfin Hardware Access..."
id "jellyfin" &>/dev/null && sudo usermod -aG render,video jellyfin

print "Configuring Jellyfin Transcoding (RAM Disk)..."
print "d /dev/shm/jellyfin 0755 jellyfin jellyfin -" | sudo tee /etc/tmpfiles.d/jellyfin-transcode.conf > /dev/null

print "Configuring Transmission Permissions..."
sudo systemctl stop transmission
sudo python -c "
import json
from pathlib import Path
path = Path('/var/lib/transmission/.config/transmission-daemon/settings.json')
if path.exists():
    data = json.loads(path.read_text())
    data['umask'] = 2
    path.write_text(json.dumps(data, indent=4))
"
sudo systemctl daemon-reload
sudo systemctl start transmission

REAL_SUNSHINE_PATH=${commands[sunshine]:A}
sudo setcap cap_sys_admin+p "$REAL_SUNSHINE_PATH"
systemctl --user enable --now sunshine

sudo wget -O /etc/udev/rules.d/42-solaar-uinput.rules https://raw.githubusercontent.com/pwr-Solaar/Solaar/refs/heads/master/rules.d-uinput/42-logitech-unify-permissions.rules
sudo udevadm control --reload-rules && sudo udevadm trigger

# ------------------------------------------------------------------------------
# 3. Custom Tools Configuration
# ------------------------------------------------------------------------------

# Purpose: Configure automated music acquisition tools.
# - Slskd: Generates config with user credentials.
# - Soularr: Clones/updates automation scripts and sets up systemd timers.

print -P "%F{green}--- Configuring Tools ---%f"

print "Configuring Slskd..."
sudo mkdir -p /etc/slskd
if [[ ! -f /etc/slskd/slskd.yml ]]; then
    print -P "%F{green}--- Configure Slskd Credentials ---%f"
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
    print -P "%F{yellow}slskd.yml exists. Skipping overwrite.%f"
fi

sudo mkdir -p /etc/systemd/system/slskd.service.d
sudo tee /etc/systemd/system/slskd.service.d/override.conf > /dev/null << EOF
[Unit]
RequiresMountsFor=/mnt/Media
[Service]
UMask=0002
ExecStart=
ExecStart=/usr/lib/slskd/slskd --config /etc/slskd/slskd.yml
EOF

print "Configuring Soularr..."
if [[ ! -d "/opt/soularr" ]]; then
    cd /opt && sudo git clone https://github.com/mrusse/soularr.git
    sudo chown -R "$USER:$(id -gn "$USER")" /opt/soularr
else
    print -P "%F{yellow}Soularr directory exists. Skipping clone.%f"
fi

sudo pip install --break-system-packages -r /opt/soularr/requirements.txt
sudo mkdir -p /opt/soularr/config
[[ ! -f /opt/soularr/config/config.ini ]] && sudo cp /opt/soularr/config.ini /opt/soularr/config/config.ini

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
# 4. Hardware & Kernel
# ------------------------------------------------------------------------------

# Purpose: Optimize hardware for gaming and hosting.
# - USB/WiFi: Disables power saving for stability (specific to Asus X670E-I controller).
# - EDID: Injects custom 2560x1600 (16:10) firmware for remote streaming without conflicting GRUB entries.
# - GRUB: Updates kernel parameters (hugepages, pstate, video). Hugepages help with legacy stability and VM readiness.
# - Storage: Mounts /mnt/Media with Btrfs optimizations (+C, zstd); also ensures proper permissions linked to 'media' group.

print -P "%F{green}--- Hardware Fixes and Media Mount ---%f"

sudo sysctl --system
print 'SUBSYSTEM=="pci", ATTR{vendor}=="0x1022", ATTR{device}=="0x43f7", ATTR{power/control}="on"' | sudo tee /etc/udev/rules.d/99-xhci-fix.rules > /dev/null

sudo tee /etc/NetworkManager/dispatcher.d/disable-wifi-powersave > /dev/null << 'EOF'
#!/bin/sh
[[ "$1" == wl* ]] && [[ "$2" == "up" ]] && /usr/bin/iw dev "$1" set power_save off
EOF
sudo chmod +x /etc/NetworkManager/dispatcher.d/disable-wifi-powersave
nmcli radio wifi off && sleep 2 && nmcli radio wifi on

print 'ACTION=="add|change", KERNEL=="nvme[0-9]n[0-9]", ATTR{queue/scheduler}="kyber"' | sudo tee /etc/udev/rules.d/60-iosched.rules > /dev/null
sudo udevadm control --reload-rules && sudo udevadm trigger

print -P "%F{yellow}--- Kernel & Monitor Configuration ---%f"
BASE_CMDLINE="loglevel=3 quiet amdgpu.ppfeaturemask=0xffffffff hugepages=512 video=3440x1440@60 amd_pstate=active"
FINAL_CMDLINE="$BASE_CMDLINE"

print "Hardware Detection:"
print "1. Monitor: iiyama G-Master GB3461WQSU-B1 (3440 x 1440)"
print "2. Client:  Slimbook EXCALIBUR-16 (2560 x 1600)"
read "INSTALL_EDID?Enable custom EDID for Moonlight streaming to Slimbook? [y/N]: "

if [[ "$INSTALL_EDID" =~ ^[Yy]$ ]]; then
    EDID_SRC="$REPO_ROOT/Resources/Sunshine/custom_2560x1600.bin"
    EDID_DEST="/usr/lib/firmware/edid/custom_2560x1600.bin"
    if [[ -f "$EDID_SRC" ]]; then
        print -P "%F{green}Installing custom EDID firmware...%f"
        sudo mkdir -p "${EDID_DEST:h}"
        sudo cp "$EDID_SRC" "$EDID_DEST"
        if ! grep -q "custom_2560x1600.bin" /etc/mkinitcpio.conf; then
            print "Adding EDID to initramfs configuration..."
            sudo sed -i 's|^FILES=(|FILES=(/usr/lib/firmware/edid/custom_2560x1600.bin |' /etc/mkinitcpio.conf
            print "Rebuilding initramfs..."
            sudo mkinitcpio -P
        fi

        local -a CONNECTED_PORTS
        for status_file in /sys/class/drm/*/status; do
            if [[ $(< $status_file) == "connected" ]]; then
                local port="${${status_file:h}:t}"
                CONNECTED_PORTS+=("${port#card*-}")
            fi
        done

        TARGET_PORT=""
        if [[ ${#CONNECTED_PORTS[@]} -eq 1 ]]; then
            TARGET_PORT="${CONNECTED_PORTS[1]}"
            print -P "Detected single monitor: %F{green}$TARGET_PORT%f"
        elif [[ ${#CONNECTED_PORTS[@]} -gt 1 ]]; then
            print -P "%F{yellow}Multiple monitors detected:%f"
            select opt in "${CONNECTED_PORTS[@]}"; do
                [[ -n "$opt" ]] && TARGET_PORT="$opt" && break
                print -P "%F{red}Invalid selection.%f"
            done
        else
            print -P "%F{red}No monitors detected automatically.%f"
            read "TARGET_PORT?Enter monitor identifier manually (e.g., DP-2): "
        fi
        if [[ -n "$TARGET_PORT" ]]; then
            print -P "Applying EDID override to port: %F{green}$TARGET_PORT%f"
            FINAL_CMDLINE="$BASE_CMDLINE drm.edid_firmware=${TARGET_PORT}:edid/custom_2560x1600.bin"
        else
            print -P "%F{red}Error: No port selected. Skipping EDID parameter.%f"
        fi
    else
        print -P "%F{yellow}Warning: EDID file not found at $EDID_SRC%f"
    fi
else
    print "Skipping custom EDID installation."
fi

print "Updating GRUB with parameters:"
print -P "%F{yellow}$FINAL_CMDLINE%f"
sudo sed -i 's|^GRUB_CMDLINE_LINUX_DEFAULT=.*|GRUB_CMDLINE_LINUX_DEFAULT="'"$FINAL_CMDLINE"'"|' /etc/default/grub
sudo grub-mkconfig -o /boot/grub/grub.cfg

print -P "%F{yellow}--- Media Drive Setup ---%f"
MOUNT_OPTS="rw,nosuid,nodev,noatime,nofail,x-gvfs-hide,x-systemd.automount,compress=zstd:3,discard=async"
if grep -q "/mnt/Media" /etc/fstab; then
    print -P "%F{yellow}/mnt/Media already configured in fstab. Skipping mount injection.%f"
else
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
                print -P "%F{green}Drive mounted. Applying structure and ACLs...%f"
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
                print -P "%F{red}Warning: Mount failed. Check UUID.%f"
            fi
        else
            print -P "%F{red}Skipping Media drive setup (No UUID provided).%f"
        fi
    else
        print -P "%F{red}Skipping Media drive setup as requested.%f"
    fi
fi

# ------------------------------------------------------------------------------
# 5. Service Finalization
# ------------------------------------------------------------------------------

# Purpose: Enable and secure the media service stack.
# - Permissions: Enforces UMask=0002 for group write access (except jellyfin due to /var/lib/jellyfin conflicts)
# - Dependencies: Ensures services wait for /mnt/Media mount.
# - State: Enables and starts all media services.

print -P "%F{green}--- Finalizing Services ---%f"
for service in $SERVICES; do
    sudo mkdir -p "/etc/systemd/system/$service.service.d"
    print "[Unit]\nRequiresMountsFor=/mnt/Media" | sudo tee "/etc/systemd/system/$service.service.d/media-mount.conf" > /dev/null
    if [[ "$service" != "jellyfin" ]]; then
        print "[Service]\nUMask=0002" | sudo tee "/etc/systemd/system/$service.service.d/permissions.conf" > /dev/null
    fi
done

sudo systemctl daemon-reload
print "Enabling and starting media stack..."
sudo systemctl enable --now $SERVICES
sudo systemctl enable --now slskd
sudo systemctl enable --now soularr.timer

# ------------------------------------------------------------------------------
# 6. Tailscale Network
# ------------------------------------------------------------------------------

# Purpose: Establish secure mesh connectivity and exit node status.
# - Service: Ensures tailscaled is enabled and running.
# - Exit Node: Advertises the Desktop as a gateway for the Laptop.

print -P "%F{green}--- Configuring Tailscale Exit Node ---%f"
sudo systemctl enable --now tailscaled
sudo tailscale up --advertise-exit-node

# ------------------------------------------------------------------------------
# 7. Sunshine Performance
# ------------------------------------------------------------------------------

# Purpose: Tune GPU performance for streaming.
# - Boost: Installs script to force high GPU clocks.
# - Scripts: Symlinks resolution/HDR automation tools.
# - Config: Interactively sets monitor indices for automated switching.
# - GPU Path: Dynamic detection proved unreliable on this hardware. 'card1' is hardcoded intentionally.

print -P "%F{green}--- Configuring Sunshine Performance ---%f"
BOOST_SCRIPT="$REPO_ROOT/Scripts/sunshine_gpu_boost.zsh"
HDR_SCRIPT="$REPO_ROOT/Scripts/sunshine_hdr.zsh"
RES_SCRIPT="$REPO_ROOT/Scripts/sunshine_res.zsh"
LAPTOP_SCRIPT="$REPO_ROOT/Scripts/sunshine_laptop.zsh"
CARD_PATH="/sys/class/drm/card1/device/device"

if [[ -n "$CARD_PATH" ]]; then
    print "Detected RX 7900 XT at: ${CARD_PATH:h}"
    if [[ -f "$BOOST_SCRIPT" ]]; then
        chmod +x "$BOOST_SCRIPT"
        DETECTED_SYSFS="${CARD_PATH:h}/power_dpm_force_performance_level"
        print "Updating boost script with path: $DETECTED_SYSFS"
        sed -i 's|^GPU_SYSFS=.*|GPU_SYSFS="'"$DETECTED_SYSFS"'"|' "$BOOST_SCRIPT"
        print "$USER ALL=(ALL) NOPASSWD: /usr/local/bin/sunshine_gpu_boost" | sudo tee /etc/sudoers.d/90-sunshine-boost > /dev/null
        sudo chmod 440 /etc/sudoers.d/90-sunshine-boost
        sudo ln -sf "$BOOST_SCRIPT" "/usr/local/bin/sunshine_gpu_boost"
        print "Configured GPU Boost in repo: $BOOST_SCRIPT"
    else
        print -P "%F{yellow}Warning: Source script $BOOST_SCRIPT not found.%f"
    fi
else
    print -P "%F{yellow}Warning: RX 7900 XT not found. Skipping GPU Boost setup.%f"
fi

for script in "$HDR_SCRIPT" "$RES_SCRIPT" "$LAPTOP_SCRIPT"; do
    if [[ -f "$script" ]]; then
        chmod +x "$script"
        sudo ln -sf "$script" "/usr/local/bin/${${script:t}:r}"
        print "Symlinked ${${script:t}:r} to /usr/local/bin"
    fi
done

if (( $+commands[kscreen-doctor] )); then
    print -P "\n%F{yellow}--- Sunshine Resolution/HDR Configuration ---%f"
    print "Current Output Configuration:"
    kscreen-doctor -o; print ""
    read "CONFIRM?Configure Sunshine Monitor and Mode Indexes now? [Y/n]: "
    if [[ "$CONFIRM" =~ ^[Yy]$ ]]; then
        read "MON_ID?Enter Monitor ID (e.g. DP-1): "
        read "STREAM_IDX?Enter Target Stream Mode Index (e.g. 9): "
        read "DEFAULT_IDX?Enter Default Mode Index (e.g. 1): "
        if [[ -n "$MON_ID" && -n "$STREAM_IDX" && -n "$DEFAULT_IDX" ]]; then
            for file in "$HDR_SCRIPT" "$RES_SCRIPT" "$LAPTOP_SCRIPT"; do
                sed -i 's/^MONITOR=.*/MONITOR="'"$MON_ID"'"/' "$file"
                sed -i 's/^STREAM_MODE=.*/STREAM_MODE="'"$STREAM_IDX"'"/' "$file"
                sed -i 's/^DEFAULT_MODE=.*/DEFAULT_MODE="'"$DEFAULT_IDX"'"/' "$file"
                print "Updated variables in $file"
            done
        else
             print -P "%F{red}Invalid input. Skipping configuration.%f"
        fi
    fi
fi

# ------------------------------------------------------------------------------
# 8. Local Binaries
# ------------------------------------------------------------------------------

# Purpose: Install utility scripts.
# - Cover Art: Symlinks Jellyfin fix script.

print -P "%F{green}--- Configuring Local Binaries ---%f"
mkdir -p "$HOME/.local/bin"
SOURCE_SCRIPT="$REPO_ROOT/Scripts/jellyfin_fix_cover_art.zsh"
TARGET_LINK="$HOME/.local/bin/fix_cover_art"

if [[ -f "$SOURCE_SCRIPT" ]]; then
    ln -sf "$SOURCE_SCRIPT" "$TARGET_LINK"
    chmod +x "$TARGET_LINK"
    print "Symlinked jellyfin_fix_cover_art to ~/.local/bin."
else
    print -P "%F{yellow}Warning: $SOURCE_SCRIPT not found.%f"
fi

# ------------------------------------------------------------------------------
# 9. KDE Integration
# ------------------------------------------------------------------------------

# Purpose: Apply desktop-specific window rules.
# - Rules: Executes kwin_apply_rules.zsh with 'desktop' profile.

print -P "%F{green}--- KDE Rules ---%f"
grep -q 'export PATH="$HOME/.local/bin:$PATH"' "$HOME/.zshrc" || print 'export PATH="$HOME/.local/bin:$PATH"' >> "$HOME/.zshrc"
[[ -f "$SCRIPT_DIR/kwin_apply_rules.zsh" ]] && chmod +x "$SCRIPT_DIR/kwin_apply_rules.zsh" && "$SCRIPT_DIR/kwin_apply_rules.zsh" desktop

# ------------------------------------------------------------------------------
# 10. Theming (Konsave)
# ------------------------------------------------------------------------------

# Purpose: Apply the visual desktop profile.
# - Konsave: Imports and applies the 'Desktop Dock' profile.

print -P "%F{green}--- Applying Visual Profile ---%f"
KONSAVE_DIR="$REPO_ROOT/Resources/Konsave"
PROFILE_FILE=( "$KONSAVE_DIR"/Desktop\ Dock*.knsv(.On[1]) )

if [[ -n "$PROFILE_FILE" && -f "$PROFILE_FILE" ]]; then
    PROFILE_NAME="${${PROFILE_FILE:t}:r}"
    print "Found profile: $PROFILE_NAME"
    konsave -r "$PROFILE_NAME" 2>/dev/null || true
    if konsave -i "$PROFILE_FILE" >/dev/null 2>&1; then
        konsave -a "$PROFILE_NAME" >/dev/null 2>&1
        print "Successfully applied profile: $PROFILE_NAME"
    else
        print -P "%F{red}Error: Failed to import profile.%f"
    fi
else
    print -P "%F{yellow}Warning: No 'Desktop Dock' profile found in $KONSAVE_DIR%f"
fi

# ------------------------------------------------------------------------------
# End - Reboot
# ------------------------------------------------------------------------------

print -P "%F{green}--- Desktop Setup Complete. Reboot Required. ---%f"
