#!/usr/bin/env bash

set -e

# Helper for better log messages
info() {
  echo -e "\033[1;32m[INFO]\033[0m $1"
}

error() {
  echo -e "\033[1;31m[ERROR]\033[0m $1"
}

# Ensure yay is installed
if ! command -v yay &> /dev/null; then
  info "yay not found. Installing yay..."
  sudo pacman -S --needed git base-devel
  git clone https://aur.archlinux.org/yay.git /tmp/yay
  pushd /tmp/yay
  makepkg -si --noconfirm
  popd
else
  info "yay is already installed"
fi

# Install official Arch Linux packages
info "Installing official Arch Linux packages..."
sudo pacman -S --noconfirm \
  hyprland waybar hyprpaper kitty zsh zsh-completions btop \
  thunar thunar-archive-plugin tumbler rofi wofi dunst python-pywal \
  papirus-icon-theme qt5ct kvantum networkmanager network-manager-applet \
  polkit-gnome brightnessctl pipewire pipewire-pulse wireplumber pavucontrol \
  bluez bluez-utils mpv firefox neovim ttf-jetbrains-mono-nerd playerctl wl-clipboard grim slurp \
  stow

# Create standard XDG user directories (Documents, Downloads, Pictures, etc.)
info "Creating standard XDG user directories..."
xdg-user-dirs-update

# Install AUR packages
info "Installing AUR packages via yay..."
yay -S --noconfirm \
  oh-my-posh-bin nordic-theme-git themix-gui-git themix-theme-oomox-git themix-icons-papirus-git

# Clone your dotfiles repository
info "Cloning dotfiles from GitHub..."
git clone https://github.com/Reep007/.dotfiles.git ~/.dotfiles

# Apply dotfiles using stow
info "Applying dotfiles using stow..."
cd ~/.dotfiles
stow */

# Set Zsh as the default shell for the current user
if [[ "$SHELL" != "/bin/zsh" ]]; then
  info "Setting Zsh as default shell..."
  chsh -s /bin/zsh
fi

# Enable necessary systemd services
info "Enabling systemd services..."
sudo systemctl enable NetworkManager
sudo systemctl enable bluetooth
sudo systemctl enable --now pipewire pipewire-pulse wireplumber

info "✅ Setup complete! Please reboot or log out and log back in to apply all changes."
