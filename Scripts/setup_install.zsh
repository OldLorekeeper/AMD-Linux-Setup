#!/bin/zsh
# ------------------------------------------------------------------------------
# AMD-Linux-Setup: Unified Installer (Zen 4)
# A monolithic, opinionated Arch Linux installer replacing archinstall.
# Target: AMD Ryzen 7000+ & Radeon 7000+ | KDE Plasma 6 | CachyOS Kernel
# ------------------------------------------------------------------------------
#
# DEVELOPMENT RULES:
#
# 1. Safety: `setopt ERR_EXIT NO_UNSET PIPE_FAIL EXTENDED_GLOB`.
# 2. Syntax: Native Zsh modifiers (e.g. ${VAR:t}).
# 3. Heredocs: Use language ID (e.g. <<ZSH, <<INI), unique IDs for nesting, and quote 'ID' to disable expansion.
# 4. Structure:
#    a) Sandwich numbered section separators (# ------) with 1 line padding before.
#    b) Purpose comment block (1 line padding) at start of every numbered section summarising code.
#    c) No inline/meta comments. Compact vertical layout (minimise blank lines)
#    d) Retain frequent context info markers (%F{cyan}) inside dense logic blocks to prevent 'frozen' UI state.
#    e) Code wrapped in '# BEGIN' and '# END' markers.
#    f) Kate modeline at EOF.
# 5. Idempotency: Re-runnable scripts. Check state before changes.
# 6. UI Hierarchy Print -P
#    a) Process marker:          Green Block (%K{green}%F{black}). Used at Start/End.
#    b) Section marker:          Blue Block  (%K{blue}%F{black}). Numbered.
#    c) Sub-section marker:      Yellow Block (%K{yellow}%F{black}).
#    d) Interaction:             Yellow description (%F{yellow}) + minimal `read` prompt.
#    e) Context/Status:          Cyan (Info ℹ), Green (Success), Red (Error/Warning).
#    f) Marker spacing:          i)  Use `\n...%k%f\n`.
#                                ii) Context (Cyan) markers MUST start and end with `\n`.
#                                iii) Omit top `\n` on consecutive markers.
#
# ------------------------------------------------------------------------------

# BEGIN
setopt ERR_EXIT NO_UNSET PIPE_FAIL EXTENDED_GLOB
SCRIPT_DIR=${0:a:h}
print -P "\n%K{green}%F{black} STARTING AMD-LINUX-SETUP (ZEN 4) %k%f\n"
# END

# ------------------------------------------------------------------------------
# 1. Pre-flight Checks & Secrets
# ------------------------------------------------------------------------------

# Purpose: Validates UEFI boot mode and internet connectivity. Attempts to download and decrypt a remote secrets file using OpenSSL; falls back to manual input if the file is missing or decryption fails.

# BEGIN
print -P "%K{blue}%F{black} 1. PRE-FLIGHT & SECRETS %k%f\n"
if [[ ! -d /sys/firmware/efi/efivars ]]; then
    print -P "%F{red}Error: System is not booted in UEFI mode.%f"
    exit 1
fi
if ! ping -c 3 archlinux.org &>/dev/null; then
    print -P "%F{red}Error: No internet connection.%f"
    exit 1
fi
SECRETS_FILE="setup_secrets.enc"
RAW_URL="https://raw.githubusercontent.com/OldLorekeeper/AMD-Linux-Setup/main/Scripts/$SECRETS_FILE"
if [[ ! -f "$SECRETS_FILE" ]]; then
    print -P "\n%F{cyan}ℹ Secrets file not found locally. Attempting remote fetch...%f\n"
    if curl -fsSL "$RAW_URL" -o "$SECRETS_FILE"; then
        print -P "%F{green}Successfully downloaded $SECRETS_FILE%f"
    else
        print -P "%F{red}Failed to download secrets. Proceeding with manual input.%f"
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
            print -P "%F{red}Secrets format invalid. Falling back to manual prompts.%f"
        fi
    else
        print -P "%F{red}Decryption failed. Continuing with manual prompts.%f"
    fi
fi
# END

# ------------------------------------------------------------------------------
# 2. User Configuration
# ------------------------------------------------------------------------------

# Purpose: Configures system identity (Hostname, User, Passwords) and Git credentials. Defaults are used if variables were not loaded via secrets.

# BEGIN
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
    print -P "%F{red}Error: Git PAT is required.%f"
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
# END

# ------------------------------------------------------------------------------
# 3. Device Profile Selection
# ------------------------------------------------------------------------------

# Purpose: Determines hardware profile (Desktop/Laptop) and collects device-specific data (Media UUID, Slskd/Soulseek credentials, EDID config).

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
EDID_ENABLE=""
MONITOR_PORT=""
if [[ "$DEVICE_PROFILE" == "desktop" ]]; then
    print -P "\n%K{yellow}%F{black} DESKTOP STORAGE & AUTOMATION %k%f\n"
    print -P "%F{cyan}ℹ Scanning block devices...%f\n"
    lsblk -o NAME,SIZE,FSTYPE,LABEL,UUID | grep -v loop || true
    print -P "%F{yellow}Enter Media Drive UUID:%f"
    read "MEDIA_UUID?UUID (Leave empty to skip): "
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
        print -P "\n%F{cyan}ℹ Generating random Slskd API key...%f\n"
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
    print -P "%F{yellow}Configure Custom Display EDID?%f"
    read "EDID_ENABLE?Enable 2560x1600 EDID? [y/N]: "
    if [[ "$EDID_ENABLE" == (#i)y* ]]; then
        print -P "\n%F{cyan}ℹ Detecting connected ports...%f\n"
        typeset -a CONNECTED_PORTS
        for status_file in /sys/class/drm/*/status(N); do
            grep -q "connected" "$status_file" && CONNECTED_PORTS+=("${${status_file:h}:t#*-}")
        done
        if (( ${#CONNECTED_PORTS} == 0 )); then
            print -P "%F{red}No monitors detected.%f"
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
# END

# ------------------------------------------------------------------------------
# 4. Live Environment Preparation
# ------------------------------------------------------------------------------

# Purpose: Selects target disk, confirms wipe, and optimizes live environment (pacman.conf, Reflector, CachyOS repos).

# BEGIN
print -P "\n%K{blue}%F{black} 4. LIVE PREPARATION %k%f\n"
print -P "%K{yellow}%F{black} INSTALLATION TARGET %k%f\n"
print -P "%F{yellow}Installation Target:%f"
read "DISK_SEL?Disk (e.g. nvme0n1): "
DISK="/dev/$DISK_SEL"
[[ ! -b "$DISK" ]] && { print -P "%F{red}Error: Invalid disk.%f"; exit 1; }
print -P "%F{red}WARNING: ALL DATA ON $DISK WILL BE ERASED!%f"
read "CONFIRM?Type 'yes' to confirm: "
[[ "$CONFIRM" != "yes" ]] && { print "Aborted."; exit 1; }
print -P "\n%K{yellow}%F{black} LIVE OPTIMISATION %k%f\n"
timedatectl set-ntp true
print -P "%F{cyan}ℹ Optimising pacman.conf and mirrors...%f\n"
sed -i 's/^Architecture = auto$/Architecture = auto x86_64_v4/' /etc/pacman.conf
sed -i 's/^#Color/Color/' /etc/pacman.conf
sed -i 's/^#*ParallelDownloads\s*=.*/ParallelDownloads = 20/' /etc/pacman.conf
reflector --country GB,IE,NL,DE,FR,EU --latest 20 --sort rate --save /etc/pacman.d/mirrorlist
print -P "%F{cyan}ℹ Adding CachyOS repositories...%f\n"
pacman-key --recv-keys F3B607488DB35A47 --keyserver keyserver.ubuntu.com
pacman-key --lsign-key F3B607488DB35A47
CACHY_URL="https://mirror.cachyos.org/repo/x86_64/cachyos"
get_latest_pkg() { curl -s "$CACHY_URL/" | grep -oP "${1}-[0-9][^>]*?pkg\.tar\.zst(?=\")" | sort -V | tail -n1; }
print -P "%F{cyan}ℹ Resolving latest package versions...%f\n"
PKG_KEYRING=$(get_latest_pkg "cachyos-keyring")
PKG_MIRROR=$(get_latest_pkg "cachyos-mirrorlist")
PKG_V4=$(get_latest_pkg "cachyos-v4-mirrorlist")
if [[ -z "$PKG_KEYRING" || -z "$PKG_MIRROR" || -z "$PKG_V4" ]]; then
    print -P "%F{red}Error: Could not resolve CachyOS packages.%f"
    exit 1
fi
print -P "%F{green}Found: $PKG_KEYRING%f"
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

# Purpose: Creates a GPT layout (EFI + Root), formats partitions (VFAT/Btrfs), creates subvolumes, and mounts to /mnt.

# BEGIN
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
# END

# ------------------------------------------------------------------------------
# 6. Base Installation
# ------------------------------------------------------------------------------

# Purpose: Installs core packages via pacstrap, generates fstab, and copies pacman configuration.

# BEGIN
print -P "\n%K{blue}%F{black} 6. BASE INSTALLATION %k%f\n"
CORE_PKGS=(
    "amd-ucode" "base" "base-devel" "bluez" "bluez-utils" "btrfs-progs"
    "cachyos-keyring" "cachyos-mirrorlist" "cachyos-settings" "cachyos-v4-mirrorlist"
    "efibootmgr" "git" "grub" "grub-btrfs" "inetutils" "linux-cachyos"
    "linux-cachyos-headers" "linux-firmware" "networkmanager" "networkmanager-qt"
    "openssh" "pacman-contrib" "reflector" "sudo" "timeshift" "vim"
    "wireless-regdb" "zram-generator" "zsh"
    "ark" "bluedevil" "dolphin" "kate" "kinfocenter" "konsole" "kscreen"
    "kwallet-pam" "mesa" "partitionmanager" "pipewire" "pipewire-alsa"
    "pipewire-pulse" "plasma-meta" "plasma-nm" "plasma-pa" "plasma-systemmonitor"
    "powerdevil" "sddm" "sddm-kcm" "spectacle" "vulkan-radeon" "wireplumber"
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
DESKTOP_PKGS=("jellyfin-server" "jellyfin-web" "kid3" "lutris" "python-dotenv" "python-pydantic" "python-requests" "python-setuptools" "python-wheel" "solaar" "yt-dlp")
LAPTOP_PKGS=("moonlight-qt" "power-profiles-daemon" "sof-firmware")
if [[ "$DEVICE_PROFILE" == "desktop" ]]; then
    CORE_PKGS+=("${DESKTOP_PKGS[@]}")
    mkdir -p /mnt/var/lib/jellyfin
    chattr +C /mnt/var/lib/jellyfin
elif [[ "$DEVICE_PROFILE" == "laptop" ]]; then
    CORE_PKGS+=("${LAPTOP_PKGS[@]}")
fi
print -P "\n%F{cyan}ℹ Installing packages via pacstrap...%f\n"
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

# Purpose: Generates and runs the internal script (`setup_internal.zsh`) within the chroot environment. Configures locale, users, network, bootloader, AUR (yay), dotfiles, and device-specific optimizations.

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
cat << 'ZSH_INTERNAL' > /mnt/setup_internal.zsh
#!/bin/zsh
setopt ERR_EXIT NO_UNSET PIPE_FAIL EXTENDED_GLOB
source /install_vars.zsh; rm /install_vars.zsh
trap 'rm -f /etc/sudoers.d/99_setup_temp' EXIT

print -P "%K{yellow}%F{black} IDENTITY & LOCALE %k%f\n"
print -P "%F{cyan}ℹ Configuring Timezone and Locale...%f\n"
ln -sf /usr/share/zoneinfo/Europe/London /etc/localtime
hwclock --systohc
print -l "en_GB.UTF-8 UTF-8" "en_US.UTF-8 UTF-8" > /etc/locale.gen
locale-gen
print "LANG=en_GB.UTF-8" > /etc/locale.conf
print "KEYMAP=uk" > /etc/vconsole.conf
print "$HOSTNAME" > /etc/hostname
print -l "127.0.1.1   $HOSTNAME.localdomain $HOSTNAME" "127.0.0.1   localhost" "::1         localhost" >> /etc/hosts

print -P "\n%K{yellow}%F{black} USERS & PERMISSIONS %k%f\n"
print -P "%F{cyan}ℹ Creating user: $TARGET_USER...%f\n"
groupadd --gid 102 polkit 2>/dev/null || true
useradd -m -G wheel,input,render,video,storage,gamemode,libvirt,realtime -s /bin/zsh "$TARGET_USER"
print "root:$ROOT_PASS" | chpasswd
print "$TARGET_USER:$USER_PASS" | chpasswd
print "%wheel ALL=(ALL:ALL) ALL" > /etc/sudoers.d/wheel
print "$TARGET_USER ALL=(ALL) NOPASSWD: ALL" > /etc/sudoers.d/99_setup_temp
chmod 440 /etc/sudoers.d/99_setup_temp
groupadd -f media; usermod -aG media "$TARGET_USER"
mkdir -p "/home/$TARGET_USER/Games"; chown "$TARGET_USER:$TARGET_USER" "/home/$TARGET_USER/Games"

print -P "\n%K{yellow}%F{black} NETWORK & SERVICES %k%f\n"
print -P "%F{cyan}ℹ Configuring NetworkManager, iwd, and Bluetooth...%f\n"
mkdir -p /etc/NetworkManager/conf.d; print -l "[device]" "wifi.backend=iwd" > /etc/NetworkManager/conf.d/wifi_backend.conf
mkdir -p /etc/iwd; print -l "[General]" "Country=GB" > /etc/iwd/main.conf
sed -i 's/^#*\(Experimental = \).*/\1true/' /etc/bluetooth/main.conf
systemctl enable NetworkManager bluetooth sshd sddm fwupd.service reflector.timer
mkdir -p /etc/xdg/reflector
print -l -- "--country GB,IE,NL,DE,FR,EU" "--latest 20" "--sort rate" "--save /etc/pacman.d/mirrorlist" > /etc/xdg/reflector/reflector.conf
print -P "\n%F{cyan}ℹ Installing Network Dispatcher Scripts...%f\n"
mkdir -p /etc/NetworkManager/dispatcher.d
print -l '#!/bin/zsh' '[[ "$2" == "up" ]] && /usr/bin/ethtool -K "$1" rx-udp-gro-forwarding on rx-gro-list off 2>/dev/null || true' > /etc/NetworkManager/dispatcher.d/99-tailscale-gro
print -l '#!/bin/bash' 'if [[ "$1" == wl* ]] && [[ "$2" == "up" ]]; then /usr/bin/iw dev "$1" set power_save off; fi' > /etc/NetworkManager/dispatcher.d/disable-wifi-powersave
chmod +x /etc/NetworkManager/dispatcher.d/{99-tailscale-gro,disable-wifi-powersave}

print -P "\n%K{yellow}%F{black} BOOTLOADER %k%f\n"
print -P "%F{cyan}ℹ Installing GRUB...%f\n"
grub-install --target=x86_64-efi --efi-directory=/efi --bootloader-id=GRUB

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

print -P "\n%K{yellow}%F{black} AUR HELPER %k%f\n"
print -P "%F{cyan}ℹ Cloning and building yay...%f\n"
chown -R "$TARGET_USER:$TARGET_USER" "/home/$TARGET_USER"
cd "/home/$TARGET_USER"
sudo -u "$TARGET_USER" git clone https://aur.archlinux.org/yay.git
cd yay; sudo -u "$TARGET_USER" makepkg -si --noconfirm; cd ..; rm -rf yay

print -P "\n%K{yellow}%F{black} EXTENDED PACKAGES %k%f\n"
TARGET_AUR=("darkly-bin" "geekbench" "google-chrome" "konsave" "kwin-effects-better-blur-dx" "papirus-folders" "plasma6-applets-panel-colorizer" "timeshift-systemd-timer")
if [[ "$DEVICE_PROFILE" == "desktop" ]]; then
    TARGET_AUR+=("lact" "lidarr-bin" "prowlarr-bin" "python-schedule" "radarr-bin" "slskd-bin" "sonarr-bin" "sunshine")
elif [[ "$DEVICE_PROFILE" == "laptop" ]]; then
    TARGET_AUR+=("mkinitcpio-numlock")
fi
print -P "%F{cyan}ℹ Installing Extended Packages via Yay...%f\n"
sudo -u "$TARGET_USER" yay -S --needed --noconfirm "${TARGET_AUR[@]}"

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
REPO_DIR="/home/$TARGET_USER/Obsidian/AMD-Linux-Setup"
print -P "\n%F{cyan}ℹ Cloning Main Repository...%f\n"
sudo -u "$TARGET_USER" git clone https://github.com/OldLorekeeper/AMD-Linux-Setup "$REPO_DIR"
SECRETS_DIR="$REPO_DIR/.secrets"
if [[ -n "$GIT_PAT" ]]; then
    print -P "\n%F{cyan}ℹ Cloning Private Secrets Repository...%f\n"
    sudo -u "$TARGET_USER" git clone "https://$GIT_NAME:$GIT_PAT@github.com/OldLorekeeper/AMD-Linux-Secrets.git" "$SECRETS_DIR" || mkdir -p "$SECRETS_DIR"
else
    mkdir -p "$SECRETS_DIR"
fi
chmod +x "$REPO_DIR/Scripts/"*.zsh
if [[ ! -d "/home/$TARGET_USER/.oh-my-zsh" ]]; then
    print -P "\n%F{cyan}ℹ Installing Oh My Zsh...%f\n"
    sudo -u "$TARGET_USER" sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
fi
ZSH_CUSTOM="/home/$TARGET_USER/.oh-my-zsh/custom"
print -P "\n%F{cyan}ℹ Installing Zsh plugins...%f\n"
sudo -u "$TARGET_USER" git clone https://github.com/zsh-users/zsh-autosuggestions "$ZSH_CUSTOM/plugins/zsh-autosuggestions" 2>/dev/null || true
sudo -u "$TARGET_USER" git clone https://github.com/zsh-users/zsh-syntax-highlighting "$ZSH_CUSTOM/plugins/zsh-syntax-highlighting" 2>/dev/null || true
ln -sf "/home/$TARGET_USER/.oh-my-zsh" /root/.oh-my-zsh
ln -sf "/home/$TARGET_USER/.zshrc" /root/.zshrc
print -P "\n%F{cyan}ℹ Linking Zsh Configuration ($DEVICE_PROFILE)...%f\n"
rm -f "/home/$TARGET_USER/.zshrc"
ln -sf "$REPO_DIR/Resources/zshrc/zshrc_$DEVICE_PROFILE" "/home/$TARGET_USER/.zshrc"
print -P "\n%F{cyan}ℹ Installing Gemini CLI...%f\n"
npm install -g @google/gemini-cli 1>/dev/null 2>&1
mkdir -p "/home/$TARGET_USER/.gemini" "$REPO_DIR/.gemini"
ln -sf "$SECRETS_DIR/settings.json" "/home/$TARGET_USER/.gemini/settings.json"
ln -sf "$SECRETS_DIR/GEMINI.md" "/home/$TARGET_USER/.gemini/GEMINI.md"
ln -sf "$SECRETS_DIR/trustedFolders.json" "/home/$TARGET_USER/.gemini/trustedFolders.json"
ln -sf "$SECRETS_DIR/.geminiignore" "$REPO_DIR/.geminiignore"
if [[ "$DEVICE_PROFILE" == "desktop" ]]; then
    ln -sf "$SECRETS_DIR/Gemini-History/Desktop" "/home/$TARGET_USER/.gemini/tmp"
elif [[ "$DEVICE_PROFILE" == "laptop" ]]; then
    ln -sf "$SECRETS_DIR/Gemini-History/Laptop" "/home/$TARGET_USER/.gemini/tmp"
fi
ln -sf "/home/$TARGET_USER/.gemini/history" "$REPO_DIR/.gemini/history_link"

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
print -P "%F{cyan}ℹ Applying KWin Rules...%f\n"
sudo -u "$TARGET_USER" "$REPO_DIR/Scripts/kwin_sync.zsh" "$DEVICE_PROFILE"
print -l "LIBVA_DRIVER_NAME=radeonsi" "VDPAU_DRIVER=radeonsi" "WINEFSYNC=1" "RADV_PERFTEST=gpl" >> /etc/environment
print 'ACTION=="add|change", KERNEL=="nvme[0-9]n[0-9]", ATTR{queue/scheduler}="kyber"' > /etc/udev/rules.d/60-iosched.rules
if [[ "$DEVICE_PROFILE" == "desktop" ]]; then
    print -P "%F{cyan}ℹ Applying Desktop Configuration...%f\n"
    print 'SUBSYSTEM=="pci", ATTR{vendor}=="0x1022", ATTR{device}=="0x43f7", ATTR{power/control}="on"' > /etc/udev/rules.d/99-xhci-fix.rules
    GRUB_CMDLINE="split_lock_detect=off loglevel=3 quiet amdgpu.ppfeaturemask=0xffffffff hugepages=512 video=3440x1440@60 amd_pstate=active"
    EDID_SRC="$REPO_DIR/Resources/Sunshine/custom_2560x1600.bin"
    if [[ -f "$EDID_SRC" ]]; then
        mkdir -p /usr/lib/firmware/edid; cp "$EDID_SRC" /usr/lib/firmware/edid/
        sed -i 's|^FILES=(|FILES=(/usr/lib/firmware/edid/custom_2560x1600.bin |' /etc/mkinitcpio.conf
        [[ -n "$MONITOR_PORT" ]] && GRUB_CMDLINE="$GRUB_CMDLINE drm.edid_firmware=${MONITOR_PORT}:edid/custom_2560x1600.bin"
    fi
    sed -i "s|^GRUB_CMDLINE_LINUX_DEFAULT=.*|GRUB_CMDLINE_LINUX_DEFAULT=\"$GRUB_CMDLINE\"|" /etc/default/grub
    sed -i 's/^GRUB_TIMEOUT=.*/GRUB_TIMEOUT=2/' /etc/default/grub
    ln -sf "$REPO_DIR/Scripts/jellyfin_fix_cover_art.zsh" "/home/$TARGET_USER/.local/bin/fix_cover_art"
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
        ln -sf "$REPO_DIR/Scripts/$script" "/usr/local/bin/${script:r}"; chmod +x "$REPO_DIR/Scripts/$script"
    done
    mkdir -p /etc/slskd
    print -l "web:" "  port: 5030" "  authentication:" "    username: $SLSKD_USER" "    password: $SLSKD_PASS" "    api_keys:" "      master:" "        key: $SLSKD_API_KEY" "        role: administrator" "soulseek:" "  username: $SOULSEEK_USER" "  password: $SOULSEEK_PASS" "directories:" "  downloads: /mnt/Media/Downloads/slskd/Complete" "  incomplete: /mnt/Media/Downloads/slskd/Incomplete" > /etc/slskd/slskd.yml
    cd /opt; git clone https://github.com/mrusse/soularr.git; chown -R "$TARGET_USER:$TARGET_USER" /opt/soularr
    sudo -u "$TARGET_USER" uv venv /opt/soularr/.venv; sudo -u "$TARGET_USER" uv pip install -r /opt/soularr/requirements.txt
    mkdir -p /opt/soularr/config
    print -l "[App]" "prefix = /soularr" "[Slskd]" "host_url = http://localhost:5030" "api_key = $SLSKD_API_KEY" "[Lidarr]" "host_url = http://localhost:8686" "api_key =" > /opt/soularr/config/config.ini
    chown -R "$TARGET_USER:$TARGET_USER" /opt/soularr/config
    print -l "[Unit]" "Wants=network-online.target lidarr.service slskd.service" "Requires=lidarr.service slskd.service" "RequiresMountsFor=/mnt/Media" "[Service]" "Type=oneshot" "User=$TARGET_USER" "Group=$(id -gn $TARGET_USER)" "UMask=0002" "WorkingDirectory=/opt/soularr" "ExecStart=/opt/soularr/.venv/bin/python /opt/soularr/soularr.py --config-dir /opt/soularr/config --no-lock-file" > /etc/systemd/system/soularr.service
    print -l "[Unit]" "Description=Run Soularr every 30 minutes" "[Timer]" "OnCalendar=*:0/30" "Persistent=true" "[Install]" "WantedBy=timers.target" > /etc/systemd/system/soularr.timer
    systemctl enable soularr.timer
    if [[ -n "$MEDIA_UUID" ]]; then
        mkdir -p /mnt/Media; mount /mnt/Media || true
        if mountpoint -q /mnt/Media; then
            mkdir -p /mnt/Media/{Films,TV,Music/{Maintained,Manual},Downloads/{lidarr,radarr,slskd,sonarr,transmission}}
            chattr +C /mnt/Media/Downloads || true
            chown -R "$TARGET_USER:media" /mnt/Media; chmod -R 775 /mnt/Media; setfacl -R -m g:media:rwX /mnt/Media; setfacl -R -m d:g:media:rwX /mnt/Media
        fi
        for svc in sonarr radarr lidarr prowlarr transmission slskd; do
            mkdir -p "/etc/systemd/system/$svc.service.d"
            print -l "[Unit]" "RequiresMountsFor=/mnt/Media" > "/etc/systemd/system/$svc.service.d/media-mount.conf"
            print -l "[Service]" "UMask=0002" > "/etc/systemd/system/$svc.service.d/permissions.conf"
            usermod -aG media "$svc" 2>/dev/null || true
        done
        mkdir -p /etc/systemd/system/slskd.service.d
        print -l "[Service]" "ExecStart=" "ExecStart=/usr/lib/slskd/slskd --config /etc/slskd/slskd.yml" > /etc/systemd/system/slskd.service.d/override.conf
    fi
    print "d /dev/shm/jellyfin 0755 jellyfin jellyfin -" > /etc/tmpfiles.d/jellyfin-transcode.conf
    usermod -aG render,video jellyfin || true
    wget -O /etc/udev/rules.d/42-solaar-uinput.rules https://raw.githubusercontent.com/pwr-Solaar/Solaar/refs/heads/master/rules.d-uinput/42-logitech-unify-permissions.rules
    systemctl enable jellyfin transmission sonarr radarr lidarr prowlarr slskd
    mkdir -p /var/lib/systemd/linger; touch "/var/lib/systemd/linger/$TARGET_USER"
    mkdir -p "/home/$TARGET_USER/.config/systemd/user/default.target.wants"
    ln -sf /usr/lib/systemd/user/sunshine.service "/home/$TARGET_USER/.config/systemd/user/default.target.wants/sunshine.service"
    BYPARR_DIR="/home/$TARGET_USER/Make/Byparr"
    print -P "\n%F{cyan}ℹ Installing Byparr...%f\n"
    sudo -u "$TARGET_USER" git clone https://github.com/ThePhaseless/Byparr "$BYPARR_DIR"
    (cd "$BYPARR_DIR" && sudo -u "$TARGET_USER" uv sync)
    print -l "[Unit]" "Description=Byparr" "After=network.target" "[Service]" "Type=simple" "WorkingDirectory=%h/Make/Byparr" "ExecStart=/usr/bin/uv run main.py" "Restart=always" "[Install]" "WantedBy=default.target" > "/home/$TARGET_USER/.config/systemd/user/byparr.service"
    chown "$TARGET_USER:$TARGET_USER" "/home/$TARGET_USER/.config/systemd/user/byparr.service"
    ln -sf "/home/$TARGET_USER/.config/systemd/user/byparr.service" "/home/$TARGET_USER/.config/systemd/user/default.target.wants/byparr.service"
elif [[ "$DEVICE_PROFILE" == "laptop" ]]; then
    print -P "\n%F{cyan}ℹ Applying Laptop Configuration...%f\n"
    print "options rtw89_pci disable_aspm_l1=y disable_aspm_l1ss=y" > /etc/modprobe.d/rtw89.conf
    GRUB_CMDLINE="loglevel=3 quiet amdgpu.ppfeaturemask=0xffffffff hugepages=512 video=2560x1600@60 amd_pstate=active"
    sed -i "s|^GRUB_CMDLINE_LINUX_DEFAULT=.*|GRUB_CMDLINE_LINUX_DEFAULT=\"$GRUB_CMDLINE\"|" /etc/default/grub
    sed -i 's/^GRUB_TIMEOUT=.*/GRUB_TIMEOUT=2/' /etc/default/grub
    sed -i 's/HOOKS=(\(.*\))/HOOKS=(\1 numlock)/' /etc/mkinitcpio.conf
    systemctl enable power-profiles-daemon
fi

print -P "\n%K{yellow}%F{black} FINAL TUNING %k%f\n"
print -P "%F{cyan}ℹ Removing Discover and Plasma Meta...%f\n"
pacman -Qi plasma-meta &>/dev/null && { pacman -R --noconfirm plasma-meta; pacman -D --asexplicit plasma-desktop; }
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
systemctl enable --now btrfs-balance.timer btrfs-scrub@-.timer timeshift-hourly.timer
mkdir -p /etc/pacman.d/hooks
print -l "[Trigger]" "Operation = Install" "Operation = Upgrade" "Type = Package" "Target = amd-ucode" "Target = btrfs-progs" "Target = mkinitcpio-firmware" "Target = linux-cachyos-headers" "[Action]" "Description = Rebuilding initramfs..." "When = PostTransaction" "Exec = /usr/bin/mkinitcpio -P" > /etc/pacman.d/hooks/98-rebuild-initramfs.hook
print -l "[Trigger]" "Operation = Install" "Operation = Upgrade" "Operation = Remove" "Type = Package" "Target = linux-cachyos" "[Action]" "Description = Updating GRUB..." "When = PostTransaction" "Exec = /usr/bin/grub-mkconfig -o /boot/grub/grub.cfg" > /etc/pacman.d/hooks/99-update-grub.hook
sed -i 's|^MODULES=.*|MODULES=(amdgpu nvme)|' /etc/mkinitcpio.conf
sed -i 's/^#COMPRESSION="zstd"/COMPRESSION="lz4"/' /etc/mkinitcpio.conf
print -P "\n%F{cyan}ℹ Regenerating initramfs and GRUB...%f\n"
mkinitcpio -P; grub-mkconfig -o /boot/grub/grub.cfg

print -P "\n%K{yellow}%F{black} FIRST BOOT SETUP %k%f\n"
print -P "%F{cyan}ℹ Scheduling First Boot Setup...%f\n"
mkdir -p "/home/$TARGET_USER/.config/autostart"
cat <<FIRSTBOOT > "/home/$TARGET_USER/.local/bin/first_boot.zsh"
#!/bin/zsh
source "/home/$TARGET_USER/.zshrc"; sleep 5
print -P "\n%K{green}%F{black} RUNNING FIRST BOOT SETUP %k%f\n"
REPO_DIR="/home/$TARGET_USER/Obsidian/AMD-Linux-Setup"
    if [[ "\$DEVICE_PROFILE" == "desktop" ]]; then
        print -P "\n%F{cyan}ℹ Connecting to Tailscale...%f\n"
        sudo tailscale up --advertise-exit-node
    TRANS_CONF="/var/lib/transmission/.config/transmission-daemon/settings.json"
    if [[ -f "\$TRANS_CONF" ]]; then
        print -P "\n%F{cyan}ℹ Enforcing Transmission Umask...%f\n"
        sudo systemctl stop transmission
        sudo jq '.umask = 2' "\$TRANS_CONF" > "\${TRANS_CONF}.tmp" && sudo mv "\${TRANS_CONF}.tmp" "\$TRANS_CONF"
        sudo chown transmission:transmission "\$TRANS_CONF"
        sudo systemctl start transmission
    fi
fi
if [[ "\$DEVICE_PROFILE" == "desktop" ]] && (( \$+commands[kscreen-doctor] )); then
    print -P "\n%K{yellow}%F{black} SUNSHINE CONFIGURATION %k%f\n"
    print -P "%F{cyan}ℹ Current Output Configuration:%f\n"
    kscreen-doctor -o; print ""
    if read -q "CONFIRM?Configure Sunshine Monitor/Mode Indexes? [y/N] "; then
        read "MON_ID?Monitor ID (e.g. DP-1): "
        read "STREAM_IDX?Target Stream Mode Index: "
        read "DEFAULT_IDX?Default Mode Index: "
        for script in sunshine_hdr.zsh sunshine_res.zsh sunshine_laptop.zsh; do
            [[ -f "\$REPO_DIR/Scripts/\$script" ]] && sed -i -e "s/^MONITOR=.*/MONITOR=\"\$MON_ID\"/" -e "s/^STREAM_MODE=.*/STREAM_MODE=\"\$STREAM_IDX\"/" -e "s/^DEFAULT_MODE=.*/DEFAULT_MODE=\"\$DEFAULT_IDX\"/" "\$REPO_DIR/Scripts/\$script"
            print -P "%F{green}Updated variables in \$script%f"
        done
     fi
fi
print -P "\n%F{green}System Setup Complete!%f"
read "k?Press Enter to cleanup..."
rm "/home/$TARGET_USER/.config/autostart/first_boot.desktop" "/home/$TARGET_USER/.local/bin/first_boot.zsh"
FIRSTBOOT
chmod +x "/home/$TARGET_USER/.local/bin/first_boot.zsh"
chown "$TARGET_USER:$TARGET_USER" "/home/$TARGET_USER/.local/bin/first_boot.zsh"
print -l "[Desktop Entry]" "Type=Application" "Exec=konsole --separate --hide-tabbar -e /home/$TARGET_USER/.local/bin/first_boot.zsh" "Hidden=false" "NoDisplay=false" "Name=First Boot Setup" "X-GNOME-Autostart-enabled=true" > "/home/$TARGET_USER/.config/autostart/first_boot.desktop"
print -P "\n%F{cyan}ℹ Finalizing permissions...%f\n"
chown -R "$TARGET_USER:$TARGET_USER" "/home/$TARGET_USER"
ZSH_INTERNAL
chmod +x /mnt/setup_internal.zsh
arch-chroot /mnt /setup_internal.zsh
# END

# ------------------------------------------------------------------------------
# 8. Completion
# ------------------------------------------------------------------------------

# Purpose: Cleans up temporary scripts and unmounts the system.

# BEGIN
rm /mnt/setup_internal.zsh
umount -R /mnt
print -P "\n%K{green}%F{black} PROCESS COMPLETE %k%f\n"
# END
print -P "%F{yellow}Please reboot system and remove installation media%f\n"
print -P "\n%F{cyan}ℹ Use 'reboot' command...%f\n"

# kate: hl Zsh; folding-markers on;
