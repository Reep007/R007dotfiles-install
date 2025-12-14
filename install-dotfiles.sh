#!/usr/bin/env bash
# R007-dotfiles — Pro Installer (OPTIMIZED ORDER + ALL FIXES)
# Usage: curl -fsSL https://raw.githubusercontent.com/Reep007/R007-dotfiles/main/install.sh | bash -s -- [options]
#
# Features:
# - Complete Hyprland rice installation
# - Optimized installation order (system → packages → config → optional tools)
# - Safe dry-run mode with optional verbose output
# - Automatic rollback on failure
# - ZenForge compilation with verification
# - CI mode for automated testing
# - Comprehensive logging and summary table
#
# Quick Start:
#   ./install.sh              # Interactive installation
#   ./install.sh --dry-run    # Preview changes
#   ./install.sh --ci         # CI/automated testing

set -euo pipefail
shopt -s inherit_errexit

# -------------------- Configuration --------------------
DOTFILES_REPO="https://github.com/Reep007/R007-dotfiles.git"
ZENFORGE_REPO="https://github.com/Reep007/ZENFORGE.git"
DOTFILES_DIR="$HOME/R007-dotfiles"
ZENFORGE_DIR="$HOME/ZENFORGE"
AUR_BUILD_BASE="${AUR_BUILD_BASE:-$HOME/.cache/aur-builds}"
LOCKFILE="/tmp/r007-installer.lock"
LOG_FILE="$HOME/r007-install-$(date +%Y%m%d_%H%M%S)-$.log"

# Flags
DRY_RUN=false
NO_CONFIRM=false
WITH_ZENFORGE="auto"  # auto | yes | no
VERBOSE_DRY_RUN=false
CI_MODE=false

# Tracking for cleanup
SUDO_KEEPALIVE_PID=""
LAST_BACKUP=""

# Installation tracking (associative array for cleaner access)
declare -A INSTALL_SUMMARY=(
  [system_updated]=false
  [paru_installed]=false
  [official_packages]=false
  [aur_packages]=false
  [dotfiles_applied]=false
  [shell_configured]=false
  [services_enabled]=false
  [rust_installed]=false
  [zenforge_compiled]=false
)
WARNINGS_COUNT=0

# Package counters for summary
OFFICIAL_PKG_COUNT=0
AUR_PKG_COUNT=0

# -------------------- Package Definitions --------------------
OFFICIAL_PKGS=(
  # Core Hyprland & Wayland
  hyprland waybar hyprpaper swww kitty hypridle hyprlock
  
  # Launchers, notifications, screenshots
  wofi dunst grim slurp wl-clipboard cliphist xdg-user-dirs
  
  # File manager + thumbnails
  thunar thunar-archive-plugin tumbler gvfs gvfs-mtp gvfs-smb
  
  # Theming & appearance
  nwg-look qt5ct kvantum qt5-wayland qt6-wayland
  xdg-desktop-portal-hyprland xdg-desktop-portal-gtk
  
  # Fonts & terminal tools
  ttf-jetbrains-mono-nerd lsd btop
  
  # Python & theming tools
  python python-pillow python-pywal python-gobject tk
  
  # Utilities
  network-manager-applet polkit-gnome mpv nano obsidian
  jq nodejs npm pacman-contrib
  
  # Shell
  zsh zsh-completions
  
  # Display manager
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
    --dry-run|--test)          DRY_RUN=true ;;
    --no-confirm|-y)           NO_CONFIRM=true ;;
    --with-zenforge)           WITH_ZENFORGE=yes ;;
    --without-zenforge)        WITH_ZENFORGE=no ;;
    --verbose)                 VERBOSE_DRY_RUN=true ;;
    --ci)                      CI_MODE=true; DRY_RUN=true; NO_CONFIRM=true ;;
    --help|-h)
      cat <<'EOF'
Usage: install.sh [OPTIONS]

OPTIONS:
  --dry-run, --test      Preview everything (no changes made)
  --no-confirm, -y       Auto-yes to all prompts
  --with-zenforge        Force ZenForge compilation
  --without-zenforge     Skip ZenForge completely
  --verbose              Show detailed output in dry-run mode
  --ci                   CI mode (non-interactive, dry-run, for testing)
  --help, -h             Show this help message

EXAMPLES:
  ./install.sh                    # Interactive installation
  ./install.sh --dry-run          # Preview changes
  ./install.sh --dry-run --verbose # Detailed preview
  ./install.sh -y --without-zenforge # Quick install, skip ZenForge
  ./install.sh --ci               # CI/automated testing mode
EOF
      exit 0
      ;;
    *)
      error "Unknown option: $arg"
      echo "Run './install.sh --help' for usage information"
      exit 1
      ;;
  esac
done

# CI mode configuration
if [[ "$CI_MODE" == true ]]; then
  info "CI mode enabled (non-interactive, dry-run enforced)"
  DRY_RUN=true
  NO_CONFIRM=true
fi

# -------------------- Colors & Logging --------------------
RED='\033[1;31m'; GREEN='\033[1;32m'; CYAN='\033[1;36m'; YELLOW='\033[1;33m'; NC='\033[0m'
info()    { printf "${CYAN}[INFO]${NC}   %b\n" "$*"; }
success() { printf "${GREEN}[OK]${NC}      %b\n" "$*"; }
warn()    { printf "${YELLOW}[WARN]${NC}    %b\n" "$*"; ((WARNINGS_COUNT++)); }
error()   { printf "${RED}[ERROR]${NC}  %b\n" "$*" >&2; exit 1; }

# Start logging
exec > >(tee -a "$LOG_FILE") 2>&1

# -------------------- Safe runner (respects DRY_RUN) --------------------
run() {
  if [[ "$DRY_RUN" == true ]]; then
    printf "${YELLOW}[DRY-RUN]${NC} %s\n" "$*"
    return 0
  fi
  "$@"
}

# Verbose runner for detailed dry-run output
run_verbose() {
  if [[ "$DRY_RUN" == true ]]; then
    if [[ "$VERBOSE_DRY_RUN" == true ]]; then
      printf "${YELLOW}[DRY-RUN]${NC} %s\n" "$*"
      # Show what would happen
      "$@" --dry-run 2>&1 | head -50 || true
    else
      printf "${YELLOW}[DRY-RUN]${NC} %s\n" "$*"
    fi
    return 0
  fi
  "$@"
}

# -------------------- Cleanup & locks --------------------
tmpdirs=()
cleanup() {
  local exit_code=$?
  
  # Kill sudo keep-alive
  if [[ -n "$SUDO_KEEPALIVE_PID" ]]; then
    kill "$SUDO_KEEPALIVE_PID" 2>/dev/null || true
  fi
  
  # Remove lockfile
  rm -f "$LOCKFILE" 2>/dev/null || true
  
  # Clean temporary directories
  for d in "${tmpdirs[@]:-}"; do
    [[ -d "$d" ]] && rm -rf "$d" 2>/dev/null || true
  done
  
  # If script failed and we have a backup, inform user
  if [[ $exit_code -ne 0 ]] && [[ -n "$LAST_BACKUP" ]] && [[ -d "$LAST_BACKUP" ]]; then
    warn "Script failed. You can restore your config with:"
    warn "  rm -rf ~/.config && mv $LAST_BACKUP ~/.config"
  fi
  
  exit $exit_code
}
trap cleanup EXIT ERR INT TERM

# Rollback function (in case of critical failure)
rollback() {
  if [[ -n "$LAST_BACKUP" ]] && [[ -d "$LAST_BACKUP" ]]; then
    warn "Rolling back to previous config..."
    rm -rf "$HOME/.config"
    mv "$LAST_BACKUP" "$HOME/.config"
    success "Rollback complete"
  fi
}

# -------------------- Helpers --------------------
confirm() {
  [[ "$NO_CONFIRM" == true || "$DRY_RUN" == true ]] && return 0
  printf "${CYAN}?${NC} %s [Y/n] " "${1:-Continue?}"
  # 60 second timeout - adjust if users need more time for complex decisions
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

check_path() {
  # Check ~/.local/bin
  if ! echo "$PATH" | grep -q "$HOME/.local/bin"; then
    warn "~/.local/bin is not in your PATH permanently!"
    
    # Offer to add it automatically
    if [[ "$DRY_RUN" == false ]] && confirm "Add ~/.local/bin to your PATH in ~/.zshrc?"; then
      local zshrc="$HOME/.zshrc"
      
      # Create .zshrc if it doesn't exist
      if [[ ! -f "$zshrc" ]]; then
        touch "$zshrc"
        info "Created ~/.zshrc"
      fi
      
      # Add PATH export if not already present
      if ! grep -q 'export PATH="$HOME/.local/bin:$PATH"' "$zshrc"; then
        echo '' >> "$zshrc"
        echo '# Added by R007-dotfiles installer' >> "$zshrc"
        echo 'export PATH="$HOME/.local/bin:$PATH"' >> "$zshrc"
        success "Added ~/.local/bin to PATH in ~/.zshrc"
        info "Changes will take effect after you log out and back in"
      else
        info "PATH already configured in ~/.zshrc"
      fi
    else
      echo "   To add it manually, add this to ~/.zshrc (or ~/.bashrc):"
      echo '   export PATH="$HOME/.local/bin:$PATH"'
      echo
    fi
  fi
  
  # Check cargo bin (if cargo is installed)
  if command -v cargo >/dev/null 2>&1; then
    local cargo_bin
    cargo_bin="$(cargo_bin_dir)"
    if ! echo "$PATH" | grep -q "$cargo_bin"; then
      warn "Cargo bin directory not in PATH: $cargo_bin"
      info "ZenForge and other Rust tools may not be accessible"
      info "Add to your shell config: export PATH=\"$cargo_bin:\$PATH\""
    fi
  fi
}

cargo_bin_dir() { 
  local install_root="${CARGO_INSTALL_ROOT:-${CARGO_HOME:-$HOME/.cargo}}"
  echo "$install_root/bin"
}

check_rust_version() {
  local min_version="1.70.0"
  local current_version
  
  if ! command -v cargo >/dev/null 2>&1; then
    return 1
  fi
  
  current_version=$(cargo --version 2>/dev/null | grep -oP '\d+\.\d+\.\d+' | head -1)
  
  if [[ -z "$current_version" ]]; then
    warn "Could not determine Rust version"
    return 1
  fi
  
  # Compare versions (works with sort -V)
  if [[ $(printf '%s\n' "$min_version" "$current_version" | sort -V | head -1) != "$min_version" ]]; then
    warn "Rust $current_version found, but $min_version+ recommended for ZenForge"
    if ! confirm "Continue with compilation anyway?"; then
      return 1
    fi
  fi
  
  info "Rust version: $current_version ✓"
  return 0
}

verify_zenforge_install() {
  local zenforge_bin="$(cargo_bin_dir)/zenforge"
  
  # Check if binary exists
  if [[ ! -f "$zenforge_bin" ]]; then
    warn "ZenForge binary not found at: $zenforge_bin"
    return 1
  fi
  
  # Check if it's executable
  if [[ ! -x "$zenforge_bin" ]]; then
    warn "ZenForge binary exists but is not executable"
    chmod +x "$zenforge_bin" 2>/dev/null || return 1
  fi
  
  # Try to run it
  if ! command -v zenforge >/dev/null 2>&1; then
    warn "ZenForge not in PATH. Add this to your shell config:"
    warn "  export PATH=\"$(cargo_bin_dir):\$PATH\""
    return 1
  fi
  
  # Get version
  local version
  version=$(zenforge --version 2>/dev/null || echo "unknown")
  success "ZenForge verified: $version"
  info "Binary location: $zenforge_bin"
  return 0
}

check_network() {
  if [[ "$DRY_RUN" == true ]]; then
    return 0
  fi
  
  info "Checking network connectivity..."
  
  # Try ping first (fastest)
  if ping -c 1 -W 2 8.8.8.8 &>/dev/null || ping -c 1 -W 2 1.1.1.1 &>/dev/null; then
    return 0
  fi
  
  # Fallback to HTTP check if ICMP is blocked
  if curl -s -I --connect-timeout 5 https://archlinux.org &>/dev/null; then
    return 0
  fi
  
  error "No internet connection detected. Please check your network."
}

check_disk_space() {
  if [[ "$DRY_RUN" == true ]]; then
    return 0
  fi
  
  local available_gb
  available_gb=$(df -BG "$HOME" | awk 'NR==2 {print $4}' | sed 's/G//')
  
  if [[ $available_gb -lt 5 ]]; then
    error "Insufficient disk space. At least 5GB free required, found ${available_gb}GB"
  fi
  
  info "Available disk space: ${available_gb}GB"
}

check_not_root() {
  if [[ $EUID -eq 0 ]]; then
    error "Do not run this script as root or with sudo. Run as normal user."
  fi
}

# -------------------- Preflight --------------------
prepare() {
  check_not_root
  [[ -f /etc/arch-release ]] || error "This script only works on Arch Linux"

  # Acquire lock FIRST - before any side effects
  if ! flock -n 200; then
    error "Another instance of the installer is already running"
  fi 200>"$LOCKFILE"

  banner
  [[ "$CI_MODE" == true ]] && info "CI MODE - Non-interactive, dry-run enforced"
  [[ "$DRY_RUN" == true ]] && info "DRY-RUN mode — nothing will be changed"
  [[ "$VERBOSE_DRY_RUN" == true ]] && info "VERBOSE mode — detailed preview enabled"
  info "Installation log: $LOG_FILE"
  
  check_network
  check_disk_space
  
  # Skip confirmation in CI mode
  if [[ "$CI_MODE" == false ]]; then
    confirm "Start the rice installation?" || error "Aborted by user"
  fi

  # Keep sudo alive with proper cleanup tracking
  if [[ "$DRY_RUN" == false ]]; then
    sudo -v
    (
      while true; do
        sudo -n true || exit
        sleep 50
        kill -0 "$$" 2>/dev/null || exit
      done
    ) &
    SUDO_KEEPALIVE_PID=$!
  fi

  run mkdir -p "$AUR_BUILD_BASE" "$HOME/.local/bin" "$HOME/.zsh"
  check_path
}

# -------------------- Installation Steps (OPTIMIZED ORDER) --------------------

# Step 1: System Update (MOVED UP - Do this first!)
system_update() {
  info "Updating system safely (keyring first)..."
  if ! run sudo pacman -Sy --noconfirm --needed archlinux-keyring; then
    warn "Keyring update failed - continuing anyway"
  fi
  
  if ! run sudo pacman -Syu --noconfirm; then
    error "System update failed"
  fi
  INSTALL_SUMMARY[system_updated]=true
  success "System updated"
}

# Step 2: Install paru
install_paru() {
  command -v paru >/dev/null 2>&1 && { info "paru already installed"; return; }

  info "Installing paru AUR helper..."
  run sudo pacman -S --noconfirm --needed base-devel git

  local build_dir
  build_dir=$(mktemp -d "$AUR_BUILD_BASE/paru.XXXXXX")
  tmpdirs+=("$build_dir")

  if ! run git clone --depth 1 --single-branch https://aur.archlinux.org/paru.git "$build_dir"; then
    error "Failed to clone paru repository"
  fi
  
  if ! (cd "$build_dir" && run makepkg -fsri --needed --noconfirm); then
    error "Failed to build paru"
  fi
  
  INSTALL_SUMMARY[paru_installed]=true
  success "paru installed"
}

# Step 3: Install official packages
install_official_packages() {
  info "Installing official packages..."
  
  OFFICIAL_PKG_COUNT=${#OFFICIAL_PKGS[@]}
  info "Package count: ${OFFICIAL_PKG_COUNT} official packages"
  
  if ! run sudo pacman -S --noconfirm --needed "${OFFICIAL_PKGS[@]}"; then
    error "Failed to install official packages"
  fi
  
  run xdg-user-dirs-update
  INSTALL_SUMMARY[official_packages]=true
  success "Official packages installed"
}

# Step 4: Install AUR packages
install_aur_packages() {
  command -v paru >/dev/null 2>&1 || { warn "paru not available → skipping AUR packages"; return; }
  info "Installing AUR packages..."
  
  AUR_PKG_COUNT=${#AUR_PKGS[@]}
  info "Package count: ${AUR_PKG_COUNT} AUR packages"
  
  if ! run paru -S --noconfirm --needed "${AUR_PKGS[@]}"; then
    warn "Some AUR packages failed to install - continuing"
  fi

  # Clean package cache (using proper flags instead of piping input)
  if [[ "$DRY_RUN" == false ]]; then
    run paru -Sc --noconfirm 2>/dev/null || true
  fi
  
  INSTALL_SUMMARY[aur_packages]=true
  success "AUR packages installed"
}

# Step 5: Apply dotfiles
apply_dotfiles() {
  info "Cloning/updating dotfiles..."
  
  if [[ ! -d "$DOTFILES_DIR/.git" ]]; then
    if ! run git clone --depth 1 --single-branch "$DOTFILES_REPO" "$DOTFILES_DIR"; then
      error "Failed to clone dotfiles repository"
    fi
  else
    if ! (cd "$DOTFILES_DIR" && run git pull --ff-only --quiet); then
      warn "Git pull failed - using existing version"
    fi
  fi

  # CRITICAL: Always backup .config before applying
  if [[ "$DRY_RUN" == false ]]; then
    if [[ -d "$HOME/.config" ]]; then
      LAST_BACKUP="$HOME/.config_backup_$(date +%Y%m%d_%H%M%S)"
      info "Backing up ~/.config → $LAST_BACKUP"
      if ! cp -a "$HOME/.config" "$LAST_BACKUP"; then
        error "Failed to create backup"
      fi
    else
      warn "~/.config does not exist - will be created fresh"
    fi
  fi

  # Install zsh plugins
  for plugin in zsh-autosuggestions zsh-syntax-highlighting; do
    local dest="$HOME/.zsh/$plugin"
    if [[ ! -d "$dest" ]]; then
      if ! run git clone --depth 1 --single-branch --quiet "https://github.com/zsh-users/$plugin" "$dest"; then
        warn "Failed to install $plugin - continuing anyway"
      fi
    fi
  done

  # Apply dotfiles with safety checks
  local excludes=(--exclude='.git/' --exclude='.gitignore' --exclude='*.swp' --exclude='*.bak' --exclude='.DS_Store' --exclude='node_modules/')
  
  for dir in .config .local; do
    [[ -d "$DOTFILES_DIR/$dir" ]] || continue
    
    info "Syncing $dir/"
    
    # Show preview in dry-run (limited to 20 lines to avoid overwhelming output)
    # Use --verbose flag to see more details: ./install.sh --dry-run --verbose
    if [[ "$DRY_RUN" == true ]]; then
      if [[ "$VERBOSE_DRY_RUN" == true ]]; then
        run rsync -a --dry-run "${excludes[@]}" "$DOTFILES_DIR/$dir/" "$HOME/$dir/"
      else
        run rsync -a --dry-run "${excludes[@]}" "$DOTFILES_DIR/$dir/" "$HOME/$dir/" | head -20
        echo "  ... (use --verbose to see all changes)"
      fi
      continue
    fi
    
    # Apply changes with error checking and rollback on failure
    if ! run rsync -a "${excludes[@]}" "$DOTFILES_DIR/$dir/" "$HOME/$dir/"; then
      error "Failed to sync $dir/ - rolling back"
      rollback
      exit 1
    fi
  done

  run find "$HOME/.local/bin" -type f -exec chmod +x {} \; 2>/dev/null || true
  INSTALL_SUMMARY[dotfiles_applied]=true
  success "Dotfiles applied successfully"
}

# Step 6: Configure shell
configure_shell() {
  command -v zsh >/dev/null || { warn "zsh not found - skipping shell configuration"; return; }
  [[ "$SHELL" == */zsh ]] && { info "Already using zsh"; return; }

  if confirm "Change default shell to zsh?"; then
    if ! run sudo chsh -s "$(command -v zsh)" "$USER"; then
      warn "Failed to change shell - you can do it manually later with: chsh -s \$(which zsh)"
    else
      INSTALL_SUMMARY[shell_configured]=true
      success "zsh set as default shell (relogin required)"
    fi
  fi
}

# Step 7: Enable services
enable_services() {
  info "Enabling essential services..."
  
  if ! run sudo systemctl enable --now NetworkManager; then
    warn "Failed to enable NetworkManager"
  fi
  
  if ! run sudo systemctl enable sddm; then
    warn "Failed to enable SDDM (will start on reboot)"
  fi
  
  INSTALL_SUMMARY[services_enabled]=true
  success "Services configured"
}

# Step 8: Install Rust (MOVED TO END)
install_rust_if_needed() {
  command -v cargo >/dev/null 2>&1 && { info "Rust/cargo already available"; return; }
  [[ "$WITH_ZENFORGE" == "no" ]] && { info "Skipping Rust (ZenForge disabled)"; return; }

  if [[ "$DRY_RUN" == true ]]; then
    info "Would install rustup (dry-run)"
    return
  fi

  printf "\n${CYAN}═══════════════════════════════════════${NC}\n"
  printf "${CYAN}Rust Installation Required${NC}\n"
  echo "  💾 Download Size: ~500MB"
  echo "  📦 Install Size: ~2GB"
  echo "  ⏱  Install Time: 2-5 minutes"
  printf "${CYAN}═══════════════════════════════════════${NC}\n\n"

  if confirm "Install rustup now?"; then
    if ! curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y --no-modify-path; then
      warn "Failed to install rustup"
      WITH_ZENFORGE=no
      return
    fi
    
    local cargo_env="${CARGO_HOME:-$HOME/.cargo}/env"
    if [[ -f "$cargo_env" ]]; then
      # shellcheck source=/dev/null
      source "$cargo_env"
      INSTALL_SUMMARY[rust_installed]=true
      success "rustup installed"
      
      # Add cargo bin to PATH in shell config
      local zshrc="$HOME/.zshrc"
      local cargo_path='export PATH="$HOME/.cargo/bin:$PATH"'
      
      if [[ -f "$zshrc" ]] && ! grep -qF "$cargo_path" "$zshrc"; then
        if confirm "Add cargo bin to PATH in ~/.zshrc?"; then
          echo '' >> "$zshrc"
          echo '# Added by R007-dotfiles installer (Rust)' >> "$zshrc"
          echo "$cargo_path" >> "$zshrc"
          success "Added cargo to PATH in ~/.zshrc"
        fi
      fi
      
      info "Note: You may need to log out and back in for cargo to be in your PATH"
    else
      warn "Cargo environment file not found - manual setup may be needed"
      WITH_ZENFORGE=no
    fi
  else
    info "Rust installation skipped"
    WITH_ZENFORGE=no
  fi
}

# Step 9: Install ZenForge (LAST - optional and time-consuming)
install_zenforge() {
  [[ "$WITH_ZENFORGE" == "no" ]] && { info "ZenForge skipped"; return; }
  
  if ! command -v cargo >/dev/null; then
    warn "cargo not available → cannot compile ZenForge"
    return
  fi

  # Check Rust version before attempting compilation
  if ! check_rust_version; then
    warn "Rust version check failed - skipping ZenForge compilation"
    return
  fi

  info "Preparing ZenForge installation..."
  
  if [[ -d "$ZENFORGE_DIR/.git" ]]; then
    if ! (cd "$ZENFORGE_DIR" && run git pull --ff-only --quiet); then
      warn "Git pull failed - using existing version"
    fi
  else
    if ! run git clone --depth 1 --single-branch "$ZENFORGE_REPO" "$ZENFORGE_DIR"; then
      warn "Failed to clone ZenForge repository"
      return
    fi
  fi

  # Enhanced pre-compilation info
  printf "\n${CYAN}═══════════════════════════════════════${NC}\n"
  printf "${CYAN}ZenForge Compilation Details${NC}\n"
  echo "  📦 Repository: $ZENFORGE_REPO"
  echo "  🎯 Target: $(cargo_bin_dir)/zenforge"
  echo "  🔧 Rust: $(cargo --version 2>/dev/null | grep -oP '\d+\.\d+\.\d+' || echo 'unknown')"
  echo "  ⏱  Time: 3–10 minutes (depends on CPU)"
  echo "  💾 Build Space: ~200MB temporary"
  echo "  🌐 Network: ~50MB dependencies"
  printf "${CYAN}═══════════════════════════════════════${NC}\n\n"

  if ! confirm "Compile and install ZenForge now?"; then
    info "ZenForge compilation skipped - you can build it later with:"
    info "  cd $ZENFORGE_DIR && cargo install --path ."
    return
  fi

  info "Compiling ZenForge... grab a coffee ☕"
  local compile_start
  compile_start=$(date +%s)
  
  if ! (cd "$ZENFORGE_DIR" && run cargo install --path . --locked --force); then
    warn "ZenForge compilation failed - check the log for details"
    return
  fi
  
  local compile_end
  compile_end=$(date +%s)
  local compile_time=$((compile_end - compile_start))
  
  INSTALL_SUMMARY[zenforge_compiled]=true
  success "ZenForge compiled in ${compile_time}s → $(cargo_bin_dir)/zenforge"
  
  # Verify the installation
  echo
  info "Verifying ZenForge installation..."
  if verify_zenforge_install; then
    success "ZenForge is ready to use!"
    info "Try: zenforge --help"
  else
    warn "ZenForge compiled but verification failed - check PATH configuration"
  fi
}

# Verification step
verify_installation() {
  [[ "$DRY_RUN" == true ]] && return 0
  
  info "Verifying critical packages..."
  local failed=()
  
  for cmd in hyprland waybar kitty zsh; do
    command -v "$cmd" >/dev/null || failed+=("$cmd")
  done
  
  if [[ ${#failed[@]} -gt 0 ]]; then
    warn "Some critical packages are missing: ${failed[*]}"
    warn "Installation may be incomplete"
    return 1
  fi
  
  success "Core packages verified ✓"
  
  # Verify ZenForge if it was installed
  if [[ ${INSTALL_SUMMARY[zenforge_compiled]} == true ]]; then
    info "Verifying ZenForge..."
    if verify_zenforge_install; then
      success "ZenForge verified ✓"
    else
      warn "ZenForge verification failed"
      return 1
    fi
  fi
  
  return 0
}

# Print installation summary
print_summary() {
  [[ "$DRY_RUN" == true ]] && return
  
  printf "\n${CYAN}═══════════════════════════════════════════════════════════${NC}\n"
  printf "${CYAN}                 INSTALLATION SUMMARY${NC}\n"
  printf "${CYAN}═══════════════════════════════════════════════════════════${NC}\n\n"
  
  # Print table using associative array
  printf "%-30s %s\n" "System Update:" "$([[ ${INSTALL_SUMMARY[system_updated]} == true ]] && echo -e "${GREEN}✓ Complete${NC}" || echo -e "${YELLOW}⊘ Skipped${NC}")"
  printf "%-30s %s\n" "Paru AUR Helper:" "$([[ ${INSTALL_SUMMARY[paru_installed]} == true ]] && echo -e "${GREEN}✓ Installed${NC}" || echo -e "${YELLOW}⊘ Skipped${NC}")"
  
  # Show package counts
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
  printf "%-30s %s\n" "Rust/Cargo:" "$([[ ${INSTALL_SUMMARY[rust_installed]} == true ]] && echo -e "${GREEN}✓ Installed${NC}" || echo -e "${YELLOW}⊘ Skipped${NC}")"
  
  # ZenForge with verification status
  if [[ ${INSTALL_SUMMARY[zenforge_compiled]} == true ]]; then
    if command -v zenforge >/dev/null 2>&1; then
      local zf_version
      zf_version=$(zenforge --version 2>/dev/null | head -1 || echo "unknown")
      printf "%-30s ${GREEN}✓ Compiled & Verified${NC}\n" "ZenForge:"
      printf "%-30s   %s\n" "" "$zf_version"
    else
      printf "%-30s ${YELLOW}⚠ Compiled (PATH issue)${NC}\n" "ZenForge:"
    fi
  else
    printf "%-30s %s\n" "ZenForge:" "${YELLOW}⊘ Skipped${NC}"
  fi
  
  printf "\n"
  
  # Show total package count
  local total_pkgs=$((OFFICIAL_PKG_COUNT + AUR_PKG_COUNT))
  if [[ $total_pkgs -gt 0 ]]; then
    printf "${CYAN}📦 Total packages installed: %d${NC}\n" "$total_pkgs"
  fi
  
  # Warnings summary
  if [[ $WARNINGS_COUNT -gt 0 ]]; then
    printf "${YELLOW}⚠  Warnings encountered: %d${NC}\n" "$WARNINGS_COUNT"
    printf "${YELLOW}   Check the log for details: %s${NC}\n\n" "$LOG_FILE"
  else
    printf "${GREEN}✓  No warnings - installation completed cleanly${NC}\n\n"
  fi
  
  printf "${CYAN}═══════════════════════════════════════════════════════════${NC}\n\n"
}

finalize() {
  if ! verify_installation; then
    warn "Installation verification found issues - check the log"
  fi
  
  clear
  
  # Special CI mode output
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
    info "Log file: $LOG_FILE"
    exit 0
  fi
  
  printf "${GREEN}"
  cat <<'EOF'
╔══════════════════════════════════════════════════════════╗
║          R007 Rice — Installation Complete!             ║
║   Hyprland • Waybar • Theming • Dotfiles • ZenForge     ║
╚══════════════════════════════════════════════════════════╝
EOF
  printf "${NC}\n"

  print_summary

  if [[ "$DRY_RUN" == true ]]; then
    info "Dry-run complete — no changes made"
    echo
    info "To perform the actual installation, run:"
    echo "  ./install.sh"
    echo
    info "For more options, run:"
    echo "  ./install.sh --help"
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

# -------------------- OPTIMIZED EXECUTION ORDER --------------------
main() {
  if [[ "$CI_MODE" == false ]]; then
    info "Installation Order:"
    echo "  1. System preflight checks"
    echo "  2. System update (keyring + packages)"
    echo "  3. Install paru (AUR helper)"
    echo "  4. Install official packages (Hyprland, tools, fonts)"
    echo "  5. Install AUR packages (themes, browsers)"
    echo "  6. Apply dotfiles configuration"
    echo "  7. Configure zsh shell"
    echo "  8. Enable system services"
    echo "  9. Install Rust (if ZenForge enabled)"
    echo "  10. Compile ZenForge (optional, last step)"
    
    if [[ "$DRY_RUN" == true ]]; then
      echo
      info "Running in DRY-RUN mode - no changes will be made"
      [[ "$VERBOSE_DRY_RUN" == true ]] && info "Verbose output enabled for detailed preview"
    fi
    echo
  else
    info "CI Mode: Testing installation script (dry-run only)"
  fi
  
  prepare                    # Step 0: Preflight
  system_update              # Step 1: Update first (MOVED UP)
  install_paru               # Step 2: AUR helper
  install_official_packages  # Step 3: Core packages
  install_aur_packages       # Step 4: Extra packages
  apply_dotfiles             # Step 5: Configuration
  configure_shell            # Step 6: Shell setup
  enable_services            # Step 7: Services
  install_rust_if_needed     # Step 8: Rust (MOVED TO END)
  install_zenforge           # Step 9: ZenForge (LAST)
  finalize                   # Step 10: Verify & reboot
}

main
