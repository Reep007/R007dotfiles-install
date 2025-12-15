#!/usr/bin/env bash
# R007-dotfiles — Pro Installer (ZenForge REMOVED, Production Ready)
# Usage: curl -fsSL https://raw.githubusercontent.com/Reep007/R007-dotfiles/main/install-no-zenforge.sh | bash -s -- [options]

set -euo pipefail
shopt -s inherit_errexit

# -------------------- Configuration --------------------
DOTFILES_REPO="https://github.com/Reep007/R007-dotfiles.git"
DOTFILES_DIR="$HOME/R007-dotfiles"
AUR_BUILD_BASE="${AUR_BUILD_BASE:-$HOME/.cache/aur-builds}"
LOCKFILE="/tmp/r007-installer.lock"
LOG_FILE="$HOME/r007-install-$(date +%Y%m%d_%H%M%S)-$.log"

# Flags
DRY_RUN=false
NO_CONFIRM=false
VERBOSE_DRY_RUN=false
CI_MODE=false

# Tracking for cleanup
SUDO_KEEPALIVE_PID=""
LAST_BACKUP=""

# Installation tracking
declare -A INSTALL_SUMMARY=(
  [system_updated]=false
  [paru_installed]=false
  [official_packages]=false
  [aur_packages]=false
  [dotfiles_applied]=false
  [shell_configured]=false
  [services_enabled]=false
)
WARNINGS_COUNT=0

# Package counters
OFFICIAL_PKG_COUNT=0
AUR_PKG_COUNT=0

# -------------------- Package Definitions --------------------
OFFICIAL_PKGS=(
  hyprland waybar hyprpaper swww kitty hypridle hyprlock
  wofi dunst grim slurp wl-clipboard cliphist xdg-user-dirs
  thunar thunar-archive-plugin tumbler gvfs gvfs-mtp gvfs-smb
  nwg-look qt5ct kvantum qt5-wayland qt6-wayland
  xdg-desktop-portal-hyprland xdg-desktop-portal-gtk
  ttf-jetbrains-mono-nerd lsd btop
  python python-pillow python-pywal python-gobject tk
  network-manager-applet polkit-gnome mpv nano obsidian
  jq nodejs npm pacman-contrib
  zsh zsh-completions
  sddm
)

AUR_PKGS=(
  brave-bin
  nordic-theme-git
  wpgtk-git
  themix-full-git
  oh-my-posh
)

# -------------------- CLI parsing --------------------
for arg in "$@"; do
  case "$arg" in
    --dry-run|--test)  DRY_RUN=true ;;
    --no-confirm|-y)   NO_CONFIRM=true ;;
    --verbose)         VERBOSE_DRY_RUN=true ;;
    --ci)              CI_MODE=true; DRY_RUN=true; NO_CONFIRM=true ;;
    --help|-h)
      cat <<'EOF'
Usage: install-no-zenforge.sh [OPTIONS]

OPTIONS:
  --dry-run, --test      Preview everything (no changes made)
  --no-confirm, -y       Auto-yes to all prompts
  --verbose              Show detailed output in dry-run mode
  --ci                   CI mode (non-interactive, dry-run, for testing)
  --help, -h             Show this help message
EOF
      exit 0
      ;;
    *)
      echo "Unknown option: $arg" >&2
      exit 1
      ;;
  esac
done

# -------------------- Colors & Logging --------------------
RED='\033[1;31m'; GREEN='\033[1;32m'; CYAN='\033[1;36m'; YELLOW='\033[1;33m'; NC='\033[0m'
info()    { printf "${CYAN}[INFO]${NC}   %b\n" "$*"; }
success() { printf "${GREEN}[OK]${NC}      %b\n" "$*"; }
warn()    { printf "${YELLOW}[WARN]${NC}    %b\n" "$*"; ((WARNINGS_COUNT++)); }
error()   { printf "${RED}[ERROR]${NC}  %b\n" "$*" >&2; exit 1; }

exec > >(tee -a "$LOG_FILE") 2>&1

# -------------------- Safe runner --------------------
run() {
  if [[ "$DRY_RUN" == true ]]; then
    printf "${YELLOW}[DRY-RUN]${NC} %s\n" "$*"
    return 0
  fi
  "$@"
}

# -------------------- Cleanup --------------------
tmpdirs=()
cleanup() {
  local exit_code=$?
  [[ -n "$SUDO_KEEPALIVE_PID" ]] && kill "$SUDO_KEEPALIVE_PID" 2>/dev/null || true
  rm -f "$LOCKFILE" 2>/dev/null || true
  for d in "${tmpdirs[@]:-}"; do
    [[ -d "$d" ]] && rm -rf "$d" 2>/dev/null || true
  done
  if [[ $exit_code -ne 0 && -n "$LAST_BACKUP" && -d "$LAST_BACKUP" ]]; then
    warn "Script failed. Restore with:"
    warn "  rm -rf ~/.config && mv $LAST_BACKUP ~/.config"
  fi
  exit $exit_code
}
trap cleanup EXIT ERR INT TERM

# -------------------- Helpers --------------------
confirm() {
  [[ "$NO_CONFIRM" == true || "$DRY_RUN" == true ]] && return 0
  printf "${CYAN}?${NC} %s [Y/n] " "${1:-Continue?}"
  read -r -t 60 ans || ans="y"
  [[ "$ans" =~ ^[Nn]$ ]] && return 1 || return 0
}

banner() {
  printf "${CYAN}"
  cat <<'EOF'
╔══════════════════════════════════════════════════════════╗
║        R007-dotfiles Pro Installer — Ready to Rice       ║
╚══════════════════════════════════════════════════════════╝
EOF
  printf "${NC}\n"
}

check_not_root() {
  [[ $EUID -eq 0 ]] && error "Do not run this script as root"
}

# -------------------- Preflight --------------------
prepare() {
  check_not_root
  [[ -f /etc/arch-release ]] || error "Arch Linux only"

  exec 200>"$LOCKFILE"
  flock -n 200 || error "Another installer is running"

  banner
  [[ "$DRY_RUN" == true ]] && info "DRY-RUN mode enabled"
  info "Log: $LOG_FILE"

  confirm "Start the rice installation?" || error "Aborted"

  if [[ "$DRY_RUN" == false ]]; then
    sudo -v
    ( while true; do sudo -n true || exit; sleep 50; kill -0 "$$" 2>/dev/null || exit; done ) &
    SUDO_KEEPALIVE_PID=$!
  fi

  run mkdir -p "$AUR_BUILD_BASE" "$HOME/.local/bin" "$HOME/.zsh"
}

# -------------------- Steps --------------------
system_update() {
  info "Updating system..."
  run sudo pacman -Sy --noconfirm --needed archlinux-keyring || true
  run sudo pacman -Syu --noconfirm
  INSTALL_SUMMARY[system_updated]=true
}

install_paru() {
  command -v paru >/dev/null && return
  info "Installing paru..."
  run sudo pacman -S --noconfirm --needed base-devel git
  local build_dir
  build_dir=$(mktemp -d "$AUR_BUILD_BASE/paru.XXXX")
  tmpdirs+=("$build_dir")
  run git clone https://aur.archlinux.org/paru.git "$build_dir"
  (cd "$build_dir" && run makepkg -fsri --noconfirm)
  INSTALL_SUMMARY[paru_installed]=true
}

install_official_packages() {
  OFFICIAL_PKG_COUNT=${#OFFICIAL_PKGS[@]}
  run sudo pacman -S --noconfirm --needed "${OFFICIAL_PKGS[@]}"
  run xdg-user-dirs-update
  INSTALL_SUMMARY[official_packages]=true
}

install_aur_packages() {
  command -v paru >/dev/null || return
  AUR_PKG_COUNT=${#AUR_PKGS[@]}
  run paru -S --noconfirm --needed "${AUR_PKGS[@]}" || true
  INSTALL_SUMMARY[aur_packages]=true
}

apply_dotfiles() {
  info "Applying dotfiles..."
  [[ -d "$DOTFILES_DIR/.git" ]] || run git clone "$DOTFILES_REPO" "$DOTFILES_DIR"

  if [[ "$DRY_RUN" == false && -d "$HOME/.config" ]]; then
    LAST_BACKUP="$HOME/.config_backup_$(date +%Y%m%d_%H%M%S)"
    cp -a "$HOME/.config" "$LAST_BACKUP"
  fi

  for plugin in zsh-autosuggestions zsh-syntax-highlighting; do
    [[ -d "$HOME/.zsh/$plugin" ]] || run git clone https://github.com/zsh-users/$plugin "$HOME/.zsh/$plugin"
  done

  rsync -a "$DOTFILES_DIR/.config/" "$HOME/.config/"
  rsync -a "$DOTFILES_DIR/.local/" "$HOME/.local/"
  INSTALL_SUMMARY[dotfiles_applied]=true
}

configure_shell() {
  command -v zsh >/dev/null || return
  [[ "$SHELL" == */zsh ]] && return
  confirm "Change default shell to zsh?" && run sudo chsh -s "$(command -v zsh)" "$USER" && INSTALL_SUMMARY[shell_configured]=true
}

enable_services() {
  run sudo systemctl enable --now NetworkManager || true
  run sudo systemctl enable sddm || true
  INSTALL_SUMMARY[services_enabled]=true
}

print_summary() {
  [[ "$DRY_RUN" == true ]] && return
  echo
  info "Installation summary:"
  for k in "${!INSTALL_SUMMARY[@]}"; do
    printf "  %-22s %s\n" "$k" "${INSTALL_SUMMARY[$k]}"
  done
  info "Total official packages: $OFFICIAL_PKG_COUNT"
  info "Total AUR packages: $AUR_PKG_COUNT"
  [[ $WARNINGS_COUNT -gt 0 ]] && info "Warnings encountered: $WARNINGS_COUNT"
}

finalize() {
  clear
  cat <<'EOF'
╔══════════════════════════════════════════════════════════╗
║          R007 Rice — Installation Complete!             ║
╚══════════════════════════════════════════════════════════╝
EOF
  print_summary
  info "Reboot recommended"
}

main() {
  prepare
  system_update
  install_paru
  install_official_packages
  install_aur_packages
  apply_dotfiles
  configure_shell
  enable_services
  finalize
}

main

