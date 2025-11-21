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
echo -e "${GREEN}--- Creating script and hook to replace Sunshine icons... ---${NC}"
# Create replacement script using local repo path
sudo tee /usr/local/bin/replace-sunshine-icons.sh > /dev/null << EOF
#!/bin/bash
DEST_DIR="/usr/share/icons/hicolor/scalable/status"
REPO_ROOT="\$(dirname "$SCRIPT_DIR")"
SOURCE_DIR="\$REPO_ROOT/5-Resources/Icons/Sunshine-Tray-Icons"

if [[ -d "\$SOURCE_DIR" ]]; then
    cp "\$SOURCE_DIR"/*.svg "\$DEST_DIR/"
    echo "Sunshine icons updated from local repo."
else
    echo "Warning: Icon source directory not found at \$SOURCE_DIR"
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
if ! grep -q "\[lizardbyte\]" /etc/pacman.conf; then
    echo -e "\n[lizardbyte]\nSigLevel = Optional\nServer = https://github.com/LizardByte/pacman-repo/releases/latest/download" | sudo tee -a /etc/pacman.conf
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
  username: [insert desired soluseek username]
  password: [insert desired soluseek password - no symbols]
EOF
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
sudo tee /etc/NetworkManager/dispatcher.d/disable-wifi-powersave > /dev/null << 'EOF'
#!/bin/sh
# Use $1 for the interface name (passed by NetworkManager)
# Use $2 for the action (up, down, etc.)

if [ "$1" = "wlan0" ] && [ "$2" = "up" ]; then
    /usr/bin/iw dev "$1" set power_save off
    /usr/bin/logger "Wifi Power Save disabled for $1"
fi
EOF
# Set permissions (Root owned + Executable)
sudo chown root:root /etc/NetworkManager/dispatcher.d/disable-wifi-powersave
sudo chmod +x /etc/NetworkManager/dispatcher.d/disable-wifi-powersave

# ------------------------------------------------------------------------------
# ------------------------------------------------------------------------------

# 6. Desktop Kernel Parameters
echo -e "${GREEN}--- Applying desktop-specific kernel parameters ---${NC}"
sudo sed -i 's/^\(GRUB_CMDLINE_LINUX_DEFAULT=".*\)"$/\1 amdgpu.ppfeaturemask=0xffffffff hugepages=512 video=3440x1440@60 amd_pstate=guided"/' /etc/default/grub
echo -e "${GREEN}--- Rebuilding GRUB configuration ---${NC}"
sudo grub-mkconfig -o /boot/grub/grub.cfg

# ------------------------------------------------------------------------------
# ------------------------------------------------------------------------------

# 7. Import KWin Rules & Install Alias
echo -e "${GREEN}--- Importing Desktop Window Rules ---${NC}"
if [[ -f "$SCRIPT_DIR/update_kwin_rules.sh" && -f "$SCRIPT_DIR/sync_kwin_rules.sh" ]]; then
    # 1a. SYNCHRONISE: Generate the final kwinrule file from the common fragment
    bash "$SCRIPT_DIR/sync_kwin_rules.sh" desktop
    # 1b. UPDATE: Convert the generated file and apply to kwinrulesrc
    bash "$SCRIPT_DIR/update_kwin_rules.sh" desktop

    # 2. Install 'update-kwin' function into .zshrc
    echo -e "${GREEN}--- Installing 'update-kwin' auto-sync command to .zshrc ---${NC}"
    if ! grep -q "function update-kwin" "$HOME/.zshrc"; then
        cat << 'EOF' >> "$HOME/.zshrc"

# --- Added by desktop_setup.sh ---
# Syncs repo, generates final rules, and reapplies Desktop rules
function update-kwin() {
    echo -e "\033[0;32m--- Entering Git Synchronization Phase ---\033[0m"
    current_dir=$(pwd)
    cd ~/Obsidian/AMD-Linux-Setup || return

    # Check for modified common fragment and automatically commit it
    if git status --porcelain 5-Resources/Window-Rules/common.kwinrule.fragment | grep -q '^ M'; then
        echo -e "\033[1;33mUncommitted changes detected in common.kwinrule.fragment. Committing automatically...\033[0m"
        git add 5-Resources/Window-Rules/common.kwinrule.fragment
        git commit -m "AUTOSYNC: KWin common fragment update from $(hostname)"
    fi

    echo -e "\033[0;32m--- Pulling latest changes from remote ---\033[0m"
    if ! git pull; then
        echo -e "\033[0;31mError: Git pull failed. Cannot continue.\033[0m"
        cd "$current_dir"
        return 1
    fi

    echo -e "\033[0;32m--- Generating and Applying Desktop Window Rules ---\033[0m"
    ./Scripts/sync_kwin_rules.sh desktop
    ./Scripts/update_kwin_rules.sh desktop

    cd "$current_dir"
}
EOF
        echo "Command 'update-kwin' installed."
    else
        echo "Command 'update-kwin' already exists in .zshrc."
    fi
else
    echo -e "${YELLOW}Warning: Required rule utilities not found. Skipping rules import.${NC}"
fi

# ------------------------------------------------------------------------------
# ------------------------------------------------------------------------------

echo -e "${GREEN}--- Automated Desktop Setup Finished ---${NC}"

echo -e "${YELLOW}--- MANUAL CONFIGURATION REQUIRED ---${NC}"
echo "Please complete the manual steps as per guide, then REBOOT."
