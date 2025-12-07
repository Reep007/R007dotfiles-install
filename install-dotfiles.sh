#!/usr/bin/env bash
# R007-dotfiles — Ultimate One-Command Rice Installer
# Hyprland + Pywal + Full Theming + ZenForge (source only)
# https://github.com/Reep007/R007-dotfiles

set -euo pipefail

# Colors
info()    { echo -e "\033[1;34m[INFO]\033[0m   $*"; }
success() { echo -e "\033[1;32m[OK]\033[0m      $*"; }
warn()    { echo -e "\033[1;33m[WARN]\033[0m    $*"; }
error()   { echo -e "\033[1;31m[ERROR]\033[0m  $*"; exit 1; }

[[ -f /etc/arch-release ]] || error "This script only works on Arch Linux!"

# Keep sudo timestamp alive
sudo -v
( while true; do sudo -n true; sleep 60; kill -0 "$$" || exit; done ) 2>/dev/null &

# ──────────────────────────────────────────────────────────────
# 1. paru AUR helper
# ──────────────────────────────────────────────────────────────
if ! command -v paru &>/dev/null; then
  info "Installing paru AUR helper..."
  sudo pacman -Sy --noconfirm --needed base-devel git
  tmpdir=$(mktemp -d); trap 'rm -rf "$tmpdir"' EXIT
  git clone https://aur.archlinux.org/paru.git "$tmpdir/paru"
  cd "$tmpdir/paru"
  makepkg --syncdeps --install --noconfirm --needed
  success "paru installed"
else
  info "paru already available"
fi

# ──────────────────────────────────────────────────────────────
# 2. Update keyring + full system upgrade (prevents 99% of failures)
# ──────────────────────────────────────────────────────────────
info "Updating system + keyring (this fixes most install issues)..."
sudo pacman -Sy --noconfirm archlinux-keyring
sudo pacman -Syu --noconfirm

# ──────────────────────────────────────────────────────────────
# 3. Official packages (loud so you see progress)
# ──────────────────────────────────────────────────────────────
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
  echo -e "\033[1;36mInstalling:\033[0m $pkgs"
  sudo pacman -S --noconfirm --needed $pkgs || warn "Some packages skipped in this batch"
done
success "Official packages installed"

# ──────────────────────────────────────────────────────────────
# 4. AUR packages (also visible)
# ──────────────────────────────────────────────────────────────
info "Installing AUR packages..."
for pkg in brave-bin nordic-theme-git wpgtk-git themix-full-git oh-my-posh; do
  echo -e "\033[1;36mBuilding AUR package:\033[0m $pkg"
  paru -S --noconfirm --needed --skipreview "$pkg" || warn "Failed/skipped: $pkg"
done
success "AUR packages done"

# ──────────────────────────────────────────────────────────────
# 5. Zsh plugins + dotfiles
# ──────────────────────────────────────────────────────────────
info "Setting up Zsh plugins and dotfiles..."
xdg-user-dirs-update --force >/dev/null 2>&1
mkdir -p "$HOME/.zsh"

for p in zsh-autosuggestions zsh-syntax-highlighting; do
  [[ -d "$HOME/.zsh/$p" ]] || git clone --quiet --depth 1 "https://github.com/zsh-users/$p" "$HOME/.zsh/$p"
done

[[ -d "$HOME/R007-dotfiles" ]] || git clone --depth 1 https://github.com/Reep007/R007-dotfiles.git "$HOME/R007-dotfiles"

rsync -a --delete "$HOME/R007-dotfiles/.config/" "$HOME/.config/" 2>/dev/null || true
rsync -a --delete "$HOME/R007-dotfiles/.local/"  "$HOME/.local/"  2>/dev/null || true
success "R007 dotfiles applied"

# Shell + services
[[ "$SHELL" == */zsh ]] || chsh -s "$(which zsh)" "$USER"
sudo systemctl enable --now NetworkManager sddm >/dev/null 2>&1

# ──────────────────────────────────────────────────────────────
# 6. Pull ZenForge source only (no compile)
# ──────────────────────────────────────────────────────────────
info "Pulling ZenForge system manager (source code only)..."
if [[ -d "$HOME/ZENFORGE" ]]; then
  (cd "$HOME/ZENFORGE" && git pull --quiet --ff-only) >/dev/null 2>&1
  success "ZENFORGE directory updated"
else
  git clone --depth 1 https://github.com/Reep007/ZENFORGE.git "$HOME/ZENFORGE" >/dev/null 2>&1
  success "ZENFORGE cloned to ~/ZENFORGE"
fi

# ──────────────────────────────────────────────────────────────
# Final beautiful banner
# ──────────────────────────────────────────────────────────────
clear
cat << "EOF"

╔══════════════════════════════════════════════════════════╗
║                                                          ║
║        R007 Rice — Installation Complete!              ║
║                                                          ║
║    • Hyprland + full theming installed                   ║
║    • Dotfiles applied                                    ║
║    • SDDM will start on next boot                        ║
║                                                          ║
║    ZenForge is ready in ~/ZENFORGE                       ║
║    → To activate generations/rollbacks/snapshots:        ║
║         cd ~/ZENFORGE && cargo install --path .         ║
║         zenforge switch                                  ║
║                                                          ║
╚══════════════════════════════════════════════════════════╝

EOF

echo "Rebooting in 20 seconds (Ctrl+C to cancel)..."
sleep 20
exec sudo reboot
