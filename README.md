# AMD Linux Setup

This repository contains my personal setup scripts and configurations for installing and configuring Arch Linux on my all-AMD desktop and laptop. The scripts and settings are tailored to my specific hardware and preferences, aiming to streamline the installation and post-installation process.

### [Get Started](1-Install/1.1-USB.md)

## Purpose

- **Automated Installation:** Streamlines the Arch Linux installation using a custom `archinstall` JSON configuration.
    
- **AMD Optimization:** Configures system-level enhancements for Ryzen and Radeon hardware, including kernel parameters, makepkg optimizations (`-march=native`), and ZRAM configuration.
    
- **KDE Plasma Customisation:** Enforces a consistent "Darkly/Breeze" visual identity with strict window rules, custom theming, and application-specific layouts.
    
- **Media & Gaming Stack:** Automates the deployment of a media server stack (*arr suite, Jellyfin) and gaming tools (Steam, Lutris, Sunshine) specifically for the desktop profile.

## Compatibility

This setup is strictly tuned for the following hardware profiles:

- **Desktop:** AMD Ryzen 7 7800X3D CPU / Radeon RX 7900 XT GPU.
    
- **Laptop:** AMD Ryzen 7 7840HS CPU / Radeon 780M Integrated Graphics.
    
- **Warning:** These scripts contain hardcoded kernel parameters (e.g. `amdgpu.ppfeaturemask`) that may cause instability on non-AMD hardware.

## Usage

**IMPORTANT WARNING**

These scripts are highly opinionated and include hardcoded hardware configurations. **Do NOT run them blindly** on different hardware. You must review and modify specific flags (especially in `desktop_setup.sh` and `archinstall_config.json`) to match your system.

This repository is **intended for personal use**. However, others are welcome to explore the scripts and adapt them for their own systems.

The setup follows a tiered execution order:
1.  **Bootstrap:** `system_install.sh` (runs `archinstall`).
2.  **User Environment:** `home_setup.sh` (configures Zsh, dotfiles, and directories).
3.  **Core Configuration:** `core_setup.sh` (installs base packages, yay, and optimises makepkg).
4.  **Device Tuning:** Automatically branches to `desktop_setup.sh` or `laptop_setup.sh`.

### Notes

- **Clean Install Required:** The scripts assume a fresh Arch Linux environment.
    
- **Manual Secrets:** Secure configuration for services (e.g., Jellyfin API keys, Slskd credentials) requires manual entry after the scripts complete.
    
- **Filesystem Assumptions:** The installation script assumes a Btrfs layout with specific subvolumes (e.g. `@games`).

## License

This repository is provided as-is, without any warranty or guarantee of functionality. Use at your own risk.

## Contributions

As this is a personal setup, I am not actively seeking contributions. However, feedback and suggestions are always welcome.
