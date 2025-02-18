{
    "additional-repositories": [
        "multilib"
    ],
    "archinstall-language": "English",
    "audio_config": {
        "audio": "pipewire"
    },
    "bootloader": "Grub",
    "config_version": "3.0.2",
    "disk_config": {
        "config_type": "default_layout",
        "device_modifications": [
            {
                "device": "/dev/nvme1n1",
                "partitions": [
                    {
                        "btrfs": [],
                        "dev_path": null,
                        "flags": [
                            "boot",
                            "esp"
                        ],
                        "fs_type": "fat32",
                        "mount_options": [],
                        "mountpoint": "/boot",
                        "obj_id": "daee8123-e113-4373-9841-6598d8aa5498",
                        "size": {
                            "sector_size": {
                                "unit": "B",
                                "value": 512
                            },
                            "unit": "GiB",
                            "value": 1
                        },
                        "start": {
                            "sector_size": {
                                "unit": "B",
                                "value": 512
                            },
                            "unit": "MiB",
                            "value": 1
                        },
                        "status": "create",
                        "type": "primary"
                    },
                    {
                        "btrfs": [
                            {
                                "mountpoint": "/",
                                "name": "@"
                            },
                            {
                                "mountpoint": "/home",
                                "name": "@home"
                            },
                            {
                                "mountpoint": "/home/curtis/Games",
                                "name": "@games"
                            },
                            {
                                "mountpoint": "/var/log",
                                "name": "@log"
                            },
                            {
                                "mountpoint": "/var/cache/pacman/pkg",
                                "name": "@pkg"
                            },
                            {
                                "mountpoint": "/.snapshots",
                                "name": "@.snapshots"
                            }
                        ],
                        "dev_path": null,
                        "flags": [],
                        "fs_type": "btrfs",
                        "mount_options": [
                            "compress=zstd"
                        ],
                        "mountpoint": null,
                        "obj_id": "efb19406-b7e8-4e64-9e73-285cdc819fe2",
                        "size": {
                            "sector_size": {
                                "unit": "B",
                                "value": 512
                            },
                            "unit": "B",
                            "value": 999129350144
                        },
                        "start": {
                            "sector_size": {
                                "unit": "B",
                                "value": 512
                            },
                            "unit": "B",
                            "value": 1074790400
                        },
                        "status": "create",
                        "type": "primary"
                    }
                ],
                "wipe": true
            }
        ]
    },
    "disk_encryption": null,
    "hostname": "NCC-1701",
    "kernels": [
        "linux-zen"
    ],
    "locale_config": {
        "kb_layout": "uk",
        "sys_enc": "UTF-8",
        "sys_lang": "en_GB"
    },
    "mirror_config": {
        "custom_mirrors": [],
        "mirror_regions": {
            "United Kingdom": [
                "http://www.mirrorservice.org/sites/ftp.archlinux.org/$repo/os/$arch",
                "https://www.mirrorservice.org/sites/ftp.archlinux.org/$repo/os/$arch",
                "http://lon.mirror.rackspace.com/archlinux/$repo/os/$arch",
                "https://lon.mirror.rackspace.com/archlinux/$repo/os/$arch",
                "http://gb.mirrors.cicku.me/archlinux/$repo/os/$arch",
                "https://gb.mirrors.cicku.me/archlinux/$repo/os/$arch",
                "http://mirrors.ukfast.co.uk/sites/archlinux.org/$repo/os/$arch",
                "https://mirrors.ukfast.co.uk/sites/archlinux.org/$repo/os/$arch",
                "http://archlinux.uk.mirror.allworldit.com/archlinux/$repo/os/$arch",
                "https://archlinux.uk.mirror.allworldit.com/archlinux/$repo/os/$arch",
                "http://mirror.netweaver.uk/archlinux/$repo/os/$arch",
                "https://mirror.netweaver.uk/archlinux/$repo/os/$arch",
                "http://mirrors.melbourne.co.uk/archlinux/$repo/os/$arch",
                "https://mirrors.melbourne.co.uk/archlinux/$repo/os/$arch",
                "https://london.mirror.pkgbuild.com/$repo/os/$arch",
                "https://repo.slithery.uk/$repo/os/$arch",
                "http://mirror.vinehost.net/archlinux/$repo/os/$arch",
                "https://mirror.vinehost.net/archlinux/$repo/os/$arch",
                "https://mirror.st2projects.com/archlinux/$repo/os/$arch",
                "http://mirror.server.net/archlinux/$repo/os/$arch",
                "https://mirror.server.net/archlinux/$repo/os/$arch",
                "https://mirrors.xhosts.co.uk/arch/$repo/os/$arch",
                "http://repo.c48.uk/arch/$repo/os/$arch",
                "https://repo.c48.uk/arch/$repo/os/$arch"
            ]
        }
    },
    "network_config": {
        "type": "nm"
    },
    "ntp": true,
    "packages": [
        "adwaita-fonts",
        "amd-ucode",
        "btrfs-progs",
        "chromium",
        "curl",
        "dosfstools",
        "git",
        "grub-btrfs",
        "kio-admin",
        "linux-zen-headers",
        "mesa-utils",
        "p7zip",
        "reflector",
        "wayland-protocols",
        "zsh"
    ],
    "parallel downloads": 50,
    "profile_config": {
        "gfx_driver": "AMD / ATI (open-source)",
        "greeter": "sddm",
        "profile": {
            "custom_settings": {
                "KDE Plasma": {}
            },
            "details": [
                "KDE Plasma"
            ],
            "main": "Desktop"
        }
    },
    "save_config": null,
    "swap": true,
    "timezone": "Europe/London",
    "uki": false,
    "version": "3.0.2"
}
