#!/bin/bash
# ------------------------------------------------------------------------------
# UNIFIED ARCH LINUX INSTALLER (Standalone)
# ------------------------------------------------------------------------------
# Purpose: Full system provisioning from Live USB, replicating the tiered 
#          setup (Home -> Core -> Device) without archinstall.
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
    fi
    
    # User Details
    read -p "Enter Hostname [NCC-1701]: " HOSTNAMEHOSTNAME=${HOSTNAME:-NCC-1701}
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
# 2. Partitioning & Formatting
# ------------------------------------------------------------------------------

echo -e "${GREEN}--- Partitioning $DISK ---${NC}"

# Wipe
sgdisk -Z "$DISK"

# Create Partitions
# 1: EFI (1GB)
# 2: Root (Remaining)
sgdisk -n 1:0:+1G -t 1:ef00 -c 1:"EFI System Partition" "$DISK"
sgdisk -n 2:0:0   -t 2:8300 -c 2:"Arch Linux Root"      "$DISK"

# Detect Partitions (NVMe vs SATA naming)
if [[ "$DISK" == *"nvme"* ]]; then
    PART1="${DISK}p1"
    PART2="${DISK}p2"
else
    PART1="${DISK}1"
    PART2="${DISK}2"
fi

echo -e "${GREEN}--- Formatting ---${NC}"
mkfs.fat -F32 -n "EFI" "$PART1"
mkfs.btrfs -f -L "ROOT" "$PART2"

# ------------------------------------------------------------------------------
# 3. Subvolumes & Mounting
# ------------------------------------------------------------------------------

echo -e "${GREEN}--- Creating Subvolumes ---${NC}"
mount "$PART2" /mnt

# Standard Arch Subvolumes
btrfs subvolume create /mnt/@
btrfs subvolume create /mnt/@home
btrfs subvolume create /mnt/@log
btrfs subvolume create /mnt/@pkg
btrfs subvolume create /mnt/@snapshots

# Custom @games (No-CoW)
btrfs subvolume create /mnt/@games

umount /mnt

echo -e "${GREEN}--- Mounting Filesystems ---${NC}"
MOUNT_OPTS="rw,noatime,compress=zstd:3,ssd,discard=async,space_cache=v2"

# Mount Root
mount -o "$MOUNT_OPTS,subvol=@" "$PART2" /mnt

# Create Mountpoints
mkdir -p /mnt/{home,boot,var/log,var/cache/pacman/pkg,Games}

# Mount Subvolumes
mount -o "$MOUNT_OPTS,subvol=@home" "$PART2" /mnt/home
mount -o "$MOUNT_OPTS,subvol=@log"  "$PART2" /mnt/var/log
mount -o "$MOUNT_OPTS,subvol=@pkg"  "$PART2" /mnt/var/cache/pacman/pkg
mount -o "$MOUNT_OPTS,subvol=@snapshots" "$PART2" /mnt/.snapshots 2>/dev/null || true

# Mount EFI
mount "$PART1" /mnt/boot

# ------------------------------------------------------------------------------
# 4. Base Installation
# ------------------------------------------------------------------------------

echo -e "${GREEN}--- Installing Base System ---${NC}"
# Note: Installing standard linux first, switched to cachyos in chroot to match setup_core logic safely
pacstrap -K /mnt base base-devel linux linux-firmware git vim openssh networkmanager grub efibootmgr

echo -e "${GREEN}--- Generating Fstab ---${NC}"
genfstab -U /mnt >> /mnt/etc/fstab

# Inject @games into fstab (User home doesn't exist yet, so we mount to /home/Games for now, 
# but we need it to point to /home/$USER/Games eventually. 
# Strategy: We will configure the fstab entry now using a placeholder or just append it.
# Better: rely on the setup_home logic to add the fstab entry? 
# No, we want it ready. We will calculate the UUID and append it correctly for the USER.)

ROOT_UUID=$(blkid -s UUID -o value "$PART2" )
# We'll use a temporary mountpoint in fstab or configure it in the chroot script
# when the user directory is created.

# ------------------------------------------------------------------------------
# 5. Chroot Setup Script
# ------------------------------------------------------------------------------

echo -e "${GREEN}--- Preparing Chroot Script ---${NC}"

cat <<EOF > /mnt/root/stage2_install.sh
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
echo -e "${GREEN}--- Setting up Users ---
${NC}"
echo "root:$ROOT_PASS" | chpasswd
useradd -m -G wheel,storage,power -s /bin/bash "$USERNAME"
echo "$USERNAME:$USER_PASS" | chpasswd
echo "%wheel ALL=(ALL:ALL) ALL" > /etc/sudoers.d/wheel

# Bootloader
echo -e "${GREEN}--- Installing GRUB ---
${NC}"
grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id=GRUB
grub-mkconfig -o /boot/grub/grub.cfg

# Network
systemctl enable NetworkManager

# ------------------------------------------------------------------------------
# Tier 1: Home Setup (Replicated)
# ------------------------------------------------------------------------------
echo -e "${GREEN}--- Tier 1: Home Setup ---
${NC}"

# Directories
USER_HOME="/home/$USERNAME"
mkdir -p "$USER_HOME"/{Games,Make,Obsidian} "$USER_HOME/.local/bin"

# @games Handling
# We mount it now to set attributes
if ! mountpoint -q "$USER_HOME/Games"; then
    mount -o subvol=@games "$DISK" "$USER_HOME/Games"
fi
chattr +C "$USER_HOME/Games"
chown -R "$USERNAME:$USERNAME" "$USER_HOME/Games"

# Add to fstab
if ! grep -q "@games" /etc/fstab; then
    echo "UUID=$ROOT_UUID $USER_HOME/Games btrfs rw,noatime,compress=zstd:3,ssd,discard=async,space_cache=v2,subvol=/@games 0 0" >> /etc/fstab
fi

# Clone Repo
REPO_DIR="$USER_HOME/Obsidian/AMD-Linux-Setup"
if [ ! -d "$REPO_DIR" ]; then
    echo -e "${YELLOW}Cloning configuration repo...
${NC}"
    # Use the token for auth if needed, or https public if public (it is public in scripts)
    # But user provided token implies we might want push access or it's private.
    # The existing script uses basic auth with token.
    git clone https://$GIT_USER:$GIT_TOKEN@github.com/OldLorekeeper/AMD-Linux-Setup "$REPO_DIR"
    chown -R "$USERNAME:$USERNAME" "$USER_HOME/Obsidian"
fi

# Git Config
su - "$USERNAME" -c "git config --global user.email '$GIT_EMAIL'"
su - "$USERNAME" -c "git config --global user.name '$GIT_USER'"
su - "$USERNAME" -c "git config --global credential.helper libsecret"

# Oh-My-Zsh & Shell (User)
if [ ! -d "$USER_HOME/.oh-my-zsh" ]; then
    su - "$USERNAME" -c "sh -c \"\
$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)\" \"\" --unattended"
fi
chsh -s /usr/bin/zsh "$USERNAME"

# Oh-My-Zsh (Root - Symlink method)
rm -f /root/.zshrc /root/.oh-my-zsh
ln -sf "$USER_HOME/.oh-my-zsh" /root/.oh-my-zsh
ln -sf "$USER_HOME/.zshrc" /root/.zshrc

# Plugins
ZSH_CUSTOM="$USER_HOME/.oh-my-zsh/custom"
mkdir -p "$ZSH_CUSTOM/plugins"
su - "$USERNAME" -c "git clone https://github.com/zsh-users/zsh-autosuggestions $ZSH_CUSTOM/plugins/zsh-autosuggestions" || true
su - "$USERNAME" -c "git clone https://github.com/zsh-users/zsh-syntax-highlighting $ZSH_CUSTOM/plugins/zsh-syntax-highlighting" || true
sed -i 's/^plugins=(git)$/plugins=(git archlinux zsh-autosuggestions zsh-syntax-highlighting)/' "$USER_HOME/.zshrc"

# Inject Aliases
cat << ALIAS_EOF >> "$USER_HOME/.zshrc"
# Start Custom Aliases
export PATH="$HOME/.local/bin:$PATH"
alias mkinit="sudo mkinitcpio -P"
alias mkgrub="sudo grub-mkconfig -o /boot/grub/grub.cfg"
git() {
    if (( EUID == 0 )); then command git "$@"; return; fi
    if [[ "$1" == "clone" && -n "$2" && -z "$3" ]]; then
        if [[ "$PWD" == "$HOME" ]]; then
            echo "Auto-cloning to ~/Make..."
            local repo_name="
${2##*/}"; repo_name="
${repo_name%.git}"
            command git clone "$2" "$HOME/Make/
${repo_name}"
        else
            command git clone "$2"
        fi
    else
        command git "$@"
    fi
}
maintain() { "$HOME/Obsidian/AMD-Linux-Setup/Scripts/system_maintain.zsh"; }
# End Custom Aliases
ALIAS_EOF

# Konsole Profiles
mkdir -p "$USER_HOME/.local/share/konsole"
cp -f "$REPO_DIR/Resources/Konsole"/* "$USER_HOME/.local/share/konsole/" 2>/dev/null || true
chown -R "$USERNAME:$USERNAME" "$USER_HOME/.local"

# ------------------------------------------------------------------------------
# Tier 2: Core Setup (Replicated)
# ------------------------------------------------------------------------------
echo -e "${GREEN}--- Tier 2: Core Setup ---
${NC}"

# Enable Multilib (Critical for Steam/Gaming)
sed -i "/^\[multilib\]/,/^Include/"'s/^#//' /etc/pacman.conf
pacman -Sy

# Install Archinstall Equivalents (DE, Graphics, Audio)
echo -e "${GREEN}--- Installing Desktop Environment & Drivers ---
${NC}"
# Graphics (AMD RDNA3 + 32bit support)
GPU_PKGS="mesa lib32-mesa vulkan-radeon lib32-vulkan-radeon xf86-video-amdgpu libva-mesa-driver"
# Desktop (KDE Plasma + Essentials)
DE_PKGS="plasma-meta sddm konsole dolphin ark xdg-user-dirs"
# Audio (Pipewire)
AUDIO_PKGS="pipewire pipewire-alsa pipewire-pulse wireplumber"
# Connectivity & Utils (From setup_config.json)
BASE_PKGS="amd-ucode bluez bluez-utils cups dosfstools os-prober ntfs-3g steam gamemode lib32-gamemode"

pacman -S --needed --noconfirm $GPU_PKGS $DE_PKGS $AUDIO_PKGS $BASE_PKGS
systemctl enable sddm

# Makepkg Optimisation
sed -i 's/^#*\(CFLAGS=".*-march=\)x86-64 -mtune=generic/\1native/' /etc/makepkg.conf
sed -i "s/^#*MAKEFLAGS=.*/MAKEFLAGS=\"-j\$(nproc)\"/" /etc/makepkg.conf
sed -i 's/^#*\(BUILDDIR=\/tmp\/makepkg\)/\1/' /etc/makepkg.conf
if ! grep -q "RUSTFLAGS" /etc/makepkg.conf; then
    echo 'RUSTFLAGS="-C target-cpu=native"' >> /etc/makepkg.conf
fi

# Mirrors
pacman -S --noconfirm reflector
reflector --country GB,IE,NL,DE,FR,EU --age 6 --protocol https --sort rate --fastest 10 --save /etc/pacman.d/mirrorlist

# Install Yay (as User)
if ! command -v yay &>/dev/null; then
    mkdir -p "\$USER_HOME/Make/yay"
    chown -R "$USERNAME:$USERNAME" "\$USER_HOME/Make"
    su - "$USERNAME" -c "git clone https://aur.archlinux.org/yay.git \$USER_HOME/Make/yay"
    su - "$USERNAME" -c "cd \$USER_HOME/Make/yay && makepkg -si --noconfirm"
fi

# CachyOS Kernel & Repo
pacman-key --recv-keys F3B607488DB35A47 --keyserver keyserver.ubuntu.com
pacman-key --lsign-key F3B607488DB35A47
pacman -U --noconfirm 'https://mirror.cachyos.org/repo/x86_64/cachyos/cachyos-keyring-20240331-1-any.pkg.tar.zst' 'https://mirror.cachyos.org/repo/x86_64/cachyos/cachyos-mirrorlist-22-1-any.pkg.tar.zst' 'https://mirror.cachyos.org/repo/x86_64/cachyos/cachyos-v4-mirrorlist-22-1-any.pkg.tar.zst'

sed -i 's/^Architecture = auto/Architecture = auto x86_64_v4/' /etc/pacman.conf
if ! grep -q "\[cachyos\]" /etc/pacman.conf; then
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
pacman -Syy --noconfirm

# Swap Kernel
pacman -S --noconfirm linux-cachyos linux-cachyos-headers
pacman -Rns --noconfirm linux linux-headers || true

# Install Core Packages (using list from repo)
# Removing discovered packages to avoid conflicts
pacman -Rdd --noconfirm discover 2>/dev/null || true
# Use yay as user to install packages
su - "$USERNAME" -c "yay -S --needed --noconfirm - < \$REPO_DIR/Resources/Packages/core_pkg.txt"

# Services & Tuning
systemctl enable bluetooth timeshift-hourly.timer fwupd.service

# Btrfs Maintenance
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

# Sysctl & ZRAM
echo -e "[zram0]\nzram-size = ram / 2\ncompression-algorithm = lz4\nswap-priority = 100" > /etc/systemd/zram-generator.conf
echo -e "vm.swappiness = 150\nvm.page-cluster = 0" > /etc/sysctl.d/99-swappiness.conf
echo -e "net.core.default_qdisc = cake\nnet.ipv4.tcp_congestion_control = bbr" > /etc/sysctl.d/99-bbr.conf
echo -e "net.ipv4.ip_forward = 1\nnet.ipv6.conf.all.forwarding = 1" > /etc/sysctl.d/99-tailscale.conf

# Initramfs (lz4)
sed -i 's/^#COMPRESSION="zstd"/COMPRESSION="lz4"/' /etc/mkinitcpio.conf
sed -i 's|^MODULES=.*|MODULES=(amdgpu nvme)|' /etc/mkinitcpio.conf
sed -i 's|^HOOKS=.*|HOOKS=(base udev autodetect modconf kms keyboard keymap consolefont block btrfs filesystems)|' /etc/mkinitcpio.conf
mkinitcpio -P

# Hooks
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
mkdir -p "\$USER_HOME/.gemini"
echo '{}' > "\$USER_HOME/.gemini/settings.json"
chown -R "$USERNAME:$USERNAME" "\$USER_HOME/.gemini"

# UI Visuals (Papirus)
pacman -S --noconfirm papirus-icon-theme papirus-folders
papirus-folders -C breeze --theme Papirus-Dark

# ------------------------------------------------------------------------------
# Tier 3: Device Profile ($PROFILE)
# ------------------------------------------------------------------------------
echo -e "\${GREEN}--- Tier 3: Device Setup ($PROFILE) ---\${NC}"

if [[ "$PROFILE" == "desktop" ]]; then
    # Desktop Logic
    su - "$USERNAME" -c "yay -S --needed --noconfirm - < \$REPO_DIR/Resources/Packages/desktop_pkg.txt"
    
    # Media Group
    groupadd -f media
    usermod -aG media "$USERNAME"
    
    # Jellyfin
    mkdir -p /var/lib/jellyfin
    chattr +C /var/lib/jellyfin
    chown -R jellyfin:jellyfin /var/lib/jellyfin
    usermod -aG render,video jellyfin
    echo "d /dev/shm/jellyfin 0755 jellyfin jellyfin -" > /etc/tmpfiles.d/jellyfin-transcode.conf

    # Permissions for services
    for svc in sonarr radarr lidarr prowlarr transmission; do
        id "\$svc" &>/dev/null && usermod -aG media "\$svc"
    done
    
    # Media Drive Setup
    if [ -n "$MEDIA_UUID" ]; then
        mkdir -p /mnt/Media
        echo "UUID=$MEDIA_UUID /mnt/Media btrfs rw,nosuid,nodev,noatime,nofail,x-gvfs-hide,x-systemd.automount,compress=zstd:3,discard=async 0 0" >> /etc/fstab
        chown -R "$USERNAME:media" /mnt/Media
        chmod 775 /mnt/Media
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
        pacman -S --noconfirm python-pip
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
    
    # Sunshine Repos
    if ! grep -q "\[lizardbyte\]" /etc/pacman.conf; then
        echo -e "\n[lizardbyte]\nSigLevel = Optional\nServer = https://github.com/LizardByte/pacman-repo/releases/latest/download" >> /etc/pacman.conf
        pacman -Syu --noconfirm
    fi
    
    # Kernel Args (Desktop)
    sed -i 's|^GRUB_CMDLINE_LINUX_DEFAULT=.*|GRUB_CMDLINE_LINUX_DEFAULT="loglevel=3 quiet amdgpu.ppfeaturemask=0xffffffff hugepages=512 video=3440x1440@60 amd_pstate=active"|' /etc/default/grub
    
    # Tailscale
    systemctl enable tailscaled
    
    # KWin Rules
    su - "$USERNAME" -c "\$REPO_DIR/Scripts/kwin_apply_rules.zsh desktop"
    
elif [[ "$PROFILE" == "laptop" ]]; then
    # Laptop Logic
    su - "$USERNAME" -c "yay -S --needed --noconfirm - < \$REPO_DIR/Resources/Packages/laptop_pkg.txt"
    
    # Kernel Args (Laptop)
    sed -i 's|^GRUB_CMDLINE_LINUX_DEFAULT=.*|GRUB_CMDLINE_LINUX_DEFAULT="loglevel=3 quiet amdgpu.ppfeaturemask=0xffffffff hugepages=512 video=2560x1600@60 amd_pstate=active"|' /etc/default/grub
    
    # Numlock Hook
    sed -i 's/HOOKS=(\(.*\))/HOOKS=(\1 numlock)/' /etc/mkinitcpio.conf
    mkinitcpio -P
    
    # KWin Rules
    su - "$USERNAME" -c "\$REPO_DIR/Scripts/kwin_apply_rules.zsh laptop"
fi

# Final Grub Update
grub-mkconfig -o /boot/grub/grub.cfg

EOF

chmod +x /mnt/root/stage2_install.sh

# ------------------------------------------------------------------------------
# 6. Execution
# ------------------------------------------------------------------------------

echo -e "${GREEN}--- Entering Chroot ---${NC}"
arch-chroot /mnt /root/stage2_install.sh

echo -e "${GREEN}--- Cleanup ---${NC}"
rm /mnt/root/stage2_install.sh
umount -R /mnt

echo -e "${GREEN}=== Installation Complete ===${NC}"
echo "Remove USB and reboot."