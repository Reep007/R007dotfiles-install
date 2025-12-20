#!/usr/bin/env bash
set -euo pipefail

# -------------------------
# Script Configuration
# -------------------------
readonly VERSION="2.3"
readonly SCRIPT_NAME="$(basename "$0")"

# -------------------------
# Color definitions
# -------------------------
readonly RED='\033[1;31m'
readonly GREEN='\033[1;32m'
readonly YELLOW='\033[1;33m'
readonly MAGENTA='\033[1;35m'
readonly CYAN='\033[1;36m'
readonly RESET='\033[0m'
readonly BOLD='\033[1m'

# -------------------------
# Logging functions
# -------------------------
info()    { echo -e "${GREEN}${BOLD}[INFO]${RESET} $1"; }
success() { echo -e "${CYAN}${BOLD}[SUCCESS]${RESET} $1"; }
warn()    { echo -e "${YELLOW}${BOLD}[WARNING]${RESET} $1"; }
error()   { echo -e "${RED}${BOLD}[ERROR]${RESET} $1"; }
section() {
    echo -e "\n${MAGENTA}${BOLD}═══════════════════════════════════════════════${RESET}"
    echo -e "${MAGENTA}${BOLD}  $1${RESET}"
    echo -e "${MAGENTA}${BOLD}═══════════════════════════════════════════════${RESET}\n"
}

# -------------------------
# Help text
# -------------------------
show_help() {
    cat << EOF
${BOLD}Arch Linux Hyprland Development Environment Installer${RESET}
Version: ${VERSION}

${BOLD}USAGE:${RESET}
    $SCRIPT_NAME [OPTIONS]

${BOLD}OPTIONS:${RESET}
    -y, --yes       Auto-confirm all prompts (non-interactive mode)
    --reboot        Automatically reboot after successful installation
    -h, --help      Show this help message and exit

${BOLD}DESCRIPTION:${RESET}
    Installs a complete Hyprland-based development environment on Arch Linux.
    This script is designed for fresh installations only and includes safety
    checks to prevent overwriting existing configurations.

${BOLD}REQUIREMENTS:${RESET}
    - Fresh Arch Linux installation
    - User account with sudo privileges
    - Internet connection
    - At least 10GB free disk space

${BOLD}EXAMPLES:${RESET}
    $SCRIPT_NAME                    # Interactive installation
    $SCRIPT_NAME --yes              # Non-interactive installation
    $SCRIPT_NAME --yes --reboot     # Install and auto-reboot

${BOLD}INSTALLED COMPONENTS:${RESET}
    - Hyprland (Wayland compositor)
    - Waybar, Kitty, Zsh with plugins
    - Pipewire audio stack
    - Development tools (VS Code, Node.js, Python)
    - Theming tools (pywal, nordic-theme)
    - Essential utilities and applications

For more information, visit:
https://github.com/Reep007/R7dotfiles-install
EOF
    exit 0
}

# -------------------------
# Flags and arguments
# -------------------------
AUTO_CONFIRM=false
AUTO_REBOOT=false

for arg in "$@"; do
    case $arg in
        -h|--help)
            show_help
            ;;
        --yes|-y)
            AUTO_CONFIRM=true
            ;;
        --reboot)
            AUTO_REBOOT=true
            ;;
        *)
            error "Unknown option: $arg"
            echo "Use --help for usage information"
            exit 1
            ;;
    esac
done

# -------------------------
# Cleanup
# -------------------------
PARU_TMP_DIR=""

cleanup() {
    [[ -n "${PARU_TMP_DIR:-}" ]] && rm -rf "$PARU_TMP_DIR"
}
trap cleanup EXIT
trap 'error "Installation failed at line $LINENO. Exiting."; exit 1' ERR

# -------------------------
# Environment checks
# -------------------------
if [[ ! -f /etc/arch-release ]]; then
    error "This script is designed for Arch Linux only."
    exit 1
fi

if [[ $EUID -eq 0 ]]; then
    error "Do NOT run as root. Use a regular user with sudo privileges."
    exit 1
fi

if ! sudo -v; then
    error "Sudo privileges are required."
    exit 1
fi

# -------------------------
# Fresh install safety checks
# -------------------------
if command -v hyprland &> /dev/null; then
    error "Hyprland is already installed. This script is for fresh installs only."
    exit 1
fi

if [[ -d "$HOME/R7dotfiles-install" ]]; then
    error "Dotfiles directory exists. This script is for fresh installs only."
    exit 1
fi

if [[ -d "$HOME/.zsh" ]]; then
    warn "Existing Zsh configuration detected. Proceeding may overwrite it."
    if ! $AUTO_CONFIRM; then
        read -p "Continue anyway? (y/N): " -n 1 -r
        echo
        [[ ! $REPLY =~ ^[Yy]$ ]] && exit 1
    fi
fi

# -------------------------
# Welcome banner
# -------------------------
[[ -t 1 ]] && clear
echo -e "${CYAN}${BOLD}"
cat << "EOF"
╔═══════════════════════════════════════════════════════════╗
║                                                           ║
║     Arch Linux Hyprland Development Environment          ║
EOF
echo -e "║                   Installer v${VERSION}                          ║"
cat << "EOF"
║           (Fresh Install Only – Safety Checks)            ║
║                                                           ║
╚═══════════════════════════════════════════════════════════╝
EOF
echo -e "${RESET}"

info "Starting installation process..."
sleep 1

# -------------------------
# System Update
# -------------------------
section "System Update"
info "Updating system packages..."
if $AUTO_CONFIRM; then
    sudo pacman -Syu --noconfirm
else
    sudo pacman -Syu
fi
success "System update complete"

# -------------------------
# Install paru (AUR helper)
# -------------------------
section "AUR Helper Installation"
if ! command -v paru &> /dev/null; then
    info "paru not found. Installing..."
    sudo pacman -S --needed --noconfirm git base-devel
    PARU_TMP_DIR=$(mktemp -d)
    git clone https://aur.archlinux.org/paru.git "$PARU_TMP_DIR"
    pushd "$PARU_TMP_DIR" > /dev/null
    makepkg -si --needed --noconfirm -j"$(nproc)"
    popd > /dev/null
    success "paru installed successfully"
else
    success "paru is already installed"
fi

# -------------------------
# Official packages
# -------------------------
section "Official Package Installation"
info "Installing official Arch Linux packages..."

readonly OFFICIAL_PACKAGES=(
    hyprland waybar hyprpaper xdg-desktop-portal-hyprland
    kitty zsh zsh-completions
    btop lsd fd wl-clipboard grim slurp jq pacman-contrib
    thunar thunar-archive-plugin tumbler
    gvfs gvfs-mtp gvfs-smb gvfs-nfs gvfs-gphoto2 gvfs-afc
    wofi dunst
    python-pywal python-gobject gtk3 qt5ct lxappearance gnome-tweaks
    ttf-jetbrains-mono-nerd
    networkmanager network-manager-applet
    pipewire pipewire-pulse wireplumber
    xdg-desktop-portal
    seatd
    polkit polkit-gnome
    code nodejs npm
    python python-pillow tk
    obsidian mpv nano
    xdg-user-dirs
)

sudo pacman -S --needed --noconfirm "${OFFICIAL_PACKAGES[@]}"
success "Official packages installed"

# -------------------------
# XDG directories
# -------------------------
section "XDG Directory Setup"
if ! locale -a | grep -qi "en_US.utf8\|en_US.UTF-8"; then
    warn "Locales may not be configured; XDG directories might fail."
    info "To fix: Edit /etc/locale.gen, uncomment your locale, then run 'sudo locale-gen'"
fi
if xdg-user-dirs-update --force; then
    success "XDG directories created"
else
    warn "XDG directory creation failed"
    info "Run 'xdg-user-dirs-update' manually after configuring locales"
fi

# -------------------------
# AUR Packages
# -------------------------
section "AUR Package Installation"
warn "AUR packages will be installed without PKGBUILD review."
readonly AUR_PACKAGES=(
    brave-bin wal-gtk pavucontrol-gtk3 oh-my-posh
    nordic-theme-git themix-gui-git themix-theme-oomox-git wpgtk-git
)
paru -S --needed --noconfirm "${AUR_PACKAGES[@]}"
success "AUR packages installed"

# -------------------------
# Dotfiles and Zsh plugins
# -------------------------
section "Dotfiles and Configuration"

readonly ZSH_DIR="$HOME/.zsh"
mkdir -p "$ZSH_DIR"

declare -A ZSH_PLUGINS=(
    [zsh-autosuggestions]="https://github.com/zsh-users/zsh-autosuggestions"
    [zsh-syntax-highlighting]="https://github.com/zsh-users/zsh-syntax-highlighting"
)

for plugin in "${!ZSH_PLUGINS[@]}"; do
    if [[ ! -d "$ZSH_DIR/$plugin" ]]; then
        info "Installing $plugin..."
        git clone "${ZSH_PLUGINS[$plugin]}" "$ZSH_DIR/$plugin"
    else
        warn "$plugin already exists, skipping..."
    fi
done

info "Cloning dotfiles..."
git clone https://github.com/Reep007/R7dotfiles-install.git "$HOME/R7dotfiles-install"
success "Dotfiles cloned"

# -------------------------
# Zsh as default shell
# -------------------------
section "Shell Configuration"
readonly ZSH_PATH="$(command -v zsh)"
if [[ "$SHELL" != "$ZSH_PATH" ]]; then
    info "Setting Zsh as default shell..."
    if chsh -s "$ZSH_PATH" "$USER"; then
        success "Zsh set as default shell"
    else
        warn "Failed to change default shell. Run manually: chsh -s $ZSH_PATH"
    fi
else
    success "Zsh is already default shell"
fi

# -------------------------
# Services
# -------------------------
section "System Services"
info "Enabling NetworkManager..."
sudo systemctl enable --now NetworkManager.service
success "NetworkManager enabled"

info "Enabling seatd..."
sudo systemctl enable seatd.service
success "seatd enabled"

if ! id -nG "$USER" | grep -qw "seat"; then
    info "Adding user to 'seat' group..."
    sudo usermod -aG seat "$USER"
    success "User added to 'seat' group (requires relogin/reboot)"
else
    success "User already in 'seat' group"
fi

# -------------------------
# Completion
# -------------------------
section "Installation Complete"
echo -e "${GREEN}${BOLD}"
cat << "EOF"
╔═══════════════════════════════════════════════════════════╗
║                                                           ║
║              ✅ Installation Successful! ✅                ║
║                                                           ║
║  Next steps:                                              ║
║  1. Reboot your system (required for group membership)    ║
║  2. Start Hyprland from TTY with: Hyprland                ║
║  3. Configure your dotfiles from ~/R7dotfiles-install     ║
║                                                           ║
╚═══════════════════════════════════════════════════════════╝
EOF
echo -e "${RESET}"

warn "A reboot is recommended to apply all changes."

if $AUTO_REBOOT; then
    info "Rebooting in 5 seconds..."
    sleep 5
    sudo reboot
elif ! $AUTO_CONFIRM; then
    read -p "Reboot now? (y/N): " -n 1 -r
    echo
    [[ $REPLY =~ ^[Yy]$ ]] && sudo reboot
else
    info "Please reboot at your convenience."
fi
