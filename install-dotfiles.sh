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
  sudo pacman -S --noconfirm --needed git base-devel
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
  hyprland waybar hyprpaper python xdg-desktop-portal-hyprland kitty lsd zsh zsh-completions btop python-pillow python tk \
  thunar thunar-archive-plugin tumbler wofi rofi dunst python-pywal python-gobject xdg-user-dirs gtk3 gtk2 \
  qt5ct network-manager-applet jq nodejs npm pacman-contrib gtk-engine-murrine gtk-engines code \
  gvfs gvfs-mtp gvfs-smb gvfs-nfs gvfs-gphoto2 gvfs-afc polkit polkit-gnome obsidian sddm \
  mpv nano ttf-jetbrains-mono-nerd wl-clipboard grim slurp fd lxappearance gnome-tweaks 

# Create standard XDG user directories (Documents, Downloads, Pictures, etc.)
info "Creating standard XDG user directories..."
xdg-user-dirs-update --force

# Install AUR packages
info "Installing AUR packages via yay..."
yay -S --noconfirm \
  brave-bin wal-gtk pavucontrol-gtk3 oh-my-posh nordic-theme-git themix-gui-git themix-theme-oomox-git wpgtk-git

# Clone dotfiles
info "Cloning dotfiles from GitHub..."
git clone https://github.com/zsh-users/zsh-autosuggestions ~/.zsh/zsh-autosuggestions
git clone https://github.com/zsh-users/zsh-syntax-highlighting ~/.zsh/zsh-syntax-highlighting
git clone https://github.com/Reep007/R007-dotfiles.git ~/R007-dotfiles

# Set Zsh as the default shell for the current user
if [[ "$SHELL" != "/bin/zsh" ]]; then
  info "Setting Zsh as default shell..."
  chsh -s /bin/zsh
fi

# Enable necessary systemd services
info "Enabling systemd services..."
sudo systemctl enable NetworkManager

info "✅ Setup complete! Please reboot or log out and log back in to apply all changes."
