local wezterm = require 'wezterm'
local config = wezterm.config_builder()

config.color_scheme = 'Catppuccin Mocha'

config.window_background_opacity = 0.79
config.hide_tab_bar_if_only_one_tab = true
config.show_new_tab_button_in_tab_bar = false
config.warn_about_missing_glyphs = false
config.font_size = 14
config.use_ime = true
config.enable_scroll_bar = false
config.use_fancy_tab_bar = true
config.tab_bar_at_bottom = true

config.keys = {
    { key="Enter", mods="SHIFT", action=wezterm.action{SendString="\x1b\r"} },
}
-- Retitle tab
table.insert(config.keys, {
  key = "R",
  mods = "CTRL|SHIFT",
  action = wezterm.action.PromptInputLine {
    description = "Set tab title",
    action = wezterm.action_callback(function(window, pane, line)
      if line then
        window:active_tab():set_title(line)
      end
    end),
  },
})


config.window_padding = { top = 15, bottom = 0, left = 10, right = 0 }

if os.getenv('WEZTERM_FLOAT_TOGGLE') then
  config.window_close_confirmation = 'NeverPrompt'
end

-- Hide the per-tab close ("x") button (Nightly builds only).
-- Wrapped so stable builds don't error on unknown config field.
pcall(function()
    config.show_close_tab_button_in_tabs = false
end)

-- Catppuccin-ish constants (tab faces)
local C = {
    mantle   = "#181825",
    crust    = "#11111b",
    surface0 = "#313244",
    surface1 = "#45475a",
    text     = "#cdd6f4",
    subtext0 = "#a6adc8",
}

-- Pull background/foreground from the active scheme (fallbacks are safe)
local schemes = wezterm.get_builtin_color_schemes()
local scheme = schemes[config.color_scheme] or {}
local TERM_BG = scheme.background or C.crust
local TERM_FG = scheme.foreground or C.text

-- TAB STRIP / FRAME: this is the part that was staying grey.
-- Force it to match the terminal background.
config.window_frame = config.window_frame or {}
config.window_frame.active_titlebar_bg = TERM_BG
config.window_frame.inactive_titlebar_bg = TERM_BG
config.window_frame.active_titlebar_fg = TERM_FG
config.window_frame.inactive_titlebar_fg = TERM_FG
config.window_frame.button_bg = TERM_BG
config.window_frame.button_fg = TERM_FG
config.window_frame.font_size = 10

-- Also force tab-bar colors so nothing falls back to default grey.
config.colors = config.colors or {}
config.colors.tab_bar = {
    background = TERM_BG,
    active_tab = { bg_color = TERM_BG, fg_color = TERM_FG },
    inactive_tab = { bg_color = TERM_BG, fg_color = TERM_FG },
    inactive_tab_hover = { bg_color = TERM_BG, fg_color = TERM_FG },
    new_tab = { bg_color = TERM_BG, fg_color = TERM_FG },
    new_tab_hover = { bg_color = TERM_BG, fg_color = TERM_FG },
}

local function tab_title(tab_info)
    local title = tab_info.tab_title
    if title and #title > 0 then
        return title
    end
    return tab_info.active_pane.title
end

wezterm.on("format-tab-title", function(tab, tabs, panes, cfg, hover, max_width)
    local bg, fg
    if tab.is_active then
        bg, fg = C.surface1, C.text
    elseif hover then
        bg, fg = C.surface0, C.text
    else
        bg, fg = C.mantle, C.subtext0
    end

    local title = tab_title(tab)
    local available = 80
    title = wezterm.truncate_right(title, available)

    return {
        -- strip bg (same as terminal)
        { Foreground = { Color = fg } },
        { Background = { Color = bg } },
        { Attribute = { Intensity = tab.is_active and "Bold" or "Normal" } },
        { Text = "  " .. title .. "  " },
    }
end)

return config
