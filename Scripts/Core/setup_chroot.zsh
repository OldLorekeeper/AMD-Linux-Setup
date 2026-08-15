#!/bin/zsh
# ------------------------------------------------------------------------------
# Arch-Config: Stage 2 (Chroot)
# Configures the base system from within the new arch-chroot environment.
# ------------------------------------------------------------------------------

# region
setopt ERR_EXIT NO_UNSET PIPE_FAIL EXTENDED_GLOB
source /install_vars.zsh; rm -f /install_vars.zsh
trap 'rm -f /etc/sudoers.d/99_setup_temp' EXIT
# endregion

# ------------------------------------------------------------------------------
# 1. Identity & Locale
# ------------------------------------------------------------------------------

# Purpose: Configures system locale, timezone, and hostname based on pre-flight variables.

# region
print -P "\n%K{yellow}%F{black} IDENTITY & LOCALE %k%f\n"
print -P "%F{cyan}ℹ Configuring Timezone and Locale...%f\n"
ln -sf /usr/share/zoneinfo/Europe/London /etc/localtime
hwclock --systohc
print -l "en_GB.UTF-8 UTF-8" "en_US.UTF-8 UTF-8" > /etc/locale.gen
locale-gen
print "LANG=en_GB.UTF-8" > /etc/locale.conf
print "KEYMAP=uk" > /etc/vconsole.conf
print "$HOSTNAME" > /etc/hostname
print -l "127.0.1.1   $HOSTNAME.localdomain $HOSTNAME" "127.0.0.1   localhost" "::1         localhost" >> /etc/hosts
# endregion

# ------------------------------------------------------------------------------
# 2. Users & Permissions
# ------------------------------------------------------------------------------

# Purpose: Creates the primary user account, applies passwords, and configures sudo/media permissions.

# region
print -P "\n%K{yellow}%F{black} USERS & PERMISSIONS %k%f\n"
print -P "%F{cyan}ℹ Creating user: $TARGET_USER...%f\n"
getent group polkit >/dev/null || groupadd polkit
id -u "$TARGET_USER" &>/dev/null || useradd -m -G wheel,input,render,video,storage,gamemode,libvirt,realtime -s /bin/zsh "$TARGET_USER"
print "root:$ROOT_PASS" | chpasswd
print "$TARGET_USER:$USER_PASS" | chpasswd
print "%wheel ALL=(ALL:ALL) ALL" > /etc/sudoers.d/wheel
print 'Defaults passprompt="Enter sudo password to continue: "' > /etc/sudoers.d/custom_prompt
print "$TARGET_USER ALL=(ALL) NOPASSWD: ALL" > /etc/sudoers.d/99_setup_temp
chmod 440 /etc/sudoers.d/99_setup_temp
chmod 440 /etc/sudoers.d/custom_prompt
getent group media >/dev/null || groupadd -f media
usermod -aG media "$TARGET_USER"
mkdir -p "/home/$TARGET_USER/Games"; chown "$TARGET_USER:$TARGET_USER" "/home/$TARGET_USER/Games"
# endregion

# ------------------------------------------------------------------------------
# 3. Network & Services
# ------------------------------------------------------------------------------

# Purpose: Configures NetworkManager, iwd (Wi-Fi), Bluetooth, and reflector services.

#region
print -P "\n%K{yellow}%F{black} NETWORK & SERVICES %k%f\n"
print -P "%F{cyan}ℹ Configuring NetworkManager, iwd, and Bluetooth...%f\n"
mkdir -p /etc/NetworkManager/conf.d; print -l "[device]" "wifi.backend=iwd" > /etc/NetworkManager/conf.d/wifi_backend.conf
mkdir -p /etc/iwd; print -l "[General]" "Country=GB" > /etc/iwd/main.conf
sed -i 's/^#*\(Experimental = \).*/\1true/' /etc/bluetooth/main.conf
systemctl enable NetworkManager bluetooth sshd plasmalogin fwupd.service reflector.timer

mkdir -p /etc/xdg/reflector
print -l -- "--country GB,IE,NL,DE,FR,EU" "--latest 20" "--sort rate" "--save /etc/pacman.d/mirrorlist" > /etc/xdg/reflector/reflector.conf

print -P "\n%F{cyan}ℹ Installing Network Dispatcher Scripts...%f\n"
mkdir -p /etc/NetworkManager/dispatcher.d
print -l '#!/bin/zsh' '[[ "$2" == "up" ]] && /usr/bin/ethtool -K "$1" rx-udp-gro-forwarding on rx-gro-list off 2>/dev/null || true' > /etc/NetworkManager/dispatcher.d/99-tailscale-gro
print -l '#!/bin/bash' 'if [[ "$1" == wl* ]] && [[ "$2" == "up" ]]; then /usr/bin/iw dev "$1" set power_save off; fi' > /etc/NetworkManager/dispatcher.d/disable-wifi-powersave
chmod +x /etc/NetworkManager/dispatcher.d/{99-tailscale-gro,disable-wifi-powersave}
# endregion

# ------------------------------------------------------------------------------
# 4. Bootloader
# ------------------------------------------------------------------------------

# Purpose: Installs the GRUB bootloader to the EFI partition.

# region
print -P "\n%K{yellow}%F{black} BOOTLOADER %k%f\n"
print -P "%F{cyan}ℹ Installing GRUB...%f\n"
grub-install --target=x86_64-efi --efi-directory=/efi --bootloader-id=GRUB
# endregion

# ------------------------------------------------------------------------------
# 5. Build Env & Repos
# ------------------------------------------------------------------------------

# Purpose: Optimises makepkg for native architecture, populates Arch/CachyOS keyrings, and updates mirrors.

# region
print -P "\n%K{yellow}%F{black} BUILD ENV & REPOS %k%f\n"
print -P "%F{cyan}ℹ Tuning makepkg and pacman keys...%f\n"
sed -i 's/-march=x86-64 -mtune=generic/-march=native/' /etc/makepkg.conf
sed -i "s/^#*MAKEFLAGS=.*/MAKEFLAGS=\"-j\$(nproc)\"/" /etc/makepkg.conf
[[ "$(findmnt -n -o FSTYPE /tmp)" == "tmpfs" ]] && sed -i 's/^#*\(BUILDDIR=\/tmp\/makepkg\)/\1/' /etc/makepkg.conf
sed -i 's/^#*COMPRESSZST=.*/COMPRESSZST=(zstd -c -z -q -T0 -3 -)/' /etc/makepkg.conf
grep -q "RUSTFLAGS" /etc/makepkg.conf || print 'RUSTFLAGS="-C target-cpu=native"' >> /etc/makepkg.conf
pacman-key --init; pacman-key --populate archlinux
pacman -Q cachyos-keyring &>/dev/null && pacman-key --populate cachyos

if ! grep -q "lizardbyte" /etc/pacman.conf; then
    print -l "" "[lizardbyte]" "SigLevel = Optional" "Server = https://github.com/LizardByte/pacman-repo/releases/latest/download" >> /etc/pacman.conf
fi
pacman -Sy
# endregion

# ------------------------------------------------------------------------------
# 6. AUR Helper (yay)
# ------------------------------------------------------------------------------

# Purpose: Clones and builds the 'yay' AUR helper.

#region
print -P "\n%K{yellow}%F{black} AUR HELPER %k%f\n"
print -P "%F{cyan}ℹ Cloning and building yay...%f\n"
chown -R "$TARGET_USER:$TARGET_USER" "/home/$TARGET_USER"
cd "/home/$TARGET_USER"
sudo -u "$TARGET_USER" git clone https://aur.archlinux.org/yay.git
cd yay; sudo -u "$TARGET_USER" makepkg -si --noconfirm; cd ..; rm -rf yay
# endregion

# ------------------------------------------------------------------------------
# 7. Extended Packages
# ------------------------------------------------------------------------------

# Purpose: Installs extended AUR packages based on the active hardware profile.

# region
print -P "\n%K{yellow}%F{black} EXTENDED PACKAGES %k%f\n"
TARGET_AUR=("antigravity" "antigravity-cli" "antigravity-ide" "darkly-bin" "geekbench" "google-chrome" "konsave" "kwin-effects-better-blur-dx" "papirus-folders" "plasma6-applets-panel-colorizer" "timeshift-systemd-timer")
if [[ "$DEVICE_PROFILE" == "desktop" ]]; then
    TARGET_AUR+=("lact" "prowlarr-bin" "radarr-bin" "seerr" "sonarr-bin" "sunshine" "bun-bin" "redis")
elif [[ "$DEVICE_PROFILE" == "laptop" ]]; then
    TARGET_AUR+=("mkinitcpio-numlock")
fi

print -P "%F{cyan}ℹ Installing Extended Packages via Yay...%f\n"
sudo -u "$TARGET_USER" yay -S --needed --noconfirm "${TARGET_AUR[@]}"
# endregion

# ------------------------------------------------------------------------------
# 8. Dotfiles & Home
# ------------------------------------------------------------------------------

# Purpose: Configures Git identity, clones the main repository, and sets up Oh My Zsh and Antigravity IDE configuration.

# region
print -P "\n%K{yellow}%F{black} DOTFILES & HOME %k%f\n"
print -P "%F{cyan}ℹ Setting up Git identity and repositories...%f\n"
mkdir -p "/home/$TARGET_USER"{Make,Obsidian} "/home/$TARGET_USER/.local/bin"
chown -R "$TARGET_USER:$TARGET_USER" "/home/$TARGET_USER"

if [[ -n "$GIT_NAME" ]]; then
    sudo -u "$TARGET_USER" git config --global user.name "$GIT_NAME"
    sudo -u "$TARGET_USER" git config --global user.email "$GIT_EMAIL"
    if [[ -n "$GIT_PAT" ]]; then
        print "https://$GIT_NAME:$GIT_PAT@github.com" > "/home/$TARGET_USER/.git-credentials"
        chmod 600 "/home/$TARGET_USER/.git-credentials"
        chown "$TARGET_USER:$TARGET_USER" "/home/$TARGET_USER/.git-credentials"
        sudo -u "$TARGET_USER" git config --global credential.helper store
    else
        sudo -u "$TARGET_USER" git config --global credential.helper libsecret
    fi
fi

REPO_DIR="/home/$TARGET_USER/Obsidian/Arch-Config"
print -P "\n%F{cyan}ℹ Cloning Main Repository...%f\n"
sudo -u "$TARGET_USER" git clone https://github.com/OldLorekeeper/Arch-Config "$REPO_DIR"
SECRETS_DIR="$REPO_DIR/Secrets"
if [[ -n "$GIT_PAT" ]]; then
    print -P "\n%F{cyan}ℹ Cloning Private Secrets Repository...%f\n"
    sudo -u "$TARGET_USER" git clone "https://$GIT_NAME:$GIT_PAT@github.com/OldLorekeeper/Arch-Secrets.git" "$SECRETS_DIR" || mkdir -p "$SECRETS_DIR"
else
    mkdir -p "$SECRETS_DIR"
fi
chmod +x "$REPO_DIR/Scripts/"*/*.zsh

if [[ ! -d "/home/$TARGET_USER/.oh-my-zsh" ]]; then
    print -P "\n%F{cyan}ℹ Installing Oh My Zsh...%f\n"
    sudo -u "$TARGET_USER" sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
fi

ZSH_CUSTOM="/home/$TARGET_USER/.oh-my-zsh/custom"
print -P "\n%F{cyan}ℹ Installing Zsh plugins...%f\n"
[[ ! -d "$ZSH_CUSTOM/plugins/zsh-autosuggestions" ]] && sudo -u "$TARGET_USER" git clone https://github.com/zsh-users/zsh-autosuggestions "$ZSH_CUSTOM/plugins/zsh-autosuggestions"
[[ ! -d "$ZSH_CUSTOM/plugins/zsh-syntax-highlighting" ]] && sudo -u "$TARGET_USER" git clone https://github.com/zsh-users/zsh-syntax-highlighting "$ZSH_CUSTOM/plugins/zsh-syntax-highlighting"

ln -sf "/home/$TARGET_USER/.oh-my-zsh" /root/.oh-my-zsh
ln -sf "/home/$TARGET_USER/.zshrc" /root/.zshrc

print -P "\n%F{cyan}ℹ Linking Zsh Configuration ($DEVICE_PROFILE)...%f\n"
rm -f "/home/$TARGET_USER/.zshrc"
ln -sf "$REPO_DIR/Resources/zshrc/zshrc_$DEVICE_PROFILE" "/home/$TARGET_USER/.zshrc"

if [[ "$SECRETS_LOADED" == "true" ]]; then
    zsh "$REPO_DIR/Scripts/Operations/antigravity_sync.zsh" "$TARGET_USER" || print -P "\n%F{red}⚠ Antigravity Sync encountered an issue but the install will continue.%f\n"
fi
# endregion

# ------------------------------------------------------------------------------
# 9. Final Theming
# ------------------------------------------------------------------------------

# Purpose: Applies custom KDE Plasma theming, including Konsole profiles, Papirus folders, and specific Kate icons.

# region
print -P "\n%K{yellow}%F{black} FINAL THEMING %k%f\n"
print -P "%F{cyan}ℹ Applying Konsole and icon themes...%f\n"
mkdir -p "/home/$TARGET_USER/.local/share/konsole"
cp -f "$REPO_DIR/Resources/Konsole"/* "/home/$TARGET_USER/.local/share/konsole/" 2>/dev/null || true
TRANS_ARCHIVE="$REPO_DIR/Resources/Plasmoids/transmission-plasmoid.tar.gz"
if [[ -f "$TRANS_ARCHIVE" ]]; then
    TRANS_DIR="/home/$TARGET_USER/.local/share/plasma/plasmoids/com.oldlorekeeper.transmission"
    mkdir -p "$TRANS_DIR"; tar -xf "$TRANS_ARCHIVE" -C "${TRANS_DIR:h}"
fi

papirus-folders -C breeze --theme Papirus-Dark || true
print -P "\n%F{cyan}ℹ Overwriting Kate Icons in Papirus...%f\n"
find /usr/share/icons/Papirus -type f \( -name "kate.svg" -o -name "kate-symbolic.svg" -o -name "kate2.svg" -o -name "org.kde.kate.svg" \) | while read -r icon; do
    [[ -f "$REPO_DIR/Resources/Icons/Kate/${icon:t}" ]] && cp -f "$REPO_DIR/Resources/Icons/Kate/${icon:t}" "$icon"
done
mkdir -p "/home/$TARGET_USER/.local/share/"{icons,kxmlgui5,plasma,color-schemes,aurorae,fonts,wallpapers}
# endregion

# ------------------------------------------------------------------------------
# 10. Device Logic
# ------------------------------------------------------------------------------

# Purpose: Applies device-specific logic (e.g. Konsave profiles, KWin rules, GRUB parameters, and Sunshine configuration).

# region
print -P "\n%K{yellow}%F{black} DEVICE LOGIC & THEME %k%f\n"
print -P "%F{cyan}ℹ Fixing permissions...%f\n"
chown -R "$TARGET_USER:$TARGET_USER" "/home/$TARGET_USER"

if [[ "$APPLY_KONSAVE" == "true" ]]; then
    PROFILE_DIR="$REPO_DIR/Resources/Konsave"
    [[ "$DEVICE_PROFILE" == "desktop" ]] && LATEST_KNSV=$(ls -t "$PROFILE_DIR"/Desktop*.knsv 2>/dev/null | head -n1) || LATEST_KNSV=$(ls -t "$PROFILE_DIR"/Laptop*.knsv 2>/dev/null | head -n1)
    if [[ -f "$LATEST_KNSV" ]]; then
        print -P "\n%F{cyan}ℹ Found latest Konsave profile: ${LATEST_KNSV:t}%f\n"
        sudo -u "$TARGET_USER" konsave -i "$LATEST_KNSV" --force
        sudo -u "$TARGET_USER" konsave -a "${LATEST_KNSV:t:r}"
    fi
fi

print -P "\n%F{cyan}ℹ Applying KWin Rules...%f\n"
sudo -u "$TARGET_USER" "$REPO_DIR/Scripts/Operations/kwin_sync.zsh" "$DEVICE_PROFILE"

print -l "LIBVA_DRIVER_NAME=radeonsi" "VDPAU_DRIVER=radeonsi" "WINEFSYNC=1" "PROTON_USE_NTSYNC=1" "PROTON_ENABLE_WAYLAND=1" >> /etc/environment
print 'ACTION=="add|change", KERNEL=="nvme[0-9]n[0-9]", ATTR{queue/scheduler}="none"' > /etc/udev/rules.d/60-iosched.rules

if [[ "$DEVICE_PROFILE" == "desktop" ]]; then
    print -P "\n%F{cyan}ℹ Applying Desktop Configuration...%f\n"
    
    print -P "%F{cyan}ℹ Configuring Media Optimizer Cronjob...%f\n"
    systemctl enable cronie.service
    ln -sf "$REPO_DIR/Scripts/Utils/media_optimizer.zsh" /usr/local/bin/media_optimizer
    sudo -u "$TARGET_USER" bash -c '(crontab -l 2>/dev/null; echo "0 1 * * * /usr/local/bin/media_optimizer > /tmp/media_optimizer.log 2>&1") | crontab -'
    
    print 'SUBSYSTEM=="pci", ATTR{vendor}=="0x1022", ATTR{device}=="0x43f7", ATTR{power/control}="on"' > /etc/udev/rules.d/99-xhci-fix.rules
    print 'w /sys/devices/system/cpu/cpu*/cpufreq/energy_performance_preference - - - - performance' > /etc/tmpfiles.d/amd-epp.conf
    GRUB_CMDLINE="split_lock_detect=off loglevel=3 quiet amdgpu.ppfeaturemask=0xffffffff video=3440x1440@60"
    EDID_SRC="$REPO_DIR/Resources/Sunshine/custom_sunshine.bin"
    if [[ "$EDID_ENABLE" == (#i)y* ]] && [[ -f "$EDID_SRC" ]]; then
        mkdir -p /usr/lib/firmware/edid; cp "$EDID_SRC" /usr/lib/firmware/edid/
        sed -i 's|^FILES=(|FILES=(/usr/lib/firmware/edid/custom_sunshine.bin |' /etc/mkinitcpio.conf
        [[ -n "$MONITOR_PORT" ]] && GRUB_CMDLINE="$GRUB_CMDLINE drm.edid_firmware=${MONITOR_PORT}:edid/custom_sunshine.bin"
    fi
    sed -i "s|^GRUB_CMDLINE_LINUX_DEFAULT=.*|GRUB_CMDLINE_LINUX_DEFAULT=\"$GRUB_CMDLINE\"|" /etc/default/grub
    sed -i 's/^GRUB_TIMEOUT=.*/GRUB_TIMEOUT=2/' /etc/default/grub
    
    print -l '#!/bin/bash' 'shopt -s nullglob' "cp \"$REPO_DIR/Resources/Icons/Sunshine\"/*.svg \"/usr/share/icons/hicolor/scalable/status/\"" 'setcap cap_sys_admin+p $(readlink -f $(command -v sunshine))' > /usr/local/bin/replace-sunshine-icons.sh
    chmod +x /usr/local/bin/replace-sunshine-icons.sh; /usr/local/bin/replace-sunshine-icons.sh
    
    mkdir -p /etc/pacman.d/hooks
    print -l "[Trigger]" "Operation = Install" "Operation = Upgrade" "Type = Package" "Target = sunshine" "[Action]" "When = PostTransaction" "Exec = /usr/local/bin/replace-sunshine-icons.sh" > /etc/pacman.d/hooks/sunshine-icons.hook
    
    mkdir -p /etc/lact
    print -l "version: 5" "daemon:" "  admin_group: wheel" "gpus:" "  default:" "    fan_control_enabled: true" "    fan_control_settings:" "      mode: curve" "      temperature_key: junction" "      curve:" "        40: 0.2" "        95: 1.0" "    power_cap: 310.0" "    performance_level: manual" > /etc/lact/config.yaml
    systemctl enable lactd
    
    print "$TARGET_USER ALL=(ALL) NOPASSWD: /usr/local/bin/sunshine_gpu_boost" > /etc/sudoers.d/90-sunshine-boost
    chmod 440 /etc/sudoers.d/90-sunshine-boost
    for script in sunshine_gpu_boost.zsh sunshine_hdr.zsh sunshine_res.zsh sunshine_laptop.zsh; do
        ln -sf "$REPO_DIR/Scripts/Sunshine/$script" "/usr/local/bin/${script:r}"; chmod +x "$REPO_DIR/Scripts/Sunshine/$script"
    done
    
    if [[ -n "$MEDIA_UUID" ]]; then
        mkdir -p /mnt/Media; mount /mnt/Media || true
        if mountpoint -q /mnt/Media; then
            mkdir -p /mnt/Media/{Films,TV,Music,Downloads/{radarr,sonarr,transmission}}
            chattr +C /mnt/Media/Downloads || true
            chown -R "$TARGET_USER:media" /mnt/Media; chmod -R 775 /mnt/Media; setfacl -R -m g:media:rwX /mnt/Media; setfacl -R -m d:g:media:rwX /mnt/Media
        fi
        for svc in sonarr radarr prowlarr transmission; do
            local svc_name="$svc"
            [[ "$svc" == "transmission" ]] && svc_name="transmission-daemon"
            
            mkdir -p "/etc/systemd/system/$svc_name.service.d"
            print -l "[Unit]" "RequiresMountsFor=/mnt/Media" > "/etc/systemd/system/$svc_name.service.d/media-mount.conf"
            print -l "[Service]" "UMask=0002" > "/etc/systemd/system/$svc_name.service.d/permissions.conf"
            id -u "$svc" &>/dev/null && usermod -aG media "$svc"
        done
    fi
    
    print "d /dev/shm/jellyfin 0755 jellyfin jellyfin -" > /etc/tmpfiles.d/jellyfin-transcode.conf
    id -u jellyfin &>/dev/null && usermod -aG render,video jellyfin
    wget -O /etc/udev/rules.d/42-solaar-uinput.rules https://raw.githubusercontent.com/pwr-Solaar/Solaar/refs/heads/master/rules.d-uinput/42-logitech-unify-permissions.rules
    systemctl enable jellyfin transmission-daemon sonarr radarr prowlarr seerr
    mkdir -p /var/lib/systemd/linger; touch "/var/lib/systemd/linger/$TARGET_USER"
    mkdir -p "/home/$TARGET_USER/.config/systemd/user/default.target.wants"
    ln -sf /usr/lib/systemd/user/app-dev.lizardbyte.app.Sunshine.service "/home/$TARGET_USER/.config/systemd/user/default.target.wants/app-dev.lizardbyte.app.Sunshine.service"
    
    print -P "\n%F{cyan}ℹ Configuring Sunshine network QoS...%f\n"
    cat <<'NFT' > /etc/nftables.conf
#!/usr/bin/nft -f
# vim:set ts=2 sw=2 et:

destroy table inet filter
table ip mangle {
  chain output {
    type filter hook output priority -150; policy accept;
    udp sport { 47998, 47999, 48000, 48002, 48010 } ip dscp set cs4
    tcp sport { 47984, 47989, 48010 } ip dscp set cs4
  }
}
NFT
    systemctl enable nftables

    TRAWL_DIR="/home/$TARGET_USER/Make/Trawl"
    print -P "\n%F{cyan}ℹ Installing TRAWL...%f\n"
    sudo -u "$TARGET_USER" git clone https://github.com/germondai/trawl "$TRAWL_DIR"
    (cd "$TRAWL_DIR" && sudo -u "$TARGET_USER" cp .env.example .env && sudo -u "$TARGET_USER" bun install)
    
    print -l "[Unit]" "Description=TRAWL" "After=network.target redis.service" "[Service]" "Type=simple" "WorkingDirectory=%h/Make/Trawl" "ExecStart=/usr/bin/bun run dev:api" "Restart=always" "[Install]" "WantedBy=default.target" > "/home/$TARGET_USER/.config/systemd/user/trawl.service"
    chown "$TARGET_USER:$TARGET_USER" "/home/$TARGET_USER/.config/systemd/user/trawl.service"
    ln -sf "/home/$TARGET_USER/.config/systemd/user/trawl.service" "/home/$TARGET_USER/.config/systemd/user/default.target.wants/trawl.service"

    ARRSTACK_DIR="/home/$TARGET_USER/Make/arrstack-mcp"
    print -P "\n%F{cyan}ℹ Installing arrstack-mcp...%f\n"
    sudo -u "$TARGET_USER" git clone https://github.com/ct4nk3r/arrstack-mcp.git "$ARRSTACK_DIR"
    (cd "$ARRSTACK_DIR" && sudo -u "$TARGET_USER" uv venv && sudo -u "$TARGET_USER" uv pip install -r requirements.txt "mcp<2.0.0")

elif [[ "$DEVICE_PROFILE" == "laptop" ]]; then
    print -P "\n%F{cyan}ℹ Applying Laptop Configuration...%f\n"
    GRUB_CMDLINE="split_lock_detect=off loglevel=3 quiet hugepages=512 i915.enable_fbc=1 i915.enable_guc=2 rcutree.enable_rcu_lazy=1"
    sed -i "s|^GRUB_CMDLINE_LINUX_DEFAULT=.*|GRUB_CMDLINE_LINUX_DEFAULT=\"$GRUB_CMDLINE\"|" /etc/default/grub
    sed -i 's/^GRUB_TIMEOUT=.*/GRUB_TIMEOUT=2/' /etc/default/grub
    sed -i 's/HOOKS=(\(.*\))/HOOKS=(\1 numlock)/' /etc/mkinitcpio.conf
    
    print -P "\n%F{cyan}ℹ Disabling NVIDIA GPU for power savings...%f\n"
    print -l "blacklist nouveau" "options nouveau modeset=0" "blacklist nvidia" "blacklist nvidia_drm" "blacklist nvidia_modeset" "blacklist nvidia_uvm" > /etc/modprobe.d/disable-nvidia.conf
    print 'ACTION=="add", SUBSYSTEM=="pci", ATTR{vendor}=="0x10de", ATTR{class}=="0x03[0-9]*", ATTR{power/control}="auto"' > /etc/udev/rules.d/80-nvidia-pm.rules

    systemctl enable power-profiles-daemon
fi
# endregion

# ------------------------------------------------------------------------------
# 11. Final Tuning
# ------------------------------------------------------------------------------

# Purpose: Cleans up unnecessary packages and configures advanced system tuning (ZRAM, BBR, Btrfs balance timers, mkinitcpio hooks).

# region
print -P "\n%K{yellow}%F{black} FINAL TUNING %k%f\n"
print -P "%F{cyan}ℹ Removing Discover and Plasma Meta...%f\n"
pacman -Qi plasma-meta &>/dev/null && { pacman -R --noconfirm plasma-meta; pacman -D --asexplicit plasma-desktop; }
pacman -Qi discover &>/dev/null && pacman -Rns --noconfirm discover

print -l "[zram0]" "zram-size = ram / 2" "compression-algorithm = lz4" "swap-priority = 100" > /etc/systemd/zram-generator.conf
print -l "vm.swappiness = 150" "vm.page-cluster = 0" "vm.max_map_count = 2147483642" > /etc/sysctl.d/99-swappiness.conf
print -l "net.core.default_qdisc = cake" "net.ipv4.tcp_congestion_control = bbr" > /etc/sysctl.d/99-bbr.conf
print -l "net.ipv4.ip_forward = 1" "net.ipv6.conf.all.forwarding = 1" > /etc/sysctl.d/99-tailscale.conf

print -l "[Unit]" "Description=Run Btrfs Balance Monthly" "[Timer]" "OnCalendar=monthly" "Persistent=true" "[Install]" "WantedBy=timers.target" > /etc/systemd/system/btrfs-balance.timer
print -l "[Unit]" "Description=Btrfs Balance" "[Service]" "Type=oneshot" "ExecStart=/usr/bin/btrfs balance start -dusage=50 -musage=50 /" > /etc/systemd/system/btrfs-balance.service

if [[ -f /usr/lib/systemd/system/grub-btrfsd.service ]]; then
    cp /usr/lib/systemd/system/grub-btrfsd.service /etc/systemd/system/grub-btrfsd.service
    sed -i 's|^ExecStart=.*|ExecStart=/usr/bin/grub-btrfsd --syslog --timeshift-auto|' /etc/systemd/system/grub-btrfsd.service
    systemctl enable grub-btrfsd
fi
if [[ "$DEVICE_PROFILE" == "desktop" ]]; then
    print 'SCX_SCHEDULER=scx_lavd' > /etc/default/scx
    systemctl enable --now scx_loader.service btrfs-balance.timer btrfs-scrub@-.timer timeshift-hourly.timer
elif [[ "$DEVICE_PROFILE" == "laptop" ]]; then
    print 'SCX_SCHEDULER=scx_bpfland' > /etc/default/scx
    systemctl enable --now scx_loader.service btrfs-balance.timer btrfs-scrub@-.timer timeshift-hourly.timer
else
    systemctl enable --now btrfs-balance.timer btrfs-scrub@-.timer timeshift-hourly.timer
fi

mkdir -p /etc/pacman.d/hooks
if [[ "$DEVICE_PROFILE" == "desktop" ]]; then
    print -l "[Trigger]" "Operation = Install" "Operation = Upgrade" "Type = Package" "Target = amd-ucode" "Target = btrfs-progs" "Target = mkinitcpio-firmware" "Target = linux-cachyos-headers" "[Action]" "Description = Rebuilding initramfs..." "When = PostTransaction" "Exec = /usr/bin/mkinitcpio -P" > /etc/pacman.d/hooks/98-rebuild-initramfs.hook
    sed -i 's|^MODULES=.*|MODULES=(amdgpu nvme)|' /etc/mkinitcpio.conf
else
    print -l "[Trigger]" "Operation = Install" "Operation = Upgrade" "Type = Package" "Target = intel-ucode" "Target = btrfs-progs" "Target = mkinitcpio-firmware" "Target = linux-cachyos-headers" "[Action]" "Description = Rebuilding initramfs..." "When = PostTransaction" "Exec = /usr/bin/mkinitcpio -P" > /etc/pacman.d/hooks/98-rebuild-initramfs.hook
    sed -i 's|^MODULES=.*|MODULES=(i915 nvme)|' /etc/mkinitcpio.conf
fi
print -l "[Trigger]" "Operation = Install" "Operation = Upgrade" "Operation = Remove" "Type = Package" "Target = linux-cachyos" "[Action]" "Description = Updating GRUB..." "When = PostTransaction" "Exec = /usr/bin/grub-mkconfig -o /boot/grub/grub.cfg" > /etc/pacman.d/hooks/99-update-grub.hook

sed -i 's/^#COMPRESSION="zstd"/COMPRESSION="lz4"/' /etc/mkinitcpio.conf

print -P "\n%F{cyan}ℹ Regenerating initramfs and GRUB...%f\n"
mkinitcpio -P; grub-mkconfig -o /boot/grub/grub.cfg
# endregion

# ------------------------------------------------------------------------------
# 12. First Boot Setup
# ------------------------------------------------------------------------------

# Purpose: Injects the Stage 3 (First Boot) payload into the user's autostart directory to trigger on next login.

# region
print -P "\n%K{yellow}%F{black} FIRST BOOT SETUP %k%f\n"
print -P "%F{cyan}ℹ Scheduling First Boot Setup...%f\n"
mkdir -p "/home/$TARGET_USER/.config/autostart"

if [[ -f /setup_boot.zsh ]]; then
    cp /setup_boot.zsh "/home/$TARGET_USER/.local/bin/setup_boot.zsh"
    sed -i "s/\$DEVICE_PROFILE/$DEVICE_PROFILE/g" "/home/$TARGET_USER/.local/bin/setup_boot.zsh"
    chmod +x "/home/$TARGET_USER/.local/bin/setup_boot.zsh"
    chown "$TARGET_USER:$TARGET_USER" "/home/$TARGET_USER/.local/bin/setup_boot.zsh"
    print -l "[Desktop Entry]" "Type=Application" "Exec=konsole --separate --hide-tabbar -e /home/$TARGET_USER/.local/bin/setup_boot.zsh" "Hidden=false" "NoDisplay=false" "Name=First Boot Setup" "X-GNOME-Autostart-enabled=true" > "/home/$TARGET_USER/.config/autostart/setup_boot.desktop"
    rm -f /setup_boot.zsh
fi

print -P "\n%F{cyan}ℹ Finalizing permissions...%f\n"
chown -R "$TARGET_USER:$TARGET_USER" "/home/$TARGET_USER"
# endregion

# ANTIGRAVITY LINK: Next stage is scheduled for next login via -> Scripts/Core/setup_boot.zsh
