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

# Safety Options
setopt ERR_EXIT     # Exit on error
setopt NO_UNSET     # Error on unset variables
setopt PIPE_FAIL    # Fail if any part of a pipe fails

# Load Colours
autoload -Uz colors && colors
GREEN="${fg[green]}"
YELLOW="${fg[yellow]}"
RED="${fg[red]}"
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

# ------------------------------------------------------------------------------
# ------------------------------------------------------------------------------

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
# NOTE: Add services here (e.g. 'power-profiles-daemon'). Empty command commented out to prevent error.
# sudo systemctl enable --now

# 2.5 Ensure Kernel Configs from Core Setup are applied now that new kernel is running
sudo sysctl --system

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

# Find profile: Match "Laptop Dock*.knsv"
# LINKAGE: Matches naming convention defined in maintain_system.zsh (Section 5).
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
