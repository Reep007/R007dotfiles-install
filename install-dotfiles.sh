#!/bin/bash

# Script to install programs and dependencies for your dotfiles after a minimal Arch Linux installation

# Exit on any error
set -e

# Check for internet connection
if ! ping -c 1 archlinux.org &> /dev/null; then
 echo "Error: No internet connection. Please connect and try again."
 exit 1
fi

echo "Starting installation process..."

# Update system and install base dependencies
echo "Updating system and installing base packages..."
sudo pacman -Syu --noconfirm
sudo pacman -S --noconfirm base-devel git

# Install yay (AUR helper) if not already installed
if ! command -v yay &> /dev/null; then
 echo "Installing yay AUR helper..."
 git clone https://aur.archlinux.org/yay.git /tmp/yay
 cd /tmp/yay
 makepkg -si --noconfirm
 cd ~
 rm -rf /tmp/yay
fi

# Clone your dotfiles repository (replace with your actual GitHub URL)
echo "Cloning dotfiles from GitHub..."
git clone https://github.com/Reep007/.dotfiles.git

# Install official Arch Linux packages
echo "Installing official Arch Linux packages..."
sudo pacman -S --noconfirm \
 hyprland waybar hyprpaper kitty zsh zsh-completions oh-my-posh btop \
 thunar thunar-archive-plugin tumbler rofi wofi dunst python-pywal \
 papirus-icon-theme nordic-theme qt5ct kvantum networkmanager network-manager-applet \
 polkit-gnome brightnessctl pipewire pipewire-alsa pipewire-pulse wireplumber pavucontrol \
 bluez bluez-utils mpv firefox neovim ttf-jetbrains-mono-nerd playerctl wl-clipboard grim slurp

# Install AUR packages using yay
echo "Installing AUR packages..."
yay -S --noconfirm \
 themix-gui-git themix-theme-oomox-git themix-icons-papirus-git

# Set up dotfiles configurations
echo "Setting up dotfiles..."
cd ~/.dotfiles

# Link configuration files using stow (install stow if not present)
if ! command -v stow &> /dev/null; then
 sudo pacman -S --noconfirm stow
fi
stow -t ~ .config .zshrc .bashrc

# Set up custom scripts
echo "Setting up custom scripts..."
mkdir -p ~/.local/bin
cp -r bin/* ~/.local/bin/
chmod +x ~/.local/bin/*

# Set up Wallpaper and Pic4_terminal directories
echo "Setting up Wallpaper and Pic4_terminal..."
mkdir -p ~/Wallpaper ~/Pic4_terminal
cp -r Wallpaper/* ~/Wallpaper/
cp -r Pic4_terminal/* ~/Pic4_terminal/

# Set up custom icons (assuming pywal-custom is in .icons/)
if [ -d ".icons" ]; then
 echo "Setting up custom icons..."
 mkdir -p ~/.icons
 cp -r .icons/* ~/.icons/
 gtk-update-icon-cache ~/.icons
fi

# Set Zsh as the default shell
if [ "$SHELL" != "/bin/zsh" ]; then
 echo "Setting Zsh as default shell..."
 chsh -s /bin/zsh
fi

# Enable necessary services
echo "Enabling services..."
sudo systemctl enable bluetooth
sudo systemctl enable NetworkManager

# Final message
echo "Installation complete! Rebooting in 5 seconds..."
sleep 5
reboot
