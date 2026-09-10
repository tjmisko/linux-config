-- Auto-close brackets and quotes. Typing `{` gives `{|}`, and Enter between
-- them expands to an indented blank line with `}` on its own line, so a Rust
-- function body or an HTML block never needs its closer typed by hand.
--
-- Loaded as a dependency of nvim-cmp (see nvim-cmp.lua) so its <CR> mapping
-- is in place before cmp installs its own; cmp's <CR> falls through to it
-- whenever no completion item is selected.
return {
  {
    "windwp/nvim-autopairs",
    event = "InsertEnter",
    opts = {
      -- Use the treesitter tree to skip pairing inside strings/comments.
      check_ts = true,
      ts_config = {
        lua = { "string" },
        javascript = { "template_string" },
      },
      -- <M-e> wraps the next word/bracket with the pair just typed.
      fast_wrap = {},
    },
  },
}
