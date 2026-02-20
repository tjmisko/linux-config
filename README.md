# Dotfiles
Configuration for a Linux desktop built around Neovim, Obsidian, and tiling window managers. Two setups in here: one for Wayland  (Hyprland), one for X11 (i3).

## Window Management

### Hyprland / i3
Both window managers are broadly configured the same way. Keys over clicks, always.


## Neovim
* **Plugins**: `.config/nvim/lua/plugins/`
* **Scripts**: `lua/goose/`.
* **Keys**: `lua/goose/`.

### Obsidian Integration
- **Wikilink completions** (`obsidian_completion.lua`): Custom nvim-cmp source that searches the vault with `rg` for both filenames and content. Caches results across keystrokes to avoid async callback races with cmp's session lifecycle. Supports full substring matching and complete wikilink insertion on Tab.
- **Header virtual text** (`obsidian_header.lua`): Renders the note's display name as virtual text above line 1.

### Claude Code
- **Session picker** (`claude.lua`, `claude-picker.sh`): Manage Claude Code tmux sessions from nvim — create, rename, kill, and open in a floating terminal. Sessions are scoped to the current working directory.
- **Waybar hooks**: Prompt-submit and stop hooks track agent state per workspace. Supports opt-in desktop notifications via "notify" keyword in prompts.

### Taskbuffer.nvim
External plugin for Obsidian-based task management with Telescope tag filtering.

### Waybar
Simple status bar. Dismiss it with `$mod+F8`.

### Other Plugins

Telescope, Harpoon, Oil, Treesitter, LSP (via lsp.lua), LuaSnip, Fugitive, Undotree, Lualine.

## Shell Scripts

Utilities live in `~/.config/scripts/` and are added to `$PATH` via `.bashrc`.

| Script | Purpose |
|--------|---------|
| `tasks` / `tasks-open` | Build and open the daily task view in nvim. Includes `task_make`, `task_do`, `task_stop`, `task_complete`, and `task_progress` for time-tracked task management. |
| `sch` | Schedule viewer — daily, weekly, and side-by-side retend mode with scroll-locked nvim splits. |
| `retend` | Retrospective/intended journal — daily time-block entries with category tagging. |
| `brightness` | Backlight control for Apple Silicon (Asahi). |
| `daily` | Generate today's Obsidian daily note from template. |
| `hypr-float-center` | Toggle a centered floating window in Hyprland with configurable size, window class, and on-close hook. |
| `claude-*` | Waybar status hooks and CSS generator for Claude Code agent state. |
| `gh_*` | GitHub workflow helpers — issue search, worktree-based development, project board management. |

## Other Configs

- **Wezterm** (`~/.config/wezterm/wezterm.lua`): Terminal emulator config.
- **Dunst** (`~/.config/dunst/`): Notification daemon.
- **Rofi** (`~/.config/rofi/`): Application launcher and omnisearch.
- **Picom** (`~/.config/picom/`): X11 compositor.
- **Polybar** (`~/.config/polybar/`): i3 status bar (counterpart to Waybar on Hyprland).
