-- Refer to the wiki for more information.
-- https://wiki.hypr.land/Configuring/
--
-- Migrated from the legacy hyprland.conf (hyprlang) format, which Hyprland
-- drops in 0.57. The previous file is kept at hyprland.conf.bak for reference.

------------------
---- MONITORS ----
------------------
-- See https://wiki.hypr.land/Configuring/Basics/Monitors/
-- Laptop display (left)
hl.monitor({ output = "eDP-1", mode = "preferred", position = "0x0", scale = 2 })
-- External monitor (right of laptop)
hl.monitor({ output = "HDMI-A-1", mode = "preferred", position = "auto-right", scale = 1 })
-- Fallback for any other monitors
hl.monitor({ output = "", mode = "preferred", position = "auto", scale = "auto" })


---------------------
---- MY PROGRAMS ----
---------------------

local terminal = "wezterm"
local fileManager = "dolphin"
local obsidian =
    [[bash -c "/home/tjmisko/AppImages/Obsidian-1.12.4.AppImage --no-sandbox --enable-features=UseOzonePlatform --ozone-platform=wayland --ozone-platform-hint=wayland"]]
local browser = "firefox"
local menu = "rofi -show drun"


-------------------
---- AUTOSTART ----
-------------------
-- See https://wiki.hypr.land/Configuring/Basics/Autostart/

hl.on("hyprland.start", function()
    hl.exec_cmd(
        "systemctl --user import-environment HYPRLAND_INSTANCE_SIGNATURE WAYLAND_DISPLAY XDG_CURRENT_DESKTOP DISPLAY")
    hl.exec_cmd("systemctl --user restart --no-block switchboard.service")
    hl.exec_cmd("waybar")
    hl.exec_cmd("/home/tjmisko/go/bin/switchboard-ctl bottombar watch")
    hl.exec_cmd("mako")
    hl.exec_cmd("wl-paste --watch cliphist store")
    hl.exec_cmd("swaybg -i ~/Photos/Wallpaper/Oakland-Watercolor-Graphic-Graphics-59528710-1-cropped.jpg")
    hl.exec_cmd("fcitx5 -d -r")
    hl.exec_cmd(terminal .. " start --class wezterm-terminal --cwd ~ -- bash -l", { workspace = "4 silent" })
    hl.exec_cmd(obsidian, { workspace = "7 silent" })
    hl.exec_cmd(browser, { workspace = "8 silent" })
    hl.dispatch(hl.dsp.focus({ workspace = 4 }))
end)


-------------------------------
---- ENVIRONMENT VARIABLES ----
-------------------------------
-- See https://wiki.hypr.land/Configuring/Advanced-and-Cool/Environment-variables/

hl.env("XCURSOR_SIZE", "18")
hl.env("HYPRCURSOR_SIZE", "18")
hl.env("TERMINAL", "wezterm")

-- Input method (fcitx5). Set here because Hyprland is exec'd from the TTY login
-- shell, so ~/.config/environment.d is NOT applied to the session. These reach
-- every app Hyprland spawns and override the inherited imsettings/ibus values.
--
-- GTK_IM_MODULE / QT_IM_MODULE are deliberately NOT set: GTK3/4 and Qt6 speak
-- the Wayland text-input protocol natively, fcitx5's Wayland frontend handles
-- them, and setting the im-module vars makes fcitx5 warn ("Wayland Diagnose")
-- because the module path bypasses the Wayland frontend.
-- XMODIFIERS is still needed for XWayland clients, SDL_IM_MODULE for SDL2.
hl.env("XMODIFIERS", "@im=fcitx")
hl.env("SDL_IM_MODULE", "fcitx")
-- GLFW only speaks the ibus protocol; fcitx5's IBus Frontend addon answers it.
hl.env("GLFW_IM_MODULE", "ibus")


-----------------------
---- LOOK AND FEEL ----
-----------------------
-- Refer to https://wiki.hypr.land/Configuring/Basics/Variables/

hl.config({
    general = {
        gaps_in = 4,
        gaps_out = 6,
        border_size = 2,

        col = {
            active_border = { colors = { "rgba(998888aa)", "rgba(ff9999aa)" }, angle = 45 },
            inactive_border = "rgba(595959aa)",
        },

        -- Set to true to enable resizing windows by clicking and dragging on borders and gaps
        resize_on_border = false,

        -- Please see https://wiki.hypr.land/Configuring/Advanced-and-Cool/Tearing/ before you turn this on
        allow_tearing = false,

        layout = "dwindle",
    },

    decoration = {
        rounding = 15,
        active_opacity = 0.91,
        inactive_opacity = 0.91,

        shadow = {
            enabled = true,
            range = 4,
            render_power = 3,
            color = "rgba(1a1a1aee)",
        },

        blur = {
            enabled = true,
            size = 10,
            passes = 2,

            vibrancy = 0.1696,
        },
    },

    animations = {
        enabled = true,
    },
})

hl.curve("easeOutQuint", { type = "bezier", points = { { 0.23, 1 }, { 0.32, 1 } } })
hl.curve("easeInOutCubic", { type = "bezier", points = { { 0.65, 0.05 }, { 0.36, 1 } } })
hl.curve("linear", { type = "bezier", points = { { 0, 0 }, { 1, 1 } } })
hl.curve("almostLinear", { type = "bezier", points = { { 0.5, 0.5 }, { 0.75, 1.0 } } })
hl.curve("quick", { type = "bezier", points = { { 0.15, 0 }, { 0.1, 1 } } })

hl.animation({ leaf = "global", enabled = true, speed = 1.00, bezier = "default" })
hl.animation({ leaf = "border", enabled = true, speed = 2.70, bezier = "easeOutQuint" })
hl.animation({ leaf = "windows", enabled = true, speed = 2.40, bezier = "easeOutQuint" })
hl.animation({ leaf = "windowsIn", enabled = true, speed = 2.05, bezier = "easeOutQuint", style = "popin 87%" })
hl.animation({ leaf = "windowsOut", enabled = true, speed = 0.75, bezier = "linear", style = "popin 87%" })
hl.animation({ leaf = "fadeIn", enabled = true, speed = 0.87, bezier = "almostLinear" })
hl.animation({ leaf = "fadeOut", enabled = true, speed = 0.73, bezier = "almostLinear" })
hl.animation({ leaf = "fade", enabled = true, speed = 1.52, bezier = "quick" })
hl.animation({ leaf = "layers", enabled = true, speed = 1.90, bezier = "easeOutQuint" })
hl.animation({ leaf = "layersIn", enabled = true, speed = 2.00, bezier = "easeOutQuint", style = "fade" })
hl.animation({ leaf = "layersOut", enabled = true, speed = 0.75, bezier = "linear", style = "fade" })
hl.animation({ leaf = "fadeLayersIn", enabled = true, speed = 0.90, bezier = "almostLinear" })
hl.animation({ leaf = "fadeLayersOut", enabled = true, speed = 0.70, bezier = "almostLinear" })
hl.animation({ leaf = "workspaces", enabled = true, speed = 0.97, bezier = "almostLinear", style = "fade" })
hl.animation({ leaf = "workspacesIn", enabled = true, speed = 0.61, bezier = "almostLinear", style = "fade" })
hl.animation({ leaf = "workspacesOut", enabled = true, speed = 0.97, bezier = "almostLinear", style = "fade" })


-- Ref https://wiki.hypr.land/Configuring/Basics/Workspace-Rules/
-- Workspace-to-monitor assignments
-- Laptop (eDP-1): workspaces 1-6
hl.workspace_rule({ workspace = "1", monitor = "eDP-1", default = true })
hl.workspace_rule({ workspace = "2", monitor = "eDP-1" })
hl.workspace_rule({ workspace = "3", monitor = "eDP-1" })
hl.workspace_rule({ workspace = "4", monitor = "eDP-1" })
hl.workspace_rule({ workspace = "5", monitor = "eDP-1" })
hl.workspace_rule({ workspace = "6", monitor = "eDP-1" })
-- External (HDMI-A-1): workspaces 7-9
hl.workspace_rule({ workspace = "7", monitor = "HDMI-A-1" })
hl.workspace_rule({ workspace = "8", monitor = "HDMI-A-1", default = true })
hl.workspace_rule({ workspace = "9", monitor = "HDMI-A-1" })

-- See https://wiki.hypr.land/Configuring/Layouts/Dwindle-Layout/ for more
hl.config({
    dwindle = {
        preserve_split = false, -- You probably want this
    },
})

-- See https://wiki.hypr.land/Configuring/Layouts/Master-Layout/ for more
hl.config({
    master = {
        new_status = "master",
    },
})

hl.config({
    misc = {
        force_default_wallpaper = 0,   -- Set to 0 or 1 to disable the anime mascot wallpapers
        disable_hyprland_logo = true,  -- If true disables the random hyprland logo / anime girl background. :(
        focus_on_activate = true,
    },
})


---------------
---- INPUT ----
---------------
-- https://wiki.hypr.land/Configuring/Basics/Variables/#input

hl.config({
    input = {
        kb_layout = "us",
        kb_variant = "",
        kb_model = "",
        kb_options = "",
        kb_rules = "",

        follow_mouse = 1,
        sensitivity = 0, -- -1.0 - 1.0, 0 means no modification.

        touchpad = {
            natural_scroll = true,
            clickfinger_behavior = true,
            disable_while_typing = true,
        },
    },
})

-- https://wiki.hypr.land/Configuring/Advanced-and-Cool/Gestures/
hl.gesture({ fingers = 3, direction = "horizontal", action = "workspace" })

-- Example per-device config
-- See https://wiki.hypr.land/Configuring/Advanced-and-Cool/Devices/ for more
hl.device({ name = "epic-mouse-v1", sensitivity = 0.25 })


---------------------
---- KEYBINDINGS ----
---------------------

-- i3 -> Hyprland keybind port

local mainMod = "SUPER"
local altMod = "ALT"

-- Claude session tracker keybindings
hl.bind(mainMod .. " + SHIFT + A", hl.dsp.exec_cmd("~/.config/scripts/claude-picker"))
hl.bind(mainMod .. " + A", hl.dsp.exec_cmd("/home/tjmisko/go/bin/switchboard-ctl attention"))
hl.bind(mainMod .. " + " .. altMod .. " + Right", hl.dsp.exec_cmd("/home/tjmisko/go/bin/switchboard-ctl cycle next"))
hl.bind(mainMod .. " + " .. altMod .. " + Left", hl.dsp.exec_cmd("/home/tjmisko/go/bin/switchboard-ctl cycle prev"))

-- --- App launchers / apps ---
hl.bind(mainMod .. " + Return", hl.dsp.exec_cmd("/usr/bin/wezterm"))
hl.bind(mainMod .. " + B", hl.dsp.exec_cmd("/usr/bin/firefox"))
hl.bind(mainMod .. " + P",
    hl.dsp.exec_cmd(
        [[gio open "obsidian://open?vault=Notes&file=projects%2FProjects.base" && hyprctl dispatch workspace 7]]))
hl.bind(mainMod .. " + SHIFT + P",
    hl.dsp.exec_cmd([[gio open "obsidian://open?vault=Notes&file=people%2FPeople.base" && hyprctl dispatch workspace 7]]))
hl.bind(mainMod .. " + SHIFT + D",
    hl.dsp.exec_cmd([[gio open "obsidian://open?vault=Notes&file=daily%2FDaily.base" && hyprctl dispatch workspace 7]]))
hl.bind(mainMod .. " + SHIFT + W",
    hl.dsp.exec_cmd([[gio open "obsidian://open?vault=Notes&file=weekly%2FWeekly.base" && hyprctl dispatch workspace 7]]))
hl.bind(mainMod .. " + S",
    hl.dsp.exec_cmd(
        [[gio open "obsidian://open?vault=Notes&file=sources%2FSources.base" && hyprctl dispatch workspace 7]]))
hl.bind(mainMod .. " + F8", hl.dsp.exec_cmd("~/.config/scripts/hypr-float-center --toggle-waybar"))
hl.bind(mainMod .. " + SHIFT + T", hl.dsp.exec_cmd("/usr/bin/wezterm start --always-new-process ~/.config/scripts/tasks-open"))
hl.bind(mainMod .. " + T", hl.dsp.exec_cmd("~/.config/scripts/hypr-float-center 58 --class tasksTop ~/.config/scripts/tasks-open"))
hl.bind(mainMod .. " + C", hl.dsp.exec_cmd("~/.config/scripts/hypr-float-center 58 --class calendarSize ~/Tools/cal_exec"))
hl.bind(mainMod .. " + F3",
    hl.dsp.exec_cmd(
        [[~/.config/scripts/hypr-float-center 90 --class retendFloat --on-close "nvim --server /tmp/nvim-retend.sock --remote-send '<C-\><C-n>:wa<CR>'" ~/.config/scripts/sch retend]]))
hl.bind(mainMod .. " + Q", hl.dsp.exec_cmd("/usr/bin/firefox https://claude.ai"))
hl.bind(mainMod .. " + M", hl.dsp.exec_cmd("~/Tools/geonote/geonote --rofi"))
-- Zettel-LLM inbox quick-capture: open a blank inbox note in $EDITOR (nvim), drop into Sources/Inbox/
hl.bind(mainMod .. " + I",
    hl.dsp.exec_cmd(
        "/usr/bin/wezterm start --class zettelCapture -- /home/tjmisko/Projects/Zettel-LLM/Meta/scripts/zettel/target/release/zettel capture --edit --vault /home/tjmisko/Projects/Zettel-LLM"))
hl.bind(mainMod .. " + N", hl.dsp.exec_cmd("/usr/bin/wezterm start --cwd ~/Notes nvim ~/Notes"))
hl.bind(mainMod .. " + O", hl.dsp.exec_cmd(obsidian))
hl.bind(mainMod .. " + SHIFT + N", hl.dsp.exec_cmd("/usr/bin/wezterm start --cwd ~/Notes newsboat"))
hl.bind(mainMod .. " + V", hl.dsp.exec_cmd("cliphist list | rofi -dmenu -i | cliphist decode | wl-copy"))

-- "omnisearch" / bookmarks / readings
hl.bind(mainMod .. " + R", hl.dsp.exec_cmd("~/.config/scripts/readings --rofi"))
hl.bind(mainMod .. " + Space", hl.dsp.exec_cmd("~/Tools/omnisearch -f rofi"))
hl.bind(mainMod .. " + U", hl.dsp.exec_cmd("~/Tools/Bookmarks/marks"))

hl.bind(mainMod .. " + F5", hl.dsp.exec_cmd("~/Resume/bin/resume-pick"))
hl.bind(mainMod .. " + F1", hl.dsp.exec_cmd("makoctl dismiss"))
hl.bind(mainMod .. " + D", hl.dsp.exec_cmd("makoctl dismiss"))
hl.bind(mainMod .. " + SHIFT + Z", hl.dsp.exec_cmd("fcitx5 -r -d"))

-- --- Kill focused window ---
hl.bind(altMod .. " + F4", hl.dsp.window.close())

-- --- Monitor focus ---
hl.bind(mainMod .. " + H", hl.dsp.focus({ monitor = "l" }))
hl.bind(mainMod .. " + L", hl.dsp.focus({ monitor = "r" }))

-- --- Move workspace to monitor ---
hl.bind(mainMod .. " + SHIFT + comma", hl.dsp.workspace.move({ monitor = "l" }))
hl.bind(mainMod .. " + SHIFT + period", hl.dsp.workspace.move({ monitor = "r" }))

-- --- Focus movement (arrow keys) ---
hl.bind(mainMod .. " + Left", hl.dsp.focus({ direction = "l" }))
hl.bind(mainMod .. " + Down", hl.dsp.focus({ direction = "d" }))
hl.bind(mainMod .. " + Up", hl.dsp.focus({ direction = "u" }))
hl.bind(mainMod .. " + Right", hl.dsp.focus({ direction = "r" }))

-- --- Move window (hjkl + arrows) ---
hl.bind(mainMod .. " + SHIFT + H", hl.dsp.window.move({ direction = "l" }))
hl.bind(mainMod .. " + SHIFT + J", hl.dsp.window.move({ direction = "d" }))
hl.bind(mainMod .. " + SHIFT + K", hl.dsp.window.move({ direction = "u" }))
hl.bind(mainMod .. " + SHIFT + L", hl.dsp.window.move({ direction = "r" }))
hl.bind(mainMod .. " + SHIFT + Left", hl.dsp.window.move({ direction = "l" }))
hl.bind(mainMod .. " + SHIFT + Down", hl.dsp.window.move({ direction = "d" }))
hl.bind(mainMod .. " + SHIFT + Up", hl.dsp.window.move({ direction = "u" }))
hl.bind(mainMod .. " + SHIFT + Right", hl.dsp.window.move({ direction = "r" }))

-- --- Splits / fullscreen ---
hl.bind(mainMod .. " + F", hl.dsp.window.fullscreen({ mode = "maximized" }))
hl.bind(mainMod .. " + SHIFT + F", hl.dsp.window.fullscreen({ mode = "fullscreen" }))

-- --- Workspace switching ---
for i = 1, 9 do
    hl.bind(mainMod .. " + " .. i, hl.dsp.focus({ workspace = i }))
    hl.bind(mainMod .. " + SHIFT + " .. i, hl.dsp.window.move({ workspace = i, follow = true }))
end

-- --- i3: Mod1+Tab back_and_forth ---
hl.bind(altMod .. " + Tab", hl.dsp.focus({ last = true }))
hl.bind(mainMod .. " + SHIFT + E", hl.dsp.exit())

-- --- Resize mode (i3 "mode resize") via Hypr submap ---
hl.bind(mainMod .. " + SHIFT + R", function()
    hl.dispatch(hl.dsp.exec_cmd([[notify-send -u low -t 2500 "Resize Mode" "hjkl / arrows to resize, Escape to exit"]]))
    hl.dispatch(hl.dsp.submap("resize"))
end)

hl.define_submap("resize", function()
    -- hjkl
    hl.bind("H", hl.dsp.window.resize({ x = -50, y = 0, relative = true }))
    hl.bind("J", hl.dsp.window.resize({ x = 0, y = 50, relative = true }))
    hl.bind("K", hl.dsp.window.resize({ x = 0, y = -50, relative = true }))
    hl.bind("L", hl.dsp.window.resize({ x = 50, y = 0, relative = true }))

    -- arrows
    hl.bind("Left", hl.dsp.window.resize({ x = -50, y = 0, relative = true }))
    hl.bind("Down", hl.dsp.window.resize({ x = 0, y = 50, relative = true }))
    hl.bind("Up", hl.dsp.window.resize({ x = 0, y = -50, relative = true }))
    hl.bind("Right", hl.dsp.window.resize({ x = 50, y = 0, relative = true }))

    -- exit resize mode
    local function leave()
        hl.dispatch(hl.dsp.exec_cmd([[notify-send -u low -t 2500 "Resize Mode" "Exited"]]))
        hl.dispatch(hl.dsp.submap("reset"))
    end
    hl.bind("Return", leave)
    hl.bind("Escape", leave)
end)

-- --- "send mode" (i3 mode send) via submap ---
hl.bind(mainMod .. " + SHIFT + M", function()
    hl.dispatch(hl.dsp.exec_cmd([[notify-send -u low -t 2500 "Send Mode" "Mod+0-9 to send window, Escape to exit"]]))
    hl.dispatch(hl.dsp.submap("send"))
end)

hl.define_submap("send", function()
    for i = 1, 9 do
        hl.bind(mainMod .. " + " .. i, hl.dsp.window.move({ workspace = i, follow = true }))
    end
    hl.bind(mainMod .. " + 0", hl.dsp.window.move({ workspace = 10, follow = true }))

    local function leave()
        hl.dispatch(hl.dsp.exec_cmd([[notify-send -u low -t 2500 "Send Mode" "Exited"]]))
        hl.dispatch(hl.dsp.submap("reset"))
    end
    hl.bind("Return", leave)
    hl.bind("Escape", leave)
    hl.bind(mainMod .. " + SHIFT + M", leave)
end)

-- --- Screen capture ---
-- Replace scrot with grim/slurp on Wayland (scrot is X11).
hl.bind(mainMod .. " + SHIFT + S",
    hl.dsp.exec_cmd(
        [[grim -g "$(slurp)" - | tee ~/Screenshots/screenshot_$(date +'%Y-%m-%d_%H-%M-%S').png | wl-copy -t image/png]]))
hl.bind("ALT + G",
    hl.dsp.exec_cmd([[grim - | tee ~/Screenshots/screenshot_$(date +'%Y-%m-%d_%H-%M-%S').png | wl-copy -t image/png]]))
hl.bind(mainMod .. " + G", hl.dsp.exec_cmd("~/.config/scripts/gif_record_start"))
hl.bind(mainMod .. " + SHIFT + G", hl.dsp.exec_cmd("~/.config/scripts/gif_record_stop"))

-- --- Volume / brightness keys ---
local el = { locked = true, repeating = true }
hl.bind("XF86AudioRaiseVolume", hl.dsp.exec_cmd("~/.config/scripts/volume-ctl raise"), el)
hl.bind("XF86AudioLowerVolume", hl.dsp.exec_cmd("~/.config/scripts/volume-ctl lower"), el)
hl.bind("XF86AudioMute", hl.dsp.exec_cmd("~/.config/scripts/volume-ctl mute"), el)
hl.bind("XF86AudioMicMute", hl.dsp.exec_cmd("~/.config/scripts/volume-ctl mic-mute"), el)
hl.bind("XF86MonBrightnessUp", hl.dsp.exec_cmd("~/.config/scripts/brightness up"), el)
hl.bind("XF86MonBrightnessDown", hl.dsp.exec_cmd("~/.config/scripts/brightness down"), el)


--------------------------------
---- WINDOWS AND WORKSPACES ----
--------------------------------
-- See https://wiki.hypr.land/Configuring/Basics/Window-Rules/

-- Ignore maximize requests from apps. You'll probably like this.
hl.window_rule({
    name = "suppress-maximize-events",
    match = { class = ".*" },
    suppress_event = "maximize",
})

-- Fix some dragging issues with XWayland
hl.window_rule({
    name = "fix-xwayland-drags",
    match = {
        class = "^$",
        title = "^$",
        xwayland = true,
        float = true,
        fullscreen = false,
        pin = false,
    },
    no_focus = true,
})

-- Encode fullscreen state in border color (dynamic -- re-evaluated by Hyprland on state change)
hl.window_rule({
    name = "fullscreen-border-color",
    match = { fullscreen = true },
    border_color = { colors = { "rgba(669988aa)", "rgba(99ccffaa)" }, angle = 45 },
})
