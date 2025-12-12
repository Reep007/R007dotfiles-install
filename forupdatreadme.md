# Quick preview
./install.sh --dry-run

# Detailed preview with all changes
./install.sh --dry-run --verbose

# Unattended installation (skip all prompts)
./install.sh -y

# Skip ZenForge for faster install
./install.sh --without-zenforge

# Full interactive with ZenForge
./install.sh

# See all options
./install.sh --help
```

## 🎯 Final Summary Table Example
```
═══════════════════════════════════════════════════════════
                 INSTALLATION SUMMARY
═══════════════════════════════════════════════════════════

System Update:                 ✓ Complete
Paru AUR Helper:              ✓ Installed
Official Packages:            ✓ Installed (35 packages)
AUR Packages:                 ✓ Installed (5 packages)
Dotfiles Applied:             ✓ Complete
Shell Configuration:          ✓ zsh set
System Services:              ✓ Enabled
Rust/Cargo:                   ✓ Installed
ZenForge:                     ✓ Compiled

📦 Total packages installed: 40

✓  No warnings - installation completed cleanly

═══════════════════════════════════════════════════════════
