#!/usr/bin/env bash
set -euo pipefail

# Colors & messages
info()    { echo -e "\033[1;34m[INFO]\033[0m   $*"; }
success() { echo -e "\033[1;32m[OK]\033[0m      $*"; }
warn()    { echo -e "\033[1;33m[WARN]\033[0m    $*"; }

# 8. Keep sudo alive for the entire script (no re-prompts during long AUR builds)
sudo -v
( while true; do sudo -n true; sleep 60; kill -0 "$$" || exit; done ) 2>/dev/null &

# 1. Install paru cleanly and safely
if ! command -v paru &>/dev/null; then
  info "paru is already installed"
else
  info "Installing paru AUR helper..."
  sudo pacman -Sy --noconfirm --needed base-devel git

  tmpdir=$(mktemp -d)
  trap 'rm -rf "$tmpdir"' EXIT

  git clone https://aur.archlinux.org/paru.git "$tmpdir/paru"
  cd "$tmpdir/paru"
  makepkg --syncdeps --install --noconfirm
  cd -
  success "paru installed"
fi

# 5 + 9. Install official packages in smaller, resilient batches
info "Installing official packages (2025 Hyprland essentials)..."

batches=(
  # Core compositor & basics
  "hyprland waybar hyprpaper swww kitty"
  # Runners, notifications, screenshots
  "wofi dunst grim slurp wl-clipboard cliphist wl-clip-persist"
  # File manager + thumbnails
  "thunar thunar-archive-plugin tumbler gvfs gvfs-mtp gvfs-smb"
  # Look & feel
  "nwg-look qt5ct kvantum qt5-wayland qt6-wayland xdg-desktop-portal-hyprland xdg-desktop-portal-gtk"
  # Fonts & tools
  "ttf-jetbrains-mono-nerd lsd btop"
  # Python & wal
  "python python-pillow python-pywal python-gobject tk"
  # Misc utilities
  "network-manager-applet polkit-gnome mpv nano obsidian jq nodejs npm pacman-contrib"
  # Display manager
  "sddm"
)

for pkg_list in "${batches[@]}"; do
  # shellcheck disable=2086
  sudo pacman -S --noconfirm --needed $pkg_list || warn "Some packages in this batch failed (continuing)"
done

# 3 + 9. AUR packages — also in batches so one broken package doesn't kill everything
info "Installing AUR packages..."
aur_packages=(
  brave-bin
  nordic-theme-git
  wpgtk-git
  themix-full-git
  oh-my-posh
)

for pkg in "${aur_packages[@]}"; do
  paru -S --noconfirm --needed --skipreview "$pkg" || warn "Failed to install AUR package: $pkg"
done

# XDG directories
xdg-user-dirs-update --force 2>/dev/null || true

# Zsh plugins
mkdir -p ~/.zsh
for plugin in zsh-autosuggestions zsh-syntax-highlighting; do
  if [[ ! -d "~/.zsh/$plugin" ]]; then
    git clone "https://github.com/zsh-users/$plugin" "~/.zsh/$plugin" >/dev/null 2>&1
  fi
done

# 6. Clone + automatically apply your dotfiles using simple rsync (safe & works for everyone)
if [[ ! -d "$HOME/R007-dotfiles" ]]; then
  info "Cloning your dotfiles..."
  git clone https://github.com/Reep007/R007-dotfiles.git "$HOME/R007-dotfiles"
fi

info "Applying dotfiles (rsync with backup of existing files)..."
rsync -a --backup --suffix=".backup.$(date +%F)" \
  "$HOME/R007-dotfiles/.config/" "$HOME/.config/" 2>/dev/null || true
rsync -a --backup --suffix=".backup.$(date +%F)" \
  "$HOME/R007-dotfiles/.local/"  "$HOME/.local/"  2>/dev/null || true

# Other common top-level dotfiles (like .zshrc) can be added here if you have them

# Set Zsh as default shell (idempotent)
if [[ "$SHELL" != *"zsh" ]]; then
  info "Setting zsh as your default shell..."
  chsh -s "$(which zsh)" "$USER"
fi

# Enable services
info "Enabling NetworkManager & SDDM..."
sudo systemctl enable --now NetworkManager sddm

# 7. Clean up paru build cache (~500–800 MB saved)
info "Cleaning paru cache..."
echo y | paru -Sc

# 10. Final message + auto-reboot with countdown
success "Hyprland rice installation completed successfully!"
echo
echo "   Your dotfiles have been automatically applied"
echo "   SDDM is enabled — you will land directly in Hyprland after reboot"
echo
echo "   Rebooting in 20 seconds (press Ctrl+C to cancel)..."
sleep 20
sudo reboot
