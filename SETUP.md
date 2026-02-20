# Setup

Steps for deploying these dotfiles on a new machine.

## 1. Clone the repo

```bash
git clone <repo-url> ~/linux-config
```

## 2. Symlink dotfiles

Run the setup script from the repo root:

```bash
./setup
```

This links top-level dotfiles (`.bashrc`, `.bash_profile`, `.xinitrc`, `.inputrc`, `.gitignore_global`, `.git-prompt.sh`) and each `.config/` subdirectory into `$HOME`. It skips any destination that already exists (file or directory) and writes a report to `setup-report.txt` showing what was linked, what was already in place, and what needs manual resolution.

## 3. Choose a display server

Edit `.bash_profile` to select either Wayland (Hyprland) or X11 (startx/i3).

The relevant lines are:

```bash
[[ -z $DISPLAY ]] && [[ $(tty) == /dev/tty1 ]] && exec Hyprland
# [[ -z $DISPLAY ]] && [[ $(tty) == /dev/tty1 ]] && exec startx
```

### Wayland (Hyprland)

Uncomment the `Hyprland` line, comment the `startx` line:

```bash
[[ -z $DISPLAY ]] && [[ $(tty) == /dev/tty1 ]] && exec Hyprland
# [[ -z $DISPLAY ]] && [[ $(tty) == /dev/tty1 ]] && exec startx
```

### startx (i3)

Comment the `Hyprland` line, uncomment the `startx` line:

```bash
# [[ -z $DISPLAY ]] && [[ $(tty) == /dev/tty1 ]] && exec Hyprland
[[ -z $DISPLAY ]] && [[ $(tty) == /dev/tty1 ]] && exec startx
```

`.xinitrc` is read by `startx` and launches i3 by default — no changes needed there unless you swap X11 window managers.

## 4. Install dependencies

### Core

- `neovim` - editor
- `wezterm` - terminal emulator
- `rofi` - application launcher
- `feh` - wallpaper / image viewer
- `bat` - `cat` replacement (aliased in `.bashrc`)
- `fzf` - fuzzy finder
- `ibus` - input method framework

### Wayland (Hyprland)

- `hyprland` - window manager
- `waybar` - status bar
- `mako` - notification daemon
- `grim` + `slurp` - screenshot tools
- `wl-clipboard` / `cliphist` - clipboard manager
- `swaybg` - wallpaper
- `wpctl` (WirePlumber) - audio control

### X11 (i3)

- `i3` - window manager
- `polybar` - status bar
- `dunst` - notification daemon
- `picom` - compositor
- `clipmenu` / `clipmenud` - clipboard manager
- `scrot` - screenshots
- `xrdb` - X resources

## 5. Neovim plugins

Open Neovim. `lazy.nvim` will bootstrap itself and install plugins on first launch:

```bash
nvim
```

## 6. Shell scripts

Scripts in `.config/scripts/` are added to `$PATH` by `.bashrc`. After symlinking, they should be available in any new shell session. Verify with:

```bash
which tasks
```

## 7. Git config

Set up global gitignore:

```bash
git config --global core.excludesfile ~/.gitignore_global
```
