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

print "${GREEN}--- Laptop Setup Complete. Reboot Required. ---${NC}"
