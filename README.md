# AMD Linux Setup

**WARNING:** All scripts and configurations in this repo are highly-opinionated and specific to the repo owner's needs. They contain hardcoded kernel parameters and hardware-specific udev rules. Do not execute on unsupported hardware without significant modification.

This repository hosts a bespoke automation suite for deploying a high-performance Arch Linux environment on specific AMD hardware. It enforces a strict configuration hierarchy (Core → Device), tailored for maximum throughput and stability on Ryzen 7000 series processors and RDNA 3 graphics.

### [Get Started ⇢](1-Install/1.1-USB.md)

## Hardware Targets

For full details, see [Hardware Spec](./7-Hardware-Specs) files.

| Profile | CPU | GPU | System |
| :--- | :--- | :--- | :--- |
| **Desktop** | Ryzen 7 7800X3D | Radeon RX 7900 XT | Asus ROG Strix X670E-I |
| **Laptop** | Ryzen 7 7840HS | Radeon 780M (iGPU) | Slimbook EXCALIBUR-16 |

## Architecture

The setup follows a strict, tiered execution order to ensure consistency and idempotency.

### Tier 0: Bootstrap
**Script:** `Scripts/system_install.sh` (Bash)
- Prepares the live environment (keys, mirrors, pacman configuration).
- Fetches the custom `archinstall` JSON configuration.
- Launches `archinstall` to provision the base OS and Btrfs filesystem.

### Tier 1: User Environment
**Script:** `Scripts/home_setup.sh` (Bash)
- Creates standard directory structure (`~/Make`, `~/Obsidian`).
- **Storage:** Detects the Btrfs root, creates the `@games` subvolume, and mounts it to `~/Games` with the `+C` (No-CoW) attribute.
- **Shell:** Deploys Oh-My-Zsh, plugins, and custom Git identity configuration.
- **Terminal:** Installs custom Konsole profiles.

### Tier 2: Core Configuration
**Script:** `Scripts/core_setup.zsh` (Zsh)
- **Kernel:** Replaces stock kernel with `linux-cachyos` and regenerates initramfs.
- **Build Chain:** Optimises `makepkg` for `-march=native`, parallel compilation, and Rust targets.
- **System:** Configures ZRAM, Btrfs maintenance tasks, and networking (BBR/Cake).
- **Environment:** Sets global variables for VA-API and prepares the environment for the next boot.

### Tier 3: Device Tuning
**Scripts:** `desktop_setup.zsh` / `laptop_setup.zsh` (Zsh)
- **Desktop:**
    - Deploys the media stack (*arr suite, Jellyfin) and gaming tools (Lutris, Sunshine).
    - Configures hardware specific fixes (AMD USB autosuspend, Kyber I/O scheduler).
    - interactive setup for dedicated Media drive mounting.
- **Laptop:**
    - Installs power management tools (`power-profiles-daemon`) and input hooks.
    - Applies specific kernel parameters for efficiency.
- **Visuals:** Applies the consistent KDE "Dock" profile via `konsave` and enforces window rules.

## Development Standards

This repository adheres to strict scripting standards to maintain stability:

- **Shell:** `bash` is used strictly for bootstrapping. `zsh` is used for all system logic and configuration.
- **Idempotency:** Post-install scripts are designed to be safe to re-run to repair configuration drift.
- **Safety:** All Zsh scripts utilise `setopt ERR_EXIT NO_UNSET PIPE_FAIL`.
- **Formatting:** Scripts utilise compact layouts with double-dotted line separators for readability (see [TEMPLATES](./Scripts/TEMPLATES) folder)

## License and Disclaimer

This is a personal configuration repository provided "as-is". No warranty is implied. Use these scripts at your own risk.
