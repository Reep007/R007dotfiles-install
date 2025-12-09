#!/usr/bin/env bash
# R007-dotfiles — Pro Installer (final optimized)
# Usage: curl -fsSL https://raw.githubusercontent.com/Reep007/R007-dotfiles/main/install.sh | bash -s -- [options]
# Options:
#   --dry-run           Show what would happen (no changes)
#   --no-confirm | -y   Skip all interactive prompts
#   --with-zenforge     Force ZenForge compilation
#   --without-zenforge  Skip ZenForge entirely

set -euo pipefail

# -------------------- Configuration --------------------
DOTFILES_REPO="https://github.com/Reep007/R007-dotfiles.git"
ZENFORGE_REPO="https://github.com/Reep007/ZENFORGE.git"
DOTFILES_DIR="$HOME/R007-dotfiles"
ZENFORGE_DIR="$HOME/ZENFORGE"
AUR_BUILD_BASE="${AUR_BUILD_BASE:-$HOME/.cache/aur-builds}"

# Default flags
DRY_RUN=false
NO_CONFIRM=false
WITH_ZENFORGE=auto  # auto | yes | no

# -------------------- CLI parsing --------------------
for arg in "$@"; do
  case "$arg" in
    --dry-run|--test)          DRY_RUN=true ;;
    --no-confirm|-y)           NO_CONFIRM=true ;;
    --with-zenforge)           WITH_ZENFORGE=yes ;;
    --without-zenforge)        WITH_ZENFORGE=no ;;
    --help|-h)
      cat <<EOF
Usage: $(basename "$0") [--dry-run] [--no-confirm] [--with-zenforge|--without-zenforge]
  --dry-run            : Preview all actions
  --no-confirm  (-y)   : Assume "yes" to all prompts
  --with-zenforge      : Force compile ZenForge
  --without-zenforge   : Skip ZenForge completely
EOF
      exit 0
      ;;
  esac
done

# -------------------- Logging --------------------
info()    { echo -e "\033[1;34m[INFO]\033[0m   $*"; }
success() { echo -e "\033[1;32m[OK]\033[0m      $*"; }
warn()    { echo -e "\033[1;33m[WARN]\033[0m    $*"; }
error()   { echo -e "\033[1;31m[ERROR]\033[0m  $*" >&2; exit 1; }

# SAFE command runner — no eval, run commands directly
run() {
  if [[ "$DRY_RUN" == true ]]; then
    echo -e "\033[0;36m[DRY-RUN]\033[0m $*"
  else
    "$@"
  fi
}

# -------------------- Cleanup & traps --------------------
tmpdirs=()
cleanup() { for d in "${tmpdirs[@]:-}"; do [[ -d "$d" ]] && rm -rf "$d" 2>/dev/null || true; done; }
trap cleanup EXIT
trap 'error "Installation failed at line $LINENO"' ERR

# -------------------- Helpers --------------------
# colored confirm prompt
confirm() {
  local prompt="${1:-Continue?}"
  [[ "$NO_CONFIRM" == true || "$DRY_RUN" == true ]] && return 0
  # cyan question mark, then prompt
  echo -ne "\033[1;36m?\033[0m $prompt [Y/n] "
  read -r -t 20 ans || ans="y"
  [[ "$ans" =~ ^[Nn]$ ]] && return 1 || return 0
}

ensure_dir() {
  local d="$1"
  if [[ "$DRY_RUN" == true ]]; then
    echo "[DRY-RUN] mkdir -p $d"
  else
    mkdir -p "$d"
  fi
}

# returns cargo bin dir (respects CARGO_HOME)
cargo_bin_dir() {
  echo "${CARGO_HOME:-$HOME/.cargo}/bin"
}

# -------------------- Preflight --------------------
prepare() {
  [[ -f /etc/arch-release ]] || error "This script only runs on Arch Linux."

  cat <<'EOF'

╔══════════════════════════════════════════════════════════╗
║        R007-dotfiles Pro Installer — Ready to Rice       ║
╚══════════════════════════════════════════════════════════╝

EOF

  [[ "$DRY_RUN" == true ]] && info "DRY-RUN mode active — nothing will be changed"
  confirm "Start installation?" || error "Aborted by user"

  if [[ "$DRY_RUN" == false ]]; then
    sudo -v || error "sudo required"
    ( while true; do sudo -n true; sleep 60; kill -0 "$$" || exit; done ) 2>/dev/null &
  fi

  ensure_dir "$AUR_BUILD_BASE"
  ensure_dir "$HOME/.local/bin"
  ensure_dir "$HOME/.zsh"
}

# -------------------- Steps --------------------
install_paru() {
  if command -v paru &>/dev/null; then
    info "paru already installed"
    return
  fi

  info "Installing paru AUR helper (builds under $AUR_BUILD_BASE)..."
  run sudo pacman -Sy --noconfirm --needed base-devel git

  if [[ "$DRY_RUN" == true ]]; then
    success "Would build paru (dry-run)"
    return
  fi

  local dir
  dir="$(mktemp -d "${AUR_BUILD_BASE}/paru.XXXXXX")"
  tmpdirs+=("$dir")

  git clone --depth 1 https://aur.archlinux.org/paru.git "$dir/paru" || error "Failed to clone paru"
  pushd "$dir/paru" >/dev/null
  makepkg --syncdeps --install --noconfirm --needed || error "paru makepkg failed"
  popd >/dev/null

  success "paru installed"
}

install_rust_if_needed() {
  if command -v cargo &>/dev/null; then
    info "Rust (cargo) already present"
    return
  fi

  [[ "$WITH_ZENFORGE" == "no" ]] && { info "Rust skipped (ZenForge disabled)"; return; }

  if [[ "$DRY_RUN" == true ]]; then
    info "Would prompt to install rustup (dry-run)"
    return
  fi

  if confirm "Rust not found — install rustup for ZenForge?"; then
    info "Installing Rust (rustup)..."
    curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y || warn "rustup installation failed"
    [[ -f "$HOME/.cargo/env" ]] && source "$HOME/.cargo/env" || true
    command -v cargo &>/dev/null || warn "cargo not found after rustup"
    success "Rust install attempted"
  else
    info "Rust installation skipped by user"
    WITH_ZENFORGE=no
  fi
}

system_update() {
  info "Updating archlinux-keyring + full system upgrade..."
  run sudo pacman -Sy --noconfirm archlinux-keyring
  run sudo pacman -Syu --noconfirm
}

install_official_packages() {
  info "Installing official packages..."
  local batches=(
    "hyprland waybar hyprpaper swww kitty hypridle hyprlock"
    "wofi dunst grim slurp wl-clipboard cliphist xdg-user-dirs"
    "thunar thunar-archive-plugin tumbler gvfs gvfs-mtp gvfs-smb"
    "nwg-look qt5ct kvantum qt5-wayland qt6-wayland xdg-desktop-portal-hyprland xdg-desktop-portal-gtk"
    "ttf-jetbrains-mono-nerd lsd btop"
    "python python-pillow python-pywal python-gobject tk imagemagick papirus-icon-theme"
    "polkit polkit-gnome network-manager-applet mpv nano obsidian jq nodejs npm pacman-contrib zsh zsh-completions"
    "sddm"
  )

  for pkgs in "${batches[@]}"; do
    info "Batch → $pkgs"
    if [[ "$DRY_RUN" == true ]]; then
      echo "[DRY-RUN] sudo pacman -S --noconfirm --needed $pkgs"
    else
      sudo pacman -S --noconfirm --needed $pkgs || warn "Some packages failed in: $pkgs"
    fi
  done

  # Update xdg user dirs (ensures Desktop/Documents etc)
  run xdg-user-dirs-update || true

  success "Official packages requested/installed"
}

install_aur_packages() {
  info "Installing AUR packages (via paru)..."
  local pkgs=(brave-bin nordic-theme-git wpgtk-git themix-full-git oh-my-posh)

  for p in "${pkgs[@]}"; do
    info "AUR → $p"
    if [[ "$DRY_RUN" == true ]]; then
      echo "[DRY-RUN] paru -S --noconfirm --needed --skipreview $p"
    else
      paru -S --noconfirm --needed --skipreview "$p" || warn "paru install failed for $p"
    fi
  done

  # Optional: clean paru cache to save disk on CI / repeated runs (non-fatal)
  if [[ "$DRY_RUN" == false ]]; then
    paru -Sc --noconfirm || true
  fi

  success "AUR package operations completed"
}

apply_dotfiles() {
  info "Applying dotfiles (selective & safe)..."

  # clone or update dotfiles
  if [[ ! -d "$DOTFILES_DIR/.git" ]]; then
    if [[ "$DRY_RUN" == true ]]; then
      echo "[DRY-RUN] git clone --depth 1 $DOTFILES_REPO -> $DOTFILES_DIR"
    else
      git clone --depth 1 "$DOTFILES_REPO" "$DOTFILES_DIR" || error "Failed to clone dotfiles"
    fi
  else
    if [[ "$DRY_RUN" == true ]]; then
      echo "[DRY-RUN] (cd $DOTFILES_DIR && git pull --ff-only --quiet)"
    else
      (cd "$DOTFILES_DIR" && git pull --ff-only --quiet) || warn "Could not update dotfiles repo"
    fi
  fi

  # backup ~/.config once (skip if a backup already exists)
  if [[ "$DRY_RUN" == false && -d "$HOME/.config" ]]; then
    if compgen -G "$HOME/.config_backup_*" > /dev/null; then
      warn "Existing ~/.config backup detected; skipping additional backup"
    else
      local b="$HOME/.config_backup_$(date +%Y%m%d_%H%M%S)"
      info "Backing up ~/.config -> $b"
      cp -a "$HOME/.config" "$b" || warn "Backup of ~/.config failed"
    fi
  else
    info "Would back up ~/.config (dry-run) or no ~/.config present"
  fi

  # ensure .zsh and local bin
  ensure_dir "$HOME/.zsh"
  ensure_dir "$HOME/.local/bin"

  # zsh plugins (non-destructive)
  for p in zsh-autosuggestions zsh-syntax-highlighting; do
    local dest="$HOME/.zsh/$p"
    if [[ "$DRY_RUN" == true ]]; then
      echo "[DRY-RUN] git clone --depth 1 --quiet https://github.com/zsh-users/$p -> $dest"
    else
      if [[ ! -d "$dest" ]]; then
        git clone --depth 1 --quiet "https://github.com/zsh-users/$p" "$dest" || warn "zsh plugin clone failed: $p"
      else
        info "zsh plugin present: $p"
      fi
    fi
  done

  # rsync excludes
  local RSYNC_EXCLUDES=(
    --exclude='.git'
    --exclude='*.swp'
    --exclude='*.swo'
    --exclude='*.swx'
    --exclude='*.bak'
    --exclude='*.tmp'
    --exclude='.DS_Store'
    --exclude='*.orig'
  )

  # selective sync: .config
  if [[ -d "$DOTFILES_DIR/.config" ]]; then
    info "Syncing .config (selective)"
    if [[ "$DRY_RUN" == true ]]; then
      echo "[DRY-RUN] rsync -a ${RSYNC_EXCLUDES[*]} \"$DOTFILES_DIR/.config/\" \"$HOME/.config/\""
    else
      rsync -a "${RSYNC_EXCLUDES[@]}" "$DOTFILES_DIR/.config/" "$HOME/.config/" || warn "rsync .config failed"
    fi
  fi

  # selective sync: .local
  if [[ -d "$DOTFILES_DIR/.local" ]]; then
    info "Syncing .local (selective)"
    if [[ "$DRY_RUN" == true ]]; then
      echo "[DRY-RUN] rsync -a ${RSYNC_EXCLUDES[*]} \"$DOTFILES_DIR/.local/\" \"$HOME/.local/\""
    else
      rsync -a "${RSYNC_EXCLUDES[@]}" "$DOTFILES_DIR/.local/" "$HOME/.local/" || warn "rsync .local failed"
    fi
  fi

  # make local bin executables executable
  if [[ "$DRY_RUN" == false ]]; then
    find "$HOME/.local/bin" -type f -exec chmod +x {} \; 2>/dev/null || true
  fi

  success "Dotfiles applied (selective)"
}

configure_shell() {
  if ! command -v zsh &>/dev/null; then
    info "zsh not installed — skipping chsh"
    return
  fi
  if [[ "$SHELL" == *"zsh" ]]; then
    info "User already uses zsh"
    return
  fi
  if [[ "$DRY_RUN" == true ]]; then
    echo "[DRY-RUN] chsh -s $(command -v zsh) $USER"
  else
    run chsh -s "$(command -v zsh)" "$USER" || warn "chsh may have failed (non-fatal)"
    success "Default shell set to zsh (relogin required)"
  fi
}

enable_services() {
  info "Enabling NetworkManager + sddm"
  if [[ "$DRY_RUN" == true ]]; then
    echo "[DRY-RUN] sudo systemctl enable --now NetworkManager sddm"
  else
    sudo systemctl enable --now NetworkManager sddm || warn "Enabling services had issues (non-fatal)"
  fi
  success "Services enabled (or requested)"
}

install_zenforge() {
  if [[ "$WITH_ZENFORGE" == "no" ]]; then
    info "ZenForge explicitly skipped"
    return
  fi

  info "Preparing ZenForge at $ZENFORGE_DIR"
  if [[ "$DRY_RUN" == true ]]; then
    echo "[DRY-RUN] clone/pull $ZENFORGE_REPO -> $ZENFORGE_DIR"
  else
    if [[ -d "$ZENFORGE_DIR/.git" ]]; then
      (cd "$ZENFORGE_DIR" && git pull --ff-only --quiet) || warn "ZenForge update failed"
    else
      git clone --depth 1 "$ZENFORGE_REPO" "$ZENFORGE_DIR" || warn "ZenForge clone failed"
    fi
  fi

  if ! command -v cargo &>/dev/null; then
    warn "cargo not found; skip compiling ZenForge. Install rustup and re-run with --with-zenforge"
    return
  fi

  if ! confirm "Compile and install ZenForge now?"; then
    info "ZenForge compile skipped"
    return
  fi

  info "Compiling ZenForge... (this may take several minutes)"
  local cargo_bin
  cargo_bin="$(cargo_bin_dir)"
  if [[ "$DRY_RUN" == true ]]; then
    echo "[DRY-RUN] (cd $ZENFORGE_DIR && cargo install --path . --locked)"
  else
    (cd "$ZENFORGE_DIR" && cargo install --path . --locked) && success "ZenForge installed → $cargo_bin/zenforge" || warn "ZenForge compilation failed"
  fi
}

finalize() {
  clear
  cat <<EOF

╔══════════════════════════════════════════════════════════╗
║               R007 Rice — Installation Finished!         ║
║   Hyprland + theming + optional ZenForge ready          ║
╚══════════════════════════════════════════════════════════╝

EOF

  [[ "$DRY_RUN" == true ]] && { info "Dry-run finished — no changes made"; return 0; }

  if confirm "Reboot now?"; then
    info "Rebooting..."
    sleep 2
    sudo systemctl reboot
  else
    success "Installation finished. Reboot when ready and select Hyprland in SDDM"
  fi
}

# -------------------- Main --------------------
prepare
install_paru
install_rust_if_needed
system_update
install_official_packages
install_aur_packages
apply_dotfiles
configure_shell
enable_services
install_zenforge
finalize

