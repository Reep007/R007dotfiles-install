#!/bin/bash

# Dotfiles Setup Script for Arch Linux
# Installs packages, clones dotfiles, and configures the user environment

set -euo pipefail

# --- Variables ---
DOTFILES_REPO="https://github.com/Reep007/.dotfiles.git"
DOTFILES_DIR="$HOME/.dotfiles"
AUR_HELPER="yay"
LOGFILE="$HOME/dotfiles-setup.log"

# --- Logging ---
exec > >(tee -a "$LOGFILE") 2>&1

# --- Helper Functions ---

info()    { echo -e "\e[34m[INFO]\e[0m $*"; }
success() { echo -e "\e[32m[SUCCESS]\e[0m $*"; }
error()   { echo -e "\e[31m[ERROR]\e[0m $*" >&2; }

check_cmd() {
  command -v "$1" &>/dev/null
}

# --- Pre-flight Checks ---

info "Checking internet connection..."
if ! ping -c 1 archlinux.org &> /dev/null; then
  error "No internet connection. Please connect and try again."
  exit 1
fi

info "Updating system and installing base packages..."
sudo pacman -Syu --noconfirm
sudo pacman -S --noconfirm base-devel git

# --- Install AUR Helper (yay) ---
if ! check_cmd "$AUR_HELPER"; then
  info "Installing AUR helper: $AUR_HELPER..."
  git clone https://aur.archlinux.org/"$AUR_HELPER".git /tmp/"$AUR_HELPER"
  pushd /tmp/"$AUR_HELPER"
  makepkg -si --noconfirm
  popd
  rm -rf /tmp/"$AUR_HELPER"
fi

# --- Clone Dotfiles ---
if [ ! -d "$DOTFILES_DIR" ]; then
  info "Cloning dotfiles from $DOTFILES_REPO..."
  git clone "$DOTFILES_REPO" "$DOTFILES_DIR"
else
  info "Dotfiles directory already exists. Skipping clone."
fi

# --- Install Official Packages ---
info "Installing official Arch Linux packages..."
sudo pacman -S --noconfirm \
  hyprland waybar hyprpaper kitty zsh zsh-completions oh-my-posh btop \
  thunar thunar-archive-plugin tumbler rofi wofi dunst python-pywal \
  papirus-icon-theme nordic-theme qt5ct kvantum networkmanager network-manager-applet \
  polkit-gnome brightnessctl pipewire pipewire-alsa pipewire-pulse wireplumber pavucontrol \
  bluez bluez-utils mpv firefox neovim ttf-jetbrains-mono-nerd playerctl wl-clipboard grim slurp

# --- Install AUR Packages ---
info "Installing AUR packages..."
yay -S --noconfirm \
  themix-gui-git themix-theme-oomox-git themix-icons-papirus-git

# --- Set up Dotfiles ---
info "Setting up dotfiles..."
cd "$DOTFILES_DIR"

if ! check_cmd stow; then
  info "Installing stow..."
  sudo pacman -S --noconfirm stow
fi

stow -t "$HOME" .config .zshrc .bashrc

# --- Custom Scripts ---
info "Setting up custom scripts..."
mkdir -p "$HOME/.local/bin"
cp -r bin/* "$HOME/.local/bin/"
chmod +x "$HOME/.local/bin/"*

# --- Wallpaper and Pic4_terminal ---
info "Setting up Wallpaper and Pic4_terminal directories..."
mkdir -p "$HOME/Wallpaper" "$HOME/Pic4_terminal"
cp -r Wallpaper/* "$HOME/Wallpaper/" 2>/dev/null || true
cp -r Pic4_terminal/* "$HOME/Pic4_terminal/" 2>/dev/null || true

# --- Custom Icons ---
if [ -d ".icons" ]; then
  info "Setting up custom icons..."
  mkdir -p "$HOME/.icons"
  cp -r .icons/* "$HOME/.icons/"
  gtk-update-icon-cache "$HOME/.icons" || true
fi

# --- Set Zsh as Default Shell ---
if [ "$SHELL" != "/bin/zsh" ]; then
  info "Setting Zsh as the default shell..."
  chsh -s /bin/zsh
fi

# --- Enable and Start Services ---
info "Enabling and starting system services..."
sudo systemctl enable --now bluetooth
sudo systemctl enable --now NetworkManager

# --- Done ---
success "Installation complete!"

# Prompt before reboot
read -rp "Reboot now to apply all changes? [y/N]: " response
if [[ "$response" =~ ^[Yy]$ ]]; then
  sudo reboot
else
  info "Please reboot manually when ready."
fi
