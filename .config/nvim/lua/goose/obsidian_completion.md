# goose/obsidian_completion — Wikilink Completion for nvim-cmp

Custom nvim-cmp source that provides `[[wikilink]]` completions for Obsidian
vaults. Replaces obsidian-nvim's built-in cmp integration, which is unreliable
because each keystroke spawns an async ripgrep search that frequently gets
discarded by cmp before results arrive.

## How It Works

### Architecture

All completion data lives in two in-memory caches built at startup:

- **Filename cache** — a flat list of every `.md` basename in the vault
- **Alias cache** — a map of `{ [basename] = { "alias1", "alias2", ... } }`
  parsed from YAML frontmatter `aliases:` blocks

Both caches are populated by a single async `rg --files` call at startup.
The `complete()` method filters these caches synchronously with substring
matching, so results are always instant — no per-keystroke rg processes,
no async callback races.

### Wikilink Context Detection

On each completion request, `detect_wikilink_context()` walks backwards
through the text before the cursor looking for `[[`. If it hits `]` first
(closed link) or reaches the start of the line, it returns nil and no
completions are shown. Otherwise it returns the query (text after `[[`)
and the column position of the opening brackets.

### Completion Items

Items are formatted for cmp with these fields:

| Field | Value | Purpose |
|-------|-------|---------|
| `label` | `[[Note Name]]` | Displayed in the completion menu |
| `filterText` | the current query | Ensures cmp's matcher always accepts our pre-filtered items |
| `word` | `Note Name]]` | Full text inserted by Tab (`select_next_item`) |
| `textEdit.newText` | `Note Name]]` | Full text inserted by Enter (`confirm`) |
| `textEdit.range` | after `[[` to cursor | Region replaced on confirm |

The `[[` prefix is excluded from `textEdit` and `word` because it already
exists in the buffer. The edit range starts *after* `[[` to align with the
keyword pattern offset — if it started at `[[`, cmp would pull the source
offset earlier, making the match input include `[[` and breaking filterText
matching.

For aliases, the format is `Note Name|alias]]` with `label` showing
`[[Note Name|alias]]`.

### Why filterText = query

We do our own substring matching (`string.find` with `plain=true`) before
returning items to cmp. Setting `filterText` to the query itself guarantees
cmp's fuzzy matcher always accepts every item we return — input "Edge"
matches filterText "Edge" perfectly. Without this, cmp's matcher would
try to match "Edge" against "Silver - 2024 - On the Edge" and could
reject it due to low scoring on non-prefix partial matches.

### Cache Refresh

A `BufWritePost *.md` autocmd refreshes both caches for the saved file:
new filenames are appended to the filename cache, and aliases are re-parsed
from frontmatter.

## Registration

The source is registered in `plugins/nvim-cmp.lua`:

```lua
cmp.register_source("obsidian_wikilink", require("goose.obsidian_completion").new())
```

And added as the first source in the sources list (highest priority, but
only activates inside `[[` in markdown files under `~/Documents/Notes`):

```lua
sources = cmp.config.sources({
  { name = "obsidian_wikilink" },
  { name = "nvim_lsp" },
  { name = "luasnip" },
}, {
  { name = "buffer" },
}),
```

obsidian-nvim's native cmp integration is disabled in `plugins/obsidian-nvim.lua`:

```lua
completion = { nvim_cmp = false },
```

## Key Design Decisions

1. **Synchronous filtering, async cache building.** The startup rg call is
   async (doesn't block nvim startup), but every `complete()` call is fully
   synchronous. This eliminates the async-callback-staleness race where cmp
   discards results that arrive after the user has typed another character.

2. **textEdit range after `[[`.** The keyword pattern `\%(\[\[\)\zs[^\]]*`
   sets the match start after `[[` via `\zs`. If the textEdit range started
   *at* `[[`, cmp would compute a source offset that includes `[[` in the
   match input, causing filterText mismatches. Aligning the range with the
   keyword offset keeps matching correct.

3. **`word` field set explicitly.** Without it, cmp derives `word` from
   `textEdit.newText` via `str.get_word()`, which truncates at spaces and
   hyphens. A note named "Silver - 2024 - On the Edge" would preview as
   just "Silver" on Tab. Setting `word` directly bypasses the truncation.

4. **`isIncomplete = true`.** Tells cmp to re-call our source on every
   keystroke so the substring filter updates as the user types.
