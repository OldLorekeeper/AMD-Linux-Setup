#!/bin/bash
# ==============================================================================
# AMD-LINUX-SETUP: UNIFIED INSTALLER (ZEN 4)
# ==============================================================================
# A monolithic, opinionated Arch Linux installer replacing archinstall.
# Target Hardware: AMD Ryzen 7000+ (Desktop/Laptop) & Radeon 7000+
# Desktop Environment: KDE Plasma 6 (Wayland)
# File System: Btrfs (Optimised Subvolumes)
# Kernel: CachyOS (x86-64-v4)
# ==============================================================================

set -e

# --- Visuals ---
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${GREEN}"
echo "======================================================"
echo "   AMD-Linux-Setup: Unified Installer (Zen 4)"
echo "======================================================"
echo -e "${NC}"

# ==============================================================================
# PHASE 1: PRE-FLIGHT CHECKS & CONFIGURATION
# ==============================================================================

# 1.1 Integrity Checks
if [[ ! -d /sys/firmware/efi/efivars ]]; then
    echo -e "${RED}[!] Error: System is not booted in UEFI mode.${NC}"
    exit 1
fi

if ! ping -c 1 archlinux.org &>/dev/null; then
    echo -e "${RED}[!] Error: No internet connection.${NC}"
    exit 1
fi

# 1.2 User Configuration
echo -e "${YELLOW}--- User Configuration ---${NC}"
read -p "Hostname [NCC-1701]: " HOSTNAME
HOSTNAME=${HOSTNAME:-NCC-1701}

read -p "Username [curtis]: " TARGET_USER
TARGET_USER=${TARGET_USER:-curtis}

echo -e "${YELLOW}Set Root Password:${NC}"
read -s ROOT_PASS
echo
echo -e "${YELLOW}Set User (${TARGET_USER}) Password:${NC}"
read -s USER_PASS
echo

# 1.3 Git Identity
echo -e "${YELLOW}--- Git Configuration (Optional) ---${NC}"
read -p "Git Name: " GIT_NAME
read -p "Git Email: " GIT_EMAIL
echo -e "${YELLOW}Git PAT (Saved to libsecret helper):${NC}"
read -s GIT_PAT
echo

# 1.4 Device Profile
echo -e "${YELLOW}--- Device Profile ---${NC}"
echo "1) Desktop (Ryzen 7800X3D / RX 7900 XT)"
echo "2) Laptop (Ryzen 7840HS / 780M)"
read -p "Select Profile [1-2]: " PROFILE_SEL

case $PROFILE_SEL in
    1) DEVICE_PROFILE="desktop" ;;
    2) DEVICE_PROFILE="laptop" ;;
    *) echo -e "${RED}Invalid selection.${NC}"; exit 1 ;;
esac

# 1.5 Desktop-Specific Inputs
SLSKD_USER=""
SLSKD_PASS=""
SOULSEEK_USER=""
SOULSEEK_PASS=""
MEDIA_UUID=""

if [[ "$DEVICE_PROFILE" == "desktop" ]]; then
    echo -e "${YELLOW}--- Desktop Automation & Storage ---${NC}"

    echo "Existing Partitions (for Media Drive):"
    lsblk -o NAME,SIZE,FSTYPE,LABEL,UUID | grep -v loop
    read -p "Enter UUID for /mnt/Media (Leave empty to skip): " MEDIA_UUID

    echo -e "${YELLOW}Slskd & Soulseek Credentials:${NC}"
    read -p "Slskd WebUI Username: " SLSKD_USER
    read -s -p "Slskd WebUI Password: " SLSKD_PASS; echo
    read -p "Soulseek Username: " SOULSEEK_USER
    read -s -p "Soulseek Password: " SOULSEEK_PASS; echo
fi

# 1.6 Disk Selection
echo -e "${YELLOW}--- Installation Target ---${NC}"
lsblk -d -n -o NAME,SIZE,MODEL,TYPE | grep disk
read -p "Target Disk (e.g., nvme0n1): " DISK
DISK="/dev/$DISK"

if [[ ! -b "$DISK" ]]; then
    echo -e "${RED}Error: Invalid disk '$DISK'.${NC}"
    exit 1
fi

echo -e "${RED}WARNING: ALL DATA ON $DISK WILL BE ERASED!${NC}"
read -p "Type 'yes' to confirm: " CONFIRM
if [[ "$CONFIRM" != "yes" ]]; then
    echo "Aborted."
    exit 1
fi

# ==============================================================================
# PHASE 2: LIVE ENVIRONMENT PREP
# ==============================================================================

echo -e "${GREEN}--- Preparing Live Environment ---${NC}"
timedatectl set-ntp true

# 2.1 Mirrors & Pacman
echo "Optimising mirrors..."
reflector --country GB,IE,NL,DE,FR,EU --age 12 --protocol https --sort rate --fastest 10 --save /etc/pacman.d/mirrorlist
sed -i 's/^#ParallelDownloads/ParallelDownloads/' /etc/pacman.conf

# 2.2 CachyOS Repositories (Zen 4 Optimised)
echo "Adding CachyOS repositories..."
pacman-key --recv-keys F3B607488DB35A47 --keyserver keyserver.ubuntu.com
pacman-key --lsign-key F3B607488DB35A47
pacman -U --noconfirm 'https://mirror.cachyos.org/repo/x86_64/cachyos/cachyos-keyring-20240331-1-any.pkg.tar.zst' \
                      'https://mirror.cachyos.org/repo/x86_64/cachyos/cachyos-mirrorlist-22-1-any.pkg.tar.zst' \
                      'https://mirror.cachyos.org/repo/x86_64/cachyos/cachyos-v4-mirrorlist-22-1-any.pkg.tar.zst'

if ! grep -q "cachyos" /etc/pacman.conf; then
    cat <<EOF >> /etc/pacman.conf

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
pacman -Sy

# ==============================================================================
# PHASE 3: PARTITIONING & FORMATTING
# ==============================================================================

echo -e "${GREEN}--- Partitioning & Formatting ---${NC}"

# 3.1 Wipe & Partition
sgdisk -Z "$DISK"
sgdisk -o "$DISK"
sgdisk -n 1:0:+1G -t 1:ef00 -c 1:"EFI" "$DISK"   # EFI
sgdisk -n 2:0:0 -t 2:8300 -c 2:"Root" "$DISK"    # Root

# 3.2 Format
PART1=$(lsblk -nl -o NAME,PATH "$DISK" | grep -E "1$|p1$" | awk '{print $2}')
PART2=$(lsblk -nl -o NAME,PATH "$DISK" | grep -E "2$|p2$" | awk '{print $2}')

mkfs.vfat -F32 -n "EFI" "$PART1"
mkfs.btrfs -L "Arch" -f "$PART2"

# 3.3 Btrfs Subvolumes
mount "$PART2" /mnt
btrfs subvolume create /mnt/@
btrfs subvolume create /mnt/@home
btrfs subvolume create /mnt/@log
btrfs subvolume create /mnt/@pkg
btrfs subvolume create /mnt/@.snapshots
btrfs subvolume create /mnt/@games
umount /mnt

# 3.4 Mount Layout
MOUNT_OPTS="rw,noatime,compress=zstd:3,ssd,discard=async,space_cache=v2"
mount -o "$MOUNT_OPTS,subvol=@" "$PART2" /mnt

mkdir -p /mnt/{boot,home,var/log,var/cache/pacman/pkg,.snapshots,Games}
mount -o "$MOUNT_OPTS,subvol=@home" "$PART2" /mnt/home
mount -o "$MOUNT_OPTS,subvol=@log" "$PART2" /mnt/var/log
mount -o "$MOUNT_OPTS,subvol=@pkg" "$PART2" /mnt/var/cache/pacman/pkg
mount -o "$MOUNT_OPTS,subvol=@.snapshots" "$PART2" /mnt/.snapshots

# @games (No-CoW)
mount -o "$MOUNT_OPTS,subvol=@games" "$PART2" /mnt/Games
chattr +C /mnt/Games

mount "$PART1" /mnt/boot

# ==============================================================================
# PHASE 4: BASE INSTALLATION
# ==============================================================================

echo -e "${GREEN}--- Installing Base System ---${NC}"

# 4.1 Package Definitions
BASE_PKGS=(
    "base" "base-devel" "linux-cachyos" "linux-cachyos-headers" "linux-firmware"
    "amd-ucode" "btrfs-progs" "networkmanager" "git" "vim" "sudo" "efibootmgr"
    "grub" "grub-btrfs" "zsh" "pacman-contrib" "reflector" "openssh"
)

DESKTOP_ENV_PKGS=(
    "plasma-meta" "sddm" "konsole" "dolphin" "ark" "kate" "spectacle"
    "pipewire" "pipewire-pulse" "pipewire-alsa" "wireplumber"
    "mesa" "vulkan-radeon" "libva-mesa-driver"
)

# Core Utils (from previous setup_config.json/core_pkg.txt)
COMMON_PKGS=(
    "7zip" "bash-language-server" "chromium" "cmake" "cmake-extras" "cpupower"
    "cups" "dkms" "dnsmasq" "dosfstools" "edk2-ovmf" "extra-cmake-modules"
    "fastfetch" "fwupd" "gamemode" "gamescope" "gwenview" "hunspell-en_gb"
    "inkscape" "isoimagewriter" "iw" "iwd" "kio-admin" "lib32-gamemode"
    "lib32-gnutls" "lib32-vulkan-radeon" "libva-utils" "libvirt" "lz4" "nss-mdns"
    "obsidian" "papirus-icon-theme" "python-pip" "qemu-desktop" "steam"
    "transmission-cli" "vdpauinfo" "virt-manager" "vlc" "vlc-plugin-ffmpeg"
    "vulkan-headers" "wayland-protocols" "wine" "wine-mono" "winetricks"
)

# 4.2 Pacstrap
pacstrap -K /mnt "${BASE_PKGS[@]}" "${DESKTOP_ENV_PKGS[@]}" "${COMMON_PKGS[@]}"

# 4.3 Fstab Generation
genfstab -U /mnt >> /mnt/etc/fstab

# Inject Media Drive (If configured)
if [[ -n "$MEDIA_UUID" ]]; then
    echo "UUID=$MEDIA_UUID  /mnt/Media  btrfs  rw,nosuid,nodev,noatime,nofail,x-gvfs-hide,x-systemd.automount,compress=zstd:3,discard=async  0 0" >> /mnt/etc/fstab
fi

# ==============================================================================
# PHASE 5: SYSTEM CONFIGURATION (CHROOT)
# ==============================================================================

echo -e "${GREEN}--- Configuring System (Chroot) ---${NC}"

# Generate internal script
cat <<CHROOT_SCRIPT > /mnt/setup_internal.sh
#!/bin/bash
set -e

# --- 5.1 Identity & Locale ---
ln -sf /usr/share/zoneinfo/Europe/London /etc/localtime
hwclock --systohc
echo "en_GB.UTF-8 UTF-8" > /etc/locale.gen
locale-gen
echo "LANG=en_GB.UTF-8" > /etc/locale.conf
echo "KEYMAP=uk" > /etc/vconsole.conf
echo "$HOSTNAME" > /etc/hostname
cat <<HOSTS >> /etc/hosts
127.0.0.1   localhost
::1         localhost
127.0.1.1   $HOSTNAME.localdomain $HOSTNAME
HOSTS

# --- 5.2 Users & Permissions ---
echo "Creating user $TARGET_USER..."
useradd -m -G wheel,input,render,video,storage,gamemode,libvirt -s /bin/zsh $TARGET_USER
echo "root:$ROOT_PASS" | chpasswd
echo "$TARGET_USER:$USER_PASS" | chpasswd
echo "%wheel ALL=(ALL:ALL) ALL" > /etc/sudoers.d/wheel

groupadd -f media
usermod -aG media $TARGET_USER

# --- 5.3 Network & Services ---
echo -e "[device]\nwifi.backend=iwd" > /etc/NetworkManager/conf.d/wifi_backend.conf
sed -i 's/^#*\(Experimental = \).*/\1true/' /etc/bluetooth/main.conf
systemctl enable NetworkManager bluetooth sshd sddm fstrim.timer

# Network Optimisation: Tailscale GRO
mkdir -p /etc/NetworkManager/dispatcher.d
cat << 'GRO' > /etc/NetworkManager/dispatcher.d/99-tailscale-gro
#!/bin/bash
[[ "\$2" == "up" ]] && /usr/bin/ethtool -K "\$1" rx-udp-gro-forwarding on rx-gro-list off 2>/dev/null || true
GRO
chmod +x /etc/NetworkManager/dispatcher.d/99-tailscale-gro

# Network Optimisation: WiFi Power Save
cat << 'WIFI' > /etc/NetworkManager/dispatcher.d/disable-wifi-powersave
#!/bin/sh
[[ "\$1" == wl* ]] && [[ "\$2" == "up" ]] && /usr/bin/iw dev "\$1" set power_save off
WIFI
chmod +x /etc/NetworkManager/dispatcher.d/disable-wifi-powersave

# --- 5.4 Bootloader ---
grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id=GRUB
sed -i 's/^GRUB_TIMEOUT=5/GRUB_TIMEOUT=2/' /etc/default/grub
grub-mkconfig -o /boot/grub/grub.cfg

# --- 5.5 Build Environment (Optimised) ---
sed -i 's/^#*\(CFLAGS=".* -march=\)x86-64 -mtune=generic/\1native/' /etc/makepkg.conf
sed -i "s/^#*MAKEFLAGS=.*/MAKEFLAGS=\"-j\$(nproc)\"/" /etc/makepkg.conf
if ! grep -q "RUSTFLAGS" /etc/makepkg.conf; then
    echo 'RUSTFLAGS="-C target-cpu=native"' >> /etc/makepkg.conf
fi
sed -i 's/^#ParallelDownloads/ParallelDownloads/' /etc/pacman.conf

# Re-inject CachyOS for Chroot Context
if ! grep -q "cachyos" /etc/pacman.conf; then
    cat <<EOF >> /etc/pacman.conf
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
pacman-key --recv-keys F3B607488DB35A47 --keyserver keyserver.ubuntu.com
pacman-key --lsign-key F3B607488DB35A47

# --- 5.6 AUR Helper (Yay) ---
cd /home/$TARGET_USER
sudo -u $TARGET_USER git clone https://aur.archlinux.org/yay.git
cd yay
sudo -u $TARGET_USER makepkg -si --noconfirm
cd ..
rm -rf yay

# --- 5.7 Extended Packages ---
# Combined Lists
CORE_AUR=(
    "darkly-bin" "ethtool" "geekbench" "google-chrome" "jq" "kio-gdrive"
    "konsave" "kwin-effects-better-blur-dx" "mkinitcpio-firmware"
    "papirus-folders" "plasma6-applets-panel-colorizer" "protontricks"
    "protonup-qt" "tailscale" "timeshift-systemd-timer" "uv" "xpadneo-dkms"
)

DESKTOP_AUR=(
    "jellyfin-web" "jellyfin-server" "kid3" "lidarr-bin" "lutris" "prowlarr-bin"
    "python-dotenv" "python-pydantic" "python-requests" "python-schedule"
    "python-setuptools" "python-wheel" "radarr-bin" "slskd-bin" "solaar"
    "sonarr-bin" "sunshine" "yt-dlp"
)

LAPTOP_AUR=(
    "mkinitcpio-numlock" "moonlight-qt" "power-profiles-daemon"
)

TARGET_AUR=("\${CORE_AUR[@]}")
if [[ "$DEVICE_PROFILE" == "desktop" ]]; then
    TARGET_AUR+=("\${DESKTOP_AUR[@]}")
elif [[ "$DEVICE_PROFILE" == "laptop" ]]; then
    TARGET_AUR+=("\${LAPTOP_AUR[@]}")
fi

echo "Installing Extended Packages via Yay..."
sudo -u $TARGET_USER yay -S --needed --noconfirm "\${TARGET_AUR[@]}"

# --- 5.8 Dotfiles & Home ---
mkdir -p /home/$TARGET_USER/{Games,Make,Obsidian} /home/$TARGET_USER/.local/bin
chown -R $TARGET_USER:$TARGET_USER /home/$TARGET_USER

REPO_DIR="/home/$TARGET_USER/Obsidian/AMD-Linux-Setup"
if [[ ! -d "\$REPO_DIR" ]]; then
    sudo -u $TARGET_USER git clone https://github.com/OldLorekeeper/AMD-Linux-Setup "\$REPO_DIR"
fi

# Git Config
if [[ -n "$GIT_NAME" ]]; then
    sudo -u $TARGET_USER git config --global user.name "$GIT_NAME"
    sudo -u $TARGET_USER git config --global user.email "$GIT_EMAIL"
    sudo -u $TARGET_USER git config --global credential.helper libsecret
fi

# ZSH & Plugins
if [[ ! -d "/home/$TARGET_USER/.oh-my-zsh" ]]; then
    sudo -u $TARGET_USER sh -c "\$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
fi
ZSH_CUSTOM="/home/$TARGET_USER/.oh-my-zsh/custom"
sudo -u $TARGET_USER git clone https://github.com/zsh-users/zsh-autosuggestions "\$ZSH_CUSTOM/plugins/zsh-autosuggestions"
sudo -u $TARGET_USER git clone https://github.com/zsh-users/zsh-syntax-highlighting "\$ZSH_CUSTOM/plugins/zsh-syntax-highlighting"
ln -sf /home/$TARGET_USER/.oh-my-zsh /root/.oh-my-zsh
ln -sf /home/$TARGET_USER/.zshrc /root/.zshrc

# ZSH Configuration Injection
cat <<'ZSHCONF' >> /home/$TARGET_USER/.zshrc

# --- Custom Configuration ---
export PATH="$HOME/.local/bin:$PATH"
alias mkinit="sudo mkinitcpio -P"
alias mkgrub="sudo grub-mkconfig -o /boot/grub/grub.cfg"

# Auto-Organize Git Clones
git() {
    if (( EUID == 0 )); then command git "\$@"; return; fi
    if [[ "\$1" == "clone" && -n "\$2" && -z "\$3" && "\$PWD" == "\$HOME" ]]; then
        print -P "%F{yellow}Auto-cloning to ~/Make...%f"
        local repo_name="\${2:t}"; repo_name="\${repo_name%.git}"
        command git clone "\$2" "$HOME/Make/\$repo_name"
    else
        command git "\$@"
    fi
}

maintain() {
    local script="$HOME/Obsidian/AMD-Linux-Setup/Scripts/system_maintain.zsh"
    [[ -x "\$script" ]] || chmod +x "\$script"
    "\$script"
}

export KWIN_PROFILE="$DEVICE_PROFILE"
update-kwin() {
    local target="\${1:-\$KWIN_PROFILE}"
    cd "$HOME/Obsidian/AMD-Linux-Setup" && git pull && ./Scripts/kwin_apply_rules.zsh "\$target"
}
ZSHCONF

sed -i 's/^plugins=(git)$/plugins=(git archlinux zsh-autosuggestions zsh-syntax-highlighting)/' /home/$TARGET_USER/.zshrc

# Gemini Config
mkdir -p /home/$TARGET_USER/.gemini
echo '{"mcpServers":{"arch-ops":{"command":"uvx","args":["arch-ops-server"]}}}' > /home/$TARGET_USER/.gemini/settings.json
chown -R $TARGET_USER:$TARGET_USER /home/$TARGET_USER/.gemini

# Resources: Konsole & Plasmoids
mkdir -p /home/$TARGET_USER/.local/share/konsole
cp -f "\$REPO_DIR/Resources/Konsole"/* /home/$TARGET_USER/.local/share/konsole/ 2>/dev/null || true
chown -R $TARGET_USER:$TARGET_USER /home/$TARGET_USER/.local/share/konsole

TRANS_ARCHIVE="\$REPO_DIR/Resources/Plasmoids/transmission-plasmoid.tar.gz"
if [[ -f "\$TRANS_ARCHIVE" ]]; then
    TRANS_DIR="/home/$TARGET_USER/.local/share/plasma/plasmoids/com.oldlorekeeper.transmission"
    mkdir -p "\$TRANS_DIR"
    tar -xf "\$TRANS_ARCHIVE" -C "\$(dirname "\$TRANS_DIR")"
    chown -R $TARGET_USER:$TARGET_USER "/home/$TARGET_USER/.local/share/plasma"
fi

# --- 5.9 Device Specific Logic ---

# Common Env Vars
echo "LIBVA_DRIVER_NAME=radeonsi" >> /etc/environment
echo "VDPAU_DRIVER=radeonsi" >> /etc/environment
echo "WINEFSYNC=1" >> /etc/environment

# Common Udev (NVMe Scheduler)
echo 'ACTION=="add|change", KERNEL=="nvme[0-9]n[0-9]", ATTR{queue/scheduler}="kyber"' > /etc/udev/rules.d/60-iosched.rules

if [[ "$DEVICE_PROFILE" == "desktop" ]]; then
    echo "Applying Desktop Configuration..."

    # 1. Hardware Configuration
    # USB Controller Fix (Asus X670E-I)
    echo 'SUBSYSTEM=="pci", ATTR{vendor}=="0x1022", ATTR{device}=="0x43f7", ATTR{power/control}="on"' > /etc/udev/rules.d/99-xhci-fix.rules

    # Boot Params
    GRUB_CMDLINE="loglevel=3 quiet amdgpu.ppfeaturemask=0xffffffff hugepages=512 video=3440x1440@60 amd_pstate=active"

    # 2. EDID Injection (2560x1600 Headless Support)
    EDID_SRC="\$REPO_DIR/Resources/Sunshine/custom_2560x1600.bin"
    if [[ -f "\$EDID_SRC" ]]; then
        mkdir -p /usr/lib/firmware/edid
        cp "\$EDID_SRC" /usr/lib/firmware/edid/
        if ! grep -q "custom_2560x1600.bin" /etc/mkinitcpio.conf; then
            sed -i 's|^FILES=(|FILES=(/usr/lib/firmware/edid/custom_2560x1600.bin |' /etc/mkinitcpio.conf
        fi
    fi
    sed -i "s|^GRUB_CMDLINE_LINUX_DEFAULT=.*|GRUB_CMDLINE_LINUX_DEFAULT=\"\$GRUB_CMDLINE\"|" /etc/default/grub

    # 3. Media Utilities
    # Fix Cover Art Script
    ln -sf "\$REPO_DIR/Scripts/jellyfin_fix_cover_art.zsh" /home/$TARGET_USER/.local/bin/fix_cover_art
    chmod +x /home/$TARGET_USER/.local/bin/fix_cover_art

    # 4. Sunshine Customisation
    # Hook for Icon Replacement
    cat << 'HOOK' > /usr/local/bin/replace-sunshine-icons.sh
#!/bin/bash
DEST="/usr/share/icons/hicolor/scalable/status"
SRC="$REPO_DIR/Resources/Icons/Sunshine"
[[ -d "\$SRC" ]] && cp "\$SRC"/*.svg "\$DEST/"
SUNSHINE=\$(command -v sunshine)
[[ -n "\$SUNSHINE" ]] && setcap cap_sys_admin+p "\$SUNSHINE"
HOOK
    chmod +x /usr/local/bin/replace-sunshine-icons.sh

    mkdir -p /etc/pacman.d/hooks
    cat << 'HOOK' > /etc/pacman.d/hooks/sunshine-icons.hook
[Trigger]
Operation = Install
Operation = Upgrade
Type = Package
Target = sunshine
[Action]
Description = Replacing Sunshine tray icons...
When = PostTransaction
Exec = /usr/local/bin/replace-sunshine-icons.sh
HOOK

    # GPU Boost Script & Helpers
    echo "$TARGET_USER ALL=(ALL) NOPASSWD: /usr/local/bin/sunshine_gpu_boost" > /etc/sudoers.d/90-sunshine-boost
    chmod 440 /etc/sudoers.d/90-sunshine-boost

    for script in sunshine_gpu_boost.zsh sunshine_hdr.zsh sunshine_res.zsh sunshine_laptop.zsh; do
        ln -sf "\$REPO_DIR/Scripts/\$script" "/usr/local/bin/\${script%.zsh}"
        chmod +x "\$REPO_DIR/Scripts/\$script"
    done

    # 5. Media Stack Automation
    # Slskd Config
    mkdir -p /etc/slskd
    cat <<YAML > /etc/slskd/slskd.yml
web:
  port: 5030
  authentication:
    username: $SLSKD_USER
    password: $SLSKD_PASS
soulseek:
  username: $SOULSEEK_USER
  password: $SOULSEEK_PASS
directories:
  downloads: /mnt/Media/Downloads/slskd/Complete
  incomplete: /mnt/Media/Downloads/slskd/Incomplete
YAML

    # Soularr Installation
    cd /opt
    git clone https://github.com/mrusse/soularr.git
    chown -R $TARGET_USER:$TARGET_USER /opt/soularr
    pip install --break-system-packages -r /opt/soularr/requirements.txt
    [[ -f /opt/soularr/config.ini ]] && cp /opt/soularr/config.ini /opt/soularr/config/config.ini || true

    cat << 'UNIT' > /etc/systemd/system/soularr.service
[Unit]
Description=Soularr (Lidarr <-> Slskd automation)
Wants=network-online.target lidarr.service slskd.service
Requires=lidarr.service slskd.service
RequiresMountsFor=/mnt/Media
[Service]
Type=oneshot
User=$TARGET_USER
Group=$(id -gn $TARGET_USER)
UMask=0002
WorkingDirectory=/opt/soularr
ExecStart=/usr/bin/python /opt/soularr/soularr.py --config-dir /opt/soularr/config --no-lock-file
UNIT

    cat << 'TIMER' > /etc/systemd/system/soularr.timer
[Unit]
Description=Run Soularr every 30 minutes
[Timer]
OnCalendar=*:0/30
Persistent=true
[Install]
WantedBy=timers.target
TIMER
    systemctl enable soularr.timer

    # 6. Media Drive & Service Overrides
    if [[ -n "$MEDIA_UUID" ]]; then
        mkdir -p /mnt/Media
        mount /mnt/Media || true

        # Structure & Permissions
        if mountpoint -q /mnt/Media; then
            mkdir -p /mnt/Media/{Films,TV,Music/{Maintained,Manual},Downloads/{lidarr,radarr,slskd,sonarr,transmission}}
            chattr +C /mnt/Media/Downloads || true
            chown -R $TARGET_USER:media /mnt/Media
            chmod -R 775 /mnt/Media
            setfacl -R -m g:media:rwX /mnt/Media
            setfacl -R -m d:g:media:rwX /mnt/Media
        fi

        # Service Dependencies
        for svc in sonarr radarr lidarr prowlarr transmission slskd jellyfin; do
            mkdir -p "/etc/systemd/system/\$svc.service.d"
            echo -e "[Unit]\nRequiresMountsFor=/mnt/Media" > "/etc/systemd/system/\$svc.service.d/media-mount.conf"
            if [[ "\$svc" != "jellyfin" ]]; then
                echo -e "[Service]\nUMask=0002" > "/etc/systemd/system/\$svc.service.d/permissions.conf"
            fi
        done
        # Slskd Config Override
        mkdir -p /etc/systemd/system/slskd.service.d
        echo -e "[Service]\nExecStart=\nExecStart=/usr/lib/slskd/slskd --config /etc/slskd/slskd.yml" > /etc/systemd/system/slskd.service.d/override.conf
    fi

    # 7. Optimisations
    # Jellyfin RAM Transcode
    echo "d /dev/shm/jellyfin 0755 jellyfin jellyfin -" > /etc/tmpfiles.d/jellyfin-transcode.conf
    usermod -aG render,video jellyfin || true
    chattr +C /var/lib/jellyfin || true

    # Solaar Rules
    wget -O /etc/udev/rules.d/42-solaar-uinput.rules https://raw.githubusercontent.com/pwr-Solaar/Solaar/refs/heads/master/rules.d-uinput/42-logitech-unify-permissions.rules

    # Enable Stack
    systemctl enable jellyfin transmission sonarr radarr lidarr prowlarr sunshine slskd

elif [[ "$DEVICE_PROFILE" == "laptop" ]]; then
    echo "Applying Laptop Configuration..."

    GRUB_CMDLINE="loglevel=3 quiet amdgpu.ppfeaturemask=0xffffffff hugepages=512 video=2560x1600@60 amd_pstate=active"
    sed -i "s|^GRUB_CMDLINE_LINUX_DEFAULT=.*|GRUB_CMDLINE_LINUX_DEFAULT=\"\$GRUB_CMDLINE\"|" /etc/default/grub

    # Numlock
    if ! grep -q "numlock" /etc/mkinitcpio.conf; then
        sed -i 's/HOOKS=(\(.*\))/HOOKS=(\1 numlock)/' /etc/mkinitcpio.conf
    fi

    systemctl enable power-profiles-daemon
fi

# --- 5.10 Final System Tuning ---

# Sysctl & ZRAM
echo -e "[zram0]\nzram-size = ram / 2\ncompression-algorithm = lz4\nswap-priority = 100" > /etc/systemd/zram-generator.conf
echo -e "vm.swappiness = 150\nvm.page-cluster = 0" > /etc/sysctl.d/99-swappiness.conf
echo -e "net.core.default_qdisc = cake\nnet.ipv4.tcp_congestion_control = bbr" > /etc/sysctl.d/99-bbr.conf
echo -e "net.ipv4.ip_forward = 1\nnet.ipv6.conf.all.forwarding = 1" > /etc/sysctl.d/99-tailscale.conf

# Btrfs Timers & Snapper/Grub
cat << 'TIMER' > /etc/systemd/system/btrfs-balance.timer
[Unit]
Description=Run Btrfs Balance Monthly
[Timer]
OnCalendar=monthly
Persistent=true
[Install]
WantedBy=timers.target
TIMER
cat << 'SERVICE' > /etc/systemd/system/btrfs-balance.service
[Unit]
Description=Btrfs Balance
[Service]
Type=oneshot
ExecStart=/usr/bin/btrfs balance start -dusage=50 -musage=50 /
SERVICE

if [[ -f /usr/lib/systemd/system/grub-btrfsd.service ]]; then
    cp /usr/lib/systemd/system/grub-btrfsd.service /etc/systemd/system/grub-btrfsd.service
    sed -i 's|^ExecStart=.*|ExecStart=/usr/bin/grub-btrfsd --syslog --timeshift-auto|' /etc/systemd/system/grub-btrfsd.service
    systemctl enable grub-btrfsd
fi

systemctl enable --now btrfs-balance.timer
systemctl enable --now btrfs-scrub@-.timer
systemctl enable timeshift-hourly.timer

# Pacman Hooks
mkdir -p /etc/pacman.d/hooks
cat <<HOOK > /etc/pacman.d/hooks/98-rebuild-initramfs.hook
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
HOOK

cat <<HOOK > /etc/pacman.d/hooks/99-update-grub.hook
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
HOOK

# Initramfs Generation (Final)
sed -i 's|^MODULES=.*|MODULES=(amdgpu nvme)|' /etc/mkinitcpio.conf
sed -i 's/^#COMPRESSION="zstd"/COMPRESSION="lz4"/' /etc/mkinitcpio.conf
mkinitcpio -P
grub-mkconfig -o /boot/grub/grub.cfg

# --- 5.11 First Boot Automation ---
echo "Scheduling First Boot Setup..."
mkdir -p /home/$TARGET_USER/.config/autostart
cat <<BOOTSCRIPT > /home/$TARGET_USER/.local/bin/first_boot.zsh
#!/bin/zsh
source /home/$TARGET_USER/.zshrc
sleep 5
echo "Running First Boot Setup..."

# Desktop: Tailscale Exit Node
[[ "$DEVICE_PROFILE" == "desktop" ]] && sudo tailscale up --advertise-exit-node

# Konsave (Theming)
PROFILE_DIR="/home/$TARGET_USER/Obsidian/AMD-Linux-Setup/Resources/Konsave"
if [[ "$DEVICE_PROFILE" == "desktop" ]]; then
    konsave -i "\$PROFILE_DIR"/Desktop*.knsv
    konsave -a \$(konsave -l | grep Desktop | head -n1 | awk '{print \$1}')
else
    konsave -i "\$PROFILE_DIR"/Laptop*.knsv
    konsave -a \$(konsave -l | grep Laptop | head -n1 | awk '{print \$1}')
fi

# KWin Rules
/home/$TARGET_USER/Obsidian/AMD-Linux-Setup/Scripts/kwin_apply_rules.zsh $DEVICE_PROFILE

# Self-Cleanup
rm /home/$TARGET_USER/.config/autostart/first_boot.desktop
rm /home/$TARGET_USER/.local/bin/first_boot.zsh
notify-send "System Setup Complete" "Ready."
BOOTSCRIPT

chmod +x /home/$TARGET_USER/.local/bin/first_boot.zsh
chown $TARGET_USER:$TARGET_USER /home/$TARGET_USER/.local/bin/first_boot.zsh

cat <<AUTOSTART > /home/$TARGET_USER/.config/autostart/first_boot.desktop
[Desktop Entry]
Type=Application
Exec=/home/$TARGET_USER/.local/bin/first_boot.zsh
Hidden=false
NoDisplay=false
Name=First Boot Setup
X-GNOME-Autostart-enabled=true
AUTOSTART
chown $TARGET_USER:$TARGET_USER /home/$TARGET_USER/.config/autostart/first_boot.desktop

CHROOT_SCRIPT

# Execute Chroot Script
chmod +x /mnt/setup_internal.sh
arch-chroot /mnt /setup_internal.sh

# ==============================================================================
# PHASE 6: COMPLETION
# ==============================================================================

echo -e "${GREEN}--- Installation Complete ---${NC}"
rm /mnt/setup_internal.sh
umount -R /mnt

echo -e "${YELLOW}System ready. Please remove installation media and reboot.${NC}"
