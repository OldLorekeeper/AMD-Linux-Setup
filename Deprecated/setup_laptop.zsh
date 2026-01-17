#!/bin/zsh
# ------------------------------------------------------------------------------
# 4. Laptop Profile Setup
# Configures the mobile profile (Power saving, Scaling, Integrated Graphics).
# ------------------------------------------------------------------------------
#
# DEVELOPMENT RULES (Read before editing):
# 1. Formatting: Keep layout compact. No vertical whitespace inside blocks.
# 2. Separators: Use double dotted lines (# ------) for major sections.
# 3. Idempotency: Scripts must be safe to re-run. Check state before changes.
# 4. Safety: Use 'setopt ERR_EXIT NO_UNSET PIPE_FAIL'.
# 5. Context: Hardcoded for AMD Ryzen 7000/Radeon 7000. No hardcoded secrets.
# 6. Syntax: Use Zsh native modifiers (e.g. ${VAR:h}) over subshells.
# 7. Output: Use 'print'. Do NOT use 'echo'.
#
# ------------------------------------------------------------------------------

setopt ERR_EXIT NO_UNSET PIPE_FAIL

sudo -v
( while true; do sudo -v; sleep 60; done; ) &
SUDO_PID=$!
trap 'kill $SUDO_PID' EXIT

SCRIPT_DIR=${0:a:h}
REPO_ROOT=${SCRIPT_DIR:h}

print -P "%F{green}--- Starting Laptop Setup ---%f"

# ------------------------------------------------------------------------------
# 1. Packages
# ------------------------------------------------------------------------------

# Purpose: Install laptop-specific packages from laptop_pkg.txt

print -P "%F{green}--- Installing Packages ---%f"
yay -S --needed --noconfirm - < "$REPO_ROOT/Resources/Packages/laptop_pkg.txt"

# ------------------------------------------------------------------------------
# 2. Kernel & Hardware
# ------------------------------------------------------------------------------

# Purpose: Optimize for battery life and integrated display.
# - GRUB: Sets resolution to 2560x1600 (16:10) and enables power-saving features.
# - Initramfs: Injects 'numlock' hook (specific to this laptop's keyboard).
# - WiFi: Disables power save to prevent connection drops on this chipset.

print -P "%F{green}--- Configuring Hardware ---%f"

NEW_CMDLINE='GRUB_CMDLINE_LINUX_DEFAULT="loglevel=3 quiet amdgpu.ppfeaturemask=0xffffffff hugepages=512 video=2560x1600@60 amd_pstate=active"'
sudo sed -i 's|^GRUB_CMDLINE_LINUX_DEFAULT=.*|'"$NEW_CMDLINE"'|' /etc/default/grub
sudo grub-mkconfig -o /boot/grub/grub.cfg

if ! grep -q "numlock" /etc/mkinitcpio.conf; then
    sudo sed -i 's/HOOKS=(\(.*\))/HOOKS=(\1 numlock)/' /etc/mkinitcpio.conf
    sudo mkinitcpio -P
fi

sudo sysctl --system

sudo tee /etc/NetworkManager/dispatcher.d/disable-wifi-powersave > /dev/null << 'EOF'
#!/bin/sh
[[ "$1" == wl* ]] && [[ "$2" == "up" ]] && /usr/bin/iw dev "$1" set power_save off
EOF
sudo chmod +x /etc/NetworkManager/dispatcher.d/disable-wifi-powersave
nmcli radio wifi off && sleep 2 && nmcli radio wifi on

# ------------------------------------------------------------------------------
# 3. KDE Integration
# ------------------------------------------------------------------------------

# Purpose: Apply laptop-specific window rules.
# - Rules: Executes kwin_apply_rules.zsh with 'laptop' profile.

print -P "%F{green}--- KDE Rules ---%f"
[[ -f "$SCRIPT_DIR/kwin_apply_rules.zsh" ]] && chmod +x "$SCRIPT_DIR/kwin_apply_rules.zsh" && "$SCRIPT_DIR/kwin_apply_rules.zsh" laptop

# ------------------------------------------------------------------------------
# 4. Theming (Konsave)
# ------------------------------------------------------------------------------

# Purpose: Apply the visual laptop profile.
# - Konsave: Imports and applies the 'Laptop Dock' profile.

print -P "%F{green}--- Applying Visual Profile ---%f"
KONSAVE_DIR="$REPO_ROOT/Resources/Konsave"
PROFILE_FILE=( "$KONSAVE_DIR"/Laptop\ Dock*.knsv(.On[1]) )

if [[ -n "$PROFILE_FILE" && -f "$PROFILE_FILE" ]]; then
    PROFILE_NAME="${${PROFILE_FILE:t}:r}"
    print "Found profile: $PROFILE_NAME"
    konsave -r "$PROFILE_NAME" 2>/dev/null || true
    if konsave -i "$PROFILE_FILE" >/dev/null 2>&1; then
        konsave -a "$PROFILE_NAME" >/dev/null 2>&1
        print "Successfully applied profile: $PROFILE_NAME"
    else
        print -P "%F{red}Error: Failed to import profile.%f"
    fi
else
    print -P "%F{yellow}Warning: No 'Laptop Dock' profile found in $KONSAVE_DIR%f"
fi

# ------------------------------------------------------------------------------
# End - Reboot
# ------------------------------------------------------------------------------

print -P "%F{green}--- Laptop Setup Complete. Reboot Required. ---%f"
