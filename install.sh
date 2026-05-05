#!/usr/bin/env bash
# Debian translation of nixos-configuration (ilyamiro/VantixOS)
# Hyprland + Quickshell + NVIDIA PRIME + AMD
# Run as root on a fresh Debian 12 (Bookworm) install

set -euo pipefail

USERNAME="ilyamiro"
USERHOME="/home/${USERNAME}"
TIMEZONE="Europe/Copenhagen"
HOSTNAME_VAL="ilyamiro"
REPO_DIR="$(cd "$(dirname "$0")" && pwd)"
BUILD_DIR="/tmp/hypr-build"

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'
info()  { echo -e "${GREEN}[+]${NC} $*"; }
warn()  { echo -e "${YELLOW}[!]${NC} $*"; }
die()   { echo -e "${RED}[✗]${NC} $*"; exit 1; }

[[ $EUID -ne 0 ]] && die "Run as root"

# ──────────────────────────────────────────────────────────────────────────────
# SYSTEM BASE
# ──────────────────────────────────────────────────────────────────────────────

info "Setting hostname, timezone, locale"
hostnamectl set-hostname "$HOSTNAME_VAL"
timedatectl set-timezone "$TIMEZONE"
localectl set-locale LANG=en_US.UTF-8
sed -i 's/^# en_US.UTF-8/en_US.UTF-8/' /etc/locale.gen
locale-gen

info "Configuring apt sources"
cat > /etc/apt/sources.list <<'EOF'
deb http://deb.debian.org/debian bookworm main contrib non-free non-free-firmware
deb http://deb.debian.org/debian bookworm-updates main contrib non-free non-free-firmware
deb http://security.debian.org/debian-security bookworm-security main contrib non-free non-free-firmware
deb http://deb.debian.org/debian bookworm-backports main contrib non-free non-free-firmware
EOF

apt-get update -qq
apt-get upgrade -y -qq

# ──────────────────────────────────────────────────────────────────────────────
# SYSTEM PACKAGES
# ──────────────────────────────────────────────────────────────────────────────

info "Installing system packages"
apt-get install -y \
  wget curl git build-essential pkg-config cmake ninja-build meson \
  zsh fzf direnv \
  neovim \
  kitty \
  btop htop \
  mpv \
  ffmpeg \
  python3 python3-pip python3-venv \
  taskwarrior \
  zbar-tools \
  p7zip-full \
  fastfetch \
  inotify-tools \
  file \
  cbonsai \
  jq bc socat tree ripgrep fd-find imagemagick \
  \
  pipewire pipewire-alsa pipewire-pulse pipewire-jack \
  wireplumber libspa-0.2-modules \
  pavucontrol pamixer \
  alsa-utils pulseaudio-utils \
  easyeffects \
  \
  network-manager network-manager-gnome \
  blueman bluez \
  iw \
  \
  cups \
  openssh-server \
  \
  power-profiles-daemon \
  acpi \
  brightnessctl \
  \
  flatpak \
  xdg-desktop-portal-gtk xdg-utils \
  \
  gdm3 \
  gnome-tweaks dconf-cli \
  adwaita-icon-theme adw-gtk3 \
  \
  grim slurp \
  wl-clipboard \
  playerctl \
  libnotify-bin \
  \
  libvirt-daemon-system virt-manager \
  qemu-system-x86 \
  \
  telegram-desktop \
  qbittorrent \
  libreoffice-qt \
  hunspell hunspell-ru hunspell-en-us \
  \
  fonts-noto fonts-liberation \
  \
  lm-sensors \
  \
  plymouth plymouth-themes \
  \
  qt6-base-dev qt6-declarative-dev qt6-wayland-dev \
  libqt6svg6-dev qt6-multimedia-dev \
  libqt6websockets6-dev libqt6webengine-dev \
  qt5ct qt6ct \
  libsForQt5.qt5ct 2>/dev/null || true \
  \
  libwayland-dev libwayland-client0 wayland-protocols \
  libxkbcommon-dev libxkbcommon-x11-dev \
  libpixman-1-dev \
  libegl-dev libgles2-mesa-dev libgbm-dev libdrm-dev \
  libudev-dev libinput-dev \
  libx11-dev libxfixes-dev libxxhash-dev libxcb-util-dev \
  libxcb-composite0-dev libxcb-icccm4-dev libxcb-image0-dev \
  libxcb-present-dev libxcb-render0-dev libxcb-renderutil0-dev \
  libxcb-shape0-dev libxcb-ewmh-dev libxcb-dri3-dev \
  libxcb-res0-dev \
  libdisplay-info-dev \
  libliftoff-dev \
  libpipewire-0.3-dev \
  libpam0g-dev \
  libgl-dev libglu1-mesa-dev \
  libseat-dev \
  libdecor-0-dev \
  libvulkan-dev libvulkan1 \
  glslang-tools \
  hwdata \
  libtomlplusplus-dev \
  libudis86-dev \
  cargo rustc \
  golang \
  \
  systemd-resolved \
  rsync \
  2>/dev/null || warn "Some packages unavailable, continuing"

# ──────────────────────────────────────────────────────────────────────────────
# USER SETUP
# ──────────────────────────────────────────────────────────────────────────────

info "Creating user ${USERNAME}"
if ! id "$USERNAME" &>/dev/null; then
  useradd -m -s /usr/bin/zsh -c "$USERNAME" "$USERNAME"
fi
usermod -aG sudo,video,audio,netdev,libvirt,input,plugdev,bluetooth "$USERNAME"

# NOPASSWD sudo (mirrors NixOS security.sudo.extraRules)
cat > /etc/sudoers.d/90-"$USERNAME"-nopasswd <<EOF
${USERNAME} ALL=(ALL) NOPASSWD: ALL
EOF
chmod 0440 /etc/sudoers.d/90-"$USERNAME"-nopasswd

# ──────────────────────────────────────────────────────────────────────────────
# NVIDIA PRIME (AMD iGPU + NVIDIA dGPU)
# ──────────────────────────────────────────────────────────────────────────────

info "Installing NVIDIA drivers + PRIME"
apt-get install -y -t bookworm-backports \
  nvidia-driver nvidia-driver-libs nvidia-settings \
  nvidia-prime \
  firmware-misc-nonfree \
  2>/dev/null || apt-get install -y nvidia-driver nvidia-settings nvidia-prime

# PRIME offload wrapper (mirrors programs.hyprland prime.offload)
cat > /usr/local/bin/prime-run <<'EOF'
#!/bin/bash
__NV_PRIME_RENDER_OFFLOAD=1 \
__NV_PRIME_RENDER_OFFLOAD_PROVIDER=NVIDIA-G0 \
__GLX_VENDOR_LIBRARY_NAME=nvidia \
__VK_LAYER_NV_optimus=NVIDIA_only \
exec "$@"
EOF
chmod +x /usr/local/bin/prime-run

# ──────────────────────────────────────────────────────────────────────────────
# KERNEL PARAMETERS (mirrors boot.kernelParams + boot.kernel.sysctl)
# ──────────────────────────────────────────────────────────────────────────────

info "Configuring kernel parameters"
sed -i 's/^GRUB_CMDLINE_LINUX_DEFAULT=.*/GRUB_CMDLINE_LINUX_DEFAULT="quiet splash loglevel=3 rd.udev.log_level=3 udev.log_priority=3 amd_pstate=active tsc=reliable"/' \
  /etc/default/grub
update-grub

info "Configuring sysctl (BBR + buffer tuning)"
cat > /etc/sysctl.d/99-vantixos.conf <<'EOF'
net.ipv4.tcp_congestion_control = bbr
net.core.default_qdisc = fq
net.core.wmem_max = 1073741824
net.core.rmem_max = 1073741824
net.ipv4.tcp_rmem = 4096 87380 1073741824
net.ipv4.tcp_wmem = 4096 87380 1073741824
EOF
sysctl --system

# BBR module on boot
echo "tcp_bbr" >> /etc/modules-load.d/bbr.conf

# CPU governor (mirrors powerManagement.cpuFreqGovernor = "performance")
apt-get install -y cpufrequtils
echo 'GOVERNOR="performance"' > /etc/default/cpufrequtils
systemctl enable cpufrequtils 2>/dev/null || true

# ──────────────────────────────────────────────────────────────────────────────
# PIPEWIRE / AUDIO
# ──────────────────────────────────────────────────────────────────────────────

info "Enabling PipeWire systemd user services"
# Enabled per-user at login via systemd --user; set up the enable links
sudo -u "$USERNAME" XDG_RUNTIME_DIR="/run/user/$(id -u "$USERNAME")" \
  systemctl --user enable pipewire pipewire-pulse wireplumber 2>/dev/null || true

# Ensure PulseAudio is disabled system-wide
systemctl --global disable pulseaudio.service pulseaudio.socket 2>/dev/null || true
# PipeWire socket activation
mkdir -p /etc/systemd/user/default.target.wants
ln -sf /usr/lib/systemd/user/pipewire.socket \
  /etc/systemd/user/default.target.wants/pipewire.socket 2>/dev/null || true

# ──────────────────────────────────────────────────────────────────────────────
# BLUETOOTH / PRINTING / SSH
# ──────────────────────────────────────────────────────────────────────────────

systemctl enable bluetooth cups ssh NetworkManager power-profiles-daemon

# WiFi powersave off (mirrors networking.networkmanager.wifi.powersave = false)
mkdir -p /etc/NetworkManager/conf.d
cat > /etc/NetworkManager/conf.d/wifi-powersave.conf <<'EOF'
[connection]
wifi.powersave = 2
EOF

# ──────────────────────────────────────────────────────────────────────────────
# FLATPAK
# ──────────────────────────────────────────────────────────────────────────────

info "Configuring Flatpak"
flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo

# ──────────────────────────────────────────────────────────────────────────────
# RUST TOOLCHAIN (latest stable for cargo installs)
# ──────────────────────────────────────────────────────────────────────────────

info "Installing Rust toolchain for user ${USERNAME}"
sudo -u "$USERNAME" bash -c \
  'curl --proto "=https" --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y --no-modify-path'
CARGO="${USERHOME}/.cargo/bin/cargo"

# ──────────────────────────────────────────────────────────────────────────────
# HYPRLAND ECOSYSTEM (build from source)
# ──────────────────────────────────────────────────────────────────────────────

mkdir -p "$BUILD_DIR"

build_cmake() {
  local name="$1" url="$2"
  info "Building ${name}"
  git clone --depth=1 --recurse-submodules "$url" "${BUILD_DIR}/${name}"
  cmake -S "${BUILD_DIR}/${name}" -B "${BUILD_DIR}/${name}/build" \
    -G Ninja -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX=/usr
  ninja -C "${BUILD_DIR}/${name}/build"
  ninja -C "${BUILD_DIR}/${name}/build" install
}

build_cmake "hyprutils"           "https://github.com/hyprwm/hyprutils"
build_cmake "hyprlang"            "https://github.com/hyprwm/hyprlang"
build_cmake "hyprwayland-scanner" "https://github.com/hyprwm/hyprwayland-scanner"
build_cmake "hyprgraphics"        "https://github.com/hyprwm/hyprgraphics"
build_cmake "hyprcursor"          "https://github.com/hyprwm/hyprcursor"
build_cmake "aquamarine"          "https://github.com/hyprwm/aquamarine"
build_cmake "Hyprland"            "https://github.com/hyprwm/Hyprland"
build_cmake "hypridle"            "https://github.com/hyprwm/hypridle"

# hyprlock uses PAM
info "Building hyprlock"
git clone --depth=1 https://github.com/hyprwm/hyprlock "${BUILD_DIR}/hyprlock"
cmake -S "${BUILD_DIR}/hyprlock" -B "${BUILD_DIR}/hyprlock/build" \
  -G Ninja -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX=/usr
ninja -C "${BUILD_DIR}/hyprlock/build"
ninja -C "${BUILD_DIR}/hyprlock/build" install

# ──────────────────────────────────────────────────────────────────────────────
# QUICKSHELL (build from source, Qt6/QML)
# ──────────────────────────────────────────────────────────────────────────────

info "Building quickshell"
git clone --depth=1 --recurse-submodules \
  https://github.com/quickshell-mirror/quickshell "${BUILD_DIR}/quickshell"
cmake -S "${BUILD_DIR}/quickshell" -B "${BUILD_DIR}/quickshell/build" \
  -G Ninja \
  -DCMAKE_BUILD_TYPE=Release \
  -DCMAKE_INSTALL_PREFIX=/usr \
  -DUSE_QT6=ON
ninja -C "${BUILD_DIR}/quickshell/build"
ninja -C "${BUILD_DIR}/quickshell/build" install

# ──────────────────────────────────────────────────────────────────────────────
# BINARY RELEASES (swww, matugen, cliphist, satty, swappy, rofi-wayland)
# ──────────────────────────────────────────────────────────────────────────────

info "Installing binary releases from GitHub"

ARCH="x86_64"

gh_latest() {
  # Usage: gh_latest owner/repo pattern
  curl -sL "https://api.github.com/repos/$1/releases/latest" \
    | jq -r ".assets[] | select(.name | test(\"$2\")) | .browser_download_url" \
    | head -1
}

# swww
SWWW_URL=$(gh_latest "LGFae/swww" "swww-x86_64-unknown-linux-musl.tar.gz")
curl -sL "$SWWW_URL" | tar -xz -C /usr/local/bin/ --strip-components=0 \
  swww swww-daemon 2>/dev/null || \
  sudo -u "$USERNAME" "$CARGO" install swww

# matugen
MATUGEN_URL=$(gh_latest "InioX/matugen" "matugen-x86_64-unknown-linux-gnu")
if [[ -n "$MATUGEN_URL" ]]; then
  curl -sL "$MATUGEN_URL" -o /usr/local/bin/matugen
  chmod +x /usr/local/bin/matugen
else
  sudo -u "$USERNAME" "$CARGO" install matugen
fi

# cliphist
CLIPHIST_URL=$(gh_latest "sentriz/cliphist" "linux_amd64")
if [[ -n "$CLIPHIST_URL" ]]; then
  curl -sL "$CLIPHIST_URL" -o /usr/local/bin/cliphist
  chmod +x /usr/local/bin/cliphist
fi

# satty (screenshot annotation)
SATTY_URL=$(gh_latest "gabm/Satty" "satty-x86_64-linux.tar.gz")
if [[ -n "$SATTY_URL" ]]; then
  curl -sL "$SATTY_URL" | tar -xz -C /usr/local/bin/
else
  sudo -u "$USERNAME" "$CARGO" install satty
fi

# swappy
apt-get install -y swappy 2>/dev/null || \
  sudo -u "$USERNAME" "$CARGO" install swappy 2>/dev/null || \
  warn "swappy not found, build manually from https://github.com/jtheoof/swappy"

# rofi-wayland
apt-get install -y rofi-wayland 2>/dev/null || \
  apt-get install -y rofi 2>/dev/null || \
  warn "rofi-wayland not in apt; install from https://github.com/lbonn/rofi"

# wl-screenrec
WL_SCREENREC_URL=$(gh_latest "russelltg/wl-screenrec" "wl-screenrec")
if [[ -n "$WL_SCREENREC_URL" ]]; then
  curl -sL "$WL_SCREENREC_URL" -o /usr/local/bin/wl-screenrec
  chmod +x /usr/local/bin/wl-screenrec
fi

# gpu-screen-recorder
apt-get install -y gpu-screen-recorder 2>/dev/null || \
  flatpak install -y flathub com.dec05eba.gpu_screen_recorder 2>/dev/null || \
  warn "gpu-screen-recorder: install flatpak com.dec05eba.gpu_screen_recorder"

# networkmanager_dmenu
pip3 install networkmanager-dmenu 2>/dev/null || \
  pip3 install networkmanager_dmenu 2>/dev/null || true

# swayosd
build_cmake "SwayOSD" "https://github.com/ErikReider/SwayOSD" || \
  warn "SwayOSD build failed; install manually"

# ──────────────────────────────────────────────────────────────────────────────
# ZSH + OH MY ZSH
# ──────────────────────────────────────────────────────────────────────────────

info "Installing Oh My Zsh for ${USERNAME}"
chsh -s /usr/bin/zsh "$USERNAME"
sudo -u "$USERNAME" bash -c \
  'RUNZSH=no CHSH=no sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"'

# zsh-autosuggestions + zsh-syntax-highlighting (mirrors NixOS plugins)
ZSH_CUSTOM="${USERHOME}/.oh-my-zsh/custom"
sudo -u "$USERNAME" git clone --depth=1 \
  https://github.com/zsh-users/zsh-autosuggestions \
  "${ZSH_CUSTOM}/plugins/zsh-autosuggestions"
sudo -u "$USERNAME" git clone --depth=1 \
  https://github.com/zsh-users/zsh-syntax-highlighting \
  "${ZSH_CUSTOM}/plugins/zsh-syntax-highlighting"

# ──────────────────────────────────────────────────────────────────────────────
# DOTFILES DEPLOYMENT
# mirrors: home.file + home.activation.copyHyprConfig
# ──────────────────────────────────────────────────────────────────────────────

info "Deploying dotfiles to ${USERHOME}"

HYPR_CFG="${USERHOME}/.config/hypr"
mkdir -p "${HYPR_CFG}/config" "${HYPR_CFG}/scripts" "${HYPR_CFG}/templates"

# Hyprland configs (config/ dir)
rsync -a "${REPO_DIR}/config/sessions/hyprland/config/"  "${HYPR_CFG}/config/"
rsync -a "${REPO_DIR}/config/sessions/hyprland/scripts/" "${HYPR_CFG}/scripts/"
rsync -a "${REPO_DIR}/config/sessions/hyprland/templates/" "${HYPR_CFG}/templates/"

# Main hyprland.conf → strip /etc/nixos prefix, use ~/.config/hypr
sed "s|/etc/nixos/config/sessions/hyprland/|${HYPR_CFG}/|g" \
  "${REPO_DIR}/config/sessions/hyprland/hyprland.conf" \
  > "${HYPR_CFG}/hyprland.conf"

# Hypridle config (generated from hypridle.nix)
mkdir -p "${USERHOME}/.config/hypr"
cat > "${USERHOME}/.config/hypr/hypridle.conf" <<'EOF'
general {
    lock_cmd = quickshell -p ~/.config/hypr/scripts/quickshell/Lock.qml
    before_sleep_cmd = loginctl lock-session
    after_sleep_cmd = hyprctl dispatch dpms on
}

listener {
    timeout = 300
    on-timeout = loginctl lock-session
}

listener {
    timeout = 900
    on-timeout = systemctl suspend
}
EOF

# kitty config
mkdir -p "${USERHOME}/.config/kitty"
rsync -a "${REPO_DIR}/config/programs/kitty/" "${USERHOME}/.config/kitty/"

# rofi config
mkdir -p "${USERHOME}/.config/rofi"
cp "${REPO_DIR}/config/programs/rofi/config.rasi" "${USERHOME}/.config/rofi/"

# cava config
mkdir -p "${USERHOME}/.config/cava"
cp "${REPO_DIR}/config/programs/cava/config" "${USERHOME}/.config/cava/"

# neovim config
mkdir -p "${USERHOME}/.config/nvim"
rsync -a "${REPO_DIR}/config/programs/neovim/nvim/" "${USERHOME}/.config/nvim/"

# matugen config + templates
mkdir -p "${USERHOME}/.config/matugen/templates"
cp "${REPO_DIR}/config/programs/matugen/config.toml" "${USERHOME}/.config/matugen/"
rsync -a "${REPO_DIR}/config/programs/matugen/templates/" \
  "${USERHOME}/.config/matugen/templates/"

# fonts (mirrors home.file ".local/share/fonts/")
mkdir -p "${USERHOME}/.local/share/fonts"
rsync -a "${REPO_DIR}/config/fonts/" "${USERHOME}/.local/share/fonts/"
fc-cache -f "${USERHOME}/.local/share/fonts"

chown -R "${USERNAME}:${USERNAME}" \
  "${USERHOME}/.config" "${USERHOME}/.local"

# ──────────────────────────────────────────────────────────────────────────────
# ZSHRC (mirrors programs.zsh settings + aliases)
# ──────────────────────────────────────────────────────────────────────────────

info "Writing .zshrc"
cat > "${USERHOME}/.zshrc" <<'ZSHRC_EOF'
export ZSH="${HOME}/.oh-my-zsh"
ZSH_THEME="robbyrussell"

plugins=(git zsh-autosuggestions zsh-syntax-highlighting)

source "${ZSH}/oh-my-zsh.sh"

HISTSIZE=10000
HISTFILE="${HOME}/.zsh_history"
setopt HIST_IGNORE_ALL_DUPS

# Aliases (translated from NixOS shellAliases)
alias edit='sudo -E nvim -n'
alias update='sudo apt-get update && sudo apt-get upgrade -y'
alias stop='shutdown now'
alias out='loginctl terminate-user ${USER}'

# Session variables (translated from home.sessionVariables)
export hypr="${HOME}/.config/hypr"
export programs="${HOME}/.config"
export NIXOS_OZONE_WL=1

# Cargo path
export PATH="${HOME}/.cargo/bin:${PATH}"
ZSHRC_EOF

# source user's init script from the repo
cat "${REPO_DIR}/config/programs/zsh/zsh-init.sh" >> "${USERHOME}/.zshrc"
chown "${USERNAME}:${USERNAME}" "${USERHOME}/.zshrc"

# ──────────────────────────────────────────────────────────────────────────────
# ENVIRONMENT VARIABLES
# mirrors: env = NIXOS_OZONE_WL,1
# ──────────────────────────────────────────────────────────────────────────────

cat >> /etc/environment <<'EOF'
NIXOS_OZONE_WL=1
QT_QPA_PLATFORM=wayland
QT_QPA_PLATFORMTHEME=qt6ct
SDL_VIDEODRIVER=wayland
_JAVA_AWT_WM_NONREPARENTING=1
EOF

# ──────────────────────────────────────────────────────────────────────────────
# PLYMOUTH (mirrors boot.plymouth custom theme)
# ──────────────────────────────────────────────────────────────────────────────

info "Installing Plymouth theme"
THEME_DIR="/usr/share/plymouth/themes/simple"
mkdir -p "$THEME_DIR"
cp -r "${REPO_DIR}/config/programs/plymouth/simple/." "$THEME_DIR/"

# Fix @out@ placeholder used by the Nix mkDerivation → real path
sed -i "s|@out@|${THEME_DIR}|g" "${THEME_DIR}/simple.plymouth"

plymouth-set-default-theme -R simple

# Boot splash in /etc/default/grub is already set above (quiet splash)

# ──────────────────────────────────────────────────────────────────────────────
# GDM / DISPLAY MANAGER
# mirrors: services.displayManager.gdm.enable + services.desktopManager.gnome.enable
# ──────────────────────────────────────────────────────────────────────────────

info "Configuring GDM"
systemctl enable gdm

# Hyprland Wayland session for GDM
cat > /usr/share/wayland-sessions/hyprland.desktop <<'EOF'
[Desktop Entry]
Name=Hyprland
Comment=An intelligent dynamic tiling Wayland compositor
Exec=Hyprland
Type=Application
EOF

# ──────────────────────────────────────────────────────────────────────────────
# LOGIND (mirrors services.logind.settings.Login.HandlePowerKey = "ignore")
# ──────────────────────────────────────────────────────────────────────────────

mkdir -p /etc/systemd/logind.conf.d
cat > /etc/systemd/logind.conf.d/powerkey.conf <<'EOF'
[Login]
HandlePowerKey=ignore
EOF

# ──────────────────────────────────────────────────────────────────────────────
# VIRTUALIZATION (mirrors virtualisation.libvirtd.enable)
# ──────────────────────────────────────────────────────────────────────────────

systemctl enable libvirtd
usermod -aG libvirt "$USERNAME"

# ──────────────────────────────────────────────────────────────────────────────
# EASYEFFECTS AUTOSTART
# mirrors: services.easyeffects.enable (home-manager)
# ──────────────────────────────────────────────────────────────────────────────

mkdir -p "${USERHOME}/.config/systemd/user"
cat > "${USERHOME}/.config/systemd/user/easyeffects.service" <<'EOF'
[Unit]
Description=EasyEffects daemon
After=pipewire.service

[Service]
ExecStart=/usr/bin/easyeffects --gapplication-service
Restart=on-failure

[Install]
WantedBy=default.target
EOF
chown -R "${USERNAME}:${USERNAME}" "${USERHOME}/.config/systemd"
sudo -u "$USERNAME" systemctl --user enable easyeffects 2>/dev/null || true

# ──────────────────────────────────────────────────────────────────────────────
# HYPRLAND AUTOSTART FIX
# Strip NixOS-specific exec-once references that don't apply
# The config/sessions/hyprland/config/autostart.conf is already plain
# and uses ~/.config/hypr/ paths, so no changes needed.
# ──────────────────────────────────────────────────────────────────────────────

# ──────────────────────────────────────────────────────────────────────────────
# OPTIONAL FLATPAK APPS
# mirrors: bottles, obsidian (no .deb in apt)
# ──────────────────────────────────────────────────────────────────────────────

info "Installing Flatpak apps"
flatpak install -y flathub \
  com.usebottles.bottles \
  md.obsidian.Obsidian \
  2>/dev/null || warn "Flatpak installs failed; run manually after reboot"

# ──────────────────────────────────────────────────────────────────────────────
# DONE
# ──────────────────────────────────────────────────────────────────────────────

info "Done. Reboot, then select Hyprland from GDM."
info "Run 'matugen image <wallpaper>' to generate your theme colors."
warn "NVIDIA: verify Bus IDs with 'lspci | grep -E \"VGA|3D\"' and update"
warn "  ~/.config/hypr/config/env.conf if your Bus IDs differ from PCI:1:0:0/PCI:4:0:0"
