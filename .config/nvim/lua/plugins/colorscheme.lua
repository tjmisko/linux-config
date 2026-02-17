return {
  "catppuccin/nvim",
  name = "catppuccin",
  priority = 1000,
  config = function()
    require("catppuccin").setup({
      transparent_background = true,

      highlight_overrides = {
        all = function(colors)
          return {
            LineNr = { fg = colors.yellow },
          }
        end,

        mocha = function(mocha)
          return {
            -- your custom groups
            retendDegeneracy = { fg = mocha.red },
            retendProductive = { fg = mocha.blue },
            retendEnrichment = { fg = mocha.green },
            retendPractice = { fg = mocha.teal },
            retendRoutine = { fg = mocha.lavender },
            retendTransition = { fg = mocha.maroon },
            retendPersonal = { fg = mocha.flamingo },
            retendSocial = { fg = mocha.peach },
            retendSleep = { fg = mocha.overlay0 },
            retendFlex = { fg = mocha.pink },
            retendJen = { fg = mocha.yellow },

            taskfileHeading = { fg = mocha.blue, style = { "bold", "italic" } },
            taskfileOverdue = { fg = mocha.red, style = { "bold", "italic" } },
            taskfileTime = { fg = mocha.yellow },
            taskfileDeferral = { fg = mocha.maroon },
            taskfileOriginal = { fg = mocha.overlay2 },
            taskfileComplete = { fg = mocha.green, style = { "bold" } },
            taskfileDate = { fg = mocha.yellow },
            taskfileDuration = { fg = mocha.peach, style = { "italic" } },
            taskfileTag = { fg = mocha.peach },

            -- Telescope: keep transparent panels, but give borders a mocha tint
            -- (fixes the “weird background” without nuking everything)
            NormalFloat = { bg = "NONE" },
            TelescopeNormal = { bg = "NONE" },
            TelescopePromptNormal = { bg = "NONE" },
            TelescopeResultsNormal = { bg = "NONE" },
            TelescopePreviewNormal = { bg = "NONE" },

            -- Borders: tinted + consistent
            FloatBorder = { fg = mocha.surface2, bg = "NONE" },
            TelescopeBorder = { fg = mocha.surface2, bg = "NONE" },
            TelescopePromptBorder = { fg = mocha.peach, bg = "NONE" }, -- slightly highlighted prompt
            TelescopeResultsBorder = { fg = mocha.surface2, bg = "NONE" },
            TelescopePreviewBorder = { fg = mocha.surface2, bg = "NONE" },

            -- Optional: prompt title / selection accents (safe, looks cohesive)
            TelescopeTitle = { fg = mocha.base, bg = mocha.peach, style = { "bold" } },
            TelescopePromptTitle = { fg = mocha.base, bg = mocha.peach, style = { "bold" } },
            TelescopeSelection = { bg = mocha.surface0 },
            TelescopeMatching = { fg = mocha.lavender, style = { "bold" } },
          }
        end,
      },

      integrations = {
        harpoon = false,
        cmp = true,
        treesitter = true,
        treesitter_context = true,
        telescope = { enabled = true },
        markdown = true,
        native_lsp = {
          enabled = true,
          virtual_text = {
            errors = { "italic" },
            hints = { "italic" },
            warnings = { "italic" },
            information = { "italic" },
          },
          underlines = {
            errors = { "underline" },
            hints = { "underline" },
            warnings = { "underline" },
            information = { "underline" },
          },
          inlay_hints = { background = true },
        },
      },
    })

    vim.cmd.colorscheme("catppuccin-mocha")
  end,
}
