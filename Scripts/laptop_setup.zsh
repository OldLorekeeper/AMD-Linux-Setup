#!/bin/zsh
# ------------------------------------------------------------------------------
# 4. Laptop Profile Setup
# ------------------------------------------------------------------------------

setopt ERR_EXIT
setopt NO_UNSET
setopt PIPE_FAIL

autoload -Uz colors && colors
GREEN="${fg[green]}"
NC="${reset_color}"

# Sudo Keep-Alive
sudo -v
( while true; do sudo -v; sleep 60; done; ) &
SUDO_PID=$!
trap 'kill $SUDO_PID' EXIT

SCRIPT_DIR=${0:a:h}

print "${GREEN}--- Starting Laptop Setup ---${NC}"

# ------------------------------------------------------------------------------
# ------------------------------------------------------------------------------

# 1. Packages
print "${GREEN}--- Installing Packages ---${NC}"
yay -S --needed --noconfirm - < "$SCRIPT_DIR/laptop_pkg.txt"

# 2. Kernel & Hardware
print "${GREEN}--- Configuring Hardware ---${NC}"

# Kernel Params
NEW_CMDLINE='GRUB_CMDLINE_LINUX_DEFAULT="loglevel=3 quiet amdgpu.ppfeaturemask=0xffffffff hugepages=512 video=2560x1600@60 amd_pstate=active"'
sudo sed -i 's|^GRUB_CMDLINE_LINUX_DEFAULT=.*|'"$NEW_CMDLINE"'|' /etc/default/grub
sudo grub-mkconfig -o /boot/grub/grub.cfg

# Numlock Hook
if ! grep -q "numlock" /etc/mkinitcpio.conf; then
    sudo sed -i 's/HOOKS=(\(.*\))/HOOKS=(\1 numlock)/' /etc/mkinitcpio.conf
    sudo mkinitcpio -P
fi

# Services
sudo systemctl enable --now power-profiles-daemon

# ------------------------------------------------------------------------------
# ------------------------------------------------------------------------------

# 3. KDE Integration
print "${GREEN}--- KDE Rules ---${NC}"

[[ -f "$SCRIPT_DIR/apply_kwin_rules.zsh" ]] && chmod +x "$SCRIPT_DIR/apply_kwin_rules.zsh" && "$SCRIPT_DIR/apply_kwin_rules.zsh" laptop

# ------------------------------------------------------------------------------
# ------------------------------------------------------------------------------

# 4. Theming (Konsave)
print "${GREEN}--- Applying Visual Profile ---${NC}"
REPO_ROOT=${SCRIPT_DIR:h}
KONSAVE_DIR="$REPO_ROOT/5-Resources/Konsave"

# Find profile: Match "Laptop Dock*.knsv", Sort by Name Descending (.On), Pick 1st
PROFILE_FILE=( "$KONSAVE_DIR"/Laptop\ Dock*.knsv(.On[1]) )

if [[ -n "$PROFILE_FILE" && -f "$PROFILE_FILE" ]]; then
    PROFILE_NAME="${${PROFILE_FILE:t}:r}"

    print "Found profile: $PROFILE_NAME"

    # Remove existing profile to force update
    konsave -r "$PROFILE_NAME" 2>/dev/null || true

    # Import and Apply (suppress deprecation warnings)
    if konsave -i "$PROFILE_FILE" >/dev/null 2>&1; then
        konsave -a "$PROFILE_NAME" >/dev/null 2>&1
        print "Successfully applied profile: $PROFILE_NAME"
    else
        print "${RED}Error: Failed to import profile.${NC}"
    fi
else
    print "${YELLOW}Warning: No 'Laptop Dock' profile found in $KONSAVE_DIR${NC}"
fi

# ------------------------------------------------------------------------------
# ------------------------------------------------------------------------------

print "${GREEN}--- Laptop Setup Complete. Reboot Required. ---${NC}"
