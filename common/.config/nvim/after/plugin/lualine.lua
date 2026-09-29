require('lualine').setup {
  options = {
    icons_enabled = true,
    -- Renamed upstream: catppuccin moved lua/lualine/themes/catppuccin.lua to
    -- catppuccin-nvim.lua ("move special integrations to `catppuccin-nvim`").
    -- Same file, so this follows the active flavour exactly as before.
    theme = 'catppuccin-nvim',
    component_separators = { left = '', right = ''},
    section_separators = { left = '', right = '' },
    disabled_filetypes = {
      statusline = {},
      winbar = {},
    },
    ignore_focus = {},
    always_divide_middle = true,
    globalstatus = true,
    refresh = {
      statusline = 100,
      tabline = 1000,
      winbar = 1000,
    }
  },
  sections = {
    lualine_a = {
      "mode"
    },
    lualine_b = {
      'branch',
      'diff',
      'diagnostics'
    },
    lualine_c = {
      {
        'filename',
        padding = 2,
        path = 1
      },
      {
        'filetype',
        colored = true,
        icon_only = true,
        icon = { align = 'center' },
        padding = 0,
      },
    },
    lualine_x = {
    },
    lualine_y = {
      'location',
    },
    lualine_z = {
      'progress',
    },
  },
  inactive_sections = {
    lualine_a = {},
    lualine_b = {},
    lualine_c = {},
    lualine_x = {},
    lualine_y = {},
    lualine_z = {}
  },
  tabline = {},
  winbar = {},
  inactive_winbar = {},
  extensions = {}
}
