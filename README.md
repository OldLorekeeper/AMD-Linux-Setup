# AMD Linux Setup

**WARNING:** All scripts and configurations in this repo are highly-opinionated and specific to the repo owner's needs. They contain hardcoded kernel parameters and hardware-specific udev rules. Do not execute on unsupported hardware without significant modification.

This repository hosts a bespoke automation suite for deploying a high-performance Arch Linux environment on specific AMD hardware. It enforces a strict configuration hierarchy (Core → Device), tailored for maximum throughput and stability on Ryzen 7000 series processors and RDNA 3 graphics.

### [Get Started ⇢](1-Install/1.1-USB.md)

---
## Hardware specs

The scripts and steps contained in this repo are tailored to the below system profiles.
#### Desktop profile:

| Component       | Model                      | Specs / Link                                                                                                                                                                              |
| :-------------- | :------------------------- | :---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **Motherboard** | Asus ROG Strix X670E-I     | [Specifications](https://rog.asus.com/uk/motherboards/rog-strix/rog-strix-x670e-i-gaming-wifi-model/spec/)                                                                                |
| **CPU**         | AMD Ryzen 7 7800X3D        | [TechPowerUp](https://www.techpowerup.com/cpu-specs/ryzen-7-7800x3d.c3022)                                                                                                                |
| **GPU**         | Gigabyte Radeon RX 7900 XT | [TechPowerUp](https://www.techpowerup.com/gpu-specs/gigabyte-rx-7900-xt-gaming-oc.b9940)                                                                                                  |
| **RAM**         | Corsair Vengeance DDR5     | [32GB (2x16GB) 6400MT/s CL36](https://www.corsair.com/uk/en/p/ddr5-ram/cmk32gx5m2b6400c36/vengeance-32gb-2x16gb-ddr5-dram-6400mt-s-c36-memory-kit-black-cmk32gx5m2b6400c36#tab-techspecs) |
| **PSU**         | Corsair SF750              | [750W 80+ Platinum SFX](https://www.corsair.com/ww/en/p/psu/cp-9020186-uk/sf-series-sf750-750-watt-80-plus-platinum-certified-high-performance-sfx-psu-uk-cp-9020186-uk#tab-techspecs)    |
| **SSD**         | Samsung 970 EVO Plus       | [1TB NVMe M.2](https://www.techpowerup.com/ssd-specs/samsung-970-evo-plus-1-tb.d61)                                                                                                       |
#### Laptop profile:

| Component | Model                      | Details                                                     |
| :-------- | :------------------------- | :---------------------------------------------------------- |
| **Model** | Slimbook EXCALIBUR-16-AMD7 | [Product Page](https://slimbook.com/en/excalibur-r7-7840hs) |
| **CPU**   | AMD Ryzen 7 7840HS         | 8 Cores / 16 Threads @ 5.14 GHz                             |
| **GPU**   | AMD Radeon 780M            | Integrated Graphics                                         |

---
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

---
## Development standards

This repository adheres to strict scripting standards to maintain stability:

- **Shell:** `zsh` is used for all system logic and configuration.
- **Idempotency:** Post-install scripts are designed to be safe to re-run to repair configuration drift.
- **Safety:** All zsh scripts utilise `setopt ERR_EXIT NO_UNSET PIPE_FAIL`.
- **Formatting:** Scripts utilise compact layouts with double-dotted line separators for readability (see [TEMPLATES](./Scripts/TEMPLATES) folder))

---
## License and disclaimer

This is a personal configuration repository provided "as-is". No warranty is implied. Use these scripts at your own risk.
