-- Auto-close brackets and quotes. Typing `{` gives `{|}`, and Enter between
-- them expands to an indented blank line with `}` on its own line, so a Rust
-- function body or an HTML block never needs its closer typed by hand.
--
-- blink.cmp leaves <CR> unmapped, so Enter always reaches this plugin's
-- expansion. Parens after accepting a function completion come from blink's
-- own auto_brackets, which writes both brackets directly rather than typing
-- `(`, so the two never double up.
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
