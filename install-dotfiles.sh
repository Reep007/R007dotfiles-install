#!/usr/bin/env bash
set -euo pipefail

# Color definitions
readonly RED='\033[1;31m'
readonly GREEN='\033[1;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[1;34m'
readonly MAGENTA='\033[1;35m'
readonly CYAN='\033[1;36m'
readonly RESET='\033[0m'
readonly BOLD='\033[1m'

# Log functions
info() {
  echo -e "${GREEN}${BOLD}[INFO]${RESET} $1"
}

success() {
  echo -e "${CYAN}${BOLD}[SUCCESS]${RESET} $1"
}

warn() {
  echo -e "${YELLOW}${BOLD}[WARNING]${RESET} $1"
}

error() {
  echo -e "${RED}${BOLD}[ERROR]${RESET} $1"
}

section() {
  echo -e "\n${MAGENTA}${BOLD}═══════════════════════════════════════════════${RESET}"
  echo -e "${MAGENTA}${BOLD}  $1${RESET}"
  echo -e "${MAGENTA}${BOLD}═══════════════════════════════════════════════${RESET}\n"
}

# Cleanup function for temporary files
cleanup() {
  [[ -n "${PARU_TMP_DIR:-}" ]] && rm -rf "$PARU_TMP_DIR"
}

# Error and cleanup handlers
trap cleanup EXIT
trap 'error "Installation failed at line $LINENO. Exiting."; exit 1' ERR

# Check if running on Arch Linux
if [[ ! -f /etc/arch-release ]]; then
  error "This script is designed for Arch Linux only."
  exit 1
fi

# Check if running as root (we don't want that)
if [[ $EUID -eq 0 ]]; then
  error "This script should NOT be run as root. Run it as a regular user with sudo privileges."
  exit 1
fi

# Check for sudo privileges
if ! sudo -v; then
  error "This script requires sudo privileges. Please run with a user that has sudo access."
  exit 1
fi

# Welcome banner
[[ -t 1 ]] && clear
echo -e "${CYAN}${BOLD}"
cat << "EOF"
╔═══════════════════════════════════════════════════════════╗
║                                                           ║
║     Arch Linux Hyprland Development Environment           ║
║                   Installer v2.0                          ║
║                                                           ║
╚═══════════════════════════════════════════════════════════╝
EOF
echo -e "${RESET}"

info "Starting installation process..."
sleep 2

# Update system
section "System Update"
info "Updating system packages..."
sudo pacman -Syu --noconfirm

# Install paru
section "AUR Helper Installation"
if ! command -v paru &> /dev/null; then
  info "paru not found. Installing paru..."
  
  # Install build dependencies
  sudo pacman -S --needed --noconfirm git base-devel
  
  # Create temporary directory
  readonly PARU_TMP_DIR=$(mktemp -d)
  
  # Clone and build paru
  git clone https://aur.archlinux.org/paru.git "$PARU_TMP_DIR"
  pushd "$PARU_TMP_DIR" > /dev/null
  makepkg -si --needed --noconfirm
  popd > /dev/null
  
  success "paru installed successfully"
else
  success "paru is already installed"
fi

# Install official packages
section "Official Package Installation"
info "Installing official Arch Linux packages..."

readonly OFFICIAL_PACKAGES=(
  # Window manager and bars
  hyprland waybar hyprpaper xdg-desktop-portal-hyprland
  
  # Terminal and shell
  kitty zsh zsh-completions
  
  # System utilities
  btop lsd fd wl-clipboard grim slurp jq pacman-contrib
  
  # File management
  thunar thunar-archive-plugin tumbler
  gvfs gvfs-mtp gvfs-smb gvfs-nfs gvfs-gphoto2 gvfs-afc
  
  # Application launchers and notifications
  wofi dunst
  
  # Theming and appearance
  python-pywal python-gobject gtk3 qt5ct lxappearance gnome-tweaks
  
  # Fonts
  ttf-jetbrains-mono-nerd
  
  # Networking
  networkmanager network-manager-applet
  
  # Audio (Pipewire)
  pipewire pipewire-pulse wireplumber
  
  # Wayland portal (Hyprland-specific)
  xdg-desktop-portal
  
  # Session management
  seatd
  
  # Security and permissions
  polkit polkit-gnome
  
  # Development and editors
  code nodejs npm
  
  # Python dependencies
  python python-pillow tk
  
  # Applications
  obsidian mpv nano
  
  # XDG utilities
  xdg-user-dirs
)

sudo pacman -S --needed --noconfirm "${OFFICIAL_PACKAGES[@]}"
success "Official packages installed"

# Create XDG directories
section "XDG Directory Setup"
info "Creating standard XDG user directories..."
if xdg-user-dirs-update --force; then
  success "XDG directories created"
else
  warn "XDG directory creation failed (this may happen if locale isn't configured)"
  info "You can run 'xdg-user-dirs-update' manually after setting up your locale"
fi

# Install AUR packages
section "AUR Package Installation"
warn "AUR packages will be installed without manual PKGBUILD review."
info "Installing AUR packages via paru..."

readonly AUR_PACKAGES=(
  brave-bin
  wal-gtk
  pavucontrol-gtk3
  oh-my-posh
  nordic-theme-git
  themix-gui-git
  themix-theme-oomox-git
  wpgtk-git
)

paru -S --needed --noconfirm "${AUR_PACKAGES[@]}"
success "AUR packages installed"

# Clone dotfiles and dependencies
section "Dotfiles and Configuration"

info "Setting up Zsh plugins..."
readonly ZSH_DIR="$HOME/.zsh"
mkdir -p "$ZSH_DIR"

if [[ ! -d "$ZSH_DIR/zsh-autosuggestions" ]]; then
  info "Installing zsh-autosuggestions..."
  git clone https://github.com/zsh-users/zsh-autosuggestions "$ZSH_DIR/zsh-autosuggestions"
else
  warn "zsh-autosuggestions already exists, skipping..."
fi

if [[ ! -d "$ZSH_DIR/zsh-syntax-highlighting" ]]; then
  info "Installing zsh-syntax-highlighting..."
  git clone https://github.com/zsh-users/zsh-syntax-highlighting "$ZSH_DIR/zsh-syntax-highlighting"
else
  warn "zsh-syntax-highlighting already exists, skipping..."
fi

readonly DOTFILES_DIR="$HOME/R7dotfiles-install"
if [[ ! -d "$DOTFILES_DIR" ]]; then
  info "Cloning dotfiles repository..."
  git clone https://github.com/Reep007/R7dotfiles-install.git "$DOTFILES_DIR"
  success "Dotfiles cloned to $DOTFILES_DIR"
else
  warn "Dotfiles directory already exists at $DOTFILES_DIR"
  read -p "Do you want to update it? (y/N): " -n 1 -r
  echo
  if [[ $REPLY =~ ^[Yy]$ ]]; then
    pushd "$DOTFILES_DIR" > /dev/null
    git pull
    popd > /dev/null
    success "Dotfiles updated"
  fi
fi

# Set Zsh as default shell
section "Shell Configuration"
readonly ZSH_PATH="$(command -v zsh)"
if [[ "$SHELL" != "$ZSH_PATH" ]]; then
  info "Setting Zsh as default shell..."
  if chsh -s "$ZSH_PATH" "$USER"; then
    success "Zsh set as default shell"
  else
    warn "Failed to change default shell. You may need to run: chsh -s $ZSH_PATH"
  fi
else
  success "Zsh is already the default shell"
fi

# Enable services
section "System Services"
info "Enabling and starting NetworkManager..."
sudo systemctl enable --now NetworkManager.service
success "NetworkManager enabled and started"

info "Enabling seatd for Wayland session management..."
sudo systemctl enable seatd.service
success "seatd enabled"

info "Adding user to 'seat' group for Hyprland session access..."
sudo usermod -aG seat "$USER"
success "User added to 'seat' group (requires relogin/reboot to take effect)"

# Final message
section "Installation Complete"
echo -e "${GREEN}${BOLD}"
cat << "EOF"
╔═══════════════════════════════════════════════════════════╗
║                                                           ║
║              ✅ Installation Successful! ✅              ║
║                                                           ║
║  Next steps:                                              ║
║  1. Reboot your system (required for group membership)    ║
║  2. Start Hyprland from TTY with: Hyprland                ║
║  3. Configure your dotfiles from ~/R7dotfiles-install     ║
║                                                           ║
║  Note: Hyprland is started manually from TTY.             ║
║  Consider installing a display manager (greetd, sddm)     ║
║  for automatic graphical login if desired.                ║
║                                                           ║
╚═══════════════════════════════════════════════════════════╝
EOF
echo -e "${RESET}"

warn "A reboot is recommended to apply all changes."
read -p "Would you like to reboot now? (y/N): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
  info "Rebooting in 5 seconds... Press Ctrl+C to cancel."
  sleep 5
  sudo reboot
else
  info "Please remember to reboot when convenient."
fi
