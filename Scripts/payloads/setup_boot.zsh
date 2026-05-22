#!/bin/zsh
# ------------------------------------------------------------------------------
# AMD-Linux-Setup: Stage 3 (First Boot)
# Automatically runs on first user login to apply final graphical and hardware tweaks.
# ------------------------------------------------------------------------------

# region
setopt ERR_EXIT NO_UNSET PIPE_FAIL EXTENDED_GLOB
source "$HOME/.zshrc"
sleep 5
print -P "\n%K{green}%F{black} RUNNING FIRST BOOT SETUP %k%f\n"
REPO_DIR="$HOME/Obsidian/AMD-Linux-Setup"
# endregion

# ------------------------------------------------------------------------------
# 1. Device Profile Tweaks
# ------------------------------------------------------------------------------

# region
if [[ "$DEVICE_PROFILE" == "desktop" ]]; then
    print -P "%F{cyan}ℹ Connecting to Tailscale...%f\n"
    sudo tailscale up --advertise-exit-node
    TRANS_CONF="/var/lib/transmission/.config/transmission-daemon/settings.json"
    if [[ -f "$TRANS_CONF" ]]; then
        print -P "%F{cyan}ℹ Enforcing Transmission Umask...%f\n"
        sudo systemctl stop transmission
        sudo jq '.umask = 2' "$TRANS_CONF" > "${TRANS_CONF}.tmp" && sudo mv "${TRANS_CONF}.tmp" "$TRANS_CONF"
        sudo chown transmission:transmission "$TRANS_CONF"
        sudo systemctl start transmission
    fi
fi
# endregion

# ------------------------------------------------------------------------------
# 2. Sunshine Configuration
# ------------------------------------------------------------------------------

# region
if [[ "$DEVICE_PROFILE" == "desktop" ]] && (( $+commands[kscreen-doctor] )); then
    print -P "\n%K{yellow}%F{black} SUNSHINE CONFIGURATION %k%f\n"
    print -P "%F{cyan}ℹ Current Output Configuration:%f\n"
    kscreen-doctor -o; print ""
    if read -q "CONFIRM?Configure Sunshine Monitor/Mode Indexes? [y/N] "; then
        read "MON_ID?Monitor ID (e.g. DP-1): "
        read "STREAM_IDX?Target Stream Mode Index: "
        read "DEFAULT_IDX?Default Mode Index: "
        for script in sunshine_hdr.zsh sunshine_res.zsh sunshine_laptop.zsh; do
            [[ -f "$REPO_DIR/Scripts/$script" ]] && sed -i -e "s/^MONITOR=.*/MONITOR=\"$MON_ID\"/" -e "s/^STREAM_MODE=.*/STREAM_MODE=\"$STREAM_IDX\"/" -e "s/^DEFAULT_MODE=.*/DEFAULT_MODE=\"$DEFAULT_IDX\"/" "$REPO_DIR/Scripts/$script"
            print -P "%F{green}Updated variables in $script%f"
        done
     fi
fi
# endregion

# ------------------------------------------------------------------------------
# 3. Cleanup & Completion
# ------------------------------------------------------------------------------

# region
print -P "\n%F{green}System Setup Complete!%f"
read "k?Press Enter to cleanup..."
rm "$HOME/.config/autostart/setup_boot.desktop" "$HOME/.local/bin/setup_boot.zsh"
# endregion

# ANTIGRAVITY LINK: Setup complete. No further stages.
