#!/bin/zsh
# ==============================================================================
# AMD-LINUX-SETUP: UNIFIED INSTALLER (ZEN 4)
# ==============================================================================
# A monolithic, opinionated Arch Linux installer replacing archinstall.
# Target Hardware: AMD Ryzen 7000+ (Desktop/Laptop) & Radeon 7000+
# Desktop Environment: KDE Plasma 6 (Wayland)
# File System: Btrfs (Optimised Subvolumes)
# Kernel: CachyOS (x86-64-v4)
# ==============================================================================

setopt ERR_EXIT NO_UNSET PIPE_FAIL

# ------------------------------------------------------------------------------
# 1. Pre-flight Checks & Configuration
# ------------------------------------------------------------------------------

print -P "%F{green}======================================================%f"
print -P "%F{green}   AMD-Linux-Setup: Unified Installer (Zen 4)%f"
print -P "%F{green}======================================================%f"

# Purpose: Ensure environment is ready (UEFI, Internet) and gather user input.

if [[ ! -d /sys/firmware/efi/efivars ]]; then
    print -P "%F{red}[!] Error: System is not booted in UEFI mode.%f"
    exit 1
fi

if ! ping -c 1 archlinux.org &>/dev/null; then
    print -P "%F{red}[!] Error: No internet connection.%f"
    exit 1
fi

print -P "%F{yellow}--- User Configuration ---%f"
read "HOSTNAME?Hostname [Default: NCC-1701]: "
HOSTNAME=${HOSTNAME:-NCC-1701}

read "TARGET_USER?Username [Default: user]: "
TARGET_USER=${TARGET_USER:-user}

print -P "%F{yellow}Set Root Password:%f"
read -s "ROOT_PASS?Password: "
print ""
print -P "%F{yellow}Set User (${TARGET_USER}) Password:%f"
read -s "USER_PASS?Password: "
print ""

print -P "%F{yellow}--- Git Configuration (Optional) ---%f"
read "GIT_NAME?Git Name: "
read "GIT_EMAIL?Git Email: "

# Partial Token Construction
local PAT_P1="github_pat_11"
local PAT_P2="I0DBPxYklMGxAZ_BUGTt1An4QZrf77WTDEZaS7eAzBQ67y1DT6QLgTGaIEBV7JUOMWQ5IYtNl0"

if [[ -f "secrets.env" ]]; then
    source "secrets.env"
fi

if [[ -n "${GIT_PAT:-}" ]]; then
    print -P "%F{green}Git PAT detected from environment. Skipping prompt.%f"
else
    print -P "%F{yellow}Git PAT Verification:%f"
    read -s "PAT_SECRET?Enter the missing 6 characters: "
    print ""
    GIT_PAT="${PAT_P1}${PAT_SECRET}${PAT_P2}"
fi

print -P "%F{yellow}--- Device Profile ---%f"
print "1) Desktop (Ryzen 7800X3D / RX 7900 XT)"
print "2) Laptop (Ryzen 7840HS / 780M)"
read "PROFILE_SEL?Select Profile [1-2]: "

case $PROFILE_SEL in
    1) DEVICE_PROFILE="desktop" ;;
    2) DEVICE_PROFILE="laptop" ;;
    *) print -P "%F{red}Invalid selection.%f"; exit 1 ;;
esac

# Desktop Specific Inputs
SLSKD_USER=""
SLSKD_PASS=""
SOULSEEK_USER=""
SOULSEEK_PASS=""
MEDIA_UUID=""
EDID_ENABLE=""
MONITOR_PORT=""

if [[ "$DEVICE_PROFILE" == "desktop" ]]; then
    print -P "%F{yellow}--- Desktop Automation & Storage ---%f"

    print "Existing Partitions (for Media Drive):"
    lsblk -o NAME,SIZE,FSTYPE,LABEL,UUID | grep -v loop
    read "MEDIA_UUID?Enter UUID for /mnt/Media (Leave empty to skip): "

    print -P "%F{yellow}Slskd & Soulseek Credentials:%f"
    read "SLSKD_USER?Slskd WebUI Username: "
    read -s "SLSKD_PASS?Slskd WebUI Password: "; print ""
    read "SOULSEEK_USER?Soulseek Username: "
    read -s "SOULSEEK_PASS?Soulseek Password: "; print ""

    print -P "%F{yellow}Display Configuration (Headless/Streaming):%f"
    read "EDID_ENABLE?Enable custom 2560x1600 EDID? [y/N]: "

    if [[ "$EDID_ENABLE" =~ ^[Yy]$ ]]; then
        print "Detecting connected ports..."
        typeset -a CONNECTED_PORTS

        # Zsh loop for detecting ports
        for status_file in /sys/class/drm/*/status; do
            if grep -q "connected" "$status_file"; then
                # Extract port name (e.g., card0-DP-1 -> DP-1)
                local port_path=${status_file:h}
                local port_name=${port_path:t}
                local clean_name=${port_name#*-}
                CONNECTED_PORTS+=("$clean_name")
            fi
        done

        if (( ${#CONNECTED_PORTS} == 0 )); then
            print -P "%F{red}No monitors detected. Enter manually (e.g., DP-1).%f"
            read "MONITOR_PORT?Port: "
        elif (( ${#CONNECTED_PORTS} == 1 )); then
            MONITOR_PORT="${CONNECTED_PORTS[1]}"
            print -P "Detected and selected: %F{green}$MONITOR_PORT%f"
        else
            print "Multiple ports detected:"
            select opt in "${CONNECTED_PORTS[@]}"; do
                MONITOR_PORT="$opt"
                break
            done
        fi
    fi
fi

print -P "%F{yellow}--- Installation Target ---%f"
lsblk -d -n -o NAME,SIZE,MODEL,TYPE | grep disk
read "DISK_SEL?Target Disk (e.g., nvme0n1): "
DISK="/dev/$DISK_SEL"

if [[ ! -b "$DISK" ]]; then
    print -P "%F{red}Error: Invalid disk '$DISK'.%f"
    exit 1
fi

print -P "%F{red}WARNING: ALL DATA ON $DISK WILL BE ERASED!%f"
read "CONFIRM?Type 'yes' to confirm: "
if [[ "$CONFIRM" != "yes" ]]; then
    print "Aborted."
    exit 1
fi

# ------------------------------------------------------------------------------
# 2. Live Environment Prep
# ------------------------------------------------------------------------------

print -P "%F{green}--- Preparing Live Environment ---%f"
timedatectl set-ntp true

print "Optimising mirrors..."
reflector --country GB,IE,NL,DE,FR,EU --save /etc/pacman.d/mirrorlist
sed -i 's/^#ParallelDownloads/ParallelDownloads/' /etc/pacman.conf

print "Adding CachyOS repositories..."
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
sed -i "/\[multilib\]/,/Include/"'s/^#//' /etc/pacman.conf
pacman -Sy

# ------------------------------------------------------------------------------
# 3. Partitioning & Formatting
# ------------------------------------------------------------------------------

print -P "%F{green}--- Partitioning & Formatting ---%f"

# Wipe & Partition
sgdisk -Z "$DISK"
sgdisk -o "$DISK"
sgdisk -n 1:0:+1G -t 1:ef00 -c 1:"EFI" "$DISK"   # EFI
sgdisk -n 2:0:0 -t 2:8300 -c 2:"Root" "$DISK"    # Root

# Format
# Wait for kernel to register partitions
sleep 2

# Determine partition scheme (NVMe 'p1' vs SATA '1')
if [[ "$DISK" =~ [0-9]$ ]]; then
    PART1="${DISK}p1"
    PART2="${DISK}p2"
else
    PART1="${DISK}1"
    PART2="${DISK}2"
fi

print "Detected partitions: EFI=$PART1, Root=$PART2"

mkfs.vfat -F32 -n "EFI" "$PART1"
mkfs.btrfs -L "Arch" -f "$PART2"

# Btrfs Subvolumes
mount "$PART2" /mnt
btrfs subvolume create /mnt/@
btrfs subvolume create /mnt/@home
btrfs subvolume create /mnt/@log
btrfs subvolume create /mnt/@pkg
btrfs subvolume create /mnt/@.snapshots
btrfs subvolume create /mnt/@games
umount /mnt

# Mount Layout
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

# ------------------------------------------------------------------------------
# 4. Base Installation
# ------------------------------------------------------------------------------

print -P "%F{green}--- Installing Base System ---%f"

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

pacstrap -K /mnt --noconfirm "${BASE_PKGS[@]}" "${DESKTOP_ENV_PKGS[@]}" "${COMMON_PKGS[@]}"
genfstab -U /mnt >> /mnt/etc/fstab

# Inject Media Drive
if [[ -n "$MEDIA_UUID" ]]; then
    print "UUID=$MEDIA_UUID  /mnt/Media  btrfs  rw,nosuid,nodev,noatime,nofail,x-gvfs-hide,x-systemd.automount,compress=zstd:3,discard=async  0 0" >> /mnt/etc/fstab
fi

# ------------------------------------------------------------------------------
# 5. System Configuration (Chroot)
# ------------------------------------------------------------------------------

print -P "%F{green}--- Configuring System (Chroot) ---%f"

# Generate Internal Zsh Script
# We use cat with variable expansion to inject vars from this outer scope
cat <<CHROOT_SCRIPT > /mnt/setup_internal.zsh
#!/bin/zsh
setopt ERR_EXIT NO_UNSET PIPE_FAIL

# --- 5.1 Identity & Locale ---
ln -sf /usr/share/zoneinfo/Europe/London /etc/localtime
hwclock --systohc
print "en_GB.UTF-8 UTF-8" > /etc/locale.gen
locale-gen
print "LANG=en_GB.UTF-8" > /etc/locale.conf
print "KEYMAP=uk" > /etc/vconsole.conf
print "$HOSTNAME" > /etc/hostname
cat <<HOSTS >> /etc/hosts
127.0.0.1   localhost
::1         localhost
127.0.1.1   $HOSTNAME.localdomain $HOSTNAME
HOSTS

# --- 5.2 Users & Permissions ---
print "Creating user $TARGET_USER..."
# Safety fix: Ensure polkit group exists
groupadd --gid 102 polkit 2>/dev/null || true

useradd -m -G wheel,input,render,video,storage,gamemode,libvirt -s /bin/zsh $TARGET_USER
print "root:$ROOT_PASS" | chpasswd
print "$TARGET_USER:$USER_PASS" | chpasswd
print "%wheel ALL=(ALL:ALL) ALL" > /etc/sudoers.d/wheel

groupadd -f media
usermod -aG media $TARGET_USER

# --- 5.3 Network & Services ---
mkdir -p /etc/NetworkManager/conf.d
print -l "[device]" "wifi.backend=iwd" > /etc/NetworkManager/conf.d/wifi_backend.conf
sed -i 's/^#*\(Experimental = \).*/\1true/' /etc/bluetooth/main.conf
systemctl enable NetworkManager bluetooth sshd sddm fstrim.timer fwupd.service

mkdir -p /etc/xdg/reflector
cat << 'REFLECTOR' > /etc/xdg/reflector/reflector.conf
--country GB,IE,NL,DE,FR,EU
--age 6
--protocol https
--sort rate
--fastest 10
--save /etc/pacman.d/mirrorlist
REFLECTOR
systemctl enable reflector.timer

mkdir -p /etc/NetworkManager/dispatcher.d
cat << 'GRO' > /etc/NetworkManager/dispatcher.d/99-tailscale-gro
#!/bin/zsh
[[ "\$2" == "up" ]] && /usr/bin/ethtool -K "\$1" rx-udp-gro-forwarding on rx-gro-list off 2>/dev/null || true
GRO
chmod +x /etc/NetworkManager/dispatcher.d/99-tailscale-gro

cat << 'WIFI' > /etc/NetworkManager/dispatcher.d/disable-wifi-powersave
#!/bin/sh
[[ "\$1" == wl* ]] && [[ "\$2" == "up" ]] && /usr/bin/iw dev "\$1" set power_save off
WIFI
chmod +x /etc/NetworkManager/dispatcher.d/disable-wifi-powersave

# --- 5.4 Bootloader ---
grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id=GRUB
sed -i 's/^GRUB_TIMEOUT=5/GRUB_TIMEOUT=2/' /etc/default/grub

# --- 5.5 Build Environment ---
sed -i 's/^#*\(CFLAGS=".* -march=\)x86-64 -mtune=generic/\1native/' /etc/makepkg.conf
sed -i "s/^#*MAKEFLAGS=.*/MAKEFLAGS=\"-j\$(nproc)\"/" /etc/makepkg.conf
if ! grep -q "RUSTFLAGS" /etc/makepkg.conf; then
    print 'RUSTFLAGS="-C target-cpu=native"' >> /etc/makepkg.conf
fi
sed -i 's/^#ParallelDownloads/ParallelDownloads/' /etc/pacman.conf

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

print "Installing Extended Packages via Yay..."
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
print '{"mcpServers":{"arch-ops":{"command":"uvx","args":["arch-ops-server"]}}}' > /home/$TARGET_USER/.gemini/settings.json
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

# Papirus Folder Colour
papirus-folders -C breeze --theme Papirus-Dark || true

# --- 5.9 Device Specific Logic ---

# Common Env Vars
print "LIBVA_DRIVER_NAME=radeonsi" >> /etc/environment
print "VDPAU_DRIVER=radeonsi" >> /etc/environment
print "WINEFSYNC=1" >> /etc/environment

# Common Udev
print 'ACTION=="add|change", KERNEL=="nvme[0-9]n[0-9]", ATTR{queue/scheduler}="kyber"' > /etc/udev/rules.d/60-iosched.rules

if [[ "$DEVICE_PROFILE" == "desktop" ]]; then
    print "Applying Desktop Configuration..."

    # Hardware Configuration
    print 'SUBSYSTEM=="pci", ATTR{vendor}=="0x1022", ATTR{device}=="0x43f7", ATTR{power/control}="on"' > /etc/udev/rules.d/99-xhci-fix.rules

    # Boot Params
    GRUB_CMDLINE="loglevel=3 quiet amdgpu.ppfeaturemask=0xffffffff hugepages=512 video=3440x1440@60 amd_pstate=active"

    # EDID Injection
    EDID_SRC="\$REPO_DIR/Resources/Sunshine/custom_2560x1600.bin"
    if [[ -f "\$EDID_SRC" ]]; then
        mkdir -p /usr/lib/firmware/edid
        cp "\$EDID_SRC" /usr/lib/firmware/edid/
        if ! grep -q "custom_2560x1600.bin" /etc/mkinitcpio.conf; then
            sed -i 's|^FILES=(|FILES=(/usr/lib/firmware/edid/custom_2560x1600.bin |' /etc/mkinitcpio.conf
        fi

        if [[ -n "$MONITOR_PORT" ]]; then
            GRUB_CMDLINE="\$GRUB_CMDLINE drm.edid_firmware=${MONITOR_PORT}:edid/custom_2560x1600.bin"
        fi
    fi
    sed -i "s|^GRUB_CMDLINE_LINUX_DEFAULT=.*|GRUB_CMDLINE_LINUX_DEFAULT=\"\$GRUB_CMDLINE\"|" /etc/default/grub

    # Media Utilities
    ln -sf "\$REPO_DIR/Scripts/jellyfin_fix_cover_art.zsh" /home/$TARGET_USER/.local/bin/fix_cover_art
    chmod +x /home/$TARGET_USER/.local/bin/fix_cover_art

    # Sunshine Customisation
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

    print "$TARGET_USER ALL=(ALL) NOPASSWD: /usr/local/bin/sunshine_gpu_boost" > /etc/sudoers.d/90-sunshine-boost
    chmod 440 /etc/sudoers.d/90-sunshine-boost

    for script in sunshine_gpu_boost.zsh sunshine_hdr.zsh sunshine_res.zsh sunshine_laptop.zsh; do
        ln -sf "\$REPO_DIR/Scripts/\$script" "/usr/local/bin/\${script%.zsh}"
        chmod +x "\$REPO_DIR/Scripts/\$script"
    done

    # Media Stack Automation
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

    # Soularr
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

    # Media Drive & Service Overrides
    if [[ -n "$MEDIA_UUID" ]]; then
        mkdir -p /mnt/Media
        mount /mnt/Media || true

        if mountpoint -q /mnt/Media; then
            mkdir -p /mnt/Media/{Films,TV,Music/{Maintained,Manual},Downloads/{lidarr,radarr,slskd,sonarr,transmission}}
            chattr +C /mnt/Media/Downloads || true
            chown -R $TARGET_USER:media /mnt/Media
            chmod -R 775 /mnt/Media
            setfacl -R -m g:media:rwX /mnt/Media
            setfacl -R -m d:g:media:rwX /mnt/Media
        fi

        for svc in sonarr radarr lidarr prowlarr transmission slskd jellyfin; do
            mkdir -p "/etc/systemd/system/\$svc.service.d"
            print -l "[Unit]" "RequiresMountsFor=/mnt/Media" > "/etc/systemd/system/\$svc.service.d/media-mount.conf"
            if [[ "\$svc" != "jellyfin" ]]; then
                print -l "[Service]" "UMask=0002" > "/etc/systemd/system/\$svc.service.d/permissions.conf"
            fi
        done
        mkdir -p /etc/systemd/system/slskd.service.d
        print -l "[Service]" "ExecStart=" "ExecStart=/usr/lib/slskd/slskd --config /etc/slskd/slskd.yml" > /etc/systemd/system/slskd.service.d/override.conf
    fi

    # Optimisations
    print "d /dev/shm/jellyfin 0755 jellyfin jellyfin -" > /etc/tmpfiles.d/jellyfin-transcode.conf
    usermod -aG render,video jellyfin || true
    chattr +C /var/lib/jellyfin || true

    wget -O /etc/udev/rules.d/42-solaar-uinput.rules https://raw.githubusercontent.com/pwr-Solaar/Solaar/refs/heads/master/rules.d-uinput/42-logitech-unify-permissions.rules

    systemctl enable jellyfin transmission sonarr radarr lidarr prowlarr sunshine slskd

elif [[ "$DEVICE_PROFILE" == "laptop" ]]; then
    print "Applying Laptop Configuration..."

    GRUB_CMDLINE="loglevel=3 quiet amdgpu.ppfeaturemask=0xffffffff hugepages=512 video=2560x1600@60 amd_pstate=active"
    sed -i "s|^GRUB_CMDLINE_LINUX_DEFAULT=.*|GRUB_CMDLINE_LINUX_DEFAULT=\"\$GRUB_CMDLINE\"|" /etc/default/grub

    if ! grep -q "numlock" /etc/mkinitcpio.conf; then
        sed -i 's/HOOKS=(\(.*\))/HOOKS=(\1 numlock)/' /etc/mkinitcpio.conf
    fi

    systemctl enable power-profiles-daemon
fi

# --- 5.10 Final System Tuning ---

print -l "[zram0]" "zram-size = ram / 2" "compression-algorithm = lz4" "swap-priority = 100" > /etc/systemd/zram-generator.conf
print -l "vm.swappiness = 150" "vm.page-cluster = 0" > /etc/sysctl.d/99-swappiness.conf
print -l "net.core.default_qdisc = cake" "net.ipv4.tcp_congestion_control = bbr" > /etc/sysctl.d/99-bbr.conf
print -l "net.ipv4.ip_forward = 1" "net.ipv6.conf.all.forwarding = 1" > /etc/sysctl.d/99-tailscale.conf

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

# Initramfs Generation
sed -i 's|^MODULES=.*|MODULES=(amdgpu nvme)|' /etc/mkinitcpio.conf
sed -i 's/^#COMPRESSION="zstd"/COMPRESSION="lz4"/' /etc/mkinitcpio.conf
mkinitcpio -P
grub-mkconfig -o /boot/grub/grub.cfg

# --- 5.11 First Boot Automation ---
print "Scheduling First Boot Setup..."
mkdir -p /home/$TARGET_USER/.config/autostart
cat <<BOOTSCRIPT > /home/$TARGET_USER/.local/bin/first_boot.zsh
#!/bin/zsh
source /home/$TARGET_USER/.zshrc
sleep 5
print "Running First Boot Setup..."
REPO_DIR="/home/$TARGET_USER/Obsidian/AMD-Linux-Setup"

# Desktop: Tailscale Exit Node
[[ "$DEVICE_PROFILE" == "desktop" ]] && sudo tailscale up --advertise-exit-node

# Konsave (Theming)
PROFILE_DIR="\$REPO_DIR/Resources/Konsave"
if [[ "$DEVICE_PROFILE" == "desktop" ]]; then
    konsave -i "\$PROFILE_DIR"/Desktop*.knsv
    konsave -a \$(konsave -l | grep Desktop | head -n1 | awk '{print \$1}')
else
    konsave -i "\$PROFILE_DIR"/Laptop*.knsv
    konsave -a \$(konsave -l | grep Laptop | head -n1 | awk '{print \$1}')
fi

# KWin Rules
"\$REPO_DIR/Scripts/kwin_apply_rules.zsh" $DEVICE_PROFILE

# Sunshine Config Wizard (Desktop Only)
if [[ "$DEVICE_PROFILE" == "desktop" ]] && (( \$+commands[kscreen-doctor] )); then
    print -P "\n%F{yellow}--- Sunshine Resolution/HDR Configuration ---%f"
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
                sed -i "s/^MONITOR=.*/MONITOR=\"\$MON_ID\"/" "\$target_file"
                sed -i "s/^STREAM_MODE=.*/STREAM_MODE=\"\$STREAM_IDX\"/" "\$target_file"
                sed -i "s/^DEFAULT_MODE=.*/DEFAULT_MODE=\"\$DEFAULT_IDX\"/" "\$target_file"
                print "Updated variables in \$script"
            fi
        done
    fi
fi

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
Exec=konsole --separate --hide-tabbar -e /home/$TARGET_USER/.local/bin/first_boot.zsh
Hidden=false
NoDisplay=false
Name=First Boot Setup
X-GNOME-Autostart-enabled=true
AUTOSTART
chown $TARGET_USER:$TARGET_USER /home/$TARGET_USER/.config/autostart/first_boot.desktop

CHROOT_SCRIPT

# Execute Chroot Script
chmod +x /mnt/setup_internal.zsh
arch-chroot /mnt /setup_internal.zsh

# ------------------------------------------------------------------------------
# 6. Completion
# ------------------------------------------------------------------------------

print -P "%F{green}--- Installation Complete ---%f"
rm /mnt/setup_internal.zsh
umount -R /mnt

print -P "%F{yellow}System ready. Please remove installation media and reboot.%f"
