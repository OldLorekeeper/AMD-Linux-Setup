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

# 1. Pre-install: Sunshine Hook and Repo
echo -e "${GREEN}--- Creating script and hook to replace Sunshine icons... ---${NC}"

# Create replacement script using local repo path
sudo tee /usr/local/bin/replace-sunshine-icons.sh > /dev/null << EOF
#!/bin/bash
DEST_DIR="/usr/share/icons/hicolor/scalable/status"
# Calculate the repo root relative to this generated script's original location
REPO_ROOT="\$(dirname "$SCRIPT_DIR")"
SOURCE_DIR="\$REPO_ROOT/5. Resources/Icons/Sunshine Tray Icons"

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

# 2. Install Desktop Packages
echo -e "${GREEN}--- Installing additional desktop packages from desktop_pkg.txt... ---${NC}"
yay -S --needed --noconfirm - < "$SCRIPT_DIR/desktop_pkg.txt"

# 3. Enable Desktop Services
echo -e "${GREEN}--- Enabling desktop services ---${NC}"
echo "Enabling services: sonarr, radarr, lidarr, prowlarr, jellyfin"
sudo systemctl enable --now sonarr radarr lidarr prowlarr jellyfin

echo "Configuring Sunshine permissions and enabling service..."
sudo setcap cap_sys_admin+p $(readlink -f $(which sunshine))
systemctl --user enable --now sunshine

echo "Adding solaar udev rules..."
sudo wget -O /etc/udev/rules.d/42-solaar-uinput.rules https://raw.githubusercontent.com/pwr-Solaar/Solaar/refs/heads/master/rules.d-uinput/42-logitech-unify-permissions.rules
sudo udevadm control --reload-rules && sudo udevadm trigger

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

# 5. Setup Slskd and Soularr
echo -e "${GREEN}--- Setting up slskd and Soularr... ---${NC}"

echo "Creating slskd systemd override..."
sudo mkdir -p /etc/systemd/system/slskd.service.d
sudo tee /etc/systemd/system/slskd.service.d/override.conf > /dev/null << 'EOF'
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

# 6. Desktop Kernel Parameters
echo -e "${GREEN}--- Applying desktop-specific kernel parameters ---${NC}"
sudo sed -i 's/^\(GRUB_CMDLINE_LINUX_DEFAULT=".*\)"$/\1 amdgpu.ppfeaturemask=0xffffffff hugepages=512 video=2560x1600@60 amd_pstate=guided"/' /etc/default/grub

echo -e "${GREEN}--- Rebuilding GRUB configuration ---${NC}"
sudo grub-mkconfig -o /boot/grub/grub.cfg

echo -e "${GREEN}--- Automated Desktop Setup Finished ---${NC}"

echo -e "${YELLOW}--- MANUAL CONFIGURATION REQUIRED ---${NC}"
echo "Please complete the manual steps as per guide, then REBOOT."
