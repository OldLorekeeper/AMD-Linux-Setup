#!/bin/zsh
# ------------------------------------------------------------------------------
# AMD-Linux-Setup: Unified Installer (Zen 4)
# A monolithic, opinionated Arch Linux installer replacing archinstall.
# Target: AMD Ryzen 7000+ & Radeon 7000+ | KDE Plasma 6 | CachyOS Kernel
# ------------------------------------------------------------------------------
#
# DEVELOPMENT RULES (Read before editing):
# 1. Formatting: Keep layout compact. No vertical whitespace inside blocks.
# 2. Separators: Use 'Sandwich' headers (# ------) with strict spacing (1 line before).
# 3. Idempotency: Scripts must be safe to re-run. Check state before changes.
# 4. Safety: Use 'setopt ERR_EXIT NO_UNSET PIPE_FAIL'.
# 5. Context: No hardcoded secrets.
# 6. Syntax: Use Zsh native modifiers and tooling.
# 7. Documentation: Start section with 'Purpose' comment block (1 line before and after). No meta or inline comments within code.
# 8. UI & Theming:
#    - Headers: Blue (%K{blue}%F{black}) for sections, Yellow (%K{yellow}%F{black}) for sub-sections.
#    - Spacing: One empty line before and after headers. Use embedded \n to save lines.
#      * Exception: If a header follows another header immediately, omit the leading \n to avoid double gaps.
#    - Inputs: Yellow description line (%F{yellow}) followed by minimal prompt (read "VAR?Prompt: ").
#    - Context: Cyan (%F{cyan}) for info/metadata (prefixed with ℹ).
#    - Status: Green (%F{green}) for success/loaded, Red (%F{red}) for errors/warnings.
#    - Silence: Do not repeat/confirm manual user input. Only print confirmation (%F{green}) if the value was pre-loaded from secrets.
#
# ------------------------------------------------------------------------------

# BEGIN
setopt ERR_EXIT NO_UNSET PIPE_FAIL EXTENDED_GLOB

print -P "\n%K{green}%F{black} STARTING AMD-LINUX-SETUP (ZEN 4) %k%f\n"
# END

# ------------------------------------------------------------------------------
# 1. Pre-flight Checks & Secrets
# ------------------------------------------------------------------------------

# Purpose: Validate UEFI boot and internet connectivity. Retrieve and decrypt remote credentials if available, falling back to manual input if the file is missing or decryption fails.

# BEGIN
if [[ ! -d /sys/firmware/efi/efivars ]]; then
    print -P "%F{red}[!] Error: System is not booted in UEFI mode.%f"
    exit 1
fi
if ! ping -c 3 archlinux.org &>/dev/null; then
    print -P "%F{red}[!] Error: No internet connection.%f"
    exit 1
fi

print -P "\n%K{blue}%F{black} 1. CREDENTIALS SETUP %k%f\n"
SECRETS_FILE="setup_secrets.enc"
RAW_URL="https://raw.githubusercontent.com/OldLorekeeper/AMD-Linux-Setup/main/Scripts/$SECRETS_FILE"
if [[ ! -f "$SECRETS_FILE" ]]; then
    print -P "%F{cyan}ℹ Secrets file not found locally. Attempting remote fetch...%f"
    if curl -fsSL "$RAW_URL" -o "$SECRETS_FILE"; then
        print -P "%F{green}Successfully downloaded $SECRETS_FILE%f"
    else
        print -P "%F{red}Failed to download secrets (Is the repo public?). Proceeding with manual input.%f"
    fi
fi
if [[ -f "$SECRETS_FILE" ]]; then
    print -P "%F{yellow}Enter Decryption Password:%f"
    read -s "DECRYPT_PASS?Password: "; print ""
    if DECRYPTED=$(openssl enc -d -aes-256-cbc -pbkdf2 -in "$SECRETS_FILE" -k "$DECRYPT_PASS" 2>/dev/null); then
        source <(print -r "$DECRYPTED")
        if [[ "${SECRETS_LOADED:-}" == "true" ]]; then
            print -P "%F{green}Secrets loaded successfully.%f"
        else
            print -P "%F{red}Secrets format invalid or missing canary. Falling back to manual prompts.%f"
        fi
    else
        print -P "%F{red}Decryption failed. Continuing with manual prompts.%f"
    fi
fi
# END

# ------------------------------------------------------------------------------
# 2. User Configuration
# ------------------------------------------------------------------------------

# Purpose: Configure basic system identity variables (Hostname, User, Passwords) and Git credentials. Uses defaults if variables were not loaded via secrets.

# BEGIN
print -P "\n%K{blue}%F{black} 2. USER CONFIGURATION %k%f\n"
print -P "%K{yellow}%F{black} SYSTEM CONFIGURATION %k%f\n"
if [[ -z "${HOSTNAME:-}" ]]; then
    print -P "%F{yellow}Enter System Hostname (Network ID):%f"
    read "HOSTNAME?Hostname [Default: NCC-1701]: "
    HOSTNAME=${HOSTNAME:-NCC-1701}
else
    print -P "Hostname:     %F{green}$HOSTNAME%f"
fi
if [[ -z "${TARGET_USER:-}" ]]; then
    print -P "%F{yellow}Enter Primary Username:%f"
    read "TARGET_USER?Username [Default: user]: "
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
    print -P "%F{yellow}Set User (${TARGET_USER}) Password:%f"
    read -s "USER_PASS?Password: "; print ""
else
    print -P "User Pass:    %F{green}Loaded from secrets%f"
fi

print -P "\n%K{yellow}%F{black} EXTERNAL IDENTITY (GIT/GITHUB) %k%f\n"
if [[ -z "${GIT_NAME:-}" ]]; then
    print -P "%F{yellow}Enter Git Commit Name:%f"
    print -P "%F{cyan}ℹ Context: Metadata for commit logs (Username or Real Name).%f"
    read "GIT_NAME?Name (e.g. Jean-Luc Picard): "
else
    print -P "Git Name:     %F{green}$GIT_NAME%f"
fi
if [[ -z "${GIT_EMAIL:-}" ]]; then
    print -P "%F{yellow}Enter Git Email:%f"
    print -P "%F{cyan}ℹ Context: Must match GitHub account for attribution.%f"
    read "GIT_EMAIL?Email: "
else
    print -P "Git Email:    %F{green}$GIT_EMAIL%f"
fi
if [[ -n "${GIT_PAT:-}" ]]; then
    print -P "Git PAT:      %F{green}Loaded from secrets%f"
else
    print -P "%F{yellow}Enter GitHub Personal Access Token:%f"
    read -s "GIT_PAT?Token: "; print ""
fi
if [[ -z "${GIT_PAT:-}" ]]; then
    print -P "%F{red}[!] Error: Git PAT is required to clone private dotfiles.%f"
    exit 1
fi

print -P "\n%K{yellow}%F{black} DESKTOP THEMING %k%f\n"
if [[ -z "${APPLY_KONSAVE:-}" ]]; then
    print -P "%F{yellow}Apply custom Konsave profile?%f"
    print -P "%F{cyan}ℹ Context: Panels, Widgets, and Visuals.%f"
    print -P "%F{red}Warning: Overwrites default KDE configuration.%f"
    read "APPLY_KONSAVE?Apply Theme? [Y/n]: "
    [[ "$APPLY_KONSAVE" == (#i)n* ]] && APPLY_KONSAVE="false" || APPLY_KONSAVE="true"
else
    print -P "Apply Theme:  %F{green}$APPLY_KONSAVE%f"
fi
# END

# ------------------------------------------------------------------------------
# 3. Device Profile Selection
# ------------------------------------------------------------------------------

# Purpose: Determine the hardware profile (Desktop/Laptop) to govern package selection and KWin rules. Collects additional data for desktops (Media UUID, specific credentials, Monitor EDID).

# BEGIN
print -P "\n%K{blue}%F{black} 3. DEVICE PROFILE %k%f\n"
print -l "1) Desktop (Ryzen 7800X3D / RX 7900 XT)" "2) Laptop (Ryzen 7840HS / 780M)"
print -P "%F{yellow}Select Hardware Profile:%f"
read "PROFILE_SEL?Selection [1-2]: "
case $PROFILE_SEL in
    1) DEVICE_PROFILE="desktop" ;;
    2) DEVICE_PROFILE="laptop" ;;
    *) print -P "%F{red}Invalid selection.%f"; exit 1 ;;
esac

SLSKD_USER="${SLSKD_USER:-}"
SLSKD_PASS="${SLSKD_PASS:-}"
SLSKD_API_KEY="${SLSKD_API_KEY:-}"
SOULSEEK_USER="${SOULSEEK_USER:-}"
SOULSEEK_PASS="${SOULSEEK_PASS:-}"
MEDIA_UUID=""
EDID_ENABLE=""; MONITOR_PORT=""

if [[ "$DEVICE_PROFILE" == "desktop" ]]; then
    print -P "\n%K{yellow}%F{black} DESKTOP AUTOMATION & STORAGE %k%f\n"
    print "Existing Partitions (for Media Drive):"
    lsblk -o NAME,SIZE,FSTYPE,LABEL,UUID | grep -v loop || true
    print -P "%F{yellow}Enter Media Drive UUID:%f"
    read "MEDIA_UUID?UUID (Leave empty to skip): "
    print -P "\n%K{yellow}%F{black} SLSKD & SOULSEEK CREDENTIALS %k%f\n"
    if [[ -z "$SLSKD_USER" ]]; then
        print -P "%F{yellow}Enter Slskd Credentials:%f"
        read "SLSKD_USER?Username: "
    else
        print -P "Slskd User:   %F{green}Loaded from secrets%f"
    fi
    if [[ -z "$SLSKD_PASS" ]]; then
        read -s "SLSKD_PASS?Password: "; print ""
    fi
    if [[ -z "$SLSKD_API_KEY" ]]; then
        print -P "Slskd API Key: %F{cyan}ℹ Generating random key...%f"
        SLSKD_API_KEY=$(tr -dc 'A-Za-z0-9' < /dev/urandom | head -c 32)
    else
        print -P "Slskd API Key: %F{green}Loaded from secrets%f"
    fi
    if [[ -z "$SOULSEEK_USER" ]]; then
        print -P "%F{yellow}Enter Soulseek Credentials:%f"
        read "SOULSEEK_USER?Username: "
    else
        print -P "Soulseek User: %F{green}Loaded from secrets%f"
    fi
    if [[ -z "$SOULSEEK_PASS" ]]; then
        read -s "SOULSEEK_PASS?Password: "; print ""
    fi
    print -P "\n%K{yellow}%F{black} DISPLAY CONFIGURATION %k%f\n"
    print -P "%F{yellow}Configure Custom Display EDID:%f"
    read "EDID_ENABLE?Enable 2560x1600 EDID? [y/N]: "
    if [[ "$EDID_ENABLE" == (#i)y* ]]; then
        print "Detecting connected ports..."
        typeset -a CONNECTED_PORTS
        for status_file in /sys/class/drm/*/status(N); do
            if grep -q "connected" "$status_file"; then
                CONNECTED_PORTS+=("${${status_file:h}:t#*-}")
            fi
        done
        if (( ${#CONNECTED_PORTS} == 0 )); then
            print -P "%F{red}No monitors detected. Enter manually (e.g. DP-1).%f"
            print -P "%F{yellow}Enter Monitor Port:%f"
            read "MONITOR_PORT?Port: "
        elif (( ${#CONNECTED_PORTS} == 1 )); then
            MONITOR_PORT="${CONNECTED_PORTS[1]}"
            print -P "Detected and selected: %F{green}$MONITOR_PORT%f"
        else
            print "Multiple ports detected:"
            select opt in "${CONNECTED_PORTS[@]}"; do
                MONITOR_PORT="$opt"; break
            done
        fi
    fi
fi
# END

# ------------------------------------------------------------------------------
# 4. Live Environment Preparation
# ------------------------------------------------------------------------------

# Purpose: Select installation target disk, wipe confirmation, and optimize the live environment (pacman config, reflector mirrors, CachyOS repositories/keys).

# BEGIN
print -P "\n%K{blue}%F{black} 4. LIVE PREPARATION %k%f\n"
print -P "%K{yellow}%F{black} INSTALLATION TARGET %k%f\n"
print -P "%F{yellow}Installation Target:%f"
read "DISK_SEL?Disk (e.g. nvme0n1): "
DISK="/dev/$DISK_SEL"
[[ ! -b "$DISK" ]] && { print -P "%F{red}Error: Invalid disk '$DISK'.%f"; exit 1; }
print -P "%F{red}WARNING: ALL DATA ON $DISK WILL BE ERASED!%f"
print -P "%F{yellow}Confirm Disk Wipe:%f"
read "CONFIRM?Type 'yes' to confirm: "
[[ "$CONFIRM" != "yes" ]] && { print "Aborted."; exit 1; }

print -P "\n%K{yellow}%F{black} LIVE ENVIRONMENT PREP %k%f\n"
timedatectl set-ntp true
print "Optimising pacman.conf (Live Env)..."
sed -i 's/^Architecture = auto$/Architecture = auto x86_64_v4/' /etc/pacman.conf
sed -i 's/^#Color/Color/' /etc/pacman.conf
sed -i 's/^#*ParallelDownloads\s*=.*/ParallelDownloads = 20/' /etc/pacman.conf

print "Optimising mirrors..."
reflector --country GB,IE,NL,DE,FR,EU --latest 20 --sort rate --save /etc/pacman.d/mirrorlist

print "Adding CachyOS repositories..."
pacman-key --recv-keys F3B607488DB35A47 --keyserver keyserver.ubuntu.com
pacman-key --lsign-key F3B607488DB35A47
CACHY_URL="https://mirror.cachyos.org/repo/x86_64/cachyos"
get_latest_pkg() {
    curl -s "$CACHY_URL/" | grep -oP "${1}-[0-9][^>]*?pkg\.tar\.zst(?=\")" | sort -V | tail -n1
}
print "Resolving latest keyring versions..."
PKG_KEYRING=$(get_latest_pkg "cachyos-keyring")
PKG_MIRROR=$(get_latest_pkg "cachyos-mirrorlist")
PKG_V4=$(get_latest_pkg "cachyos-v4-mirrorlist")
if [[ -z "$PKG_KEYRING" || -z "$PKG_MIRROR" || -z "$PKG_V4" ]]; then
    print -P "%F{red}[!] Error: Could not resolve CachyOS package filenames via HTML scraping.%f"
    print -P "%F{yellow}Attempting fallback to known static versions or manual intervention required.%f"
    exit 1
fi
print -P "Found: %F{green}${PKG_KEYRING}%f"
pacman -U --noconfirm "${CACHY_URL}/${PKG_KEYRING}" "${CACHY_URL}/${PKG_MIRROR}" "${CACHY_URL}/${PKG_V4}"
if ! grep -q "cachyos" /etc/pacman.conf; then
    print -l "" "[cachyos-znver4]" "Include = /etc/pacman.d/cachyos-v4-mirrorlist" \
             "[cachyos-core-znver4]" "Include = /etc/pacman.d/cachyos-v4-mirrorlist" \
             "[cachyos-extra-znver4]" "Include = /etc/pacman.d/cachyos-v4-mirrorlist" \
             "[cachyos]" "Include = /etc/pacman.d/cachyos-mirrorlist" >> /etc/pacman.conf
fi
sed -i "/\[multilib\]/,/Include/"'s/^#//' /etc/pacman.conf
pacman -Sy
# END

# ------------------------------------------------------------------------------
# 5. Partitioning & Formatting
# ------------------------------------------------------------------------------

# Purpose: Execute sgdisk to create a GPT layout (EFI + Root), format with VFAT/Btrfs, create optimized subvolumes (Timeshift/Snapper standard), and mount to /mnt.

# BEGIN
print -P "\n%K{blue}%F{black} 5. PARTITIONING & FORMATTING %k%f\n"
sgdisk -Z "$DISK"
sgdisk -o "$DISK"
sgdisk -n 1:0:+1G -t 1:ef00 -c 1:"EFI" "$DISK"
sgdisk -n 2:0:0 -t 2:8300 -c 2:"Root" "$DISK"
sleep 2
if [[ "$DISK" == *[0-9] ]]; then
    PART1="${DISK}p1"; PART2="${DISK}p2"
else
    PART1="${DISK}1"; PART2="${DISK}2"
fi
print "Detected partitions: EFI=$PART1, Root=$PART2"
mkfs.vfat -F32 -n "EFI" "$PART1"
mkfs.btrfs -L "Arch" -f "$PART2"
mount "$PART2" /mnt
btrfs subvolume create /mnt/@
btrfs subvolume create /mnt/@home
btrfs subvolume create /mnt/@log
btrfs subvolume create /mnt/@pkg
btrfs subvolume create /mnt/@.snapshots
btrfs subvolume create /mnt/@games
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
# END <<< 5. PARTITIONING

# ------------------------------------------------------------------------------
# 6. Base Installation
# ------------------------------------------------------------------------------

# Purpose: Install core packages using pacstrap.
# - Includes kernel, firmware, base-devel, network tools, and desktop environment metadata packages based on profile.
# - Desktop: Pre-creates Jellyfin directory with No-CoW to prevent fragmentation
# - Generates fstab.
# - Copies pacman tweaks from live env to installed system

# BEGIN
print -P "\n%K{blue}%F{black} 6. BASE INSTALLATION %k%f\n"
CORE_PKGS=(
    # BASE / KERNEL
    "amd-ucode" "base" "base-devel" "bluez" "bluez-utils" "btrfs-progs"
    "cachyos-keyring" "cachyos-mirrorlist" "cachyos-settings" "cachyos-v4-mirrorlist"
    "efibootmgr" "git" "grub" "grub-btrfs" "inetutils" "linux-cachyos"
    "linux-cachyos-headers" "linux-firmware" "networkmanager" "networkmanager-qt"
    "openssh" "pacman-contrib" "reflector" "sudo" "timeshift" "vim"
    "wireless-regdb" "zram-generator" "zsh"
    # GUI / GRAPHICs
    "ark" "bluedevil" "dolphin" "kate" "kinfocenter" "konsole" "kscreen"
    "kwallet-pam" "mesa" "partitionmanager" "pipewire" "pipewire-alsa"
    "pipewire-pulse" "plasma-meta" "plasma-nm" "plasma-pa" "plasma-systemmonitor"
    "powerdevil" "sddm" "sddm-kcm" "spectacle" "vulkan-radeon" "wireplumber"
    # COMMON FOR DESKTOP AND LAPTOP
    "7zip" "bash-language-server" "chromium" "cmake" "cmake-extras" "cpupower"
    "cups" "dkms" "dnsmasq" "dosfstools" "edk2-ovmf" "ethtool" "extra-cmake-modules"
    "fastfetch" "fwupd" "gamemode" "gamescope" "gwenview" "hunspell-en_gb"
    "inkscape" "isoimagewriter" "iw" "iwd" "jq" "kio-admin" "kio-gdrive" "lib32-gamemode"
    "lib32-gnutls" "lib32-vulkan-radeon" "libva-utils" "libvirt" "lz4" "mkinitcpio-firmware"
    "npm" "nss-mdns" "obsidian" "papirus-icon-theme" "protontricks" "protonup-qt"
    "python-pip" "qemu-desktop" "realtime-privileges" "steam" "tailscale" "transmission-cli" "uv" "vdpauinfo"
    "virt-manager" "vlc" "vlc-plugin-ffmpeg" "vulkan-headers" "wayland-protocols"
    "wine" "wine-mono" "winetricks" "xpadneo-dkms"
)
DESKTOP_PKGS=(
    "jellyfin-server" "jellyfin-web" "kid3" "lutris" "python-dotenv" "python-pydantic"
    "python-requests" "python-setuptools" "python-wheel" "solaar" "yt-dlp"
)
LAPTOP_PKGS=(
    "moonlight-qt" "power-profiles-daemon" "sof-firmware"
)
if [[ "$DEVICE_PROFILE" == "desktop" ]]; then
    CORE_PKGS+=("${DESKTOP_PKGS[@]}")
    mkdir -p /mnt/var/lib/jellyfin
    chattr +C /mnt/var/lib/jellyfin
elif [[ "$DEVICE_PROFILE" == "laptop" ]]; then
    CORE_PKGS+=("${LAPTOP_PKGS[@]}")
fi
pacstrap -K /mnt --noconfirm "${CORE_PKGS[@]}"
genfstab -U /mnt >> /mnt/etc/fstab
ROOT_UUID=$(blkid -s UUID -o value "$PART2")
print "UUID=$ROOT_UUID  /home/$TARGET_USER/Games  btrfs  $MOUNT_OPTS,subvol=@games  0 0" >> /mnt/etc/fstab
if [[ -n "$MEDIA_UUID" ]]; then
    print "UUID=$MEDIA_UUID  /mnt/Media  btrfs  rw,nosuid,nodev,noatime,nofail,x-gvfs-hide,x-systemd.automount,compress=zstd:3,discard=async  0 0" >> /mnt/etc/fstab
fi
cp /etc/pacman.conf /mnt/etc/pacman.conf
cp /etc/pacman.d/mirrorlist /mnt/etc/pacman.d/mirrorlist
# END

# ------------------------------------------------------------------------------
# 7. System Configuration (Chroot)
# ------------------------------------------------------------------------------

# Purpose: Generate and execute the internal script to run inside `arch-chroot`. This handles locale, users, bootloader, AUR (yay), dotfiles cloning, device-specific tweaks, and systemd services.

# BEGIN
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
SLSKD_USER=${(q)SLSKD_USER}
SLSKD_PASS=${(q)SLSKD_PASS}
SLSKD_API_KEY=${(q)SLSKD_API_KEY}
SOULSEEK_USER=${(q)SOULSEEK_USER}
SOULSEEK_PASS=${(q)SOULSEEK_PASS}
MEDIA_UUID=${(q)MEDIA_UUID}
MONITOR_PORT=${(q)MONITOR_PORT}
ZSH
cat << 'ZSH' > /mnt/setup_internal.zsh
#!/bin/zsh
setopt ERR_EXIT NO_UNSET PIPE_FAIL EXTENDED_GLOB
source /install_vars.zsh
rm /install_vars.zsh
trap 'rm -f /etc/sudoers.d/99_setup_temp' EXIT

# ------------------------------------------------------------------------------
# 7.1 Identity & Locale
# ------------------------------------------------------------------------------

# Purpose: Configure timezones, locale generation, keymaps, and hostname.

print -P "%K{yellow}%F{black} IDENTITY & LOCALE %k%f\n"
ln -sf /usr/share/zoneinfo/Europe/London /etc/localtime
hwclock --systohc
print -l "en_GB.UTF-8 UTF-8" "en_US.UTF-8 UTF-8" > /etc/locale.gen
locale-gen
print "LANG=en_GB.UTF-8" > /etc/locale.conf
print "KEYMAP=uk" > /etc/vconsole.conf
print "$HOSTNAME" > /etc/hostname
print -l "127.0.1.1   $HOSTNAME.localdomain $HOSTNAME" "127.0.0.1   localhost" "::1         localhost" >> /etc/hosts

# ------------------------------------------------------------------------------
# 7.2 Users & Permissions
# ------------------------------------------------------------------------------

# Purpose: Create users, set passwords, and configure group memberships/sudoers.

print -P "\n%K{yellow}%F{black} USERS & PERMISSIONS %k%f\n"
print "Creating user $TARGET_USER..."
groupadd --gid 102 polkit 2>/dev/null || true
useradd -m -G wheel,input,render,video,storage,gamemode,libvirt,realtime -s /bin/zsh "$TARGET_USER"
print "root:$ROOT_PASS" | chpasswd
print "$TARGET_USER:$USER_PASS" | chpasswd
print "%wheel ALL=(ALL:ALL) ALL" > /etc/sudoers.d/wheel
print "$TARGET_USER ALL=(ALL) NOPASSWD: ALL" > /etc/sudoers.d/99_setup_temp
chmod 440 /etc/sudoers.d/99_setup_temp
groupadd -f media
usermod -aG media "$TARGET_USER"
mkdir -p "/home/$TARGET_USER/Games"
chown "$TARGET_USER:$TARGET_USER" "/home/$TARGET_USER/Games"

# ------------------------------------------------------------------------------
# 7.3 Network & Services
# ------------------------------------------------------------------------------

# Purpose: Configure NetworkManager, Bluetooth, Reflector, and network dispatcher scripts.

print -P "\n%K{yellow}%F{black} NETWORK & SERVICES %k%f\n"
mkdir -p /etc/NetworkManager/conf.d
print -l "[device]" "wifi.backend=iwd" > /etc/NetworkManager/conf.d/wifi_backend.conf
mkdir -p /etc/iwd
print -l "[General]" "Country=GB" > /etc/iwd/main.conf
sed -i 's/^#*\(Experimental = \).*/\1true/' /etc/bluetooth/main.conf
systemctl enable NetworkManager bluetooth sshd sddm fwupd.service
mkdir -p /etc/xdg/reflector
print -l -- "--country GB,IE,NL,DE,FR,EU" "--latest 20" "--sort rate" "--save /etc/pacman.d/mirrorlist" > /etc/xdg/reflector/reflector.conf
systemctl enable reflector.timer
mkdir -p /etc/NetworkManager/dispatcher.d
cat << 'ZSH' > /etc/NetworkManager/dispatcher.d/99-tailscale-gro
#!/bin/zsh
[[ "$2" == "up" ]] && /usr/bin/ethtool -K "$1" rx-udp-gro-forwarding on rx-gro-list off 2>/dev/null || true
ZSH
chmod +x /etc/NetworkManager/dispatcher.d/99-tailscale-gro
cat << 'BASH' > /etc/NetworkManager/dispatcher.d/disable-wifi-powersave
#!/bin/bash
if [[ "$1" == wl* ]] && [[ "$2" == "up" ]]; then
    /usr/bin/iw dev "$1" set power_save off
fi
exit 0
BASH
chmod +x /etc/NetworkManager/dispatcher.d/disable-wifi-powersave

# ------------------------------------------------------------------------------
# 7.4 Bootloader
# ------------------------------------------------------------------------------

# Purpose: Install and configure GRUB bootloader.

print -P "\n%K{yellow}%F{black} BOOTLOADER %k%f\n"
grub-install --target=x86_64-efi --efi-directory=/efi --bootloader-id=GRUB

# ------------------------------------------------------------------------------
# 7.5 Build Environment & Repos
# ------------------------------------------------------------------------------

# Purpose: Configure makepkg compilation flags and pacman repositories (CachyOS/Chaotic).

print -P "\n%K{yellow}%F{black} BUILD ENV & REPOS %k%f\n"
sed -i 's/-march=x86-64 -mtune=generic/-march=native/' /etc/makepkg.conf
sed -i "s/^#*MAKEFLAGS=.*/MAKEFLAGS=\"-j\$(nproc)\"/" /etc/makepkg.conf
if [[ "$(findmnt -n -o FSTYPE /tmp)" == "tmpfs" ]]; then
    sed -i 's/^#*\(BUILDDIR=\/tmp\/makepkg\)/\1/' /etc/makepkg.conf
fi
sed -i 's/^#*COMPRESSZST=.*/COMPRESSZST=(zstd -c -z -q -T0 -3 -)/' /etc/makepkg.conf
grep -q "RUSTFLAGS" /etc/makepkg.conf || print 'RUSTFLAGS="-C target-cpu=native"' >> /etc/makepkg.conf

# PACMAN CONFIG ALREADY COPIED FROM LIVE ENV - Just Init Keys
pacman-key --init
pacman-key --populate archlinux
if pacman -Q cachyos-keyring &>/dev/null; then
    pacman-key --populate cachyos
fi
if ! grep -q "lizardbyte" /etc/pacman.conf; then
    print -l "" "[lizardbyte]" "SigLevel = Optional" \
             "Server = https://github.com/LizardByte/pacman-repo/releases/latest/download" >> /etc/pacman.conf
fi
pacman -Sy

# ------------------------------------------------------------------------------
# 7.6 AUR Helper (Yay)
# ------------------------------------------------------------------------------

# Purpose: Clone and build the 'yay' AUR helper.

print -P "\n%K{yellow}%F{black} AUR HELPER %k%f\n"
chown -R "$TARGET_USER:$TARGET_USER" "/home/$TARGET_USER"
cd "/home/$TARGET_USER"
sudo -u "$TARGET_USER" git clone https://aur.archlinux.org/yay.git
cd yay
sudo -u "$TARGET_USER" makepkg -si --noconfirm
cd ..
rm -rf yay

# ------------------------------------------------------------------------------
# 7.7 Extended Packages (AUR Only)
# ------------------------------------------------------------------------------

# Purpose: Install extended packages via AUR based on device profile.

print -P "\n%K{yellow}%F{black} EXTENDED PACKAGES %k%f\n"
CORE_AUR=(
    "darkly-bin" "geekbench" "google-chrome" "konsave" "kwin-effects-better-blur-dx"
    "papirus-folders" "plasma6-applets-panel-colorizer" "timeshift-systemd-timer"
)
DESKTOP_AUR=(
    "lact" "lidarr-bin" "prowlarr-bin" "python-schedule" "radarr-bin"
    "slskd-bin" "sonarr-bin" "sunshine"
)
LAPTOP_AUR=(
    "mkinitcpio-numlock"
)
TARGET_AUR=("${CORE_AUR[@]}")
if [[ "$DEVICE_PROFILE" == "desktop" ]]; then
    TARGET_AUR+=("${DESKTOP_AUR[@]}")
elif [[ "$DEVICE_PROFILE" == "laptop" ]]; then
    TARGET_AUR+=("${LAPTOP_AUR[@]}")
fi
print "Installing Extended Packages via Yay..."
sudo -u "$TARGET_USER" yay -S --needed --noconfirm "${TARGET_AUR[@]}"

# ------------------------------------------------------------------------------
# 7.8 Dotfiles & Home
# ------------------------------------------------------------------------------

# Purpose: Clone dotfiles, configure Git identity, install Oh My Zsh, and set up custom shell environment.

print -P "\n%K{yellow}%F{black} DOTFILES & HOME %k%f\n"
mkdir -p "/home/$TARGET_USER"{Make,Obsidian} "/home/$TARGET_USER/.local/bin"
chown -R "$TARGET_USER:$TARGET_USER" "/home/$TARGET_USER"

if [[ -n "$GIT_NAME" ]]; then
    print -P "%F{cyan}ℹ Configuring Git Identity...%f"
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
    print -P "%F{green}Git identity configured.%f"
fi

REPO_DIR="/home/$TARGET_USER/Obsidian/AMD-Linux-Setup"
if [[ ! -d "$REPO_DIR" ]]; then
    print -P "%F{cyan}ℹ Cloning Main Repository...%f"
    sudo -u "$TARGET_USER" git clone https://github.com/OldLorekeeper/AMD-Linux-Setup "$REPO_DIR"
    print -P "%F{green}Repository cloned.%f"
fi

SECRETS_DIR="$REPO_DIR/.secrets"
if [[ ! -d "$SECRETS_DIR" ]]; then
    print -P "%F{cyan}ℹ Cloning Private Secrets Repository...%f"
    if [[ -n "$GIT_PAT" ]]; then
        if sudo -u "$TARGET_USER" git clone "https://$GIT_NAME:$GIT_PAT@github.com/OldLorekeeper/AMD-Linux-Secrets.git" "$SECRETS_DIR"; then
            print -P "%F{green}Secrets repository cloned successfully.%f"
        else
            print -P "%F{red}Failed to clone secrets repository.%f"
        fi
    else
        print -P "%F{yellow}No PAT provided. Skipping secrets clone.%f"
        mkdir -p "$SECRETS_DIR"
    fi
fi
chmod +x "$REPO_DIR/Scripts/"*.zsh

if [[ ! -d "/home/$TARGET_USER/.oh-my-zsh" ]]; then
    print -P "%F{cyan}ℹ Installing Oh My Zsh...%f"
    sudo -u "$TARGET_USER" sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
fi
ZSH_CUSTOM="/home/$TARGET_USER/.oh-my-zsh/custom"
sudo -u "$TARGET_USER" git clone https://github.com/zsh-users/zsh-autosuggestions "$ZSH_CUSTOM/plugins/zsh-autosuggestions" 2>/dev/null || true
sudo -u "$TARGET_USER" git clone https://github.com/zsh-users/zsh-syntax-highlighting "$ZSH_CUSTOM/plugins/zsh-syntax-highlighting" 2>/dev/null || true
ln -sf "/home/$TARGET_USER/.oh-my-zsh" /root/.oh-my-zsh
ln -sf "/home/$TARGET_USER/.zshrc" /root/.zshrc
sed -i 's/^plugins=(git)$/plugins=(git archlinux zsh-autosuggestions zsh-syntax-highlighting)/' "/home/$TARGET_USER/.zshrc"

print -P "%F{cyan}ℹ Appending Custom Zsh Configuration...%f"
print "export SYS_PROFILE=\"$DEVICE_PROFILE\"" >> "/home/$TARGET_USER/.zshrc"

cat <<'ZSH' >> "/home/$TARGET_USER/.zshrc"

# ------------------------------------------------------------------------------
# 1. CUSTOM CONFIGURATION
# ------------------------------------------------------------------------------

export PATH="$HOME/.local/bin:$PATH"
export NVM_DIR="$HOME/.nvm"
[ -s "/usr/share/nvm/init-nvm.sh" ] && source "/usr/share/nvm/init-nvm.sh"

# Core Aliases
alias mkinit="sudo mkinitcpio -P"
alias mkgrub="sudo grub-mkconfig -o /boot/grub/grub.cfg"

# Repo Variables
export ARCH_REPO="$HOME/Obsidian/AMD-Linux-Setup"
alias gemini-arch="cd $ARCH_REPO && gemini"

# ------------------------------------------------------------------------------
# 2. GIT AUTO-ORGANISATION
# ------------------------------------------------------------------------------

git() {
    if (( EUID == 0 )); then
        command git "$@"
        return
    fi
    if [[ "$1" == "clone" && -n "$2" && -z "$3" ]]; then
        if [[ "$PWD" == "$HOME" ]]; then
            print -P "%F{yellow}Auto-cloning to ~/Make...%f"
            # Extract basename and remove .git extension
            local repo_name="${${2:t}%.git}"
            command git clone "$2" "$HOME/Make/$repo_name"
        else
            command git clone "$2"
        fi
    else
        command git "$@"
    fi
}

# ------------------------------------------------------------------------------
# 3. ARCH REPO MANAGEMENT
# ------------------------------------------------------------------------------

repo-pull() {
    if [[ -n "$_REPO_SYNC_ACTIVE" ]]; then
        print -P "%K{blue}%F{black} PULL %k%f\n"
    else
        print -P "\n%K{green}%F{black} REPO SYNC: PULL %k%f\n"
    fi
    if [[ -d "$ARCH_REPO" ]]; then
        print -P "%F{cyan}→ Main Repo%f\n"
        (cd "$ARCH_REPO" && command git pull)
    else
        print -P "%F{red}Error: Main repo not found at $ARCH_REPO%f"
    fi
    if [[ -d "$ARCH_REPO/.secrets" ]]; then
        print -P "\n%F{cyan}→ Secrets Folder%f\n"
        (cd "$ARCH_REPO/.secrets" && command git pull)
    fi
    if [[ -z "$_REPO_SYNC_ACTIVE" ]]; then
        print -P "\n%K{green}%F{black} PULL COMPLETE %k%f\n"
    fi
}

repo-commit() {
    local msg="${1:-System update}"
    if [[ -n "$_REPO_SYNC_ACTIVE" ]]; then
        print -P "\n%K{blue}%F{black} COMMIT %k%f\n"
    else
        print -P "\n%K{green}%F{black} REPO SYNC: COMMIT %k%f\n"
    fi
    if [[ -d "$ARCH_REPO/.secrets" ]]; then
        print -P "%F{cyan}→ Secrets Folder%f\n"
        (cd "$ARCH_REPO/.secrets" && command git add . && command git commit -m "$msg")
    fi
    if [[ -d "$ARCH_REPO" ]]; then
        print -P "\n%F{cyan}→ Main Repo%f\n"
        (cd "$ARCH_REPO" && command git add . && command git commit -m "$msg")
    fi
    if [[ -z "$_REPO_SYNC_ACTIVE" ]]; then
        print -P "\n%K{green}%F{black} COMMIT COMPLETE %k%f\n"
    fi
}

repo-push() {
    if [[ -n "$_REPO_SYNC_ACTIVE" ]]; then
        print -P "\n%K{blue}%F{black} PUSH %k%f\n"
    else
        print -P "\n%K{green}%F{black} REPO SYNC: PUSH %k%f\n"
    fi
    if [[ -d "$ARCH_REPO/.secrets" ]]; then
        print -P "%F{cyan}→ Secrets Folder%f\n"
        (cd "$ARCH_REPO/.secrets" && command git push)
    fi
    if [[ -d "$ARCH_REPO" ]]; then
        print -P "\n%F{cyan}→ Main Repo%f\n"
        (cd "$ARCH_REPO" && command git push)
    fi
    if [[ -z "$_REPO_SYNC_ACTIVE" ]]; then
        print -P "\n%K{green}%F{black} PUSH COMPLETE %k%f\n"
    fi
}

repo-sync() {
    export _REPO_SYNC_ACTIVE="true"
    print -P "\n%K{green}%F{black} AMD-LINUX SYSTEM SYNC %k%f\n"
    repo-pull
    if [[ $? -ne 0 ]]; then
        print -P "\n%F{red}Sync aborted due to pull error.%f"
        unset _REPO_SYNC_ACTIVE
        return 1
    fi
    repo-commit "$@"
    repo-push
    print -P "\n%K{green}%F{black} SYNC COMPLETE %k%f\n"
    unset _REPO_SYNC_ACTIVE
}

# ------------------------------------------------------------------------------
# 4. SYSTEM MAINTENANCE
# ------------------------------------------------------------------------------

maintain() {
    local script="$ARCH_REPO/Scripts/system_maintain.zsh"
    if [[ -f "$script" ]]; then
        [[ -x "$script" ]] || chmod +x "$script"
        "$script"
    else
        print -P "%F{red}Error: Maintenance script not found at:%f"
        print -P "%F{red}$script%f"
        return 1
    fi
}

# ------------------------------------------------------------------------------
# 5. KWIN MANAGEMENT
# ------------------------------------------------------------------------------

kwin-sync() {
    local target="${1:-$SYS_PROFILE}"
    print -P "\n%K{green}%F{black} KWIN SYNC & UPDATE %k%f\n"
    if [[ -z "$target" ]]; then
        print -P "%F{red}Error: No profile specified and SYS_PROFILE not set.%f"
        return 1
    fi
    print -P "%F{cyan}ℹ Profile: $target%f"
    local current_dir="$PWD"
    cd "$ARCH_REPO" || return
    print -P "\n%K{yellow}%F{black} FRAGMENT CHECK: %k%f\n"
    if git status --porcelain Resources/Kwin/common.kwinrule.fragment | grep -q '^ M'; then
        print -P "%F{yellow}Changes detected in common fragment. Committing...%f"
        git add Resources/Kwin/common.kwinrule.fragment
        git commit -m "AUTOSYNC: KWin common fragment update from ${HOST}"
        print -P "%F{green}Committed.%f"
    else
        print -P "%F{green}No changes in common fragment.%f"
    fi
    print -P "\n%K{yellow}%F{black} UPDATING REPO %k%f\n"
    if ! git pull; then
        print -P "%F{red}Error: Git pull failed.%f"
        cd "$current_dir"
        return 1
    fi
    ./Scripts/kwin_apply_rules.zsh "$target"
    cd "$current_dir"
}

kwin-edit() {
    local target="${1:-$SYS_PROFILE}"
    local repo_dir="$ARCH_REPO/Resources/Kwin"
    local file_path=""
    print -P "\n%K{blue}%F{black} EDIT KWIN TEMPLATE %k%f\n"
    case "$target" in
        "desktop") file_path="$repo_dir/desktop.rule.template" ;;
        "laptop")  file_path="$repo_dir/laptop.rule.template" ;;
        "common")  file_path="$repo_dir/common.kwinrule.fragment" ;;
        *)         file_path="$repo_dir/common.kwinrule.fragment" ;;
    esac
    if [[ -f "$file_path" ]]; then
        print -P "%F{cyan}ℹ Opening: $file_path%f"
        kate "$file_path" &!
        print -P "%F{green}Editor launched.%f"
    else
        print -P "%F{red}Error: File not found: $file_path%f"
        return 1
    fi
}
ZSH

print -P "\n%K{yellow}%F{black} GEMINI CLI CONFIGURATION %k%f\n"
print -P "%F{cyan}ℹ Installing Gemini CLI...%f"
npm install -g @google/gemini-cli 1>/dev/null 2>&1
mkdir -p "/home/$TARGET_USER/.gemini"

print -P "%F{cyan}ℹ Creating Symlinks...%f"
ln -sf "$SECRETS_DIR/settings.json" "/home/$TARGET_USER/.gemini/settings.json"
if [[ -f "$SECRETS_DIR/GEMINI.md" ]]; then
    ln -sf "$SECRETS_DIR/GEMINI.md" "/home/$TARGET_USER/.gemini/GEMINI.md"
fi
mkdir -p "$REPO_DIR/.gemini"
ln -sf "/home/$TARGET_USER/.gemini/history" "$REPO_DIR/.gemini/history_link"
print -P "%F{green}Gemini Configured.%f"

print -P "\n%K{yellow}%F{black} FINAL THEMING %k%f\n"
mkdir -p "/home/$TARGET_USER/.local/share/konsole"
cp -f "$REPO_DIR/Resources/Konsole"/* "/home/$TARGET_USER/.local/share/konsole/" 2>/dev/null || true
TRANS_ARCHIVE="$REPO_DIR/Resources/Plasmoids/transmission-plasmoid.tar.gz"
if [[ -f "$TRANS_ARCHIVE" ]]; then
    TRANS_DIR="/home/$TARGET_USER/.local/share/plasma/plasmoids/com.oldlorekeeper.transmission"
    mkdir -p "$TRANS_DIR"
    tar -xf "$TRANS_ARCHIVE" -C "${TRANS_DIR:h}"
fi
papirus-folders -C breeze --theme Papirus-Dark || true
print -P "%F{cyan}ℹ Overwriting Kate Icons in Papirus...%f"
KATE_SRC="$REPO_DIR/Resources/Icons/Kate"
if [[ -d "$KATE_SRC" ]]; then
    find /usr/share/icons/Papirus -type f \( -name "kate.svg" -o -name "kate-symbolic.svg" -o -name "kate2.svg" -o -name "org.kde.kate.svg" \) | while read -r icon; do
        fname="${icon:t}"
        [[ -f "$KATE_SRC/$fname" ]] && cp -f "$KATE_SRC/$fname" "$icon"
    done
fi
mkdir -p "/home/$TARGET_USER/.local/share/"{icons,kxmlgui5,plasma,color-schemes,aurorae,fonts,wallpapers}
print -P "%F{green}Theming resources applied.%f"

# ------------------------------------------------------------------------------
# 7.9 Device Specific Logic & Theming
# ------------------------------------------------------------------------------

# Purpose: Apply device-specific configurations, Konsave themes, KWin rules, and hardware optimization (Sunshine/Lact/Soularr).

print -P "\n%K{yellow}%F{black} DEVICE LOGIC & THEME %k%f\n"
print "Fixing permissions and applying Konsave Theme..."
chown -R "$TARGET_USER:$TARGET_USER" "/home/$TARGET_USER"

if [[ "$APPLY_KONSAVE" == "true" ]]; then
    PROFILE_DIR="$REPO_DIR/Resources/Konsave"
    if [[ "$DEVICE_PROFILE" == "desktop" ]]; then
        LATEST_KNSV=$(ls -t "$PROFILE_DIR"/Desktop*.knsv 2>/dev/null | head -n1)
    else
        LATEST_KNSV=$(ls -t "$PROFILE_DIR"/Laptop*.knsv 2>/dev/null | head -n1)
    fi
    if [[ -f "$LATEST_KNSV" ]]; then
        print "Found latest Konsave profile: ${LATEST_KNSV:t}"
        sudo -u "$TARGET_USER" konsave -i "$LATEST_KNSV" --force
        PROFILE_NAME="${LATEST_KNSV:t:r}"
        print "Applying Profile: $PROFILE_NAME"
        sudo -u "$TARGET_USER" konsave -a "$PROFILE_NAME"
    else
        print -P "%F{red}No Konsave profile found!%f"
    fi
else
    print -P "%F{yellow}Skipping Konsave profile application as requested.%f"
fi
print "Applying KWin Rules..."
chmod +x "$REPO_DIR/Scripts/kwin_apply_rules.zsh"
sudo -u "$TARGET_USER" "$REPO_DIR/Scripts/kwin_apply_rules.zsh" "$DEVICE_PROFILE"
print "LIBVA_DRIVER_NAME=radeonsi" >> /etc/environment
print "VDPAU_DRIVER=radeonsi" >> /etc/environment
print "WINEFSYNC=1" >> /etc/environment
print "RADV_PERFTEST=gpl" >> /etc/environment
print 'ACTION=="add|change", KERNEL=="nvme[0-9]n[0-9]", ATTR{queue/scheduler}="kyber"' > /etc/udev/rules.d/60-iosched.rules
if [[ "$DEVICE_PROFILE" == "desktop" ]]; then
    print "Applying Desktop Configuration..."
    print 'SUBSYSTEM=="pci", ATTR{vendor}=="0x1022", ATTR{device}=="0x43f7", ATTR{power/control}="on"' > /etc/udev/rules.d/99-xhci-fix.rules
    GRUB_CMDLINE="split_lock_detect=off loglevel=3 quiet amdgpu.ppfeaturemask=0xffffffff hugepages=512 video=3440x1440@60 amd_pstate=active"
    EDID_SRC="$REPO_DIR/Resources/Sunshine/custom_2560x1600.bin"
    if [[ -f "$EDID_SRC" ]]; then
        mkdir -p /usr/lib/firmware/edid
        cp "$EDID_SRC" /usr/lib/firmware/edid/
        grep -q "custom_2560x1600.bin" /etc/mkinitcpio.conf || sed -i 's|^FILES=(|FILES=(/usr/lib/firmware/edid/custom_2560x1600.bin |' /etc/mkinitcpio.conf
        if [[ -n "$MONITOR_PORT" ]]; then
            GRUB_CMDLINE="$GRUB_CMDLINE drm.edid_firmware=${MONITOR_PORT}:edid/custom_2560x1600.bin"
        fi
    fi
    sed -i 's/^GRUB_TIMEOUT=.*/GRUB_TIMEOUT=2/' /etc/default/grub
    sed -i "s|^GRUB_CMDLINE_LINUX_DEFAULT=.*|GRUB_CMDLINE_LINUX_DEFAULT=\"$GRUB_CMDLINE\"|" /etc/default/grub
    ln -sf "$REPO_DIR/Scripts/jellyfin_fix_cover_art.zsh" "/home/$TARGET_USER/.local/bin/fix_cover_art"
    chmod +x "/home/$TARGET_USER/.local/bin/fix_cover_art"
    cat << 'BASH' > /usr/local/bin/replace-sunshine-icons.sh
#!/bin/bash
shopt -s nullglob
DEST="/usr/share/icons/hicolor/scalable/status"
SRC="$REPO_DIR/Resources/Icons/Sunshine"
[[ -d "$SRC" ]] && cp "$SRC"/*.svg "$DEST/"
SUNSHINE=$(command -v sunshine)
if [[ -n "$SUNSHINE" ]]; then
    REAL_PATH=$(readlink -f "$SUNSHINE")
    setcap cap_sys_admin+p "$REAL_PATH"
fi
BASH
    chmod +x /usr/local/bin/replace-sunshine-icons.sh
    /usr/local/bin/replace-sunshine-icons.sh
    mkdir -p /etc/pacman.d/hooks
    cat << 'INI' > /etc/pacman.d/hooks/sunshine-icons.hook
[Trigger]
Operation = Install
Operation = Upgrade
Type = Package
Target = sunshine
[Action]
Description = Replacing Sunshine tray icons...
When = PostTransaction
Exec = /usr/local/bin/replace-sunshine-icons.sh
INI
    mkdir -p /etc/lact
    cat << 'YAML' > /etc/lact/config.yaml
version: 5
apply_settings_timer: 5
daemon:
  log_level: info
  admin_group: wheel
gpus:
  default:
    fan_control_enabled: true
    fan_control_settings:
      mode: curve
      temperature_key: junction
      hysteresis: 3
      curve:
        40: 0.2
        55: 0.35
        70: 0.5
        85: 0.75
        95: 1.0
      spindown_delay_ms: 10000
      change_threshold: 3
    pmfw_options:
      zero_rpm: false
    power_cap: 310.0
    performance_level: manual
YAML
    systemctl enable lactd
    print "$TARGET_USER ALL=(ALL) NOPASSWD: /usr/local/bin/sunshine_gpu_boost" > /etc/sudoers.d/90-sunshine-boost
    chmod 440 /etc/sudoers.d/90-sunshine-boost
    for script in sunshine_gpu_boost.zsh sunshine_hdr.zsh sunshine_res.zsh sunshine_laptop.zsh; do
        ln -sf "$REPO_DIR/Scripts/$script" "/usr/local/bin/${script:r}"
        chmod +x "$REPO_DIR/Scripts/$script"
    done
    mkdir -p /etc/slskd
    print -l "web:" "  port: 5030" "  authentication:" "    username: $SLSKD_USER" "    password: $SLSKD_PASS" \
             "    api_keys:" "      master:" "        key: $SLSKD_API_KEY" "        role: administrator" "        cidr: 127.0.0.1/32,::1/128" \
             "soulseek:" "  username: $SOULSEEK_USER" "  password: $SOULSEEK_PASS" \
             "directories:" "  downloads: /mnt/Media/Downloads/slskd/Complete" "  incomplete: /mnt/Media/Downloads/slskd/Incomplete" > /etc/slskd/slskd.yml
    cd /opt
    git clone https://github.com/mrusse/soularr.git
    chown -R "$TARGET_USER:$TARGET_USER" /opt/soularr
    sudo -u "$TARGET_USER" uv venv /opt/soularr/.venv
    sudo -u "$TARGET_USER" uv pip install -r /opt/soularr/requirements.txt
    mkdir -p /opt/soularr/config
    if [[ -f /opt/soularr/config.ini ]]; then
        cp /opt/soularr/config.ini /opt/soularr/config/config.ini
    elif [[ -f /opt/soularr/config.ini.example ]]; then
        cp /opt/soularr/config.ini.example /opt/soularr/config/config.ini
    else
        print -l "[App]" "prefix = /soularr" "[Slskd]" "host_url = http://slskd:5030" "api_key =" "[Lidarr]" "host_url = http://lidarr:8686" "api_key =" > /opt/soularr/config/config.ini
    fi
    chown -R "$TARGET_USER:$TARGET_USER" /opt/soularr/config
    if [[ -n "$SLSKD_API_KEY" ]]; then
        print "Setting Slskd API Key and Hosts in Soularr config..."
        [[ ! -f /opt/soularr/config/config.ini ]] && touch /opt/soularr/config/config.ini
        sed -i "/^\[Slskd\]/,/^\[/ s|^api_key.*|api_key = $SLSKD_API_KEY|" /opt/soularr/config/config.ini
        sed -i "/^\[Slskd\]/,/^\[/ s|^host_url.*|host_url = http://localhost:5030|" /opt/soularr/config/config.ini
        sed -i "/^\[Lidarr\]/,/^\[/ s|^host_url.*|host_url = http://localhost:8686|" /opt/soularr/config/config.ini
    fi
    cat << INI > /etc/systemd/system/soularr.service
[Unit]
Description=Soularr
Wants=network-online.target lidarr.service slskd.service
Requires=lidarr.service slskd.service
RequiresMountsFor=/mnt/Media
[Service]
Type=oneshot
User=$TARGET_USER
Group=$(id -gn $TARGET_USER)
UMask=0002
WorkingDirectory=/opt/soularr
ExecStart=/opt/soularr/.venv/bin/python /opt/soularr/soularr.py --config-dir /opt/soularr/config --no-lock-file
INI
    print -l "[Unit]" "Description=Run Soularr every 30 minutes" "[Timer]" "OnCalendar=*:0/30" "Persistent=true" "[Install]" "WantedBy=timers.target" > /etc/systemd/system/soularr.timer
    systemctl enable soularr.timer
    if [[ -n "$MEDIA_UUID" ]]; then
        mkdir -p /mnt/Media
        mount /mnt/Media || true
        if mountpoint -q /mnt/Media; then
            mkdir -p /mnt/Media/{Films,TV,Music/{Maintained,Manual},Downloads/{lidarr,radarr,slskd,sonarr,transmission}}
            chattr +C /mnt/Media/Downloads || true
            chown -R "$TARGET_USER:media" /mnt/Media
            chmod -R 775 /mnt/Media
            setfacl -R -m g:media:rwX /mnt/Media
            setfacl -R -m d:g:media:rwX /mnt/Media
        fi
        for svc in sonarr radarr lidarr prowlarr transmission slskd jellyfin; do
            mkdir -p "/etc/systemd/system/$svc.service.d"
            print -l "[Unit]" "RequiresMountsFor=/mnt/Media" > "/etc/systemd/system/$svc.service.d/media-mount.conf"
            [[ "$svc" != "jellyfin" ]] && print -l "[Service]" "UMask=0002" > "/etc/systemd/system/$svc.service.d/permissions.conf"
        done
        mkdir -p /etc/systemd/system/slskd.service.d
        print -l "[Service]" "ExecStart=" "ExecStart=/usr/lib/slskd/slskd --config /etc/slskd/slskd.yml" > /etc/systemd/system/slskd.service.d/override.conf
    fi
    print "d /dev/shm/jellyfin 0755 jellyfin jellyfin -" > /etc/tmpfiles.d/jellyfin-transcode.conf
    for svc in sonarr radarr lidarr prowlarr transmission slskd jellyfin; do
        usermod -aG media "$svc" 2>/dev/null || true
    done
    usermod -aG render,video jellyfin || true
    wget -O /etc/udev/rules.d/42-solaar-uinput.rules https://raw.githubusercontent.com/pwr-Solaar/Solaar/refs/heads/master/rules.d-uinput/42-logitech-unify-permissions.rules
    systemctl enable jellyfin transmission sonarr radarr lidarr prowlarr slskd
    mkdir -p /var/lib/systemd/linger
    touch "/var/lib/systemd/linger/$TARGET_USER"
    mkdir -p "/home/$TARGET_USER/.config/systemd/user/default.target.wants"
    ln -sf /usr/lib/systemd/user/sunshine.service "/home/$TARGET_USER/.config/systemd/user/default.target.wants/sunshine.service"
    print "Installing Byparr..."
    BYPARR_DIR="/home/$TARGET_USER/Make/Byparr"
    sudo -u "$TARGET_USER" git clone https://github.com/ThePhaseless/Byparr "$BYPARR_DIR"
    (cd "$BYPARR_DIR" && sudo -u "$TARGET_USER" uv sync)
    cat << INI > "/home/$TARGET_USER/.config/systemd/user/byparr.service"
[Unit]
Description=Byparr (FlareSolverr Alternative)
After=network.target
[Service]
Type=simple
WorkingDirectory=%h/Make/Byparr
ExecStart=/usr/bin/uv run main.py
Restart=always
RestartSec=5
[Install]
WantedBy=default.target
INI
    chown "$TARGET_USER:$TARGET_USER" "/home/$TARGET_USER/.config/systemd/user/byparr.service"
    ln -sf "/home/$TARGET_USER/.config/systemd/user/byparr.service" "/home/$TARGET_USER/.config/systemd/user/default.target.wants/byparr.service"
elif [[ "$DEVICE_PROFILE" == "laptop" ]]; then
    print "Applying Laptop Configuration..."
    print "options rtw89_pci disable_aspm_l1=y disable_aspm_l1ss=y" > /etc/modprobe.d/rtw89.conf
    GRUB_CMDLINE="loglevel=3 quiet amdgpu.ppfeaturemask=0xffffffff hugepages=512 video=2560x1600@60 amd_pstate=active"
    sed -i "s|^GRUB_CMDLINE_LINUX_DEFAULT=.*|GRUB_CMDLINE_LINUX_DEFAULT=\"$GRUB_CMDLINE\"|" /etc/default/grub
    # Timeout set here for laptop profile consistency
    sed -i 's/^GRUB_TIMEOUT=.*/GRUB_TIMEOUT=2/' /etc/default/grub
    grep -q "numlock" /etc/mkinitcpio.conf || sed -i 's/HOOKS=(\(.*\))/HOOKS=(\1 numlock)/' /etc/mkinitcpio.conf
    systemctl enable power-profiles-daemon
fi

# ------------------------------------------------------------------------------
# 7.10 Final System Tuning
# ------------------------------------------------------------------------------

# Purpose: Perform final system tuning (sysctl, zram, hooks) and regenerate initramfs/grub.

print -P "\n%K{yellow}%F{black} FINAL TUNING %k%f\n"
print "Removing Discover and Plasma Meta..."
if pacman -Qi plasma-meta &>/dev/null; then
    pacman -R --noconfirm plasma-meta
    pacman -D --asexplicit plasma-desktop
fi
pacman -Rns --noconfirm discover || true
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
systemctl enable --now btrfs-balance.timer
systemctl enable --now btrfs-scrub@-.timer
systemctl enable timeshift-hourly.timer
mkdir -p /etc/pacman.d/hooks
cat <<INI > /etc/pacman.d/hooks/98-rebuild-initramfs.hook
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
INI
cat <<INI > /etc/pacman.d/hooks/99-update-grub.hook
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
INI
sed -i 's|^MODULES=.*|MODULES=(amdgpu nvme)|' /etc/mkinitcpio.conf
sed -i 's/^#COMPRESSION="zstd"/COMPRESSION="lz4"/' /etc/mkinitcpio.conf
mkinitcpio -P
grub-mkconfig -o /boot/grub/grub.cfg

# ------------------------------------------------------------------------------
# 7.11 First Boot Automation
# ------------------------------------------------------------------------------

# Purpose: Generate the first-boot setup script for post-install configuration.

print -P "\n%K{yellow}%F{black} FIRST BOOT SETUP %k%f\n"
print "Scheduling First Boot Setup..."
mkdir -p "/home/$TARGET_USER/.config/autostart"
cat <<ZSH > "/home/$TARGET_USER/.local/bin/first_boot.zsh"
#!/bin/zsh
source "/home/$TARGET_USER/.zshrc"
sleep 5
print -P "\n%K{green}%F{black} RUNNING FIRST BOOT SETUP %k%f\n"
REPO_DIR="/home/$TARGET_USER/Obsidian/AMD-Linux-Setup"
if [[ "$DEVICE_PROFILE" == "desktop" ]]; then
    print "Connecting to Tailscale..."
    sudo tailscale up --advertise-exit-node
    TRANS_CONF="/var/lib/transmission/.config/transmission-daemon/settings.json"
    if [[ -f "\$TRANS_CONF" ]]; then
        print "Enforcing Transmission Umask..."
        sudo systemctl stop transmission
        sudo jq '.umask = 2' "\$TRANS_CONF" > "\${TRANS_CONF}.tmp" && sudo mv "\${TRANS_CONF}.tmp" "\$TRANS_CONF"
        sudo chown transmission:transmission "\$TRANS_CONF"
        sudo systemctl start transmission
    fi
fi
if [[ "$DEVICE_PROFILE" == "desktop" ]] && (( $+commands[kscreen-doctor] )); then
    print -P "\n%K{yellow}%F{black} SUNSHINE RESOLUTION/HDR CONFIGURATION %k%f\n"
    print "Current Output Configuration:"
    kscreen-doctor -o; print ""
    if read -q "CONFIRM?Configure Sunshine Monitor and Mode Indexes now? [y/N] "; then
        print ""
        read "MON_ID?Enter Monitor ID (e.g. DP-1): "
        read "STREAM_IDX?Enter Target Stream Mode Index (e.g. 9): "
        read "DEFAULT_IDX?Enter Default Mode Index (e.g. 1): "
        SCRIPTS_DIR="\$REPO_DIR/Scripts"
        for script in sunshine_hdr.zsh sunshine_res.zsh sunshine_laptop.zsh; do
            target_file="\$SCRIPTS_DIR/\$script"
            if [[ -f "\$target_file" ]]; then
                sed -i -e "s/^MONITOR=.*/MONITOR=\"\$MON_ID\"/" \
                       -e "s/^STREAM_MODE=.*/STREAM_MODE=\"\$STREAM_IDX\"/" \
                       -e "s/^DEFAULT_MODE=.*/DEFAULT_MODE=\"\$DEFAULT_IDX\"/" \
                       "\$target_file"
                print "Updated variables in \$script"
            fi
        done
     fi
fi
print -P "\n%F{green}System Setup Complete!%f"
print "You can scroll up to review any errors."
read "k?Press Enter to cleanup and close this terminal..."
rm "/home/$TARGET_USER/.config/autostart/first_boot.desktop"
rm "/home/$TARGET_USER/.local/bin/first_boot.zsh"
ZSH
chmod +x "/home/$TARGET_USER/.local/bin/first_boot.zsh"
chown "$TARGET_USER:$TARGET_USER" "/home/$TARGET_USER/.local/bin/first_boot.zsh"
print -l "[Desktop Entry]" "Type=Application" "Exec=konsole --separate --hide-tabbar -e /home/$TARGET_USER/.local/bin/first_boot.zsh" \
         "Hidden=false" "NoDisplay=false" "Name=First Boot Setup" "X-GNOME-Autostart-enabled=true" > "/home/$TARGET_USER/.config/autostart/first_boot.desktop"
print "Finalizing permissions..."
chown -R "$TARGET_USER:$TARGET_USER" "/home/$TARGET_USER"
ZSH
chmod +x /mnt/setup_internal.zsh
arch-chroot /mnt /setup_internal.zsh
# END

# ------------------------------------------------------------------------------
# 8. Completion
# ------------------------------------------------------------------------------

# Purpose: Clean up temporary scripts and unmount the new system.

# BEGIN
print -P "\n%K{blue}%F{black} 8. COMPLETION %k%f\n"
rm /mnt/setup_internal.zsh
umount -R /mnt
print -P "\n%K{green}%F{black} PROCESS COMPLETE %k%f\n"
# END

# kate: hl Zsh; folding-markers on;
