
                                  🌑 R007 Dotfiles — Arch + Hyprland Pro Installer
                                                           +
                                                     🧷 ZenForge
                        Forge your perfect Arch + Hyprland system — declaratively, atomically, forever.

<p align="center"> <img src="https://img.shields.io/badge/Arch_Linux-1793D1?logo=arch-linux&logoColor=white&style=for-the-badge"> <img src="https://img.shields.io/badge/Hyprland-0099E5?logo=linux&logoColor=white&style=for-the-badge"> <img src="https://img.shields.io/badge/Zsh-000000?logo=zsh&logoColor=white&style=for-the-badge"> <img src="https://img.shields.io/badge/AUR-Paru-blue?style=for-the-badge"> </p> <p align="center"> <b>Fast. Safe. Modern. Fully-automated Arch Linux ricing with Hyprland.</b> </p>


                                    📘 Table of Contents

                                      ✨ Features
                                      📦 What’s Included
                                      🚀 Quick Install
                                      ⚙️ Installer Options
                                      🖥️ Screenshot 
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
cd R007dotfiles-install
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
install.sh -y


Preview everything (no risk):
install.sh --dry-run


Install with ZenForge:
install.sh --with-zenforge

🖥️ ZenForge Screenshots

<img width="645" height="848" alt="image" src="https://github.com/user-attachments/assets/138b0707-e220-44fb-b37f-8c535fcc1e23" />

<img width="716" height="687" alt="image" src="https://github.com/user-attachments/assets/b8fa3fee-35fd-40c5-9267-46cf0a48a02a" />






🖥️ Theme Screenshots


<img width="1920" height="1080" alt="20251209_191943" src="https://github.com/user-attachments/assets/1ae4dff7-3eb3-461d-baa4-f3a4974ea53f" />



<img width="2564" height="1441" alt="20251209_191119" src="https://github.com/user-attachments/assets/75675d85-98e0-4da7-9787-7c97ebac66dc" />



<img width="2565" height="1441" alt="20251209_191547" src="https://github.com/user-attachments/assets/d6a4b738-6a0c-4075-9d35-da4985621409" />


<img width="2566" height="1441" alt="20251209_190650" src="https://github.com/user-attachments/assets/95f51bb5-8c08-4a2c-9bb0-8970fab009ed" />


<img width="2571" height="1440" alt="20250710_025817 (copy 1)" src="https://github.com/user-attachments/assets/78e27eee-3f46-4fca-8503-c6118d360692" />








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
```
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
```

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





