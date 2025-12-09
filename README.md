```
                                             🌑 R007 Dotfiles — Arch + Hyprland Pro Installer
```
<p align="center"> <img src="https://img.shields.io/badge/Arch_Linux-1793D1?logo=arch-linux&logoColor=white&style=for-the-badge"> <img src="https://img.shields.io/badge/Hyprland-0099E5?logo=linux&logoColor=white&style=for-the-badge"> <img src="https://img.shields.io/badge/Zsh-000000?logo=zsh&logoColor=white&style=for-the-badge"> <img src="https://img.shields.io/badge/AUR-Paru-blue?style=for-the-badge"> </p> <p align="center"> <b>Fast. Safe. Modern. Fully-automated Arch Linux ricing with Hyprland.</b> </p>


                                              📘 Table of Contents

                                              ✨ Features

                                              📦 What’s Included

                                              🚀 Quick Install

                                              ⚙️ Installer Options

                                               🖥️ Screenshots

                                               🔧 How It Works

                                               🔒 Safety Mechanisms

                                               📁 Recommended Repo Structure

                                               🧷 ZenForge Integration

                                               🧪 Testing

                                               🧹 Uninstall / Restore


🚀 One-Command Full Rice
From base Arch → fully themed Hyprland desktop in minutes.

🔒 Safe Selective Dotfile Sync
Only syncs folders that exist in the repo
No forced deletions
Auto-backup of ~/.config on first run

🧰 Automated Setup Includes
Official packages
AUR packages (via paru)
zsh + plugins
GTK/QT theming
Fonts, icons, utilities

🛡️ Modern Bash Practices
set -euo pipefail
Safe commands (no eval!)
Trap-based cleanup
DRY-RUN mode
Color-coded logs

🔧 Optional ZenForge Support
Auto-installs Rust, compiles ZenForge, and sets it up professionally.


📦 What’s Included

| Component        | Purpose                  |
| ---------------- | ------------------------ |
| Hyprland         | Window manager (Wayland) |
| Waybar           | Status bar               |
| Hyprpaper / swww | Wallpapers               |
| Dunst            | Notifications            |
| Wofi             | App launcher             |
| Cliphist         | Clipboard history        |



🎨 Theming

| Category         | Items                    |
| ---------------- | ------------------------ |
| GTK Theme        | Nordic                   |
| Icons            | Papirus                  |
| Terminal Font    | JetBrains Mono Nerd Font |
| Wallpaper Engine | WPgtk + Pywal            |
| QT theming       | Kvantum                  |



🗂 Utilities

| Type         | Included                   |
| ------------ | -------------------------- |
| File Manager | Thunar + plugins           |
| Terminal     | Kitty                      |
| Tools        | lsd, btop, jq, imagemagick |
| Desktop      | SDDM                       |
| Networking   | NetworkManager + Applet    |
| Dev          | Node.js, npm, Python, Zsh  |


🧩 AUR Packages/
brave-bin
nordic-theme-git
wpgtk-git
themix-full-git
oh-my-posh


🚀 Quick Install

Run directly from GitHub
```
curl -fsSL https://raw.githubusercontent.com/Reep007/R007dotfiles-install/main/install.sh | bash
```
Or clone first
```
git clone https://github.com/Reep007/R007dotfiles-install.git
cd REPO
bash install.sh
```

⚙️ Installer Options

| Flag                  | Description                         |
| --------------------- | ----------------------------------- |
| `--dry-run`           | Simulates install (no changes made) |
| `--no-confirm` / `-y` | Non-interactive mode                |
| `--with-zenforge`     | Force ZenForge compilation          |
| `--without-zenforge`  | Skip ZenForge                       |
| `--help`              | Show help                           |


Examples:

Full automatic install:
bash install.sh -y


Preview everything (no risk):
bash install.sh --dry-run


Install with ZenForge:
bash install.sh --with-zenforge

🖥️ Screenshots

ADD MY SCREEN SHOTS HERE!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!





🔧 How It Works/
Verifies Arch Linux
Installs paru (AUR helper)
Optionally installs Rust
Updates system
Installs official packages (batched)
Installs AUR packages
Clones dotfiles repo
Backs up ~/.config (only once)
Selectively rsyncs .config/ and .local/
Installs Zsh plugins
Enables sddm and NetworkManager
Optional ZenForge build
Reboot prompt



🔒 Safety Mechanisms

✔ DRY-RUN mode

✔ Backup first, sync second

✔ No global overwrite or deletes

✔ AUR work isolated (~/.cache/aur-builds)

✔ Colorized warnings/errors

✔ Fail-safe trap for crashes



📁 Recommended Repo Structure
R007-dotfiles/
│── install.sh
│── README.md
│── .config/
│   ├── hypr/
│   ├── waybar/
│   ├── kitty/
│   └── ...
│── .local/
│   └── bin/
└── screenshots/


🧷 ZenForge Integration

If Rust is installed (or the user allows it), the installer will:

Clone ZenForge repo

Auto-update if already present

Compile with Cargo

Install into $CARGO_HOME/bin (or ~/.cargo/bin)

To skip:
--without-zenforge

To force-enable:
--with-zenforge

🧪 Testing

Run the installer in full simulation mode:
bash install.sh --dry-run


🧹 Uninstall / Restore
To restore your old config:
cp -a ~/.config_backup_*/* ~/.config/





