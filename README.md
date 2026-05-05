# Debian Port — ilyamiro/VantixOS Hyprland Config

Translated from NixOS `configuration.nix` + `home.nix` for Debian 12 (Bookworm).

## What changed vs NixOS

| NixOS mechanism | Debian equivalent |
|---|---|
| `environment.systemPackages` | `apt-get install` |
| `home-manager` | manual dotfile rsync |
| `programs.zsh` module | `.zshrc` + oh-my-zsh |
| `wayland.windowManager.hyprland` | build from source |
| `services.hypridle` | `hypridle.conf` + autostart |
| `services.easyeffects` | systemd user service |
| `boot.plymouth` theme | `/usr/share/plymouth/themes/simple` |
| `boot.kernelParams` | `GRUB_CMDLINE_LINUX_DEFAULT` |
| `boot.kernel.sysctl` | `/etc/sysctl.d/99-vantixos.conf` |
| `hardware.nvidia` PRIME | `nvidia-prime` + `prime-run` wrapper |
| `powerManagement.cpuFreqGovernor` | `cpufrequtils` |
| `services.logind.settings` | `/etc/systemd/logind.conf.d/` |
| `nixpkgs.config.allowUnfree` | `contrib non-free` in sources.list |
| `nix.settings.experimental-features` | N/A |
| `nix.gc` | N/A |

## Layout

```
install.sh                          ← run as root on fresh Debian 12
config/
  sessions/hyprland/
    hyprland.conf                   ← patched (no /etc/nixos paths)
    hypridle.conf                   ← generated from hypridle.nix
    config/
      env.conf                      ← patched (Debian/NVIDIA vars)
      autostart.conf                ← unchanged, paths already use ~/
      monitors.conf, keybindings.conf, rules.conf, settings.conf, variables.conf
    scripts/                        ← unchanged
    templates/                      ← unchanged
  programs/
    kitty/, rofi/, cava/, neovim/   ← deployed to ~/.config/
    matugen/                        ← deployed to ~/.config/matugen/
    zsh/zsh-init.sh                 ← sourced by .zshrc
  fonts/                            ← deployed to ~/.local/share/fonts/
.zshrc                              ← translated from programs.zsh NixOS module
```

## Usage

```bash
sudo bash install.sh
```

The script must run from the repo root (same directory as `config/`).

## Post-install

1. Reboot; select Hyprland from GDM.
2. Run `matugen image <path-to-wallpaper>` once to populate `~/.cache/matugen/`.
3. `swww img <wallpaper>` to set the wallpaper.
4. Verify NVIDIA Bus IDs: `lspci | grep -E "VGA|3D"` — if they differ from
   `PCI:1:0:0` / `PCI:4:0:0`, update `~/.config/hypr/config/env.conf`.

## Not included / manual steps

- **obsidian** — `flatpak install flathub md.obsidian.Obsidian`
- **bottles** — `flatpak install flathub com.usebottles.bottles`
- **gpu-screen-recorder** — `flatpak install flathub com.dec05eba.gpu_screen_recorder`
- **steam** — download .deb from https://store.steampowered.com/about/
- **JDK 8** — `apt-get install openjdk-8-jdk` (via Java PPA if needed)
- **jetbrains IDEA** — download from https://jetbrains.com or via Flatpak
- **fortune / pipes / cbonsai** — `apt-get install fortune-mod cmatrix`
- **papers** — GNOME document viewer; install via Flatpak: `org.gnome.Papers`
- **quickshell** build may require Qt ≥ 6.5; if Bookworm's Qt 6.4.x is too old,
  add backports or pull Qt6 from upstream: https://www.qt.io/offline-installers

## Kernel modules

`tcp_bbr` is loaded via `/etc/modules-load.d/bbr.conf`. The `asus_wmi` param
from the NixOS config is hardware-specific — `asus_wmi` is autoloaded on ASUS
hardware by default on Debian; no explicit config needed.
