### 1. Add US locale

```
kate /etc/locale.gen
```

Uncomment relevant entry:

`#en_US.UTF-8`

Generate locale:

```
sudo locale-gen
```

---
### 2. Add environment variables

```
kate /etc/environment
```

Add the following

```
LIBVA_DRIVER_NAME=radeonsi
VDPAU_DRIVER=radeonsi
WINEFSYNC=1
```

---
### 3. Add kernel parameters

```
kate /etc/default/grub
```

Add following to GRUB_CMDLINE_LINUX_DEFAULT:

```
amdgpu.ppfeaturemask=0xffffffff hugepages=512 video=2560x1600@60
```

---
### 4. Configure zram swap

```
kate /etc/systemd/zram-generator.conf
```

Replace with the following:

```
[zram0]
zram-size = ram / 2
compression-algorithm = zstd
swap-priority = 100
```

---
### 5. Add pacman hooks

Create executable script:

```
sudo tee /usr/local/bin/update-init-grub > /dev/null <<EOF && sudo chmod +x /usr/local/bin/update-init-grub
#!/bin/bash
# Replace the below commands with the actual commands that your aliases refer to.
sudo mkinitcpio -P
sudo grub-mkconfig -o /boot/grub/grub.cfg
EOF
```

Create hook:

```
sudo tee /etc/pacman.d/hooks/99-update-init-grub.hook > /dev/null <<EOF
[Trigger]
Operation = Install
Operation = Upgrade
Type = Package
Target = *

[Action]
Description = Updating initramfs and GRUB configurations
When = PostTransaction
Exec = /usr/local/bin/update-init-grub
EOF
```


