#!/usr/bin/env bash
# R007-dotfiles — Ultimate One-Command Rice Installer
# Hyprland + Pywal + Full Theming + Optional ZenForge (source only)
# https://github.com/Reep007/R007-dotfiles

set -euo pipefail

# Colors
info()    { echo -e "\033[1;34m[INFO]\033[0m   $*"; }
success() { echo -e "\033[1;32m[OK]\033[0m      $*"; }
warn()    { echo -e "\033[1;33m[WARN]\033[0m    $*"; }
error()   { echo -e "\033[1;31m[ERROR]\033[0m  $*"; exit 1; }

[[ -f /etc/arch-release ]] || error "This script only works on Arch Linux!"

# Keep sudo alive during the whole process
sudo -v
( while true; do sudo -n true; sleep 60; kill -0 "$$" || exit; done ) 2>/dev/null &

# paru AUR helper
if ! command -v paru &>/dev/null; then
  info "Installing paru AUR helper..."
  sudo pacman -Sy --noconfirm --needed base-devel git
  tmpdir=$(mktemp -d); trap 'rm -rf "$tmpdir"' EXIT
  git clone https://aur.archlinux.org/paru.git "$tmpdir/paru"
  cd "$tmpdir/paru" && makepkg --syncdeps --install --noconfirm
  success "paru installed"
else
  info "paru already available"
fi

# Official packages
info "Installing official packages..."
batches=(
  "hyprland waybar hyprpaper swww kitty hypridle hyprlock"
  "wofi dunst grim slurp wl-clipboard cliphist xdg-user-dirs"
  "thunar thunar-archive-plugin tumbler gvfs gvfs-mtp gvfs-smb"
  "nwg-look qt5ct kvantum qt5-wayland qt6-wayland xdg-desktop-portal-hyprland xdg-desktop-portal-gtk"
  "ttf-jetbrains-mono-nerd lsd btop"
  "python python-pillow python-pywal python-gobject tk imagemagick papirus-icon-theme"
  "network-manager-applet polkit-gnome mpv nano obsidian jq nodejs npm pacman-contrib zsh zsh-completions"
  "sddm"
)

for pkgs in "${batches[@]}"; do
  sudo pacman -S --noconfirm --needed $pkgs >/dev/null 2>&1 || true
done

# AUR packages
info "Installing AUR packages..."
for pkg in brave-bin nordic-theme-git wpgtk-git themix-full-git oh-my-posh; do
  paru -S --noconfirm --needed "$pkg" >/dev/null 2>&1 || warn "Failed: $pkg"
done

# Zsh plugins
info "Setting up Zsh plugins..."
xdg-user-dirs-update --force >/dev/null 2>&1
mkdir -p "$HOME/.zsh"
for p in zsh-autosuggestions zsh-syntax-highlighting; do
  [[ -d "$HOME/.zsh/$p" ]] || git clone --quiet --depth 1 "https://github.com/zsh-users/$p" "$HOME/.zsh/$p"
done

# Pull your beautiful dotfiles
info "Applying R007 dotfiles..."
[[ -d "$HOME/R007-dotfiles" ]] || git clone --depth 1 https://github.com/Reep007/R007-dotfiles.git "$HOME/R007-dotfiles"
rsync -a --delete "$HOME/R007-dotfiles/.config/" "$HOME/.config/" >/dev/null 2>&1
rsync -a --delete "$HOME/R007-dotfiles/.local/"  "$HOME/.local/"  >/dev/null 2>&1
success "Dotfiles applied"

# Shell + services
[[ "$SHELL" == */zsh ]] || chsh -s "$(which zsh)" "$USER"
sudo systemctl enable --now NetworkManager sddm >/dev/null 2>&1

# Pull ZenForge source (no compile, no install — just ready when you want it)
info "Pulling ZenForge system manager (source only)..."
if [[ -d "$HOME/ZENFORGE" ]]; then
  (cd "$HOME/ZENFORGE" && git pull --quiet --ff-only) >/dev/null 2>&1
  success "ZENFORGE directory updated"
else
  git clone --depth 1 https://github.com/Reep007/ZENFORGE.git "$HOME/ZENFORGE" >/dev/null 2>&1
  success "ZENFORGE cloned to ~/ZENFORGE"
fi

# Final banner
clear
cat << "EOF"

╔══════════════════════════════════════════════════════════╗
║                                                          ║
║        R007 Rice + ZenForge — Installation Complete!     ║
║                                                          ║
║    • All dotfiles applied                                ║
║    • Hyprland + full theming ready                       ║
║    • SDDM will start on next boot                        ║
║                                                          ║
║    ZenForge is waiting in ~/ZENFORGE                     ║
║    → When you want generations/rollbacks/snapshots:      ║
║         cd ~/ZENFORGE && cargo install --path . --locked ║
║         zenforge switch                                  ║
║                                                          ║
╚══════════════════════════════════════════════════════════╝

EOF

echo "Rebooting in 20 seconds (Ctrl+C to cancel)..."
sleep 20
exec sudo reboot
