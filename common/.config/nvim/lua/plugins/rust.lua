-- Rust toolchain integration via rustaceanvim.
--
-- rustaceanvim configures and starts rust-analyzer itself, so rust_analyzer is
-- deliberately NOT set up through lsp.lua's cfg()/mason path: rustaceanvim
-- warns that a second lspconfig client for the same server conflicts with it.
-- rust-analyzer comes from the rustup proxy in ~/.cargo/bin, which means it
-- follows each project's rust-toolchain.toml; do not let mason install one.
--
-- What this wires up:
--   clippy   -> rust-analyzer runs `cargo clippy` on save (check.command).
--   rustfmt  -> rust-analyzer serves textDocument/formatting via rustfmt,
--               triggered on BufWritePre below; honors rustfmt.toml.
--   nextest  -> :RustLsp testables (<leader>rt) uses cargo-nextest when it is
--               installed, falling back to cargo test.
--   bacon    -> runs in its own wezterm pane (`bacon nextest`), not in nvim.
--               Do not also run `bacon clippy`: it would compete with
--               rust-analyzer's check-on-save for the cargo lock.
return {
  {
    "mrcjkb/rustaceanvim",
    version = "^9",
    lazy = false,
    init = function()
      vim.g.rustaceanvim = {
        tools = {
          -- Run tests in the background and surface failures as diagnostics.
          test_executor = "background",
        },
        server = {
          -- Pin to the rustup proxy. rustaceanvim otherwise prefers a mason
          -- rust-analyzer if one is installed, which would not follow
          -- rust-toolchain.toml.
          cmd = { vim.fn.expand("~/.cargo/bin/rust-analyzer") },
          on_attach = function(client, bufnr)
            local map = function(mode, lhs, rhs, desc)
              vim.keymap.set(mode, lhs, rhs, { buffer = bufnr, silent = true, desc = desc })
            end

            -- Same core mappings as lsp.lua's on_attach.
            map("n", "gd", vim.lsp.buf.definition, "Go to definition")
            map("n", "gr", vim.lsp.buf.references, "References")
            map("n", "gi", vim.lsp.buf.implementation, "Go to implementation")
            map("n", "<leader>rn", vim.lsp.buf.rename, "Rename")
            map("n", "[d", vim.diagnostic.goto_prev, "Previous diagnostic")
            map("n", "]d", vim.diagnostic.goto_next, "Next diagnostic")

            -- Rust-aware replacements for K / <leader>ca / <leader>e.
            map("n", "K", function() vim.cmd.RustLsp({ "hover", "actions" }) end, "Hover with actions")
            map("n", "<leader>ca", function() vim.cmd.RustLsp("codeAction") end, "Grouped code actions")
            map("n", "<leader>e", function() vim.cmd.RustLsp("renderDiagnostic") end, "Full rustc diagnostic")
            map("n", "<leader>ee", function() vim.cmd.RustLsp("explainError") end, "rustc --explain")
            map("n", "<leader>rt", function() vim.cmd.RustLsp("testables") end, "Run test under cursor")
            map("n", "<leader>rr", function() vim.cmd.RustLsp("runnables") end, "Pick a runnable")
            map("n", "<leader>rm", function() vim.cmd.RustLsp("expandMacro") end, "Expand macro")

            -- rustfmt on save, served by rust-analyzer.
            vim.api.nvim_create_autocmd("BufWritePre", {
              buffer = bufnr,
              group = vim.api.nvim_create_augroup("goose_rustfmt_" .. bufnr, { clear = true }),
              callback = function()
                vim.lsp.buf.format({ bufnr = bufnr, id = client.id, timeout_ms = 2000 })
              end,
            })
          end,
          default_settings = {
            ["rust-analyzer"] = {
              cargo = { allFeatures = true },
              -- Clippy, not plain check, on every save. rust-analyzer already
              -- passes --all-targets (check.allTargets defaults to true); adding
              -- it again via extraArgs makes cargo reject the command.
              check = { command = "clippy" },
            },
          },
        },
      }
    end,
  },
}
