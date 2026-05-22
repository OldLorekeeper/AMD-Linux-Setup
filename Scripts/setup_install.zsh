#!/bin/zsh
# ------------------------------------------------------------------------------
# AMD-Linux-Setup: Unified Installer (Zen 4)
# A seamlessly modular, opinionated Arch Linux installer replacing archinstall.
# Target: AMD Ryzen 7000+ & Radeon 7000+ | KDE Plasma 6 | CachyOS Kernel
# ------------------------------------------------------------------------------

# region 0. Runtime Configuration
setopt ERR_EXIT NO_UNSET PIPE_FAIL EXTENDED_GLOB
SCRIPT_DIR=${0:a:h}
print -P "\n%K{green}%F{black} STARTING AMD-LINUX-SETUP (ZEN 4) %k%f\n"
# endregion

# ------------------------------------------------------------------------------
# 1. Pre-flight Checks & Secrets
# ------------------------------------------------------------------------------
# region 1. Pre-flight & Secrets
print -P "\n%K{blue}%F{black} 1. PRE-FLIGHT & SECRETS %k%f\n"
if [[ ! -d /sys/firmware/efi/efivars ]]; then
    print -P "%F{red}Error: System is not booted in UEFI mode.%f\n"
    exit 1
fi
if ! ping -c 3 archlinux.org &>/dev/null; then
    print -P "%F{red}Error: No internet connection.%f\n"
    exit 1
fi

print -P "%F{cyan}ℹ Fetching installer components...%f\n"
if ! curl -fsSL "https://github.com/OldLorekeeper/AMD-Linux-Setup/archive/refs/heads/main.zip" -o /tmp/amd_setup.zip; then
    print -P "%F{red}Error: Failed to fetch repository.%f\n"
    exit 1
fi
mkdir -p /tmp/amd_setup
bsdtar -xf /tmp/amd_setup.zip -C /tmp/amd_setup --strip-components=1
PAYLOAD_DIR="/tmp/amd_setup/Scripts/payloads"
if [[ ! -d "$PAYLOAD_DIR" ]]; then
    print -P "%F{red}Error: Failed to locate payloads in downloaded repository.%f\n"
    exit 1
fi

SECRETS_FILE="setup_secrets.enc"
RAW_URL="https://raw.githubusercontent.com/OldLorekeeper/AMD-Linux-Setup/main/Scripts/$SECRETS_FILE"
if [[ ! -f "$SECRETS_FILE" ]]; then
    print -P "\n%F{cyan}ℹ Secrets file not found locally. Attempting remote fetch...%f\n"
    if curl -fsSL "$RAW_URL" -o "$SECRETS_FILE"; then
        print -P "%F{green}Successfully downloaded $SECRETS_FILE%f\n"
    else
        print -P "%F{red}Failed to download secrets. Proceeding with manual input.%f\n"
    fi
fi

if [[ -f "$SECRETS_FILE" ]]; then
    print -P "%F{yellow}Enter Decryption Password:%f"
    read -s "DECRYPT_PASS?Password: "; print ""
    if DECRYPTED=$(openssl enc -d -aes-256-cbc -pbkdf2 -in "$SECRETS_FILE" -k "$DECRYPT_PASS" 2>/dev/null); then
        source <(print -r "$DECRYPTED")
        if [[ "${SECRETS_LOADED:-}" == "true" ]]; then
            print -P "\n%F{green}Secrets loaded successfully.%f\n"
        else
            print -P "\n%F{red}Secrets format invalid. Falling back to manual prompts.%f\n"
        fi
    else
        print -P "\n%F{red}Decryption failed. Continuing with manual prompts.%f\n"
    fi
fi
# endregion

# ------------------------------------------------------------------------------
# 2. User Configuration
# ------------------------------------------------------------------------------
# region 2. User Configuration
print -P "\n%K{blue}%F{black} 2. USER CONFIGURATION %k%f\n"

print -P "%K{yellow}%F{black} SYSTEM IDENTITY %k%f\n"
if [[ -z "${HOSTNAME:-}" ]]; then
    print -P "%F{yellow}Enter System Hostname:%f"
    read "HOSTNAME?Hostname [NCC-1701]: "
    HOSTNAME=${HOSTNAME:-NCC-1701}
else
    print -P "Hostname:     %F{green}$HOSTNAME%f"
fi
if [[ -z "${TARGET_USER:-}" ]]; then
    print -P "%F{yellow}Enter Primary Username:%f"
    read "TARGET_USER?Username [user]: "
    TARGET_USER=${TARGET_USER:-user}
else
    print -P "Username:     %F{green}$TARGET_USER%f"
fi
if [[ -z "${ROOT_PASS:-}" ]]; then
    print -P "%F{yellow}Set Root Password:%f"
    read -s "ROOT_PASS?Password: "; print ""
else
    print -P "Root Pass:    %F{green}Loaded from secrets%f"
fi
if [[ -z "${USER_PASS:-}" ]]; then
    print -P "%F{yellow}Set User Password:%f"
    read -s "USER_PASS?Password: "; print ""
else
    print -P "User Pass:    %F{green}Loaded from secrets%f"
fi

print -P "\n%K{yellow}%F{black} GIT IDENTITY %k%f\n"
if [[ -z "${GIT_NAME:-}" ]]; then
    print -P "%F{yellow}Enter Git Commit Name:%f"
    read "GIT_NAME?Name: "
else
    print -P "Git Name:     %F{green}$GIT_NAME%f"
fi
if [[ -z "${GIT_EMAIL:-}" ]]; then
    print -P "%F{yellow}Enter Git Email:%f"
    read "GIT_EMAIL?Email: "
else
    print -P "Git Email:    %F{green}$GIT_EMAIL%f"
fi
if [[ -n "${GIT_PAT:-}" ]]; then
    print -P "Git PAT:      %F{green}Loaded from secrets%f"
else
    print -P "%F{yellow}Enter GitHub PAT:%f"
    read -s "GIT_PAT?Token: "; print ""
fi
if [[ -z "${GIT_PAT:-}" ]]; then
    print -P "\n%F{red}Error: Git PAT is required.%f\n"
    exit 1
fi

print -P "\n%K{yellow}%F{black} DESKTOP THEMING %k%f\n"
if [[ -z "${APPLY_KONSAVE:-}" ]]; then
    print -P "%F{yellow}Apply custom Konsave profile?%f"
    read "APPLY_KONSAVE?Apply Theme? [Y/n]: "
    [[ "$APPLY_KONSAVE" == (#i)n* ]] && APPLY_KONSAVE="false" || APPLY_KONSAVE="true"
else
    print -P "Apply Theme:  %F{green}$APPLY_KONSAVE%f"
fi
# endregion

# ------------------------------------------------------------------------------
# 3. Device Profile Selection
# ------------------------------------------------------------------------------
# region 3. Device Profile
print -P "\n%K{blue}%F{black} 3. DEVICE PROFILE %k%f\n"

print -l "1) Desktop (Ryzen 7800X3D / RX 7900 XT)" "2) Laptop (Ryzen 7840HS / 780M)"
print -P "%F{yellow}Select Hardware Profile:%f"
read "PROFILE_SEL?Selection [1-2]: "
case $PROFILE_SEL in
    1) DEVICE_PROFILE="desktop" ;;
    2) DEVICE_PROFILE="laptop" ;;
    *) print -P "\n%F{red}Invalid selection.%f\n"; exit 1 ;;
esac

MEDIA_UUID=""
EDID_ENABLE=""
MONITOR_PORT=""

if [[ "$DEVICE_PROFILE" == "desktop" ]]; then
    print -P "\n%K{yellow}%F{black} DESKTOP STORAGE & AUTOMATION %k%f\n"
    print -P "%F{cyan}ℹ Scanning block devices...%f\n"
    lsblk -o NAME,SIZE,FSTYPE,LABEL,UUID | grep -v loop || true

    print -P "%F{yellow}Enter Media Drive UUID:%f"
    read "MEDIA_UUID?UUID (Leave empty to skip): "

    print -P "\n%K{yellow}%F{black} DISPLAY CONFIGURATION %k%f\n"
    print -P "%F{yellow}Configure Custom Display EDID?%f"
    read "EDID_ENABLE?Enable 2560x1600 EDID? [y/N]: "
    
    if [[ "$EDID_ENABLE" == (#i)y* ]]; then
        print -P "\n%F{cyan}ℹ Detecting connected ports...%f\n"
        typeset -a CONNECTED_PORTS
        for status_file in /sys/class/drm/*/status(N); do
            grep -q "connected" "$status_file" && CONNECTED_PORTS+=("${${status_file:h}:t#*-}")
        done
        
        if (( ${#CONNECTED_PORTS} == 0 )); then
            print -P "\n%F{red}No monitors detected.%f\n"
            print -P "%F{yellow}Enter Monitor Port Manually:%f"
            read "MONITOR_PORT?Port: "
        elif (( ${#CONNECTED_PORTS} == 1 )); then
            MONITOR_PORT="${CONNECTED_PORTS[1]}"
            print -P "Selected:     %F{green}$MONITOR_PORT%f"
        else
            select opt in "${CONNECTED_PORTS[@]}"; do MONITOR_PORT="$opt"; break; done
        fi
    fi
fi
# endregion

# ------------------------------------------------------------------------------
# 4. Live Environment Preparation
# ------------------------------------------------------------------------------
# region 4. Live Preparation
print -P "\n%K{blue}%F{black} 4. LIVE PREPARATION %k%f\n"

print -P "%K{yellow}%F{black} INSTALLATION TARGET %k%f\n"
print -P "%F{yellow}Installation Target:%f"
read "DISK_SEL?Disk (e.g. nvme0n1): "
DISK="/dev/$DISK_SEL"
[[ ! -b "$DISK" ]] && { print -P "\n%F{red}Error: Invalid disk.%f\n"; exit 1; }

print -P "\n%F{red}WARNING: ALL DATA ON $DISK WILL BE ERASED!%f\n"
read "CONFIRM?Type 'yes' to confirm: "
[[ "$CONFIRM" != "yes" ]] && { print "Aborted."; exit 1; }

print -P "\n%K{yellow}%F{black} LIVE OPTIMISATION %k%f\n"
timedatectl set-ntp true

print -P "%F{cyan}ℹ Optimising pacman.conf and mirrors...%f\n"
sed -i 's/^Architecture = auto$/Architecture = auto x86_64_v4/' /etc/pacman.conf
sed -i 's/^#Color/Color/' /etc/pacman.conf
sed -i 's/^#*ParallelDownloads\s*=.*/ParallelDownloads = 20/' /etc/pacman.conf
reflector --country GB,IE,NL,DE,FR,EU --latest 20 --sort rate --save /etc/pacman.d/mirrorlist

print -P "\n%F{cyan}ℹ Adding CachyOS repositories...%f\n"
pacman-key --recv-keys F3B607488DB35A47 --keyserver keyserver.ubuntu.com
pacman-key --lsign-key F3B607488DB35A47
CACHY_URL="https://mirror.cachyos.org/repo/x86_64/cachyos"
get_latest_pkg() { curl -s "$CACHY_URL/" | grep -oP "${1}-[0-9][^>]*?pkg\.tar\.zst(?=\")" | sort -V | tail -n1; }

print -P "\n%F{cyan}ℹ Resolving latest package versions...%f\n"
PKG_KEYRING=$(get_latest_pkg "cachyos-keyring")
PKG_MIRROR=$(get_latest_pkg "cachyos-mirrorlist")
PKG_V4=$(get_latest_pkg "cachyos-v4-mirrorlist")

if [[ -z "$PKG_KEYRING" || -z "$PKG_MIRROR" || -z "$PKG_V4" ]]; then
    print -P "\n%F{red}Error: Could not resolve CachyOS packages.%f\n"
    exit 1
fi

print -P "\n%F{green}Found: $PKG_KEYRING%f\n"
pacman -U --noconfirm "${CACHY_URL}/${PKG_KEYRING}" "${CACHY_URL}/${PKG_MIRROR}" "${CACHY_URL}/${PKG_V4}"

if ! grep -q "cachyos" /etc/pacman.conf; then
    print -l "" "[cachyos-znver4]" "Include = /etc/pacman.d/cachyos-v4-mirrorlist" \
             "[cachyos-core-znver4]" "Include = /etc/pacman.d/cachyos-v4-mirrorlist" \
             "[cachyos-extra-znver4]" "Include = /etc/pacman.d/cachyos-v4-mirrorlist" \
             "[cachyos]" "Include = /etc/pacman.d/cachyos-mirrorlist" >> /etc/pacman.conf
fi
sed -i "/\[multilib\]/,/Include/"'s/^#//' /etc/pacman.conf
pacman -Sy
# endregion

# ------------------------------------------------------------------------------
# 5. Partitioning & Formatting
# ------------------------------------------------------------------------------
# region 5. Partitioning
print -P "\n%K{blue}%F{black} 5. PARTITIONING & FORMATTING %k%f\n"
sgdisk -Z "$DISK"
sgdisk -o "$DISK"
sgdisk -n 1:0:+1G -t 1:ef00 -c 1:"EFI" "$DISK"
sgdisk -n 2:0:0 -t 2:8300 -c 2:"Root" "$DISK"
sleep 2

[[ "$DISK" == *[0-9] ]] && { PART1="${DISK}p1"; PART2="${DISK}p2"; } || { PART1="${DISK}1"; PART2="${DISK}2"; }
print -P "\n%F{cyan}ℹ Partition Map: EFI=${PART1} | Root=${PART2}%f\n"

mkfs.vfat -F32 -n "EFI" "$PART1"
mkfs.btrfs -L "Arch" -f "$PART2"
mount "$PART2" /mnt
for sub in @ @home @log @pkg @.snapshots @games; do btrfs subvolume create "/mnt/$sub"; done
umount /mnt

MOUNT_OPTS="rw,noatime,compress=zstd:3,ssd,discard=async,space_cache=v2"
mount -o "$MOUNT_OPTS,subvol=@" "$PART2" /mnt
mkdir -p /mnt/{home,var/log,var/cache/pacman/pkg,.snapshots}
mount -o "$MOUNT_OPTS,subvol=@home" "$PART2" /mnt/home
mount -o "$MOUNT_OPTS,subvol=@log" "$PART2" /mnt/var/log
mount -o "$MOUNT_OPTS,subvol=@pkg" "$PART2" /mnt/var/cache/pacman/pkg
mount -o "$MOUNT_OPTS,subvol=@.snapshots" "$PART2" /mnt/.snapshots

mkdir -p /mnt/tmp_games
mount -o "$MOUNT_OPTS,subvol=@games" "$PART2" /mnt/tmp_games
chattr +C /mnt/tmp_games
chown 1000:1000 /mnt/tmp_games
umount /mnt/tmp_games
rmdir /mnt/tmp_games

mkdir -p /mnt/efi
mount "$PART1" /mnt/efi
# endregion

# ------------------------------------------------------------------------------
# 6. Base Installation
# ------------------------------------------------------------------------------
# region 6. Base Installation
print -P "\n%K{blue}%F{black} 6. BASE INSTALLATION %k%f\n"

CORE_PKGS=(
    "amd-ucode" "base" "base-devel" "bluez" "bluez-utils" "btrfs-progs"
    "cachyos-keyring" "cachyos-mirrorlist" "cachyos-settings" "cachyos-v4-mirrorlist"
    "efibootmgr" "git" "grub" "grub-btrfs" "linux-cachyos"
    "linux-cachyos-headers" "linux-firmware" "networkmanager" "networkmanager-qt"
    "openssh" "pacman-contrib" "reflector" "sudo" "timeshift" "vim"
    "wireless-regdb" "zram-generator" "zsh"
    "ark" "bluedevil" "dolphin" "kate" "kinfocenter" "konsole" "kscreen"
    "kwallet-pam" "mesa" "partitionmanager" "pipewire" "pipewire-alsa"
    "pipewire-pulse" "plasma-login-manager" "plasma-meta" "plasma-nm" "plasma-pa" "plasma-systemmonitor"
    "powerdevil" "spectacle" "vulkan-radeon" "wireplumber"
    "7zip" "bash-language-server" "chromium" "cmake" "cmake-extras" "cpupower"
    "cups" "dkms" "dnsmasq" "dosfstools" "edk2-ovmf" "ethtool" "extra-cmake-modules"
    "fastfetch" "fwupd" "gamemode" "gamescope" "gwenview" "hunspell-en_gb"
    "inkscape" "isoimagewriter" "iw" "iwd" "jq" "kio-admin" "kio-gdrive" "lib32-gamemode"
    "lib32-gnutls" "lib32-vulkan-radeon" "libva-utils" "libvirt" "lz4" "mkinitcpio-firmware"
    "npm" "nss-mdns" "obsidian" "papirus-icon-theme" "protontricks" "protonup-qt"
    "qemu-desktop" "realtime-privileges" "rocm-hip-runtime" "rocm-opencl-runtime" "steam" "tailscale" "transmission-cli" "uv" "vdpauinfo"
    "virt-manager" "vlc" "vlc-plugin-ffmpeg" "vulkan-headers" "wayland-protocols"
    "wine" "wine-mono" "winetricks" "xpadneo-dkms"
)
DESKTOP_PKGS=("jellyfin-server" "jellyfin-web" "lutris" "solaar" "yt-dlp")
LAPTOP_PKGS=("moonlight-qt" "power-profiles-daemon" "sof-firmware")

if [[ "$DEVICE_PROFILE" == "desktop" ]]; then
    CORE_PKGS+=("${DESKTOP_PKGS[@]}")
    mkdir -p /mnt/var/lib/jellyfin
    chattr +C /mnt/var/lib/jellyfin
elif [[ "$DEVICE_PROFILE" == "laptop" ]]; then
    CORE_PKGS+=("${LAPTOP_PKGS[@]}")
fi

print -P "%F{cyan}ℹ Installing packages via pacstrap...%f\n"
pacstrap -K /mnt --noconfirm "${CORE_PKGS[@]}"

genfstab -U /mnt >> /mnt/etc/fstab
ROOT_UUID=$(blkid -s UUID -o value "$PART2")
print "UUID=$ROOT_UUID  /home/$TARGET_USER/Games  btrfs  $MOUNT_OPTS,subvol=@games  0 0" >> /mnt/etc/fstab

if [[ -n "$MEDIA_UUID" ]]; then
    print "UUID=$MEDIA_UUID  /mnt/Media  btrfs  rw,nosuid,nodev,noatime,nofail,x-gvfs-hide,x-systemd.automount,compress=zstd:3,discard=async  0 0" >> /mnt/etc/fstab
fi

cp /etc/pacman.conf /mnt/etc/pacman.conf
cp /etc/pacman.d/mirrorlist /mnt/etc/pacman.d/mirrorlist
# endregion

# ------------------------------------------------------------------------------
# 7. System Configuration (Chroot)
# ------------------------------------------------------------------------------
# region 7. Chroot Configuration
print -P "\n%K{blue}%F{black} 7. SYSTEM CONFIGURATION (CHROOT) %k%f\n"

cat <<ZSH > /mnt/install_vars.zsh
TARGET_USER=${(q)TARGET_USER}
ROOT_PASS=${(q)ROOT_PASS}
USER_PASS=${(q)USER_PASS}
HOSTNAME=${(q)HOSTNAME}
GIT_NAME=${(q)GIT_NAME}
GIT_EMAIL=${(q)GIT_EMAIL}
GIT_PAT=${(q)GIT_PAT}
APPLY_KONSAVE=${(q)APPLY_KONSAVE}
DEVICE_PROFILE=${(q)DEVICE_PROFILE}
MEDIA_UUID=${(q)MEDIA_UUID}
MONITOR_PORT=${(q)MONITOR_PORT}
EDID_ENABLE=${(q)EDID_ENABLE:-}
SECRETS_LOADED=${(q)SECRETS_LOADED:-false}
ZSH

print -P "%F{cyan}ℹ Injecting payload scripts into chroot...%f\n"
cp "$PAYLOAD_DIR/setup_chroot.zsh" /mnt/setup_chroot.zsh
cp "$PAYLOAD_DIR/setup_boot.zsh" /mnt/setup_boot.zsh
chmod +x /mnt/setup_chroot.zsh

arch-chroot /mnt /setup_chroot.zsh
# endregion

# ------------------------------------------------------------------------------
# 8. Completion
# ------------------------------------------------------------------------------
# region 8. Cleanup
rm -f /mnt/setup_chroot.zsh
umount -R /mnt
print -P "\n%K{green}%F{black} PROCESS COMPLETE %k%f\n"
# endregion

print -P "\n%F{yellow}Please reboot system and remove installation media%f\n"
print -P "%F{cyan}ℹ Use 'reboot' command...%f\n"

# ANTIGRAVITY LINK: Next stage is executed inside chroot via -> Scripts/payloads/setup_chroot.zsh
