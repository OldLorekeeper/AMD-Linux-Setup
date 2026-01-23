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

setopt ERR_EXIT NO_UNSET PIPE_FAIL EXTENDED_GLOB

print -P "\n%K{green}%F{black} STARTING AMD-LINUX-SETUP (ZEN 4) %k%f\n"

# ------------------------------------------------------------------------------
# 1. Pre-flight Checks & Secrets
# ------------------------------------------------------------------------------

# Purpose: Validate UEFI boot and internet connectivity. Retrieve and decrypt remote credentials if available, falling back to manual input if the file is missing or decryption fails.

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

# ------------------------------------------------------------------------------
# 2. User Configuration
# ------------------------------------------------------------------------------

# Purpose: Configure basic system identity variables (Hostname, User, Passwords) and Git credentials. Uses defaults if variables were not loaded via secrets.

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

# ------------------------------------------------------------------------------
# 3. Device Profile Selection
# ------------------------------------------------------------------------------

# Purpose: Determine the hardware profile (Desktop/Laptop) to govern package selection and KWin rules. Collects additional data for desktops (Media UUID, specific credentials, Monitor EDID).

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

# ------------------------------------------------------------------------------
# 4. Live Environment Preparation
# ------------------------------------------------------------------------------

# Purpose: Select installation target disk, wipe confirmation, and optimize the live environment (pacman config, reflector mirrors, CachyOS repositories/keys).

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

# ------------------------------------------------------------------------------
# 5. Partitioning & Formatting
# ------------------------------------------------------------------------------

# Purpose: Execute sgdisk to create a GPT layout (EFI + Root), format with VFAT/Btrfs, create optimized subvolumes (Timeshift/Snapper standard), and mount to /mnt.

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

# ------------------------------------------------------------------------------
# 6. Base Installation
# ------------------------------------------------------------------------------

# Purpose: Install core packages using pacstrap. Includes kernel, firmware, base-devel, network tools, and desktop environment metadata packages based on profile. Generates fstab.

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
    # COMMON FOR DESKTOP ANDD LAPTOP
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
    # Pre-create Jellyfin directory with No-CoW to prevent fragmentation
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

# ------------------------------------------------------------------------------
# 7. System Configuration (Chroot)
# ------------------------------------------------------------------------------

# Purpose: Generate and execute the internal script to run inside `arch-chroot`. This handles locale, users, bootloader, AUR (yay), dotfiles cloning, device-specific tweaks, and systemd services.

print -P "\n%K{blue}%F{black} 7. SYSTEM CONFIGURATION (CHROOT) %k%f\n"
cat <<VARS > /mnt/install_vars.zsh
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
VARS
cat << 'CHROOT_SCRIPT' > /mnt/setup_internal.zsh
#!/bin/zsh
setopt ERR_EXIT NO_UNSET PIPE_FAIL EXTENDED_GLOB
source /install_vars.zsh
rm /install_vars.zsh
trap 'rm -f /etc/sudoers.d/99_setup_temp' EXIT

# ------------------------------------------------------------------------------
# 7.1 Identity & Locale
# ------------------------------------------------------------------------------

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
cat << 'GRO' > /etc/NetworkManager/dispatcher.d/99-tailscale-gro
#!/bin/zsh
[[ "$2" == "up" ]] && /usr/bin/ethtool -K "$1" rx-udp-gro-forwarding on rx-gro-list off 2>/dev/null || true
GRO
chmod +x /etc/NetworkManager/dispatcher.d/99-tailscale-gro
cat << 'WIFI' > /etc/NetworkManager/dispatcher.d/disable-wifi-powersave
#!/bin/sh
[[ "$1" == wl* ]] && [[ "$2" == "up" ]] && /usr/bin/iw dev "$1" set power_save off
WIFI
chmod +x /etc/NetworkManager/dispatcher.d/disable-wifi-powersave

# ------------------------------------------------------------------------------
# 7.4 Bootloader
# ------------------------------------------------------------------------------

print -P "\n%K{yellow}%F{black} BOOTLOADER %k%f\n"
grub-install --target=x86_64-efi --efi-directory=/efi --bootloader-id=GRUB
sed -i 's/^GRUB_TIMEOUT=5/GRUB_TIMEOUT=2/' /etc/default/grub

# ------------------------------------------------------------------------------
# 7.5 Build Environment & Repos
# ------------------------------------------------------------------------------

print -P "\n%K{yellow}%F{black} BUILD ENV & REPOS %k%f\n"
sed -i 's/-march=x86-64 -mtune=generic/-march=native/' /etc/makepkg.conf
sed -i "s/^#*MAKEFLAGS=.*/MAKEFLAGS=\"-j\$(nproc)\"/" /etc/makepkg.conf
if [[ "$(findmnt -n -o FSTYPE /tmp)" == "tmpfs" ]]; then
    sed -i 's/^#*\(BUILDDIR=\/tmp\/makepkg\)/\1/' /etc/makepkg.conf
fi
sed -i 's/^#*COMPRESSZST=.*/COMPRESSZST=(zstd -c -z -q -T0 -3 -)/' /etc/makepkg.conf
grep -q "RUSTFLAGS" /etc/makepkg.conf || print 'RUSTFLAGS="-C target-cpu=native"' >> /etc/makepkg.conf
sed -i 's/^Architecture = auto$/Architecture = auto x86_64_v4/' /etc/pacman.conf
sed -i 's/^#Color/Color/' /etc/pacman.conf
sed -i 's/^#*ParallelDownloads\s*=.*/ParallelDownloads = 20/' /etc/pacman.conf
sed -i "/\[multilib\]/,/Include/"'s/^#//' /etc/pacman.conf
pacman-key --init
pacman-key --populate archlinux
if pacman -Q cachyos-keyring &>/dev/null; then
    pacman-key --populate cachyos
fi
if ! grep -q "cachyos" /etc/pacman.conf; then
    print -l "" "[cachyos-znver4]" "Include = /etc/pacman.d/cachyos-v4-mirrorlist" \
             "[cachyos-core-znver4]" "Include = /etc/pacman.d/cachyos-v4-mirrorlist" \
             "[cachyos-extra-znver4]" "Include = /etc/pacman.d/cachyos-v4-mirrorlist" \
             "[cachyos]" "Include = /etc/pacman.d/cachyos-mirrorlist" >> /etc/pacman.conf
fi
if ! grep -q "lizardbyte" /etc/pacman.conf; then
    print -l "" "[lizardbyte]" "SigLevel = Optional" \
             "Server = https://github.com/LizardByte/pacman-repo/releases/latest/download" >> /etc/pacman.conf
fi
pacman -Sy

# ------------------------------------------------------------------------------
# 7.6 AUR Helper (Yay)
# ------------------------------------------------------------------------------

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

print -P "\n%K{yellow}%F{black} DOTFILES & HOME %k%f\n"
mkdir -p "/home/$TARGET_USER"{Make,Obsidian} "/home/$TARGET_USER/.local/bin"
chown -R "$TARGET_USER:$TARGET_USER" "/home/$TARGET_USER"

# 1. Git Identity
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

# 2. Main Repo Clone
REPO_DIR="/home/$TARGET_USER/Obsidian/AMD-Linux-Setup"
if [[ ! -d "$REPO_DIR" ]]; then
    print -P "%F{cyan}ℹ Cloning Main Repository...%f"
    sudo -u "$TARGET_USER" git clone https://github.com/OldLorekeeper/AMD-Linux-Setup "$REPO_DIR"
    print -P "%F{green}Repository cloned.%f"
fi

# 3. Secrets Repo Clone (Nested)
SECRETS_DIR="$REPO_DIR/.secrets"
if [[ ! -d "$SECRETS_DIR" ]]; then
    print -P "%F{cyan}ℹ Cloning Private Secrets Repository...%f"
    if [[ -n "$GIT_PAT" ]]; then
        # Use PAT for authentication to clone the private repo
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

# 4. Oh My Zsh
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

# 5. Append Custom Configuration
print -P "%F{cyan}ℹ Appending Custom Zsh Configuration...%f"
print "export KWIN_PROFILE=\"$DEVICE_PROFILE\"" >> "/home/$TARGET_USER/.zshrc"

cat <<'ZSHCONF' >> "/home/$TARGET_USER/.zshrc"

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
    print -P "\n%K{green}%F{black} REPO SYNC: PULL %k%f\n"

    # Main Repo
    if [[ -d "$ARCH_REPO" ]]; then
        print -P "%K{blue}%F{black} MAIN REPO %k%f\n"
        (cd "$ARCH_REPO" && command git pull)
    else
        print -P "%F{red}Error: Main repo not found at $ARCH_REPO%f"
    fi

    # Secrets Repo
    if [[ -d "$ARCH_REPO/.secrets" ]]; then
        print -P "\n%K{blue}%F{black} SECRETS FOLDER %k%f\n"
        (cd "$ARCH_REPO/.secrets" && command git pull)
    else
        print -P "%F{red}Warning: Secrets repo not found at $ARCH_REPO/.secrets%f"
    fi

    print -P "\n%K{green}%F{black} PULL COMPLETE %k%f\n"
}

repo-commit() {
    local msg="${1:-System update}"

    print -P "\n%K{green}%F{black} REPO SYNC: COMMIT %k%f\n"

    # Secrets Repo (Commit First)
    if [[ -d "$ARCH_REPO/.secrets" ]]; then
        print -P "%K{blue}%F{black} SECRETS FOLDER %k%f\n"
        (cd "$ARCH_REPO/.secrets" && command git add . && command git commit -m "$msg")
    fi

    # Main Repo (Commit Second)
    if [[ -d "$ARCH_REPO" ]]; then
        print -P "\n%K{blue}%F{black} MAIN REPO %k%f\n"
        (cd "$ARCH_REPO" && command git add . && command git commit -m "$msg")
    fi

    print -P "\n%K{green}%F{black} COMMIT COMPLETE %k%f\n"
}

repo-push() {
    print -P "\n%K{green}%F{black} REPO SYNC: PUSH %k%f\n"

    # Secrets Repo
    if [[ -d "$ARCH_REPO/.secrets" ]]; then
        print -P "%K{blue}%F{black} SECRETS FOLDER %k%f\n"
        (cd "$ARCH_REPO/.secrets" && command git push)
    fi

    # Main Repo
    if [[ -d "$ARCH_REPO" ]]; then
        print -P "\n%K{blue}%F{black} MAIN REPO %k%f\n"
        (cd "$ARCH_REPO" && command git push)
    fi

    print -P "\n%K{green}%F{black} PUSH COMPLETE %k%f\n"
}

repo-sync() {
    # 1. Pull latest changes first to avoid conflicts
    repo-pull

    # 2. Commit new changes (passes arguments to repo-commit)
    repo-commit "$@"

    # 3. Push everything to GitHub
    repo-push
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
    local target="${1:-$KWIN_PROFILE}"

    print -P "\n%K{blue}%F{black} KWIN SYNC & UPDATE %k%f\n"

    # Context Check
    if [[ -z "$target" ]]; then
        print -P "%F{red}Error: No profile specified and KWIN_PROFILE not set.%f"
        return 1
    fi
    print -P "%F{cyan}ℹ Profile: $target%f"

    local current_dir="$PWD"
    cd "$ARCH_REPO" || return

    # Step 1: Auto-commit
    print -P "\n%K{yellow}%F{black} FRAGMENT CHECK %k%f\n"
    if git status --porcelain Resources/Kwin/common.kwinrule.fragment | grep -q '^ M'; then
        print -P "%F{yellow}Changes detected in common fragment. Committing...%f"
        git add Resources/Kwin/common.kwinrule.fragment
        git commit -m "AUTOSYNC: KWin common fragment update from ${HOST}"
        print -P "%F{green}Committed.%f"
    else
        print -P "%F{green}No changes in common fragment.%f"
    fi

    # Step 2: Git Pull
    print -P "\n%K{yellow}%F{black} UPDATING REPO %k%f\n"
    if ! git pull; then
        print -P "%F{red}Error: Git pull failed.%f"
        cd "$current_dir"
        return 1
    fi

    # Step 3: Apply Rules
    print -P "\n%K{yellow}%F{black} APPLYING RULES %k%f\n"
    ./Scripts/kwin_apply_rules.zsh "$target"

    cd "$current_dir"
}

kwin-edit() {
    local target="${1:-$KWIN_PROFILE}"
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
ZSHCONF

# 6. Gemini CLI Setup
print -P "\n%K{yellow}%F{black} GEMINI CLI CONFIGURATION %k%f\n"
print -P "%F{cyan}ℹ Installing Gemini CLI...%f"
npm install -g @google/gemini-cli 1>/dev/null 2>&1
mkdir -p "/home/$TARGET_USER/.gemini"

print -P "%F{cyan}ℹ Generating Settings in Secrets Repo...%f"
cat << JSON > "$SECRETS_DIR/settings.json"
{
  "general": {
    "previewFeatures": true
  },
  "security": {
    "auth": {
      "selectedType": "oauth-personal"
    }
  },
  "mcpServers": {
    "arch-ops": {
      "command": "uvx",
      "args": [
        "arch-ops-server"
      ]
    },
    "memory": {
      "command": "npx",
      "args": [
        "-y",
        "@modelcontextprotocol/server-memory"
      ],
      "env": {
        "MEMORY_FILE_PATH": "$SECRETS_DIR/memory.json"
      }
    },
    "fetch": {
      "command": "uvx",
      "args": [
        "mcp-server-fetch"
      ]
    },
    "gitArch": {
      "command": "uvx",
      "args": [
        "mcp-server-git",
        "--repository",
        "$REPO_DIR"
      ]
    }
  }
}
JSON
chown "$TARGET_USER:$TARGET_USER" "$SECRETS_DIR/settings.json"

print -P "%F{cyan}ℹ Creating Symlinks...%f"
# Symlink Settings (Force overwrite if default exists)
ln -sf "$SECRETS_DIR/settings.json" "/home/$TARGET_USER/.gemini/settings.json"
# Symlink Context (Only if it exists in secrets)
if [[ -f "$SECRETS_DIR/GEMINI.md" ]]; then
    ln -sf "$SECRETS_DIR/GEMINI.md" "/home/$TARGET_USER/.gemini/GEMINI.md"
fi
mkdir -p "$REPO_DIR/.gemini"
ln -sf "/home/$TARGET_USER/.gemini/history" "$REPO_DIR/.gemini/history_link"
print -P "%F{green}Gemini Configured.%f"

# 7. Final Theming
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
mkdir -p "/home/$TARGET_USER/.local/share/"{icons,kxmlgui5,plasma,color-schemes,aurorae,fonts,wallpapers}
print -P "%F{green}Theming resources applied.%f"

# ------------------------------------------------------------------------------
# 7.9 Device Specific Logic & Theming
# ------------------------------------------------------------------------------

print -P "\n%K{yellow}%F{black} DEVICE LOGIC & THEME %k%f\n"
print "Fixing permissions and applying Konsave Theme..."
# Ensure the user owns everything created so far (especially .local/share) before Konsave runs
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
    sed -i "s|^GRUB_CMDLINE_LINUX_DEFAULT=.*|GRUB_CMDLINE_LINUX_DEFAULT=\"$GRUB_CMDLINE\"|" /etc/default/grub
    ln -sf "$REPO_DIR/Scripts/jellyfin_fix_cover_art.zsh" "/home/$TARGET_USER/.local/bin/fix_cover_art"
    chmod +x "/home/$TARGET_USER/.local/bin/fix_cover_art"
    cat << 'HOOK' > /usr/local/bin/replace-sunshine-icons.sh
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
HOOK
    chmod +x /usr/local/bin/replace-sunshine-icons.sh
    /usr/local/bin/replace-sunshine-icons.sh
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
    mkdir -p /etc/lact
    cat << 'LACTYAML' > /etc/lact/config.yaml
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
LACTYAML
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

    # --------------------------------------------------------------------------------
    # Soularr Config: Robust Logic
    # --------------------------------------------------------------------------------
    mkdir -p /opt/soularr/config
    if [[ -f /opt/soularr/config.ini ]]; then
        cp /opt/soularr/config.ini /opt/soularr/config/config.ini
    elif [[ -f /opt/soularr/config.ini.example ]]; then
        cp /opt/soularr/config.ini.example /opt/soularr/config/config.ini
    else
        # Skeleton fallback
        print -l "[App]" "prefix = /soularr" "[Slskd]" "host_url = http://slskd:5030" "api_key =" "[Lidarr]" "host_url = http://lidarr:8686" "api_key =" > /opt/soularr/config/config.ini
    fi
    chown -R "$TARGET_USER:$TARGET_USER" /opt/soularr/config

    if [[ -n "$SLSKD_API_KEY" ]]; then
        print "Setting Slskd API Key and Hosts in Soularr config..."
        # Ensure file exists before sed
        [[ ! -f /opt/soularr/config/config.ini ]] && touch /opt/soularr/config/config.ini

        sed -i "/^\[Slskd\]/,/^\[/ s|^api_key.*|api_key = $SLSKD_API_KEY|" /opt/soularr/config/config.ini
        sed -i "/^\[Slskd\]/,/^\[/ s|^host_url.*|host_url = http://localhost:5030|" /opt/soularr/config/config.ini
        sed -i "/^\[Lidarr\]/,/^\[/ s|^host_url.*|host_url = http://localhost:8686|" /opt/soularr/config/config.ini
    fi
    # --------------------------------------------------------------------------------

    cat << 'UNIT' > /etc/systemd/system/soularr.service
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
UNIT
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
    chattr +C /var/lib/jellyfin || true
    wget -O /etc/udev/rules.d/42-solaar-uinput.rules https://raw.githubusercontent.com/pwr-Solaar/Solaar/refs/heads/master/rules.d-uinput/42-logitech-unify-permissions.rules
    systemctl enable jellyfin transmission sonarr radarr lidarr prowlarr slskd
    mkdir -p /var/lib/systemd/linger
    touch "/var/lib/systemd/linger/$TARGET_USER"
    mkdir -p "/home/$TARGET_USER/.config/systemd/user/default.target.wants"
    ln -sf /usr/lib/systemd/user/sunshine.service "/home/$TARGET_USER/.config/systemd/user/default.target.wants/sunshine.service"
elif [[ "$DEVICE_PROFILE" == "laptop" ]]; then
    print "Applying Laptop Configuration..."
    GRUB_CMDLINE="loglevel=3 quiet amdgpu.ppfeaturemask=0xffffffff hugepages=512 video=2560x1600@60 amd_pstate=active"
    sed -i "s|^GRUB_CMDLINE_LINUX_DEFAULT=.*|GRUB_CMDLINE_LINUX_DEFAULT=\"$GRUB_CMDLINE\"|" /etc/default/grub
    grep -q "numlock" /etc/mkinitcpio.conf || sed -i 's/HOOKS=(\(.*\))/HOOKS=(\1 numlock)/' /etc/mkinitcpio.conf
    systemctl enable power-profiles-daemon
fi

# ------------------------------------------------------------------------------
# 7.10 Final System Tuning
# ------------------------------------------------------------------------------

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
sed -i 's|^MODULES=.*|MODULES=(amdgpu nvme)|' /etc/mkinitcpio.conf
sed -i 's/^#COMPRESSION="zstd"/COMPRESSION="lz4"/' /etc/mkinitcpio.conf
mkinitcpio -P
grub-mkconfig -o /boot/grub/grub.cfg

# ------------------------------------------------------------------------------
# 7.11 First Boot Automation
# ------------------------------------------------------------------------------

print -P "\n%K{yellow}%F{black} FIRST BOOT SETUP %k%f\n"
print "Scheduling First Boot Setup..."
mkdir -p "/home/$TARGET_USER/.config/autostart"
cat <<BOOTSCRIPT > "/home/$TARGET_USER/.local/bin/first_boot.zsh"
#!/bin/zsh
source "/home/$TARGET_USER/.zshrc"
sleep 5
print "Running First Boot Setup..."
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
BOOTSCRIPT
chmod +x "/home/$TARGET_USER/.local/bin/first_boot.zsh"
chown "$TARGET_USER:$TARGET_USER" "/home/$TARGET_USER/.local/bin/first_boot.zsh"
print -l "[Desktop Entry]" "Type=Application" "Exec=konsole --separate --hide-tabbar -e /home/$TARGET_USER/.local/bin/first_boot.zsh" \
         "Hidden=false" "NoDisplay=false" "Name=First Boot Setup" "X-GNOME-Autostart-enabled=true" > "/home/$TARGET_USER/.config/autostart/first_boot.desktop"
print "Finalizing permissions..."
chown -R "$TARGET_USER:$TARGET_USER" "/home/$TARGET_USER"
CHROOT_SCRIPT
chmod +x /mnt/setup_internal.zsh
arch-chroot /mnt /setup_internal.zsh

# ------------------------------------------------------------------------------
# 8. Completion
# ------------------------------------------------------------------------------

# Purpose: Clean up temporary scripts and unmount the new system.

print -P "\n%K{blue}%F{black} 8. COMPLETION %k%f\n"
rm /mnt/setup_internal.zsh
umount -R /mnt
print -P "\n%K{green}%F{black} PROCESS COMPLETE %k%f\n"
