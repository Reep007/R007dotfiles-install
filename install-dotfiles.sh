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

EXAMPLES:
  ./install-no-zenforge.sh                  # Interactive installation
  ./install-no-zenforge.sh --dry-run        # Preview changes
  ./install-no-zenforge.sh -y               # Auto-install without prompts
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

# Start logging (tee to both console and file)
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
  [[ "$CI_MODE" == true ]] && info "CI MODE - Non-interactive, dry-run enforced"
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

# -------------------- Installation Steps --------------------
system_update() {
  info "Updating system..."
  run sudo pacman -Sy --noconfirm --needed archlinux-keyring || warn "Keyring update failed"
  run sudo pacman -Syu --noconfirm || error "System update failed"
  INSTALL_SUMMARY[system_updated]=true
  success "System updated"
}

install_paru() {
  if command -v paru >/dev/null 2>&1; then
    info "paru already installed"
    return
  fi
  
  info "Installing paru..."
  run sudo pacman -S --noconfirm --needed base-devel git
  local build_dir
  build_dir=$(mktemp -d "$AUR_BUILD_BASE/paru.XXXX")
  tmpdirs+=("$build_dir")
  run git clone --depth 1 https://aur.archlinux.org/paru.git "$build_dir"
  (cd "$build_dir" && run makepkg -fsri --noconfirm)
  INSTALL_SUMMARY[paru_installed]=true
  success "paru installed"
}

install_official_packages() {
  info "Installing official packages..."
  OFFICIAL_PKG_COUNT=${#OFFICIAL_PKGS[@]}
  info "Package count: ${OFFICIAL_PKG_COUNT} packages"
  run sudo pacman -S --noconfirm --needed "${OFFICIAL_PKGS[@]}" || error "Failed to install official packages"
  run xdg-user-dirs-update || true
  INSTALL_SUMMARY[official_packages]=true
  success "Official packages installed"
}

install_aur_packages() {
  if ! command -v paru >/dev/null 2>&1; then
    warn "paru not available - skipping AUR packages"
    return
  fi
  
  info "Installing AUR packages..."
  AUR_PKG_COUNT=${#AUR_PKGS[@]}
  info "Package count: ${AUR_PKG_COUNT} packages"
  run paru -S --noconfirm --needed "${AUR_PKGS[@]}" || warn "Some AUR packages failed"
  
  # Clean cache
  if [[ "$DRY_RUN" == false ]]; then
    paru -Sc --noconfirm 2>/dev/null || true
  fi
  
  INSTALL_SUMMARY[aur_packages]=true
  success "AUR packages installed"
}

apply_dotfiles() {
  info "Applying dotfiles..."
  
  # Clone or update dotfiles repo
  if [[ ! -d "$DOTFILES_DIR/.git" ]]; then
    run git clone --depth 1 "$DOTFILES_REPO" "$DOTFILES_DIR" || error "Failed to clone dotfiles"
  else
    (cd "$DOTFILES_DIR" && run git pull --ff-only --quiet) || warn "Git pull failed - using existing version"
  fi

  # Backup existing config
  if [[ "$DRY_RUN" == false && -d "$HOME/.config" ]]; then
    LAST_BACKUP="$HOME/.config_backup_$(date +%Y%m%d_%H%M%S)"
    info "Backing up ~/.config → $LAST_BACKUP"
    cp -a "$HOME/.config" "$LAST_BACKUP"
  fi

  # Install zsh plugins
  for plugin in zsh-autosuggestions zsh-syntax-highlighting; do
    local dest="$HOME/.zsh/$plugin"
    if [[ ! -d "$dest" ]]; then
      run git clone --depth 1 --quiet "https://github.com/zsh-users/$plugin" "$dest" || warn "Failed to install $plugin"
    fi
  done

  # FIX: Apply dotfiles with run wrapper for dry-run support
  info "Syncing .config/"
  run rsync -a "$DOTFILES_DIR/.config/" "$HOME/.config/" || error "Failed to sync .config"
  
  info "Syncing .local/"
  run rsync -a "$DOTFILES_DIR/.local/" "$HOME/.local/" || error "Failed to sync .local"
  
  # Make scripts executable
  run find "$HOME/.local/bin" -type f -exec chmod +x {} \; 2>/dev/null || true
  
  INSTALL_SUMMARY[dotfiles_applied]=true
  success "Dotfiles applied"
}

configure_shell() {
  if ! command -v zsh >/dev/null 2>&1; then
    warn "zsh not found - skipping shell configuration"
    return
  fi
  
  if [[ "$SHELL" == */zsh ]]; then
    info "Already using zsh"
    return
  fi
  
  if confirm "Change default shell to zsh?"; then
    run sudo chsh -s "$(command -v zsh)" "$USER" || warn "Failed to change shell"
    INSTALL_SUMMARY[shell_configured]=true
    success "zsh set as default shell (relogin required)"
  fi
}

enable_services() {
  info "Enabling system services..."
  run sudo systemctl enable --now NetworkManager || warn "Failed to enable NetworkManager"
  run sudo systemctl enable sddm || warn "Failed to enable SDDM"
  INSTALL_SUMMARY[services_enabled]=true
  success "Services enabled"
}

# -------------------- Summary & Finalize --------------------
print_summary() {
  [[ "$DRY_RUN" == true ]] && return
  
  printf "\n${CYAN}═══════════════════════════════════════════════════════════${NC}\n"
  printf "${CYAN}                 INSTALLATION SUMMARY${NC}\n"
  printf "${CYAN}═══════════════════════════════════════════════════════════${NC}\n\n"
  
  printf "%-30s %s\n" "System Update:" "$([[ ${INSTALL_SUMMARY[system_updated]} == true ]] && echo -e "${GREEN}✓ Complete${NC}" || echo -e "${YELLOW}⊘ Skipped${NC}")"
  printf "%-30s %s\n" "Paru AUR Helper:" "$([[ ${INSTALL_SUMMARY[paru_installed]} == true ]] && echo -e "${GREEN}✓ Installed${NC}" || echo -e "${YELLOW}⊘ Skipped${NC}")"
  
  if [[ ${INSTALL_SUMMARY[official_packages]} == true ]]; then
    printf "%-30s ${GREEN}✓ Installed${NC} (${OFFICIAL_PKG_COUNT} packages)\n" "Official Packages:"
  else
    printf "%-30s %s\n" "Official Packages:" "${YELLOW}⊘ Skipped${NC}"
  fi
  
  if [[ ${INSTALL_SUMMARY[aur_packages]} == true ]]; then
    printf "%-30s ${GREEN}✓ Installed${NC} (${AUR_PKG_COUNT} packages)\n" "AUR Packages:"
  else
    printf "%-30s %s\n" "AUR Packages:" "${YELLOW}⊘ Skipped${NC}"
  fi
  
  printf "%-30s %s\n" "Dotfiles Applied:" "$([[ ${INSTALL_SUMMARY[dotfiles_applied]} == true ]] && echo -e "${GREEN}✓ Complete${NC}" || echo -e "${YELLOW}⊘ Skipped${NC}")"
  printf "%-30s %s\n" "Shell Configuration:" "$([[ ${INSTALL_SUMMARY[shell_configured]} == true ]] && echo -e "${GREEN}✓ zsh set${NC}" || echo -e "${YELLOW}⊘ Unchanged${NC}")"
  printf "%-30s %s\n" "System Services:" "$([[ ${INSTALL_SUMMARY[services_enabled]} == true ]] && echo -e "${GREEN}✓ Enabled${NC}" || echo -e "${YELLOW}⊘ Skipped${NC}")"
  
  printf "\n"
  
  local total_pkgs=$((OFFICIAL_PKG_COUNT + AUR_PKG_COUNT))
  [[ $total_pkgs -gt 0 ]] && printf "${CYAN}📦 Total packages installed: %d${NC}\n" "$total_pkgs"
  
  if [[ $WARNINGS_COUNT -gt 0 ]]; then
    printf "${YELLOW}⚠  Warnings encountered: %d${NC}\n" "$WARNINGS_COUNT"
    printf "${YELLOW}   Check the log for details: %s${NC}\n\n" "$LOG_FILE"
  else
    printf "${GREEN}✓  No warnings - installation completed cleanly${NC}\n\n"
  fi
  
  printf "${CYAN}═══════════════════════════════════════════════════════════${NC}\n\n"
}

finalize() {
  clear
  
  if [[ "$CI_MODE" == true ]]; then
    printf "${GREEN}"
    cat <<'EOF'
╔══════════════════════════════════════════════════════════╗
║          CI Mode - Dry-Run Complete                     ║
╚══════════════════════════════════════════════════════════╝
EOF
    printf "${NC}\n"
    print_summary
    info "CI mode complete - script validation passed"
    exit 0
  fi
  
  printf "${GREEN}"
  cat <<'EOF'
╔══════════════════════════════════════════════════════════╗
║          R007 Rice — Installation Complete!             ║
║        Hyprland • Waybar • Theming • Dotfiles           ║
╚══════════════════════════════════════════════════════════╝
EOF
  printf "${NC}\n"

  print_summary

  if [[ "$DRY_RUN" == true ]]; then
    info "Dry-run complete — no changes made"
    echo
    info "To perform the actual installation, run:"
    echo "  ./install-no-zenforge.sh"
    return
  fi

  info "Installation log: $LOG_FILE"
  [[ -n "$LAST_BACKUP" ]] && info "Config backup: $LAST_BACKUP"
  echo
  info "Next steps:"
  echo "  1. Reboot your system"
  echo "  2. Select 'Hyprland' from SDDM login screen"
  echo "  3. Enjoy your new rice! 🍚"
  echo
  
  if confirm "Reboot now?"; then
    info "Rebooting in 5 seconds... (Ctrl+C to cancel)"
    sleep 5
    sudo systemctl reboot
  else
    success "Installation complete! Reboot when ready."
  fi
}

# -------------------- Main Execution --------------------
main() {
  if [[ "$CI_MODE" == false ]]; then
    info "Installation Steps:"
    echo "  1. System update"
    echo "  2. Install paru (AUR helper)"
    echo "  3. Install official packages (Hyprland, tools, fonts)"
    echo "  4. Install AUR packages (themes, browsers)"
    echo "  5. Apply dotfiles configuration"
    echo "  6. Configure zsh shell"
    echo "  7. Enable system services"
    
    [[ "$DRY_RUN" == true ]] && info "Running in DRY-RUN mode - no changes will be made"
    echo
  fi
  
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

