#!/bin/bash
#
# This script configures the Desktop, installing packages from
# desktop_pkg.txt and setting up services.
# Run this *after* core_setup.sh
#
# MANUAL configuration for API keys and hardware-specific
# settings will be required after this script completes.

set -e

# Colour Codes
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}--- Starting Automated Desktop Setup ---${NC}"

# Define paths for consistency
SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )

# ------------------------------------------------------------------------------
# ------------------------------------------------------------------------------

# 1. Pre-install: Sunshine Hook and Repo
echo -e "${GREEN}--- Creating script and hook to replace Sunshine icons and restore permissions... ---${NC}"
# Create replacement script using local repo path
# UPDATE: Added setcap command to restore permissions on update
sudo tee /usr/local/bin/replace-sunshine-icons.sh > /dev/null << EOF
#!/bin/bash
DEST_DIR="/usr/share/icons/hicolor/scalable/status"
REPO_ROOT="\$(dirname "$SCRIPT_DIR")"
SOURCE_DIR="\$REPO_ROOT/5-Resources/Icons/Sunshine-Tray-Icons"
SUNSHINE_BIN="/usr/bin/sunshine"

# 1. Restore Icons
if [[ -d "\$SOURCE_DIR" ]]; then
    cp "\$SOURCE_DIR"/*.svg "\$DEST_DIR/"
    echo "Sunshine icons updated from local repo."
else
    echo "Warning: Icon source directory not found at \$SOURCE_DIR"
fi

# 2. Restore Capabilities (Required for KMS/Screen Capture)
if [[ -f "\$SUNSHINE_BIN" ]]; then
    setcap cap_sys_admin+p "\$SUNSHINE_BIN"
    echo "Sunshine cap_sys_admin capability restored."
else
    echo "Warning: Sunshine binary not found at \$SUNSHINE_BIN"
fi
EOF
sudo chmod +x /usr/local/bin/replace-sunshine-icons.sh
# Create pacman hook
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
echo -e "${GREEN}--- Adding [lizardbyte] repo for Sunshine... ---${NC}"
if grep -q "\[cachyos-znver4\]" /etc/pacman.conf; then
        echo "Injecting [lizardbyte] above CachyOS repositories..."
        sudo sed -i '/\[cachyos-znver4\]/i \
[lizardbyte]\
SigLevel = Optional\
Server = https://github.com/LizardByte/pacman-repo/releases/latest/download' /etc/pacman.conf
    else
        echo "Injecting [lizardbyte] above CachyOS repositories..."
        # Sed insert: inserts text before the line matching [cachyos-znver4]
        sudo sed -i '/\[cachyos-znver4\]/i \
[lizardbyte]\
SigLevel = Optional\
Server = https://github.com/LizardByte/pacman-repo/releases/latest/download\
' /etc/pacman.conf
    else
        # Fallback: Append if CachyOS repos are missing
        echo -e "\n[lizardbyte]\nSigLevel = Optional\nServer = https://github.com/LizardByte/pacman-repo/releases/latest/download" | sudo tee -a /etc/pacman.conf
    fi

    # FIX: Use -Syu to prevent partial upgrade issues
    echo -e "${YELLOW}Syncing repositories...${NC}"
    sudo pacman -Syu
else
    echo "[lizardbyte] repo already found in /etc/pacman.conf."
fi

# ------------------------------------------------------------------------------
# ------------------------------------------------------------------------------

# 2. Install Desktop Packages
echo -e "${GREEN}--- Installing additional desktop packages from desktop_pkg.txt... ---${NC}"
yay -S --needed --noconfirm - < "$SCRIPT_DIR/desktop_pkg.txt"

# ------------------------------------------------------------------------------
# ------------------------------------------------------------------------------

# 3. Enable Desktop Services
echo -e "${GREEN}--- Enabling desktop services ---${NC}"
echo "Enabling services: sonarr, radarr, lidarr, prowlarr, jellyfin"
sudo systemctl enable --now sonarr radarr lidarr prowlarr jellyfin
# Prevent shutdown hangs by ensuring services stop before /mnt/Media unmounts
echo -e "${GREEN}--- Applying Shutdown Safety Overrides ---${NC}"
SAFETY_SERVICES=("jellyfin" "sonarr" "radarr" "lidarr" "transmission")
for SERVICE in "${SAFETY_SERVICES[@]}"; do
    echo "Securing $SERVICE..."
    sudo mkdir -p "/etc/systemd/system/$SERVICE.service.d"
    echo -e "[Unit]\nRequiresMountsFor=/mnt/Media" | sudo tee "/etc/systemd/system/$SERVICE.service.d/media-mount.conf" > /dev/null
done
sudo systemctl daemon-reload
echo "Configuring Sunshine permissions and enabling service..."
sudo setcap cap_sys_admin+p $(readlink -f $(which sunshine))
systemctl --user enable --now sunshine
echo "Adding solaar udev rules..."
sudo wget -O /etc/udev/rules.d/42-solaar-uinput.rules https://raw.githubusercontent.com/pwr-Solaar/Solaar/refs/heads/master/rules.d-uinput/42-logitech-unify-permissions.rules
sudo udevadm control --reload-rules && sudo udevadm trigger

# ------------------------------------------------------------------------------
# ------------------------------------------------------------------------------

# 4. Jellyfin HideMe Script
echo -e "${GREEN}--- Setting up Jellyfin HideMe script... ---${NC}"
tee ~/Make/hideme_tag.py > /dev/null << 'EOF'
#!/usr/bin/env python3
import requests

JELLYFIN_URL = "http://localhost:8096"
API_KEY = "INSERT-API"
USERNAME = "INSERT-USERNAME"
HIDE_TAG = "hideme"

headers = {
    "X-Emby-Token": API_KEY
}

# Get user ID from name
users_resp = requests.get(f"{JELLYFIN_URL}/Users", headers=headers)
users_resp.raise_for_status()
users = users_resp.json()
user = next(u for u in users if u["Name"] == USERNAME)
user_id = user["Id"]

# Find tagged items
resp = requests.get(f"{JELLYFIN_URL}/Users/{user_id}/Items", params={
    "Recursive": "true",
    "IncludeItemTypes": "Episode,Movie",
    "Tags": HIDE_TAG
}, headers=headers)
resp.raise_for_status()
items = resp.json()["Items"]

# Mark as played and simulate full playback
for item in items:
    item_id = item["Id"]
    name = item["Name"]
    runtime = item.get("RunTimeTicks")

    if not runtime:
        print(f"Skipping {name} (no duration info)")
        continue

    print(f"Marking as played: {name}")

    requests.post(f"{JELLYFIN_URL}/Users/{user_id}/PlayedItems/{item_id}", headers=headers)
    requests.post(f"{JELLYFIN_URL}/Sessions/Playing/Stopped", headers=headers, json={
        "ItemId": item_id,
        "PositionTicks": runtime - 1,
        "PlaySessionId": "",
        "CanSeek": True
    })
EOF
chmod +x ~/Make/hideme_tag.py
# Create systemd service and timer
mkdir -p ~/.config/systemd/user
tee ~/.config/systemd/user/hideme_tag.service > /dev/null << 'EOF'
[Unit]
Description=Run Jellyfin HideMe cleanup
After=network.target

[Service]
Type=oneshot
ExecStart=/home/USER/Make/hideme_tag.py
EOF
# Replace placeholder USER with the actual username
sed -i "s|/home/USER/|/home/$USER/|" ~/.config/systemd/user/hideme_tag.service
tee ~/.config/systemd/user/hideme_tag.timer > /dev/null << 'EOF'
[Unit]
Description=Run HideMe script every 10 minutes

[Timer]
OnBootSec=1min
OnUnitActiveSec=10min
Persistent=true

[Install]
WantedBy=default.target
EOF
echo "Enabling Jellyfin HideMe timer (user service)..."
systemctl --user daemon-reload
systemctl --user enable --now hideme_tag.timer

# ------------------------------------------------------------------------------
# ------------------------------------------------------------------------------

# 5. Setup Slskd and Soularr
echo -e "${GREEN}--- Setting up slskd and Soularr... ---${NC}"
echo "Creating slskd systemd override..."
sudo mkdir -p /etc/systemd/system/slskd.service.d
sudo tee /etc/systemd/system/slskd.service.d/override.conf > /dev/null << 'EOF'
[Unit]
RequiresMountsFor=/mnt/Media

[Service]  
ExecStart=  
ExecStart=/usr/lib/slskd/slskd --config /etc/slskd/slskd.yml
EOF
echo "Creating slskd config directory and placeholder file..."
sudo mkdir -p /etc/slskd
# Only create the file if it does NOT exist to preserve user credentials
if [ ! -f /etc/slskd/slskd.yml ]; then
    sudo tee /etc/slskd/slskd.yml > /dev/null << 'EOF'
#
# Placeholder file created by script.
# EDIT THIS FILE with your details before use.
#
web:
  port: 5030
  https:
    disabled: true
  authentication:
    disabled: false
    username: [insert webui username]
    password: [insert webui password]
    api_keys:
       my_api_key:
         key: edf07c6dee0dc36986eff33d2ba56093
         role: administrator
         cidr: 127.0.0.1/32,::1/128
directories:
  downloads: /mnt/Media/Torrents/slskd/Complete
  incomplete: /mnt/Media/Torrents/slskd/Incomplete
soulseek:
  username: [insert desired soulseek username]
  password: [insert desired soulseek password - no symbols]
EOF
    echo "Created new placeholder slskd.yml."
else
    echo "Existing slskd.yml found. Skipping overwrite to preserve credentials."
fi
echo "Enabling slskd service..."
sudo systemctl daemon-reload
sudo systemctl enable --now slskd.service
echo "Installing Soularr from git..."
if [ -d "/opt/soularr" ]; then
    echo "Soularr directory already exists, skipping clone."
else
    cd /opt
    sudo git clone https://github.com/mrusse/soularr.git
    sudo chown -R $USER:$(id -gn $USER) /opt/soularr
fi
echo "Installing Soularr Python dependencies (pip)..."
sudo pip install --break-system-packages -r /opt/soularr/requirements.txt
echo "Creating Soularr config directory..."
sudo mkdir -p /opt/soularr/config
if [ -f "/opt/soularr/config/config.ini" ]; then
    echo "Soularr config.ini already exists, skipping copy."
else
    sudo cp /opt/soularr/config.ini /opt/soularr/config/config.ini
fi
echo "Creating Soularr systemd service..."
sudo tee /etc/systemd/system/soularr.service > /dev/null << 'EOF'
[Unit]
Description=Soularr (Lidarr ↔ Slskd automation)
Wants=network-online.target lidarr.service slskd.service
After=network-online.target lidarr.service slskd.service
Requires=lidarr.service slskd.service
RequiresMountsFor=/mnt/Media

[Service]
Type=oneshot
User=USER
Group=USER
WorkingDirectory=/opt/soularr
ExecStart=/usr/bin/python /opt/soularr/soularr.py --config-dir /opt/soularr/config --no-lock-file
NoNewPrivileges=yes
PrivateTmp=yes
ProtectSystem=full
ProtectHome=read-only
ReadWritePaths=/opt/soularr /var/log /mnt/Media/Torrents/slskd/Complete/
EOF
# Replace placeholder USER/GROUP with the actual user/group
sudo sed -i "s/User=USER/User=$USER/" /etc/systemd/system/soularr.service
sudo sed -i "s/Group=USER/Group=$(id -gn $USER)/" /etc/systemd/system/soularr.service
echo "Creating Soularr systemd timer..."
sudo tee /etc/systemd/system/soularr.timer > /dev/null << 'EOF'
[Unit]
Description=Run Soularr every 30 minutes

[Timer]
OnCalendar=*:0/30
Persistent=true
AccuracySec=1min

[Install]
WantedBy=timers.target
EOF
echo "Enabling Soularr timer..."
sudo systemctl daemon-reload
sudo systemctl enable --now soularr.timer

# ------------------------------------------------------------------------------
# ------------------------------------------------------------------------------

# 5.1 Hardware Fixes
echo -e "${GREEN}--- Applying AMD Chipset USB Fix ---${NC}"
echo "Disabling runtime power management for AMD 600 Series USB 3.2 Controller (1022:43f7)..."
sudo tee /etc/udev/rules.d/99-xhci-fix.rules > /dev/null << 'EOF'
# Disable runtime power management for AMD 600 Series USB 3.2 Controller (1022:43f7)
SUBSYSTEM=="pci", ATTR{vendor}=="0x1022", ATTR{device}=="0x43f7", ATTR{power/control}="on"
EOF
sudo udevadm control --reload-rules && sudo udevadm trigger

# ------------------------------------------------------------------------------
# ------------------------------------------------------------------------------

# 5.2 Wi-Fi Power Management Fix (Asus ROG Strix X670E-I)
echo -e "${GREEN}--- Applying Wi-Fi Power Save Fix ---${NC}"
# Ensure iw is installed (required for the fix)
yay -S --needed --noconfirm iw
# Create NetworkManager Dispatcher Script
# UPDATE: Changed logic to detect ANY wireless interface (wl*) dynamically
sudo tee /etc/NetworkManager/dispatcher.d/disable-wifi-powersave > /dev/null << 'EOF'
#!/bin/sh
# Use $1 for the interface name (passed by NetworkManager)
# Use $2 for the action (up, down, etc.)

case "$1" in
    wl*)
        if [ "$2" = "up" ]; then
            /usr/bin/iw dev "$1" set power_save off
            /usr/bin/logger "Wifi Power Save disabled for wireless interface: $1"
        fi
        ;;
esac
EOF
# Set permissions (Root owned + Executable)
sudo chown root:root /etc/NetworkManager/dispatcher.d/disable-wifi-powersave
sudo chmod +x /etc/NetworkManager/dispatcher.d/disable-wifi-powersave

# ------------------------------------------------------------------------------
# ------------------------------------------------------------------------------

# 6. Local Binaries and PATH Setup
echo -e "${GREEN}--- Configuring ~/.local/bin and updating ZSH PATH ---${NC}"
# 6a. Create directory and Symlink fix-cover-art script
mkdir -p "$HOME/.local/bin"
SOURCE_SCRIPT="$REPO_ROOT/5-Resources/Local-Scripts/fix-cover-art"
TARGET_LINK="$HOME/.local/bin/fix-cover-art"
if [[ -f "$SOURCE_SCRIPT" ]]; then
    ln -sf "$SOURCE_SCRIPT" "$TARGET_LINK"
    chmod +x "$TARGET_LINK"
    echo "Symlinked fix-cover-art to ~/.local/bin."
else
    echo -e "${YELLOW}Warning: Source script $SOURCE_SCRIPT not found. Skipping symlink.${NC}"
fi
# 6b. Update ZSH PATH
if ! grep -q 'export PATH="$HOME/.local/bin:$PATH"' "$HOME/.zshrc"; then
    echo -e "\n# Added by desktop_setup.sh for local binaries" >> "$HOME/.zshrc"
    echo 'export PATH="$HOME/.local/bin:$PATH"' >> "$HOME/.zshrc"
    echo "Added ~/.local/bin to \$PATH in .zshrc."
else
    echo -e "${YELLOW}~/.local/bin already in ZSH PATH. Skipping append.${NC}"
fi

# ------------------------------------------------------------------------------
# ------------------------------------------------------------------------------

# 7. Desktop Kernel Parameters
echo -e "${GREEN}--- Enforcing desktop-specific kernel parameters ---${NC}"
# Define the exact string requested
# Includes: loglevel=3, quiet, GPU features, Hugepages, Resolution (3440x1440), and Active P-State
NEW_CMDLINE='GRUB_CMDLINE_LINUX_DEFAULT="loglevel=3 quiet amdgpu.ppfeaturemask=0xffffffff hugepages=512 video=3440x1440@60 amd_pstate=active"'
# Force replace the line in /etc/default/grub
sudo sed -i 's|^GRUB_CMDLINE_LINUX_DEFAULT=.*|'"$NEW_CMDLINE"'|' /etc/default/grub
echo -e "${GREEN}--- Rebuilding GRUB configuration ---${NC}"
sudo grub-mkconfig -o /boot/grub/grub.cfg

# ------------------------------------------------------------------------------
# ------------------------------------------------------------------------------

# 8. Import KWin Rules & Install Alias
echo -e "${GREEN}--- Importing Desktop Window Rules ---${NC}"
# A. Set Persistent Profile Variable (Fixes "No profile specified" error)
echo -e "${GREEN}--- Setting KWIN_PROFILE to 'desktop' in .zshrc ---${NC}"
# Check if variable is already exported to prevent duplicate lines
if ! grep -q "export KWIN_PROFILE=" "$HOME/.zshrc"; then
    echo 'export KWIN_PROFILE="desktop"' >> "$HOME/.zshrc"
    # Export immediately for the current script's session
    export KWIN_PROFILE="desktop"
fi
# B. Apply Rules Immediately
if [[ -f "$SCRIPT_DIR/apply_kwin_rules.sh" ]]; then
    chmod +x "$SCRIPT_DIR/apply_kwin_rules.sh"
    "$SCRIPT_DIR/apply_kwin_rules.sh" desktop
else
    echo -e "${YELLOW}Warning: apply_kwin_rules.sh not found. Skipping immediate application.${NC}"
fi
# C. Install Smart 'update-kwin' and 'edit-kwin' functions
echo -e "${GREEN}--- Installing smart KWin functions to .zshrc ---${NC}"
if ! grep -q "function update-kwin" "$HOME/.zshrc"; then
    cat << 'EOF' >> "$HOME/.zshrc"

function update-kwin() {
    # Default to KWIN_PROFILE if set, otherwise require argument
    local target="${1:-$KWIN_PROFILE}"

    if [[ -z "$target" ]]; then
        echo "Error: No profile specified and KWIN_PROFILE not set."
        return 1
    fi

    echo -e "\033[0;32m--- Syncing and Updating for Profile: $target ---\033[0m"
    current_dir=$(pwd)
    cd ~/Obsidian/AMD-Linux-Setup || return

    # Auto-commit common fragment changes
    if git status --porcelain 5-Resources/Window-Rules/common.kwinrule.fragment | grep -q '^ M'; then
        echo -e "\033[1;33mCommitting changes to common.kwinrule.fragment...\033[0m"
        # FIX: Use ${HOST} (Zsh built-in) instead of missing 'hostname' binary
        git add 5-Resources/Window-Rules/common.kwinrule.fragment
        git commit -m "AUTOSYNC: KWin common fragment update from ${HOST}"
    fi

    if ! git pull; then
        echo -e "\033[0;31mError: Git pull failed.\033[0m"
        cd "$current_dir"
        return 1
    fi

    ./Scripts/apply_kwin_rules.sh "$target"
    cd "$current_dir"
}

function edit-kwin() {
    local target="${1:-$KWIN_PROFILE}"
    local repo_dir=~/Obsidian/AMD-Linux-Setup/5-Resources/Window-Rules
    local file_path=""

    case "$target" in
        "desktop") file_path="$repo_dir/desktop.rule.template" ;;
        "laptop")  file_path="$repo_dir/laptop.rule.template" ;;
        "common")  file_path="$repo_dir/common.kwinrule.fragment" ;;
        *)         file_path="$repo_dir/common.kwinrule.fragment" ;;
    esac

    if [[ -f "$file_path" ]]; then
        echo "Opening template for: $target"
        kate "$file_path" &
    else
        echo "Error: File not found: $file_path"
    fi
}
EOF
    echo "Smart KWin functions installed."
else
    echo "Functions already exist in .zshrc."
fi

# ------------------------------------------------------------------------------
# ------------------------------------------------------------------------------

# 9. Optimise NVMe Scheduler (Kyber)
# Your logs confirmed 'kyber' is available. This forces it for NVMe drives.
echo -e "${GREEN}--- Setting NVMe I/O Scheduler to Kyber ---${NC}"
sudo tee /etc/udev/rules.d/60-iosched.rules > /dev/null << 'EOF'
ACTION=="add|change", KERNEL=="nvme[0-9]n[0-9]", ATTR{queue/scheduler}="kyber"
EOF
sudo udevadm control --reload-rules && sudo udevadm trigger

# ------------------------------------------------------------------------------
# ------------------------------------------------------------------------------

echo -e "${GREEN}--- Automated Desktop Setup Finished ---${NC}"

echo -e "${YELLOW}--- MANUAL CONFIGURATION REQUIRED ---${NC}"
echo "Please complete the manual steps as per guide, then REBOOT."
