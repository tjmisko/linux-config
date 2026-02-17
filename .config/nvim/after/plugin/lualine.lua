require('lualine').setup {
  options = {
    icons_enabled = true,
    theme = 'catppuccin',
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
    lualine_a = {},
    lualine_b = {
        'branch',
        'diff',
        'diagnostics'
    },
    lualine_c = {
        {
            'filename',
            padding = 1,
            path = 1
        },
        {
            'filetype',
            colored = true,
            icon_only = true,
            icon = { align = 'center' },
            padding = 0,
        },
        {
            'location',
            padding = 0
        },
    },
    lualine_x = {'encoding'},
    lualine_y = {
        {'mode', padding = { right = 1 } }
    },
    lualine_z = {
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
