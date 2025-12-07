#!/usr/bin/env bash
set -euo pipefail

info()    { echo -e "\033[1;34m[INFO]\033[0m   $*"; }
success() { echo -e "\033[1;32m[OK]\033[0m      $*"; }
warn()    { echo -e "\033[1;33m[WARN]\033[0m    $*"; }
error()   { echo -e "\033[1;31m[ERROR]\033[0m  $*"; exit 1; }

[[ -f /etc/arch-release ]] || error "This script only works on Arch Linux!"

# Keep sudo alive
sudo -v
( while true; do sudo -n true; sleep 60; kill -0 "$$" || exit; done ) 2>/dev/null &

# paru
if ! command -v paru &>/dev/null; then
  info "Installing paru AUR helper..."
  sudo pacman -Sy --noconfirm --needed base-devel git
  tmpdir=$(mktemp -d); trap 'rm -rf "$tmpdir"' EXIT
  git clone https://aur.archlinux.org/paru.git "$tmpdir/paru"
  cd "$tmpdir/paru" && makepkg --syncdeps --install --noconfirm
  success "paru installed"
else
  info "paru is already installed"
fi

# Official + AUR packages (your exact list)
info "Installing packages..."
batches=(
  "hyprland waybar hyprpaper swww kitty hypridle hyprlock wofi dunst grim slurp wl-clipboard cliphist xdg-user-dirs thunar thunar-archive-plugin tumbler gvfs gvfs-mtp gvfs-smb"
  "nwg-look qt5ct kvantum qt5-wayland qt6-wayland xdg-desktop-portal-hyprland xdg-desktop-portal-gtk"
  "ttf-jetbrains-mono-nerd lsd btop python python-pillow python-pywal python-gobject tk imagemagick papirus-icon-theme"
  "network-manager-applet polkit-gnome mpv nano obsidian jq nodejs npm pacman-contrib zsh zsh-completions sddm"
)

for pkgs in "${batches[@]}"; do
  sudo pacman -S --noconfirm --needed $pkgs || true
done

paru -S --noconfirm --needed brave-bin nordic-theme-git wpgtk-git themix-full-git oh-my-posh || true

# Zsh plugins & dotfiles
info "Setting up dotfiles and shell..."
xdg-user-dirs-update --force >/dev/null 2>&1
mkdir -p "$HOME/.zsh"
for p in zsh-autosuggestions zsh-syntax-highlighting; do
  [[ -d "$HOME/.zsh/$p" ]] || git clone "https://github.com/zsh-users/$p" "$HOME/.zsh/$p" >/dev/null 2>&1
done

[[ -d "$HOME/R007-dotfiles" ]] || git clone https://github.com/Reep007/R007-dotfiles.git "$HOME/R007-dotfiles"
rsync -a --delete "$HOME/R007-dotfiles/.config/" "$HOME/.config/" >/dev/null 2>&1
rsync -a --delete "$HOME/R007-dotfiles/.local/"  "$HOME/.local/"  >/dev/null 2>&1

[[ "$SHELL" == */zsh ]] || chsh -s "$(which zsh)" "$USER"
sudo systemctl enable --now NetworkManager sddm

# ZenForge — the cherry on top
info "Installing ZenForge (optional but highly recommended)..."
if ! command -v zenforge &>/dev/null; then
  if ! command -v cargo &>/dev/null; then
    curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
    source "$HOME/.cargo/env"
  fi
  cargo install --git https://github.com/Reep007/ZENFORGE.git --locked
fi

success "R007 rice installed!"
echo
echo "   Dotfiles applied • SDDM ready • ZenForge available"
echo "   Run 'zenforge switch' now or after reboot to activate generations & BTRFS snapshots"
echo
echo "Rebooting in 15 seconds (Ctrl+C to cancel)..."
sleep 15
sudo reboot
