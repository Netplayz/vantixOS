export ZSH="${HOME}/.oh-my-zsh"
ZSH_THEME="robbyrussell"

plugins=(git zsh-autosuggestions zsh-syntax-highlighting)

source "${ZSH}/oh-my-zsh.sh"

HISTSIZE=10000
HISTFILE="${HOME}/.zsh_history"
setopt HIST_IGNORE_ALL_DUPS

# ── Aliases (translated from NixOS shellAliases) ──────────────────────────────
alias edit='sudo -E nvim -n'
alias update='sudo apt-get update && sudo apt-get upgrade -y'
alias stop='shutdown now'
alias out='loginctl terminate-user ${USER}'
# 'edconf' and 'gitavail' were NixOS-specific; removed

# ── Session variables ─────────────────────────────────────────────────────────
export hypr="${HOME}/.config/hypr"
export programs="${HOME}/.config"

# ── Path additions ────────────────────────────────────────────────────────────
export PATH="${HOME}/.cargo/bin:${HOME}/.local/bin:${PATH}"

# ── Wayland / OZONE ──────────────────────────────────────────────────────────
export NIXOS_OZONE_WL=1
export ELECTRON_OZONE_PLATFORM_HINT=auto
