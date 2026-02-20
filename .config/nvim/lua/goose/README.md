# goose/claude — Neovim Claude Code Session Manager

Manage multiple Claude Code sessions from Neovim via tmux, with an fzf-based session picker and floating terminal windows.

## Files

- `claude.lua` — Main plugin: float management, session lifecycle, context sending, keymaps
- `claude-picker.sh` — fzf-based session picker script

## Keymaps

| Key | Mode | Description |
|-----|------|-------------|
| `Alt-a` | normal, terminal | Toggle the active Claude session float |
| `Alt-f` | normal, terminal | Open the fzf session picker |
| `Alt-c` | normal | Send buffer/harpoon/quickfix paths as `@file` context to the active session |

## Picker Controls

| Key | Action |
|-----|--------|
| `Enter` | Attach to selected session |
| `Ctrl-n` | Create a new session |
| `Ctrl-x` | Kill selected session |
| `Ctrl-r` | Rename selected session |

## How It Works

Each Claude session runs in a dedicated tmux session (named `claude-N`). Neovim attaches to these sessions via `tmux attach-session` inside a floating terminal buffer. This decouples the Claude process from Neovim's lifecycle — sessions persist if Neovim closes, and can be reattached later.

When a new session is created, Claude is launched with a system prompt instructing it to rename the tmux session to a short, descriptive name based on the task.

### Session Switching and the `on_exit` Guard

When switching between sessions, the old terminal buffer is force-deleted, which kills its `tmux attach` process. This triggers the buffer's `on_exit` callback via `vim.schedule`. Since the new session's buffer and window are created synchronously before that scheduled callback runs, the stale callback would close the newly opened window and nil out state variables.

To prevent this, the `on_exit` handler captures `float_buf` into a local (`this_buf`) at creation time and checks `float_buf ~= this_buf` before cleaning up. If the active buffer has changed, the callback is stale and returns early.

## Context Sending

`Alt-c` collects file paths from three sources and sends them as `@file` references to the active Claude session:

1. Listed buffers
2. Harpoon list (if available)
3. Quickfix list
