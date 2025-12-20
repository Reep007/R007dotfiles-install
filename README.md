
#                                                                                          🌑 R007 Dotfiles — Arch + Hyprland Installer
                                                                                                                  
#                                                                        

<p align="center"> <img src="https://img.shields.io/badge/Arch_Linux-1793D1?logo=arch-linux&logoColor=white&style=for-the-badge"> <img src="https://img.shields.io/badge/Hyprland-0099E5?logo=linux&logoColor=white&style=for-the-badge"> <img src="https://img.shields.io/badge/Zsh-000000?logo=zsh&logoColor=white&style=for-the-badge"> <img src="https://img.shields.io/badge/AUR-Paru-blue?style=for-the-badge"> </p> <p align="center"> <b>Fast. Safe. Modern. Fully-automated Arch Linux ricing with Hyprland.</b> </p>




🖥️ Theme Screenshots


<img width="1920" height="1080" alt="20251209_191943" src="https://github.com/user-attachments/assets/1ae4dff7-3eb3-461d-baa4-f3a4974ea53f" />



<img width="2564" height="1441" alt="20251209_191119" src="https://github.com/user-attachments/assets/75675d85-98e0-4da7-9787-7c97ebac66dc" />



<img width="2565" height="1441" alt="20251209_191547" src="https://github.com/user-attachments/assets/d6a4b738-6a0c-4075-9d35-da4985621409" />


<img width="2566" height="1441" alt="20251209_190650" src="https://github.com/user-attachments/assets/95f51bb5-8c08-4a2c-9bb0-8970fab009ed" />


<img width="2571" height="1440" alt="20250710_025817 (copy 1)" src="https://github.com/user-attachments/assets/78e27eee-3f46-4fca-8503-c6118d360692" />



# Arch Linux Hyprland Development Environment Installer

A comprehensive, production-ready installation script for setting up a complete Hyprland-based development environment on Arch Linux.

## 🎯 Overview

This installer automates the setup of a modern Wayland desktop environment featuring:
- **Hyprland** - Dynamic tiling Wayland compositor
- **Waybar** - Highly customizable status bar
- **Complete audio stack** with Pipewire
- **Development tools** including VS Code, Node.js, and Python
- **Theming tools** with pywal integration
- **Essential utilities** for a productive workflow

## ✨ Features

- ✅ **Error handling** - Comprehensive error checking with helpful messages
- ✅ **Idempotent** - Safe to run multiple times
- ✅ **Color-coded output** - Clear visual feedback during installation
- ✅ **Fresh install ready** - Handles minimal Arch installations
- ✅ **Safety checks** - Prevents common mistakes (root execution, non-Arch systems)

## 📋 Prerequisites

### Required
- Fresh or existing **Arch Linux** installation
- User account with **sudo privileges**
- Internet connection

### Recommended
- Base system installed with `base-devel`
- At least 10GB free disk space
- Configured locale (optional, script handles missing locales gracefully)

## 🚀 Quick Start

### 1. Download the installer

```bash
curl -O https://raw.githubusercontent.com/Reep007/R7dotfiles-install/main/installer.sh
chmod +x installer.sh
```

Or clone the repository:

```bash
git clone https://github.com/Reep007/R7dotfiles-install.git
cd R7dotfiles-install
chmod +x installer.sh
```

### 2. Run the installer

```bash
./installer.sh
```

### 3. Reboot

```bash
sudo reboot
```

### 4. Start Hyprland

After reboot, login to TTY and run:

```bash
Hyprland
```

## 📦 What Gets Installed

### Window Manager & Desktop
- `hyprland` - Wayland compositor
- `waybar` - Status bar
- `hyprpaper` - Wallpaper utility
- `xdg-desktop-portal-hyprland` - Portal implementation

### Terminal & Shell
- `kitty` - GPU-accelerated terminal
- `zsh` with plugins:
  - zsh-autosuggestions
  - zsh-syntax-highlighting
- `oh-my-posh` - Prompt theme engine

### Audio
- `pipewire` - Modern audio server
- `pipewire-pulse` - PulseAudio compatibility
- `wireplumber` - Session manager
- `pavucontrol-gtk3` - Volume control GUI

### File Management
- `thunar` - File manager
- `tumbler` - Thumbnail generator
- `gvfs` - Virtual filesystem (MTP, SMB, NFS support)

### Utilities
- `btop` - System monitor
- `lsd` - Modern ls replacement
- `fd` - Fast find alternative
- `wl-clipboard` - Wayland clipboard
- `grim` + `slurp` - Screenshot tools

### Theming
- `python-pywal` - Color scheme generator
- `wpgtk` - Wallpaper and theme manager
- `nordic-theme` - GTK theme
- `themix-gui` - Theme customization
- `lxappearance` - GTK theme switcher

### Applications
- `brave-bin` - Web browser
- `obsidian` - Note-taking
- `code` - VS Code
- `mpv` - Media player

### Development
- `nodejs` + `npm`
- `python` + `python-pillow`
- `git`

## ⚙️ Configuration

### Dotfiles

The installer clones dotfiles to `~/R7dotfiles-install`. To apply them:

```bash
cd ~/R7dotfiles-install
# Follow the dotfiles repository instructions
```

### Hyprland Config

Default config location: `~/.config/hypr/hyprland.conf`

### Waybar Config

Default config location: `~/.config/waybar/`

## 🔧 Post-Installation

### Optional: Install a Display Manager

For automatic graphical login, install a display manager:

```bash
# Option 1: SDDM (full-featured)
sudo pacman -S sddm
sudo systemctl enable sddm.service

# Option 2: greetd + tuigreet (minimal)
sudo pacman -S greetd greetd-tuigreet
sudo systemctl enable greetd.service
```

### Configure Locale (if needed)

If XDG directories weren't created:

```bash
# Edit /etc/locale.gen and uncomment your locale
sudo nano /etc/locale.gen

# Generate locales
sudo locale-gen

# Create XDG directories
xdg-user-dirs-update
```

### Network Configuration

NetworkManager is enabled by default. To manage connections:

```bash
nmtui  # Text UI
nmcli  # Command line
# Or use the network manager applet in waybar
```

## 🛠️ Troubleshooting

### Hyprland won't start
- Ensure you rebooted after installation (required for `seat` group)
- Check if seatd is running: `systemctl status seatd`
- Verify group membership: `groups` (should include `seat`)

### No audio
- Check Pipewire status: `systemctl --user status pipewire`
- Start Pipewire if needed: `systemctl --user start pipewire pipewire-pulse`

### Display issues
- Check Hyprland logs: `~/.local/share/hyprland/hyprland.log`
- Verify GPU drivers are installed

### AUR package build failures
- Update system: `sudo pacman -Syu`
- Clear paru cache: `paru -Sc`
- Try manual installation of failed package

## 🔒 Security Notes

- Script checks for root execution and refuses to run
- AUR packages are installed **without manual PKGBUILD review** (`--noconfirm`)
- For production systems, consider reviewing PKGBUILDs manually
- All official packages come from Arch repositories

## 📝 Customization

### Adding Packages

Edit the package arrays in the script:

```bash
readonly OFFICIAL_PACKAGES=(
  # Add your packages here
  your-package-name
)

readonly AUR_PACKAGES=(
  # Add AUR packages here
  your-aur-package
)
```

### Removing Packages

Simply remove unwanted entries from the package arrays before running.

## 🤝 Contributing

Issues and pull requests welcome! Please ensure:
- Script remains idempotent
- Error handling is maintained
- Changes are tested on fresh Arch install

## 📄 License

This installer script is provided as-is. Use at your own risk.

## 🙏 Credits

- Dotfiles: [R7dotfiles-install](https://github.com/Reep007/R7dotfiles-install)
- Hyprland: [hyprland.org](https://hyprland.org)
- Arch Linux: [archlinux.org](https://archlinux.org)

## 📞 Support

For issues with:
- **This installer**: Open an issue in this repository
- **Hyprland**: See [Hyprland wiki](https://wiki.hyprland.org)
- **Arch Linux**: See [Arch wiki](https://wiki.archlinux.org)

---

**Note**: This installer is designed for personal use and fresh Arch installations. Always review scripts before running them with sudo privileges.





