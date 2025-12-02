#!/bin/zsh
# ------------------------------------------------------------------------------
# Jellyfin HideMe Tag Configuration Script
# Generates the executable hideme_tag.py with user-provided credentials.
# ------------------------------------------------------------------------------
#

# Safety Options
setopt ERR_EXIT
setopt NO_UNSET
setopt PIPE_FAIL

# Load Colours
autoload -Uz colors && colors
GREEN="${fg[green]}"
YELLOW="${fg[yellow]}"
RED="${fg[red]}"
NC="${reset_color}"

# Path Resolution (Zsh Native)
SCRIPT_DIR=${0:a:h}

print "${GREEN}--- Starting HideMe Setup ---${NC}"

# ------------------------------------------------------------------------------
# ------------------------------------------------------------------------------

# 1. Prerequisite Checks
if ! (( $+commands[python3] )) || ! (( $+commands[systemctl] )); then
    print "${RED}Error: python3 or systemctl is not available. Aborting.${NC}"
    exit 1
fi

# ------------------------------------------------------------------------------
# ------------------------------------------------------------------------------

# 2. Main Logic
print "${GREEN}--- Gathering Credentials ---${NC}"

print "Please enter your Jellyfin credentials:"
read "JF_API?API Key (Required): "
read "JF_USER?Username (Required): "
if [[ -z "$JF_API" || -z "$JF_USER" ]]; then
    print "${RED}Error: API Key and Username are required. Aborting.${NC}"
    exit 1
fi

TARGET_SCRIPT="$HOME/Make/hideme_tag.py"
SERVICE_PATH="$HOME/.config/systemd/user"

# Generate Python Script
print "Generating executable Python script at: $TARGET_SCRIPT"
tee "$TARGET_SCRIPT" > /dev/null << EOF
#!/usr/bin/env python3
import requests

JELLYFIN_URL = "http://localhost:8096"
API_KEY = "$JF_API"
USERNAME = "$JF_USER"
HIDE_TAG = "hideme"

headers = {
    "X-Emby-Token": API_KEY
}

# Get user ID from name
try:
    users_resp = requests.get(f"{JELLYFIN_URL}/Users", headers=headers)
    users_resp.raise_for_status()
    users = users_resp.json()
    user = next(u for u in users if u["Name"] == USERNAME)
    user_id = user["Id"]
except requests.exceptions.RequestException as e:
    print(f"Error connecting to Jellyfin or authenticating: {e}")
    exit(1)
except StopIteration:
    print(f"Error: User '{USERNAME}' not found.")
    exit(1)

# Find tagged items
try:
    resp = requests.get(f"{JELLYFIN_URL}/Users/{user_id}/Items", params={{
        "Recursive": "true",
        "IncludeItemTypes": "Episode,Movie",
        "Tags": HIDE_TAG
    }}, headers=headers)
    resp.raise_for_status()
    items = resp.json()["Items"]
except requests.exceptions.RequestException as e:
    print(f"Error retrieving items: {e}")
    exit(1)

# Mark as played and simulate full playback
for item in items:
    item_id = item["Id"]
    name = item["Name"]
    runtime = item.get("RunTimeTicks")

    if not runtime:
        print(f"Skipping {{name}} (no duration info)")
        continue

    print(f"Marking as played: {{name}}")

    requests.post(f"{{JELLYFIN_URL}}/Users/{{user_id}}/PlayedItems/{{item_id}}", headers=headers)
    requests.post(f"{{JELLYFIN_URL}}/Sessions/Playing/Stopped", headers=headers, json={{
        "ItemId": item_id,
        "PositionTicks": runtime - 1,
        "PlaySessionId": "",
        "CanSeek": True
    }})
EOF

chmod +x "$TARGET_SCRIPT"

# ------------------------------------------------------------------------------
# ------------------------------------------------------------------------------

# 3. Setup Systemd User Service and Timer
print "${GREEN}--- Setting up Systemd User Services ---${NC}"
mkdir -p "$SERVICE_PATH"
tee "$SERVICE_PATH/hideme_tag.service" > /dev/null << EOF
[Unit]
Description=Run Jellyfin HideMe
[Service]
Type=oneshot
ExecStart=$TARGET_SCRIPT
EOF

tee "$SERVICE_PATH/hideme_tag.timer" > /dev/null << 'EOF'
[Unit]
Description=Timer for HideMe
[Timer]
OnBootSec=1min
OnUnitActiveSec=10min
Persistent=true
[Install]
WantedBy=default.target
EOF

systemctl --user daemon-reload
systemctl --user enable --now hideme_tag.timer

# ------------------------------------------------------------------------------
# ------------------------------------------------------------------------------

print "${GREEN}--- HideMe Setup Complete ---${NC}"
