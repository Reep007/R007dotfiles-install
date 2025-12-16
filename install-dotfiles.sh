#!/usr/bin/env bash
# R007-dotfiles — Pro Installer (Production Ready, VM/Main Rig Compatible)

set -euo pipefail

# -------------------- Configuration --------------------
DOTFILES_REPO="https://github.com/Reep007/R007-dotfiles.git"
DOTFILES_DIR="$HOME/R007-dotfiles"
AUR_BUILD_BASE="${AUR_BUILD_BASE:-$HOME/.cache/aur-builds}"

# Flags
DRY_RUN=false
NO_CONFIRM=false

# -------------------- Package Definitions --------------------
OFFICIAL_PKGS=(
  hyprland waybar hyprpaper swww kitty hypridle hyprlock wofi dunst
  grim slurp wl-clipboard cliphist xdg-user-dirs thunar thunar-archive-plugin
  tumbler gvfs gvfs-mtp gvfs-smb nwg-look qt5ct kvantum qt5-wayland qt6-wayland
  xdg-desktop-portal-hyprland xdg-desktop-portal-gtk ttf-jetbrains-mono-nerd
  lsd btop python python-pillow python-pywal python-gobject tk
  network-manager-applet polkit-gnome mpv nano obsidian jq nodejs npm
  pacman-contrib zsh zsh-completions sddm rsync
)

AUR_PKGS=(
  brave-bin nordic-theme-git wpgtk-git themix-full-git oh-my-posh
)

# -------------------- CLI parsing --------------------
for arg in "$@"; do
  case "$arg" in
    --dry-run|--test)  DRY_RUN=true ;;
    --no-confirm|-y)   NO_CONFIRM=true ;;
    --help|-h)
      cat <<'EOF'
Usage: install-dotfiles.sh [OPTIONS]
  --dry-run, --test      Preview everything (no changes made)
  --no-confirm, -y       Auto-yes to all prompts
  --help, -h             Show this help message
EOF
      exit 0 ;;
    *) echo "Unknown option: $arg" >&2; exit 1 ;;
  esac
done

# -------------------- Colors --------------------
RED='\033[1;31m'
GREEN='\033[1;32m'
CYAN='\033[1;36m'
YELLOW='\033[1;33m'
NC='\033[0m'

info()    { printf "${CYAN}[INFO]${NC}   %b\n" "$*"; }
success() { printf "${GREEN}[OK]${NC}     %b\n" "$*"; }
warn()    { printf "${YELLOW}[WARN]${NC}   %b\n" "$*"; }
error()   { printf "${RED}[ERROR]${NC} %b\n" "$*" >&2; exit 1; }

# -------------------- Safe runner --------------------
run() {
  if [[ "$DRY_RUN" == true ]]; then
    printf "${YELLOW}[DRY-RUN]${NC} %s\n" "$*"
    return 0
  fi
  "$@"
}

# -------------------- Helpers --------------------
confirm() {
  [[ "$NO_CONFIRM" == true || "$DRY_RUN" == true ]] && return 0
  printf "${CYAN}?${NC} %s [Y/n] " "${1:-Continue?}"
  read -r ans
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

# -------------------- Preflight --------------------
prepare() {
  [[ $EUID -eq 0 ]] && error "Do not run this script as root"
  [[ -f /etc/arch-release ]] || error "Arch Linux only"
  
  banner
  [[ "$DRY_RUN" == true ]] && info "DRY-RUN mode enabled"
  
  confirm "Start the rice installation?" || error "Installation cancelled"
  
  run mkdir -p "$AUR_BUILD_BASE" "$HOME/.local/bin" "$HOME/.zsh"
  
  if [[ "$DRY_RUN" == false ]]; then
    sudo -v || error "sudo authentication failed"
  fi
}

# -------------------- Installation Steps --------------------
system_update() {
  info "Updating system..."
  run sudo pacman -Sy --noconfirm --needed archlinux-keyring
  run sudo pacman -Syu --noconfirm
  success "System updated"
}

install_paru() {
  if command -v paru >/dev/null 2>&1; then
    info "paru already installed"
    return
  fi
  
  info "Installing paru..."
  run sudo pacman -S --noconfirm --needed base-devel git
  
  local build_dir="$AUR_BUILD_BASE/paru-build-$$"
  run git clone --depth 1 https://aur.archlinux.org/paru.git "$build_dir"
  
  if [[ "$DRY_RUN" == false ]]; then
    (cd "$build_dir" && makepkg -fsri --noconfirm)
    rm -rf "$build_dir"
  fi
  
  success "paru installed"
}

install_official_packages() {
  info "Installing ${#OFFICIAL_PKGS[@]} official packages..."
  run sudo pacman -S --noconfirm --needed "${OFFICIAL_PKGS[@]}"
  run xdg-user-dirs-update
  success "Official packages installed"
}

install_aur_packages() {
  if ! command -v paru >/dev/null 2>&1; then
    warn "paru not available, skipping AUR packages"
    return
  fi
  
  info "Installing ${#AUR_PKGS[@]} AUR packages..."
  run paru -S --noconfirm --needed "${AUR_PKGS[@]}"
  run paru -Sc --noconfirm
  success "AUR packages installed"
}

apply_dotfiles() {
  info "Applying dotfiles..."
  
  if [[ ! -d "$DOTFILES_DIR/.git" ]]; then
    run git clone --depth 1 "$DOTFILES_REPO" "$DOTFILES_DIR"
  else
    (cd "$DOTFILES_DIR" && run git pull --ff-only --quiet)
  fi
  
  if [[ "$DRY_RUN" == false && -d "$HOME/.config" ]]; then
    local backup="$HOME/.config_backup_$(date +%Y%m%d_%H%M%S)"
    cp -a "$HOME/.config" "$backup"
    info "Config backed up to: $backup"
  fi
  
  # Install zsh plugins
  for plugin in zsh-autosuggestions zsh-syntax-highlighting; do
    if [[ ! -d "$HOME/.zsh/$plugin" ]]; then
      run git clone --depth 1 "https://github.com/zsh-users/$plugin" "$HOME/.zsh/$plugin"
    fi
  done
  
  run rsync -a "$DOTFILES_DIR/.config/" "$HOME/.config/"
  run rsync -a "$DOTFILES_DIR/.local/" "$HOME/.local/"
  run find "$HOME/.local/bin" -type f -exec chmod +x {} \;
  
  success "Dotfiles applied"
}

configure_shell() {
  if ! command -v zsh >/dev/null 2>&1; then
    warn "zsh not found"
    return
  fi
  
  if [[ "$SHELL" == */zsh ]]; then
    info "Already using zsh"
    return
  fi
  
  if confirm "Change default shell to zsh?"; then
    run sudo chsh -s "$(command -v zsh)" "$USER"
    success "zsh set as default shell"
  fi
}

enable_services() {
  info "Enabling services..."
  run sudo systemctl enable --now NetworkManager
  run sudo systemctl enable sddm
  success "Services enabled"
}

# -------------------- Summary --------------------
finalize() {
  echo ""
  banner
  
  if [[ "$DRY_RUN" == true ]]; then
    info "Dry-run complete — no changes made"
  else
    success "Installation complete!"
    echo ""
    info "Next steps:"
    echo "  1. Reboot your system"
    echo "  2. Log in via SDDM"
    echo "  3. Press Super+Enter to open Kitty"
    echo "  4. Enjoy your new Hyprland rice!"
  fi
}

# -------------------- Main --------------------
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

main "$@"
