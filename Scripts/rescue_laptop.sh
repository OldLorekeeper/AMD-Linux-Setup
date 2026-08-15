#!/bin/bash
echo "==> Rescuing Installation..."

echo "==> Enabling timers..."
systemctl enable btrfs-balance.timer btrfs-scrub@-.timer timeshift-hourly.timer

echo "==> Generating initramfs and GRUB..."
mkinitcpio -P
grub-mkconfig -o /boot/grub/grub.cfg

echo "==> Setting up First Boot Script..."
USER=$(ls /home | head -n 1)
if [[ -n "$USER" && -f /setup_boot.zsh ]]; then
    mkdir -p "/home/$USER/.config/autostart" "/home/$USER/.local/bin"
    cp /setup_boot.zsh "/home/$USER/.local/bin/setup_boot.zsh"
    chmod +x "/home/$USER/.local/bin/setup_boot.zsh"
    chown "$USER:$USER" "/home/$USER/.local/bin/setup_boot.zsh"
    echo -e "[Desktop Entry]\nType=Application\nExec=konsole --separate --hide-tabbar -e /home/$USER/.local/bin/setup_boot.zsh\nHidden=false\nNoDisplay=false\nName=First Boot Setup\nX-GNOME-Autostart-enabled=true" > "/home/$USER/.config/autostart/setup_boot.desktop"
    rm -f /setup_boot.zsh
else
    echo "==> Warning: setup_boot.zsh not found or user not detected. Skipping autostart config."
fi

echo "==> Rescue Complete! You can now type 'exit' and then 'reboot'."
