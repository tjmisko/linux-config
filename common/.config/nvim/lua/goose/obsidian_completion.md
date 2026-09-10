# goose/obsidian_completion — Wikilink Completion for blink.cmp

Custom blink.cmp source that provides `[[wikilink]]` completions for Obsidian
vaults. It replaces obsidian-nvim's own completion, which spawns an async
ripgrep search per keystroke and frequently has its results discarded before
they arrive.

## How It Works

### Architecture

All completion data lives in three in-memory caches built at startup:

- **Filename cache** — a flat list of every `.md` basename in the vault
- **Alias cache** — `{ [basename] = { "alias1", "alias2", ... } }` parsed
  from YAML frontmatter `aliases:` (inline or block form)
- **Uncreated cache** — every `[[target]]` in the vault that has no note yet

The first two come from one async `rg --files` pass, the third from a second
`rg -o` pass over link targets. `get_completions()` reads the caches
synchronously, so results are instant and there is no async race.

### Wikilink Context Detection

On each request, `detect_wikilink_context()` walks backwards through the
text before the cursor looking for `[[`. If it hits `]` first (closed link)
or reaches the start of the line, it returns nil and no items are offered.
Otherwise it returns the query and the column of the opening brackets.

### Completion Items

Every cached entry is returned on every request; blink does the filtering.

| Field | Value | Purpose |
|-------|-------|---------|
| `label` | `[[Note Name]]` | Shown in the menu |
| `filterText` | `Note Name` (alias items: `alias Note Name`) | What blink fuzzy-matches the typed keyword against |
| `textEdit.newText` | `Note Name]]` | Text inserted on accept |
| `textEdit.range` | after `[[` to cursor | Region replaced on accept |
| `sortText` | `zzz…` on uncreated items | Sinks them below real notes |

The `[[` prefix is excluded from the edit because it already exists in the
buffer. blink derives the match keyword from the buffer line (the word
before the cursor), scores it against `filterText`, and applies `textEdit`
verbatim on accept, so the edit range and the keyword do not need to line up
the way they did under nvim-cmp.

### Cache Refresh

A `BufWritePost <notes_dir>/*.md` autocmd refreshes the caches for the saved
file: new filenames are appended, aliases are re-parsed, new link targets
without a note are added to the uncreated cache, and a target that now has a
note is promoted out of it.

## Registration

The source is registered in `plugins/blink-cmp.lua` as a provider, enabled
for markdown buffers alongside the default sources:

```lua
sources = {
  per_filetype = {
    markdown = { inherit_defaults = true, "obsidian_wikilink" },
  },
  providers = {
    obsidian_wikilink = {
      name = "Wikilink",
      module = "goose.obsidian_completion",
      score_offset = 10,
      opts = { notes_dir = "~/Notes" },
    },
  },
}
```

`enabled()` further restricts it to buffers whose path is under `notes_dir`.
`notes_dir` is an option so tests can point the source at a scratch vault.

## obsidian-ls

obsidian.nvim 3.x runs an in-process LSP ("obsidian-ls") whose ref and tag
completions duplicate this source. Its items are dropped with a
`transform_items` filter on blink's `lsp` provider (matching on
`item.client_name`), while the server itself keeps serving definition,
references, rename and workspace symbols.

## Design Notes

1. **Startup caches, synchronous requests.** Cache building is async so nvim
   startup is not blocked, but `get_completions()` never waits on anything.
2. **blink owns filtering.** Under nvim-cmp the source pre-filtered and set
   `filterText = query` to force cmp's matcher to accept everything. blink's
   matcher is fast enough to score the whole vault per keystroke, so the
   source returns all items with a meaningful `filterText` and gets typo
   tolerance and frecency for free.
3. **`is_incomplete_forward = false`.** The item set does not depend on the
   keyword, so blink can filter the cached response client-side instead of
   re-requesting on every keystroke.
