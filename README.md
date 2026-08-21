# Dotfiles

Configuration for a Linux desktop built around Neovim, Obsidian and tiling
window managers, plus the headless servers that share the same shell and
editor setup. Deployed with [GNU Stow](https://www.gnu.org/software/stow/).

## Layout

Each top-level directory is a stow package whose contents mirror the tree it
deploys into `$HOME`. The package directories *are* the install manifest, so
there is no separate list to drift out of sync.

| Package   | Files | Contents |
|-----------|-------|----------|
| `common`  | 111   | shell, nvim, `.config/scripts`, git, btop, newsboat, neofetch, ytfzf |
| `gui`     | 15    | wezterm, zathura, rofi, mimeapps, `.desktop` entries, switchboard units |
| `laptop`  | 3     | backlight floor, battery notifications |
| `x11`     | 6     | i3, i3status, polybar, picom, dunst, `.xinitrc` |
| `wayland` | 18    | hypr, waybar, mako, fcitx5, swayidle, session target |

`README.md` and `.gitignore` stay at the root; stow only touches packages named
on its command line.

## Install

```sh
git clone <repo> ~/linux-config
cd ~/linux-config

stow common gui laptop x11        # nlessfun     -- X11 / i3 laptop
stow common gui laptop wayland    # GooseBook    -- Wayland / Hyprland laptop
stow common                       # microserver  -- headless, SSH only
```

Useful flags: `-n -v` to simulate without touching anything, `-R` to restow
after a pull (and repair drift), `-D` to remove a package.

Stow refuses to overwrite a real file, so a pre-existing config shows up as a
conflict rather than being silently clobbered. Resolve by folding the content
into the repo and deleting the stray file.

## First run on a new machine

```sh
git config --global core.excludesfile ~/.gitignore_global   # nothing wires this up on its own
nvim                                                        # lazy.nvim bootstraps and installs plugins
which tasks                                                 # confirms .config/scripts reached $PATH
```

Then log out and back in. Values in `hosts/*.env` are exported by the login
shell, so polybar and wezterm only see them in a session started afterwards.

## Dependencies

**Core** — `stow`, `neovim` (>= 0.12 for treesitter `main`), `wezterm`, `rofi`,
`bat`, `fzf`, `feh`, `ripgrep`.

**X11 / i3** — `i3`, `polybar`, `picom`, `dunst` (notifications; also provides
`dunstctl`, which the `$mod+F1` binding calls), `scrot` and `xclip` (both
required by `.config/scripts/screenshot`), `clipmenu`/`clipmenud`, `xorg-xrdb`.

**Wayland / Hyprland** — `hyprland`, `waybar`, `mako`, `grim` + `slurp`,
`wl-clipboard`/`cliphist`, `swaybg`, `wireplumber` (`wpctl`), `fcitx5` with
`fcitx5-chinese-addons`.

Note that `hostname(1)` is *not* required and must not be relied on: it lives in
`inetutils` and is absent from a base Arch install. `.bashrc` uses bash's own
`$HOSTNAME`.

## Per-host settings

Machine-varying values live in `common/.config/hosts/<hostname>.env`, sourced
at the top of `.bashrc` with the hostname lowercased. Everything that reads
them carries a fallback, so a host with no file still works.

| Variable | Purpose |
|----------|---------|
| `AUTOSTART_SESSION` | `hyprland`, `startx`, or empty to land at a shell on a tty1 login |
| `POLYBAR_BATTERY` / `POLYBAR_ADAPTER` | device names under `/sys/class/power_supply` |
| `POLYBAR_FONT` | full font spec; polybar only substitutes `${env:...}` as a whole value |
| `WEZTERM_FONT_SIZE` | terminal font size for this display |
| `OBSIDIAN_BIN` | override for the Obsidian launcher |

Values must be exported: polybar and wezterm read them from the environment
they inherit from the login shell.

Anything that varies by *session* rather than by host is detected at runtime
instead, because one machine can boot either — see `.config/scripts/obsidian`
and `.config/scripts/newsboat-bookmark`.

## Window management

i3 and Hyprland are configured broadly the same way. Keys over clicks, always.
Both use `rofi` as the launcher; notifications are dunst on X11 and mako on
Wayland. Toggle the bar with `$mod+F8`.

## Neovim

* **Plugins**: `common/.config/nvim/lua/plugins/`
* **Scripts and keys**: `common/.config/nvim/lua/goose/`

Telescope, Harpoon, Oil, Treesitter, LSP, LuaSnip, Fugitive, Undotree, Lualine.
Treesitter tracks the `main` branch rewrite and needs Neovim >= 0.12.

### Obsidian integration

- **Wikilink completions** (`obsidian_completion.lua`): nvim-cmp source that
  searches the vault with `rg` for filenames and content, caching across
  keystrokes to avoid async races with cmp's session lifecycle.
- **Header virtual text** (`obsidian_header.lua`): renders the note's display
  name above line 1.
- **Taskbuffer** (`tjmisko/taskbuffer.nvim`): Obsidian-based task management
  with Telescope tag filtering.

## Scripts

`.config/scripts/` is on `$PATH` via `.bashrc`.

| Script | Purpose |
|--------|---------|
| `tasks` / `tasks-open` | Daily task view in nvim, with time-tracked task management |
| `sch` | Schedule viewer -- daily, weekly and side-by-side retend mode |
| `retend` | Retrospective/intended journal with category tagging |
| `daily` | Generate today's Obsidian daily note from template |
| `obsidian` | Launch Obsidian however it is installed on this host |
| `newsboat-bookmark` | Dispatch newsboat bookmarks to the session's helper |
| `screenshot` | `scrot` wrapper: save, copy to clipboard, notify |
| `brightness` | Backlight control for Apple Silicon (Asahi) |
| `hypr-float-center` | Toggle a centered floating window in Hyprland |
| `gh_*` | GitHub workflow helpers -- issues, worktrees, project boards |
