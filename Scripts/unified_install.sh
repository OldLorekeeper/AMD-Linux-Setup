#!/bin/bash
# ------------------------------------------------------------------------------
# UNIFIED ARCH LINUX INSTALLER (Standalone)
# ------------------------------------------------------------------------------
# Purpose: Full system provisioning from Live USB, replacing all modular scripts:
#          system_install.sh, setup_config.json, setup_home.sh, setup_core.zsh, 
#          setup_desktop.zsh, setup_laptop.zsh.
# Context: AMD Ryzen 7000 / Radeon 7000 Optimised.
# ------------------------------------------------------------------------------

set -e

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

# ------------------------------------------------------------------------------
# 0. Preamble & Checks
# ------------------------------------------------------------------------------

echo -e "${GREEN}=== AMD-Linux-Setup Unified Installer ===${NC}"

# Check UEFI
if [ ! -d "/sys/firmware/efi" ]; then
    echo -e "${RED}Error: System is not booted in UEFI mode.${NC}"
    exit 1
fi

# Check Internet
if ! ping -c 1 google.com &>/dev/null; then
    echo -e "${RED}Error: No internet connection.${NC}"
    exit 1
fi

# ------------------------------------------------------------------------------
# 1. User Configuration
# ------------------------------------------------------------------------------

echo -e "${YELLOW}--- Configuration ---${NC}"

# Disk Selection
echo "Available Disks:"
lsblk -d -n -o NAME,SIZE,MODEL | grep -v "loop"
read -p "Enter target disk (e.g. nvme0n1): " DISK
DISK="/dev/$DISK"

if [ ! -b "$DISK" ]; then
    echo -e "${RED}Error: Disk $DISK not found.${NC}"
    exit 1
fi

# Profile Selection
echo "Select Profile:"
echo "1) Desktop (RX 7900 XT, Media Server, Sunshine)"
echo "2) Laptop (Ryzen 7840HS, Power Saving)"
read -p "Choice [1-2]: " PROFILE_CHOICE
case $PROFILE_CHOICE in
    1) PROFILE="desktop" ;; 
    2) PROFILE="laptop" ;; 
        *) echo -e "${RED}Invalid choice.${NC}"; exit 1 ;; 
esac

# Desktop Specific Configuration (Pre-Gathering)
if [ "$PROFILE" == "desktop" ]; then
    echo -e "${YELLOW}--- Desktop Media Setup ---${NC}"
    echo "Available Partitions (for /mnt/Media):"
    lsblk -o NAME,SIZE,FSTYPE,UUID | grep -v "loop"
    read -p "Enter Media Partition UUID (leave empty to skip): " MEDIA_UUID
    
    echo -e "${YELLOW}--- Service Credentials (Slskd) ---${NC}"
    read -p "Slskd WebUI Username: " SLSKD_USER
    read -s -p "Slskd WebUI Password: " SLSKD_PASS; echo
    read -p "Soulseek Username: " SOULSEEK_USER
    read -s -p "Soulseek Password: " SOULSEEK_PASS; echo

    echo -e "${YELLOW}--- Monitor Configuration ---${NC}"
    read -p "Enable custom EDID for Moonlight streaming (Slimbook 16:10)? [y/N]: " INSTALL_EDID
fi

# User Details
read -p "Enter Hostname [NCC-1701]: " HOSTNAME
HOSTNAME=${HOSTNAME:-NCC-1701}
read -p "Enter Username: " USERNAME
read -s -p "Enter User Password: " USER_PASS; echo
read -s -p "Enter Root Password: " ROOT_PASS; echo

# Git Credentials (for cloning repo during install)
echo -e "${YELLOW}--- Git Identity (Required for Setup) ---${NC}"
read -p "GitHub Email: " GIT_EMAIL
read -p "GitHub Username: " GIT_USER
read -s -p "GitHub PAT (Token): " GIT_TOKEN; echo

echo -e "${RED}WARNING: ALL DATA ON $DISK WILL BE ERASED!${NC}"
read -p "Are you sure? (type 'yes'): " CONFIRM
if [ "$CONFIRM" != "yes" ]; then
    echo "Aborted."
    exit 1
fi

# ------------------------------------------------------------------------------
# 2. Host Preparation (Live ISO)
# ------------------------------------------------------------------------------

echo -e "${GREEN}--- Optimising Live Environment ---${NC}"

# Reflector (Host)
echo "Updating mirrors (Host)..."
reflector --country GB,IE,NL,DE,FR,EU --age 6 --protocol https --sort rate --fastest 10 --save /etc/pacman.d/mirrorlist

# CachyOS Repos (Host)
echo "Configuring CachyOS repositories..."
pacman-key --recv-keys F3B607488DB35A47 --keyserver keyserver.ubuntu.com
pacman-key --lsign-key F3B607488DB35A47
pacman -U --noconfirm 'https://mirror.cachyos.org/repo/x86_64/cachyos/cachyos-keyring-20240331-1-any.pkg.tar.zst' \
                      'https://mirror.cachyos.org/repo/x86_64/cachyos/cachyos-mirrorlist-22-1-any.pkg.tar.zst' \
                      'https://mirror.cachyos.org/repo/x86_64/cachyos/cachyos-v4-mirrorlist-22-1-any.pkg.tar.zst'

if ! grep -q "\[cachyos-znver4\]" /etc/pacman.conf; then
    cat <<REPO >> /etc/pacman.conf

[cachyos-znver4]
Include = /etc/pacman.d/cachyos-v4-mirrorlist
[cachyos-core-znver4]
Include = /etc/pacman.d/cachyos-v4-mirrorlist
[cachyos-extra-znver4]
Include = /etc/pacman.d/cachyos-v4-mirrorlist
[cachyos]
Include = /etc/pacman.d/cachyos-mirrorlist
REPO
fi

# Refresh DB
pacman -Sy

# ------------------------------------------------------------------------------
# 3. Partitioning & Formatting
# ------------------------------------------------------------------------------

echo -e "${GREEN}--- Partitioning $DISK ---${NC}"

sgdisk -Z "$DISK"
sgdisk -n 1:0:+1G -t 1:ef00 -c 1:"EFI System Partition" "$DISK"
sgdisk -n 2:0:0   -t 2:8300 -c 2:"Arch Linux Root"      "$DISK"

if [[ "$DISK" == *"nvme"* ]]; then
    PART1="${DISK}p1"; PART2="${DISK}p2"
else
    PART1="${DISK}1"; PART2="${DISK}2"
fi

echo -e "${GREEN}--- Formatting ---${NC}"
mkfs.fat -F32 -n "EFI" "$PART1"
mkfs.btrfs -f -L "ROOT" "$PART2"

# ------------------------------------------------------------------------------
# 4. Subvolumes & Mounting
# ------------------------------------------------------------------------------

echo -e "${GREEN}--- Creating Subvolumes ---${NC}"
mount "$PART2" /mnt

btrfs subvolume create /mnt/@
btrfs subvolume create /mnt/@home
btrfs subvolume create /mnt/@log
btrfs subvolume create /mnt/@pkg
btrfs subvolume create /mnt/@snapshots
btrfs subvolume create /mnt/@games

# Apply No-CoW to @games immediately
chattr +C /mnt/@games

umount /mnt

echo -e "${GREEN}--- Mounting Filesystems ---${NC}"
MOUNT_OPTS="rw,noatime,compress=zstd:3,ssd,discard=async,space_cache=v2"

mount -o "$MOUNT_OPTS,subvol=@" "$PART2" /mnt
mkdir -p /mnt/{home,boot,var/log,var/cache/pacman/pkg,Games}

mount -o "$MOUNT_OPTS,subvol=@home" "$PART2" /mnt/home
mount -o "$MOUNT_OPTS,subvol=@log"  "$PART2" /mnt/var/log
mount -o "$MOUNT_OPTS,subvol=@pkg"  "$PART2" /mnt/var/cache/pacman/pkg
mount -o "$MOUNT_OPTS,subvol=@snapshots" "$PART2" /mnt/.snapshots 2>/dev/null || true

mount "$PART1" /mnt/boot

# ------------------------------------------------------------------------------
# 5. Repo & Package Lists
# ------------------------------------------------------------------------------

echo -e "${GREEN}--- Fetching Package Lists ---${NC}"
USER_HOME_MNT="/mnt/home/$USERNAME"
REPO_DIR_MNT="$USER_HOME_MNT/Obsidian/AMD-Linux-Setup"
mkdir -p "$REPO_DIR_MNT"

# Clone Repo using provided creds
git clone "https://$GIT_USER:$GIT_TOKEN@github.com/OldLorekeeper/AMD-Linux-Setup" "$REPO_DIR_MNT"

# Read Packages
CORE_PKGS=$(grep -vE "^\s*#|^\s*$" "$REPO_DIR_MNT/Resources/Packages/core_pkg.txt" | tr '\n' ' ')
DEVICE_PKGS=$(grep -vE "^\s*#|^\s*$" "$REPO_DIR_MNT/Resources/Packages/${PROFILE}_pkg.txt" | tr '\n' ' ')

# Manual Definitions
# Drivers & DE (from scripts)
GPU_PKGS="mesa lib32-mesa vulkan-radeon lib32-vulkan-radeon xf86-video-amdgpu libva-mesa-driver"
DE_PKGS="plasma-meta sddm konsole dolphin ark xdg-user-dirs"
AUDIO_PKGS="pipewire pipewire-alsa pipewire-pulse wireplumber"

# Base Extras (Merged from setup_config.json and setup_core.zsh)
# Missing items from JSON now included: obsidian, chromium, vlc, wine, virtualization, etc.
BASE_EXTRAS="amd-ucode bluez bluez-utils cups dosfstools os-prober ntfs-3g steam gamemode lib32-gamemode \
7zip bash-language-server chromium cmake cmake-extras cpupower dkms dnsmasq edk2-ovmf extra-cmake-modules \
fastfetch gamescope gwenview hunspell-en_gb inkscape isoimagewriter iw iwd kio-admin lib32-gnutls libva-utils \
libvirt lz4 nss-mdns obsidian pacman-contrib python-pip qemu-desktop transmission-cli vdpauinfo virt-manager \
vlc vlc-plugin-ffmpeg vulkan-headers wayland-protocols wine wine-mono winetricks"

# Combined List
INSTALL_LIST="base base-devel linux-cachyos linux-cachyos-headers linux-firmware git vim openssh networkmanager grub efibootmgr yay reflector $GPU_PKGS $DE_PKGS $AUDIO_PKGS $BASE_EXTRAS $CORE_PKGS $DEVICE_PKGS"

# ------------------------------------------------------------------------------
# 6. Installation (Pacstrap)
# ------------------------------------------------------------------------------

echo -e "${GREEN}--- Installing System (Single Pass) ---${NC}"
pacstrap -K -C /etc/pacman.conf /mnt $INSTALL_LIST

echo -e "${GREEN}--- Generating Fstab ---${NC}"
genfstab -U /mnt >> /mnt/etc/fstab

# Copy CachyOS config to target
cp /etc/pacman.conf /mnt/etc/pacman.conf
cp /etc/pacman.d/mirrorlist /mnt/etc/pacman.d/mirrorlist
mkdir -p /mnt/etc/pacman.d
cp /etc/pacman.d/cachyos* /mnt/etc/pacman.d/ 2>/dev/null || true

# ------------------------------------------------------------------------------
# 7. Chroot Setup Script (Configuration Only)
# ------------------------------------------------------------------------------

echo -e "${GREEN}--- Preparing Configuration Script ---${NC}"

cat <<EOF > /mnt/root/stage2_config.sh
#!/bin/bash
set -e
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "
${GREEN}--- Configuring System Internals ---
${NC}"

# Timezone & Locale
ln -sf /usr/share/zoneinfo/Europe/London /etc/localtime
hwclock --systohc
sed -i 's/^#en_GB.UTF-8/en_GB.UTF-8/' /etc/locale.gen
sed -i 's/^#en_US.UTF-8/en_US.UTF-8/' /etc/locale.gen
locale-gen
echo "LANG=en_GB.UTF-8" > /etc/locale.conf
echo "KEYMAP=uk" > /etc/vconsole.conf

# Hostname
echo "$HOSTNAME" > /etc/hostname
echo "127.0.0.1   localhost" >> /etc/hosts
echo "::1         localhost" >> /etc/hosts
echo "127.0.1.1   $HOSTNAME.localdomain $HOSTNAME" >> /etc/hosts

# Users
echo -e "
${GREEN}--- Setting up Users ---
${NC}"

echo "root:$ROOT_PASS" | chpasswd
useradd -m -G wheel,storage,power -s /bin/bash "$USERNAME"
echo "$USERNAME:$USER_PASS" | chpasswd

echo "%wheel ALL=(ALL:ALL) ALL" > /etc/sudoers.d/wheel

# Fix Repo Ownership
chown -R "$USERNAME:$USERNAME" "/home/$USERNAME/Obsidian"

# Bootloader
echo -e "
${GREEN}--- Installing GRUB ---
${NC}"
grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id=GRUB
grub-mkconfig -o /boot/grub/grub.cfg

# Network
systemctl enable NetworkManager

# ------------------------------------------------------------------------------
# Tier 1: Home Setup
# ------------------------------------------------------------------------------
echo -e "
${GREEN}--- Tier 1: Home Setup ---
${NC}"

USER_HOME="/home/$USERNAME"
mkdir -p "$USER_HOME"/{Games,Make} "$USER_HOME/.local/bin"

# @games Handling
if ! mountpoint -q "$USER_HOME/Games"; then
    mount -o subvol=@games "$DISK" "$USER_HOME/Games"
fi
chattr +C "$USER_HOME/Games"
chown -R "$USERNAME:$USERNAME" "$USER_HOME/Games"

# Add @games to fstab
ROOT_UUID=$(blkid -s UUID -o value "$PART2")
if ! grep -q "@games" /etc/fstab; then
    echo "UUID=$ROOT_UUID $USER_HOME/Games btrfs rw,noatime,compress=zstd:3,ssd,discard=async,space_cache=v2,subvol=/@games 0 0" >> /etc/fstab
fi

# Git Config
su - "$USERNAME" -c "git config --global user.email '$GIT_EMAIL'"
su - "$USERNAME" -c "git config --global user.name '$GIT_USER'"
su - "$USERNAME" -c "git config --global credential.helper libsecret"

# Oh-My-Zsh & Shell
if [ ! -d "$USER_HOME/.oh-my-zsh" ]; then
    su - "$USERNAME" -c "sh -c \"\
$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)
\" \" --unattended"
fi
chsh -s /usr/bin/zsh "$USERNAME"

# Root Zsh Symlinks
rm -f /root/.zshrc /root/.oh-my-zsh
ln -sf "$USER_HOME/.oh-my-zsh" /root/.oh-my-zsh
ln -sf "$USER_HOME/.zshrc" /root/.zshrc

# Plugins
ZSH_CUSTOM="$USER_HOME/.oh-my-zsh/custom"
mkdir -p "$ZSH_CUSTOM/plugins"
su - "$USERNAME" -c "git clone https://github.com/zsh-users/zsh-autosuggestions $ZSH_CUSTOM/plugins/zsh-autosuggestions" || true
su - "$USERNAME" -c "git clone https://github.com/zsh-users/zsh-syntax-highlighting $ZSH_CUSTOM/plugins/zsh-syntax-highlighting" || true
sed -i 's/^plugins=(git)$/plugins=(git archlinux zsh-autosuggestions zsh-syntax-highlighting)/' "$USER_HOME/.zshrc"

# Inject Aliases & Functions
cat << ZSHRC_EOF >> "$USER_HOME/.zshrc"
# Start Custom Aliases
export PATH="$HOME/.local/bin:$PATH"
alias mkinit="sudo mkinitcpio -P"
alias mkgrub="sudo grub-mkconfig -o /boot/grub/grub.cfg"
git() {
    if (( EUID == 0 )); then command git "$@"; return; fi
    if [[ "$1" == "clone" && -n "$2" && -z "$3" ]]; then
        if [[ "$PWD" == "$HOME" ]]; then
            echo "Auto-cloning to ~/Make..."
            local repo_name="\\
${2##*/}"; repo_name="\\
${repo_name%.git}"
            command git clone "$2" "$HOME/Make/\\
${repo_name}"
        else
            command git clone "$2"
        fi
    else
        command git "$@"
    fi
}
maintain() { "$HOME/Obsidian/AMD-Linux-Setup/Scripts/system_maintain.zsh"; }

# Start KWin Management
export KWIN_PROFILE="$PROFILE"

update-kwin() {
    local target="
${1:-\\$KWIN_PROFILE}"
    if [[ -z "$target" ]]; then
        echo "Error: No profile specified."
        return 1
    fi
    echo "Syncing and Updating for Profile: $target"
    (cd "$HOME/Obsidian/AMD-Linux-Setup" && git pull && ./Scripts/kwin_apply_rules.zsh "$target")
}

edit-kwin() {
    local target="
${1:-\\$KWIN_PROFILE}"
    local repo_dir="$HOME/Obsidian/AMD-Linux-Setup/Resources/Kwin"
    local file_path=""
    case "$target" in
        "desktop") file_path="$repo_dir/desktop.rule.template" ;; \
        "laptop")  file_path="$repo_dir/laptop.rule.template" ;; \
        "common")  file_path="$repo_dir/common.kwinrule.fragment" ;; \
        *)         file_path="$repo_dir/common.kwinrule.fragment" ;; \
    esac
    [[ -f "$file_path" ]] && kate "$file_path" &!
}
# End KWin Management
# End Custom Aliases
ZSHRC_EOF

# Konsole Profiles
REPO_DIR="$USER_HOME/Obsidian/AMD-Linux-Setup"
mkdir -p "$USER_HOME/.local/share/konsole"
cp -f "$REPO_DIR/Resources/Konsole"/* "$USER_HOME/.local/share/konsole/" 2>/dev/null || true
chown -R "$USERNAME:$USERNAME" "$USER_HOME/.local"

# ------------------------------------------------------------------------------
# Tier 2: Core Configuration
# ------------------------------------------------------------------------------
echo -e "
${GREEN}--- Tier 2: Core Config ---
${NC}"

sed -i "/^\\\[multilib\\\\]/,/^Include/"'s/^#//' /etc/pacman.conf

sed -i 's/^#*\(CFLAGS=\".*\-march=\"\)x86-64 -mtune=generic/\1native/' /etc/makepkg.conf
sed -i "s/^#*MAKEFLAGS=.*/MAKEFLAGS=\"-j\
$(nproc)\"/. " /etc/makepkg.conf
sed -i 's/^#*\(BUILDDIR=\/tmp\/makepkg\)/\1/' /etc/makepkg.conf
if ! grep -q "RUSTFLAGS" /etc/makepkg.conf; then
    echo 'RUSTFLAGS="-C target-cpu=native"' >> /etc/makepkg.conf
fi

systemctl enable bluetooth timeshift-hourly.timer fwupd.service sddm

if ! grep -q "LIBVA_DRIVER_NAME" /etc/environment; then
    echo -e "\nLIBVA_DRIVER_NAME=radeonsi\nVDPAU_DRIVER=radeonsi\nWINEFSYNC=1" >> /etc/environment
fi

sed -i 's/^#*\(Experimental = \).*/\1true/' /etc/bluetooth/main.conf

cat << REF > /etc/xdg/reflector/reflector.conf
--country GB,IE,NL,DE,FR,EU
--age 6
--protocol https
--sort rate
--fastest 10
--save /etc/pacman.d/mirrorlist
REF
systemctl enable reflector.timer

cat << UNIT > /etc/systemd/system/btrfs-balance.service
[Unit]
Description=Btrfs Balance
[Service]
Type=oneshot
ExecStart=/usr/bin/btrfs balance start -dusage=50 -musage=50 /
UNIT
cat << TIMER > /etc/systemd/system/btrfs-balance.timer
[Unit]
Description=Run Btrfs Balance Monthly
[Timer]
OnCalendar=monthly
Persistent=true
[Install]
WantedBy=timers.target
TIMER
systemctl enable btrfs-balance.timer
systemctl enable btrfs-scrub@-.timer

if [ -f /usr/lib/systemd/system/grub-btrfsd.service ]; then
    cp /usr/lib/systemd/system/grub-btrfsd.service /etc/systemd/system/grub-btrfsd.service
    sed -i 's|^ExecStart=.*|ExecStart=/usr/bin/grub-btrfsd --syslog --timeshift-auto|' /etc/systemd/system/grub-btrfsd.service
    systemctl enable grub-btrfsd
fi

echo -e "[zram0]\nzram-size = ram / 2\ncompression-algorithm = lz4\nswap-priority = 100" > /etc/systemd/zram-generator.conf
echo -e "vm.swappiness = 150\nvm.page-cluster = 0" > /etc/sysctl.d/99-swappiness.conf
echo -e "net.core.default_qdisc = cake\nnet.ipv4.tcp_congestion_control = bbr" > /etc/sysctl.d/99-bbr.conf
echo -e "net.ipv4.ip_forward = 1\nnet.ipv6.conf.all.forwarding = 1" > /etc/sysctl.d/99-tailscale.conf

mkdir -p /etc/NetworkManager/dispatcher.d
cat << GRO > /etc/NetworkManager/dispatcher.d/99-tailscale-gro
#!/bin/bash
[[ "$2" == "up" ]] && /usr/bin/ethtool -K "$1" rx-udp-gro-forwarding on rx-gro-list off 2>/dev/null || true
GRO
chmod +x /etc/NetworkManager/dispatcher.d/99-tailscale-gro

sed -i 's/^#COMPRESSION="zstd"/COMPRESSION="lz4"/' /etc/mkinitcpio.conf
sed -i 's|^MODULES=.*|MODULES=(amdgpu nvme)|' /etc/mkinitcpio.conf
sed -i 's|^HOOKS=.*|HOOKS=(base udev autodetect modconf kms keyboard keymap consolefont block btrfs filesystems)|' /etc/mkinitcpio.conf
mkinitcpio -P

mkdir -p /etc/pacman.d/hooks
cat << HOOK1 > /etc/pacman.d/hooks/98-rebuild-initramfs.hook
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
HOOK1

cat << HOOK2 > /etc/pacman.d/hooks/99-update-grub.hook
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
HOOK2

# Gemini Config
mkdir -p "$USER_HOME/.gemini"
echo '{}' > "$USER_HOME/.gemini/settings.json"
chown -R "$USERNAME:$USERNAME" "$USER_HOME/.gemini"

# UI Visuals
papirus-folders -C breeze --theme Papirus-Dark

# ------------------------------------------------------------------------------
# Tier 3: Device Configuration ($PROFILE)
# ------------------------------------------------------------------------------
echo -e "
${GREEN}--- Tier 3: Device Config ($PROFILE) ---
${NC}"

if [[ "$PROFILE" == "desktop" ]]; then
    
    groupadd -f media
    usermod -aG media "$USERNAME"
    
    mkdir -p /var/lib/jellyfin
    chattr +C /var/lib/jellyfin
    chown -R jellyfin:jellyfin /var/lib/jellyfin
    usermod -aG render,video jellyfin
    echo "d /dev/shm/jellyfin 0755 jellyfin jellyfin -" > /etc/tmpfiles.d/jellyfin-transcode.conf

    for svc in sonarr radarr lidarr prowlarr transmission; do
        id "$svc" &>/dev/null && usermod -aG media "$svc"
    done
    
    # Media Drive Setup
    if [ -n "$MEDIA_UUID" ]; then
        mkdir -p /mnt/Media
        echo "UUID=$MEDIA_UUID /mnt/Media btrfs rw,nosuid,nodev,noatime,nofail,x-gvfs-hide,x-systemd.automount,compress=zstd:3,discard=async 0 0" >> /etc/fstab
        chown -R "$USERNAME:media" /mnt/Media
        chmod 775 /mnt/Media
        setfacl -R -m g:media:rwX /mnt/Media
        setfacl -R -m d:g:media:rwX /mnt/Media
    fi

    # Slskd Configuration
    if [ -n "$SLSKD_USER" ]; then
        mkdir -p /etc/slskd
        cat <<SLSKD > /etc/slskd/slskd.yml
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
SLSKD
        mkdir -p /etc/systemd/system/slskd.service.d
        echo -e "[Unit]\nRequiresMountsFor=/mnt/Media\n[Service]\nUMask=0002\nExecStart=\nExecStart=/usr/lib/slskd/slskd --config /etc/slskd/slskd.yml" > /etc/systemd/system/slskd.service.d/override.conf
        systemctl enable slskd
    fi

    # Soularr Setup
    if [ ! -d "/opt/soularr" ]; then
        cd /opt
        git clone https://github.com/mrusse/soularr.git
        chown -R "$USERNAME:$USERNAME" /opt/soularr
        # pip is installed by base extras/desktop pkg
        pip install --break-system-packages -r /opt/soularr/requirements.txt
        mkdir -p /opt/soularr/config
        cp /opt/soularr/config.ini /opt/soularr/config/config.ini
        
        cat <<SOULARR > /etc/systemd/system/soularr.service
[Unit]
Description=Soularr (Lidarr <-> Slskd automation)
Wants=network-online.target lidarr.service slskd.service
After=network-online.target lidarr.service slskd.service
Requires=lidarr.service slskd.service
RequiresMountsFor=/mnt/Media
[Service]
Type=oneshot
User=$USERNAME
Group=$USERNAME
UMask=0002
WorkingDirectory=/opt/soularr
ExecStart=/usr/bin/python /opt/soularr/soularr.py --config-dir /opt/soularr/config --no-lock-file
NoNewPrivileges=yes
PrivateTmp=yes
ProtectSystem=full
ProtectHome=read-only
ReadWritePaths=/opt/soularr /var/log /mnt/Media/Downloads/slskd/Complete/
SOULARR
        
        cat <<SOULARRTIMER > /etc/systemd/system/soularr.timer
[Unit]
Description=Run Soularr every 30 minutes
[Timer]
OnCalendar=*:0/30
Persistent=true
AccuracySec=1min
[Install]
WantedBy=timers.target
SOULARRTIMER
        systemctl enable soularr.timer
    fi
    
    # Sunshine Repos (Already handled by pacman.conf/pacstrap, but we need to enable [lizardbyte] in target conf)
    if ! grep -q "\[lizardbyte\]" /etc/pacman.conf; then
        echo -e "\n[lizardbyte]\nSigLevel = Optional\nServer = https://github.com/LizardByte/pacman-repo/releases/latest/download" >> /etc/pacman.conf
    fi

    # Sunshine Hooks & Icons
    cat << ICONS > /usr/local/bin/replace-sunshine-icons.sh
#!/bin/bash
DEST="/usr/share/icons/hicolor/scalable/status"
SRC="$REPO_DIR/Resources/Icons/Sunshine"
[[ -d "$SRC" ]] && cp "$SRC"/*.svg "$DEST/"
SUNSHINE_PATH=$(command -v sunshine)
[[ -n "$SUNSHINE_PATH" ]] && setcap cap_sys_admin+p "$SUNSHINE_PATH"
ICONS
    chmod +x /usr/local/bin/replace-sunshine-icons.sh
    
    cat << ICONHOOK > /etc/pacman.d/hooks/sunshine-icons.hook
[Trigger]
Operation = Install
Operation = Upgrade
Type = Package
Target = sunshine
[Action]
Description = Replacing Sunshine tray icons...
When = PostTransaction
Exec = /usr/local/bin/replace-sunshine-icons.sh
ICONHOOK

    # Sunshine Helper Scripts
    ln -sf "$REPO_DIR/Scripts/sunshine_gpu_boost.zsh" /usr/local/bin/sunshine_gpu_boost
    ln -sf "$REPO_DIR/Scripts/sunshine_hdr.zsh" /usr/local/bin/sunshine_hdr
    ln -sf "$REPO_DIR/Scripts/sunshine_res.zsh" /usr/local/bin/sunshine_res
    ln -sf "$REPO_DIR/Scripts/sunshine_laptop.zsh" /usr/local/bin/sunshine_laptop
    chmod +x "$REPO_DIR/Scripts/"sunshine*.zsh

    # Hardware Fixes (Desktop)
    echo 'SUBSYSTEM=="pci", ATTR{vendor}=="0x1022", ATTR{device}=="0x43f7", ATTR{power/control}=="on"' > /etc/udev/rules.d/99-xhci-fix.rules
    echo 'ACTION=="add|change", KERNEL=="nvme[0-9]n[0-9]", ATTR{queue/scheduler}=="kyber"' > /etc/udev/rules.d/60-iosched.rules
    
    # WiFi Power Save
    cat << WIFI > /etc/NetworkManager/dispatcher.d/disable-wifi-powersave
#!/bin/sh
[[ "$1" == wl* ]] && [[ "$2" == "up" ]] && /usr/bin/iw dev "$1" set power_save off
WIFI
    chmod +x /etc/NetworkManager/dispatcher.d/disable-wifi-powersave
    
    # Custom EDID
    KERNEL_CMDLINE="loglevel=3 quiet amdgpu.ppfeaturemask=0xffffffff hugepages=512 video=3440x1440@60 amd_pstate=active"
    if [[ "$INSTALL_EDID" =~ ^[Yy]$ ]]; then
        mkdir -p /usr/lib/firmware/edid
        cp "$REPO_DIR/Resources/Sunshine/custom_2560x1600.bin" /usr/lib/firmware/edid/
        # Inject into Initramfs
        sed -i 's|^FILES=(|FILES=(/usr/lib/firmware/edid/custom_2560x1600.bin |' /etc/mkinitcpio.conf
        mkinitcpio -P
    fi
    sed -i 's|^GRUB_CMDLINE_LINUX_DEFAULT=.*|GRUB_CMDLINE_LINUX_DEFAULT="$KERNEL_CMDLINE"|' /etc/default/grub
    
    # Tailscale
    systemctl enable tailscaled
    
    # KWin Rules
    su - "$USERNAME" -c "$REPO_DIR/Scripts/kwin_apply_rules.zsh desktop"
    
elif [[ "$PROFILE" == "laptop" ]]; then
    # Kernel Args (Laptop)
    sed -i 's|^GRUB_CMDLINE_LINUX_DEFAULT=.*|GRUB_CMDLINE_LINUX_DEFAULT="loglevel=3 quiet amdgpu.ppfeaturemask=0xffffffff hugepages=512 video=2560x1600@60 amd_pstate=active"|' /etc/default/grub
    
    # WiFi Power Save
    cat << WIFI > /etc/NetworkManager/dispatcher.d/disable-wifi-powersave
#!/bin/sh
[[ "$1" == wl* ]] && [[ "$2" == "up" ]] && /usr/bin/iw dev "$1" set power_save off
WIFI
    chmod +x /etc/NetworkManager/dispatcher.d/disable-wifi-powersave

    # Numlock Hook
    sed -i 's/HOOKS=(\(.*\))/HOOKS=(\1 numlock)/' /etc/mkinitcpio.conf
    mkinitcpio -P
    
    # KWin Rules
    su - "$USERNAME" -c "$REPO_DIR/Scripts/kwin_apply_rules.zsh laptop"
fi

# Konsave & Visuals
echo -e "${GREEN}--- Applying Visual Profiles ---
${NC}"
KONSAVE_DIR="$REPO_DIR/Resources/Konsave"
if [[ "$PROFILE" == "desktop" ]]; then
    PROFILE_FILE=$(ls -1 "$KONSAVE_DIR"/Desktop\ Dock*.knsv 2>/dev/null | tail -n 1)
else
    PROFILE_FILE=$(ls -1 "$KONSAVE_DIR"/Laptop\ Dock*.knsv 2>/dev/null | tail -n 1)
fi

if [[ -n "$PROFILE_FILE" ]]; then
    su - "$USERNAME" -c "konsave -i \"$PROFILE_FILE\""
    su - "$USERNAME" -c "konsave -a \"
${PROFILE_FILE##*/}\" && konsave -a \"
${PROFILE_FILE##*/%.*}\"" || true
fi

TRANS_ARCHIVE="$REPO_DIR/Resources/Plasmoids/transmission-plasmoid.tar.gz"
if [[ -f "$TRANS_ARCHIVE" ]]; then
    su - "$USERNAME" -c "mkdir -p ~/.local/share/plasma/plasmoids && tar -xf \"$TRANS_ARCHIVE\" -C ~/.local/share/plasma/plasmoids"
fi

grub-mkconfig -o /boot/grub/grub.cfg

EOF

chmod +x /mnt/root/stage2_config.sh

echo -e "${GREEN}--- Entering Chroot for Config ---
${NC}"
arch-chroot /mnt /root/stage2_config.sh

echo -e "${GREEN}--- Cleanup ---
${NC}"
rm /mnt/root/stage2_config.sh
umount -R /mnt

echo -e "${GREEN}=== Installation Complete ===
${NC}"

echo "Remove USB and reboot."
