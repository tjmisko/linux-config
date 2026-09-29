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

With a single-word query every cached entry is returned and blink does the
filtering. With a multi-word query (see below) the source filters first.

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

### Multi-Word Queries

blink's keyword is the run of letters, digits, `_` and `-` before the cursor.
Its Rust matcher can widen that per item (`guess_keyword_range`) but stops
dead at whitespace, so for `[[my note` every item is scored against `note`
alone and `my` is ignored.

The source detects this by asking blink for its keyword
(`blink.cmp.fuzzy.get_keyword_range`) and comparing it with the full text
after `[[`. When they differ it switches modes:

1. The whole query is matched case-insensitively against every item's
   haystack (note name, alias, or uncreated target) the way Obsidian's link
   suggester does, in tiers: exact name, name starts with the query, name
   contains the query as a phrase, name contains every query word in any
   order. Within a tier shorter names rank first, then alphabetical. There is
   deliberately no loose fuzzy tier: `vim.fn.matchfuzzypos` was tried and let
   `with` match "Writing Has", burying real phrase matches.
2. Only the hits are returned. Each gets `filterText` set to blink's keyword,
   so blink's own matcher gives them all the same (exact) score.
3. `sortText` carries the rank (`a000001`, ...; uncreated targets use a `z`
   prefix so they stay below real notes). blink's default sorts are `score`
   then `sort_text`, so the rank decides the order.
4. The response is flagged incomplete so blink re-requests on every
   keystroke instead of filtering its cached list.

Single-word queries keep the plain path so blink's typo tolerance and
frecency still apply there; multi-word queries have no typo tolerance.

### Surviving the Space

blink treats space as a blocked trigger character everywhere, so on its own
it hides the menu the moment you type `[[good ` and only brings it back on
the next letter. Three pieces keep the menu up instead:

1. The source lists `" "` in `get_trigger_characters()`, so a space can open
   a fresh context.
2. `completion.trigger.show_on_blocked_trigger_characters` in
   `plugins/blink-cmp.lua` is a function: it returns the default list minus
   space while `source.cursor_in_wikilink()` is true (markdown buffer, open
   `[[` before the cursor on the current line), and the default otherwise.
3. A trigger-character context ignores `min_keyword_length` and queries every
   enabled source, so the `buffer` and `snippets` providers get a
   `should_show_items` that returns false inside a wikilink. Otherwise every
   buffer word and snippet would appear under the wikilinks on the space.

The context opened by the space has an empty keyword; the source's hits then
carry `filterText = ""`, which blink's matcher accepts for every item, so the
phrase-matched list shows in rank order until the next letter narrows it.

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
3. **`is_incomplete_forward = false` for single-word queries.** There the
   item set does not depend on the keyword, so blink filters the cached
   response client-side. Multi-word queries flip it to `true` because the
   source pre-filters and the set changes with every keystroke.
