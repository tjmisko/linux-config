# Setup

Steps for deploying these dotfiles on a new machine.

## 1. Clone the repo

```bash
git clone <repo-url> ~/linux-config
```

## 2. Symlink dotfiles

Link each top-level dotfile and `.config/` directory to its expected location in `$HOME`:

```bash
ln -sf ~/linux-config/.bashrc ~/.bashrc
ln -sf ~/linux-config/.bash_profile ~/.bash_profile
ln -sf ~/linux-config/.xinitrc ~/.xinitrc
ln -sf ~/linux-config/.inputrc ~/.inputrc
ln -sf ~/linux-config/.gitignore_global ~/.gitignore_global
ln -sf ~/linux-config/.git-prompt.sh ~/.git-prompt.sh
```

For `.config/`, symlink each subdirectory:

```bash
for dir in ~/linux-config/.config/*/; do
    ln -sf "$dir" ~/.config/
done
```

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

Then confirm `.xinitrc` has the correct window manager uncommented:

```bash
exec i3
# exec dwm
```

The default is `exec i3`. If you use a different X11 window manager, comment out the `i3` line and uncomment or add the appropriate `exec` line.

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
