# AMD Linux Setup

**WARNING:** All scripts and configurations in this repo are highly-opinionated and specific to the repo owner's needs. They contain hardcoded kernel parameters and hardware-specific udev rules. Do not execute on unsupported hardware without significant modification.

This repository hosts a bespoke automation suite for deploying a high-performance Arch Linux environment on specific AMD hardware. It enforces a strict configuration hierarchy (Core → Device), tailored for maximum throughput and stability on Ryzen 7000 series processors and RDNA 3 graphics.

### [Get Started ⇢](1-Install/1.1-USB.md)

## Hardware targets

For full details, see [Hardware Spec](./4-Hardware-Specs) files.

| Profile | CPU | GPU | System |
| :--- | :--- | :--- | :--- |
| **Desktop** | Ryzen 7 7800X3D | Radeon RX 7900 XT | Asus ROG Strix X670E-I |
| **Laptop** | Ryzen 7 7840HS | Radeon 780M (iGPU) | Slimbook EXCALIBUR-16 |

## Architecture

​The setup utilises a unified, monolithic installer to ensure consistency and atomic configuration.

#### ​Stage 1: Unified Installer (Live Environment)

​**Script:** setup_install.zsh (Zsh)

- ​**Pre-flight:** Validates UEFI boot mode and internet connectivity.
- ​**Configuration:** Collects user inputs (Hostname, Passwords, Git Credentials) and Device Profile (Desktop/Laptop).
- ​**Partitioning:** Wipes the target disk and creates a Btrfs layout with optimised subvolumes (including +C for @games).
- ​**Base System:** Bootstraps CachyOS (x86-64-v4) via pacstrap, replacing archinstall.
- ​**System Configuration:** Injects network config (iwd/NetworkManager), creates users, and establishes the build environment within chroot.

#### ​Stage 2: First Boot Automation

​**Mechanism:** first_boot.zsh (Auto-generated)

- ​**Execution:** Runs automatically upon first login via a self-destructing Autostart entry.
- ​**Device Tuning:** Applies profile-specific configurations (Desktop/Laptop) defined in the installer.
- ​**Visuals:** Applies Konsave profiles and KWin rules.
- ​**Hardware:** Configures Sunshine (if Desktop) or specific power profiles (if Laptop).

#### ​Stage 3: Manual Finalisation

- ​**Tasks:** Installation of proprietary fonts, authentication of Obsidian, and application-specific setup.

## Development standards

This repository adheres to strict scripting standards to maintain stability:

- **Shell:** `zsh` is used for all system logic and configuration.
- **Idempotency:** Post-install scripts are designed to be safe to re-run to repair configuration drift.
- **Safety:** All zsh scripts utilise `setopt ERR_EXIT NO_UNSET PIPE_FAIL`.
- **Formatting:** Scripts utilise compact layouts with double-dotted line separators for readability (see [TEMPLATES](./Scripts/TEMPLATES) folder)

## License and disclaimer

This is a personal configuration repository provided "as-is". No warranty is implied. Use these scripts at your own risk.
