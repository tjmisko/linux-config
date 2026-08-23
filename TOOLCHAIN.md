# Toolchain and minimal Linux reproduction

This is an audit of the current `linux-config` worktree, not a claim that every
tracked feature is required on every machine. The repository is a collection of
GNU Stow packages with one shared base and mutually exclusive desktop profiles.
The smallest useful installation is `common`; a desktop adds `gui` and exactly
one of `x11` or `wayland`. `laptop` is a hardware-specific add-on.

The audit was made on 2026-08-23 from branch `fix/x11-machine-config`. It covers
tracked files plus the current uncommitted worktree, including the current
`.bashrc` Rust environment line and the current Tree-sitter build hook. Package
versions, Neovim plugins, AppImages, private tools, and systemd enablement are
not locked by this repository, so this guide reproduces the shape and behavior
of the setup rather than a bit-for-bit machine image.

## Profile map

| Goal | Stow packages | What it supplies |
|---|---|---|
| Headless shell/editor | `common` | Bash, Neovim, Git helpers, CLI scripts, btop/newsboat/ytfzf config |
| Shared GUI layer | `common gui` | WezTerm, rofi, zathura, MIME handlers, desktop entries, Switchboard user units |
| X11 desktop | `common gui x11` | i3, Polybar, Picom, Dunst, X init |
| X11 laptop | `common gui laptop x11` | X11 plus battery/backlight user units |
| Wayland desktop | `common gui wayland` | Hyprland, Waybar, Mako, fcitx5, swayidle |
| Wayland laptop | `common gui laptop wayland` | Wayland plus battery/backlight user units |

Do not install both `x11` and `wayland` into the same home without reviewing
their application/session behavior. Their files mostly do not collide, but the
result is no longer a minimal profile and several scripts select behavior from
the live session.

## Supported baseline

The scripts target a conventional GNU/Linux userspace, not a minimal BusyBox
system. They use Bash arrays and case conversion, GNU `date -d`, `find -printf`,
`sort -V`, `sed -i`, `/proc`, systemd user units, and standard Linux filesystem
paths. The practical floor is:

- Bash 4.3 or newer. Bash 5 is the reference environment.
- Git and GNU Stow.
- GNU coreutils, findutils, grep, sed, gawk, util-linux, procps, and psmisc.
- A normal user home under `/home`. A different username requires the path
  changes described under **Portability blockers**.
- systemd for the supplied user services. The shell/editor profile itself does
  not need systemd.
- Network access on Neovim's first run so `lazy.nvim`, plugins, parsers, and
  Mason packages can be fetched.

Alpine, embedded distributions, non-systemd distributions, and immutable
systems can use parts of the repository, but are ports rather than direct
installs.

## Minimal `common` installation

### Required tools

| Capability | Commands/packages | Why it is needed |
|---|---|---|
| Deployment | `git`, `stow` | Clone the repository and link a selected package into `$HOME` |
| Shell | `bash >= 4.3` | `.bashrc` and most scripts use Bash-only syntax |
| Editor | `nvim >= 0.12` | The config tracks the rewritten `nvim-treesitter` `main` branch |
| Parser builds | `tree-sitter >= 0.26.1`, a C compiler, `make`, `curl`, `tar` | The current Tree-sitter plugin build installs the configured parsers; Telescope's native fzf extension also runs `make` |
| Plugin/LSP downloads | `git`, `curl` or `wget`, `unzip`, `gzip`, GNU `tar` | `lazy.nvim` and Mason bootstrap from the network |
| Configured LSPs | `node`, `npm`, `go` | Mason installs Pyright and the TypeScript/HTML/CSS/Emmet servers through Node tooling and `gopls` through Go |
| Daily CLI use | `rg`, `fd`, `fzf`, `bat`, `less`, `jq` | Directly called by shell functions, Neovim, and scripts |

The upstream requirements are useful checks: [nvim-treesitter `main`](https://github.com/nvim-treesitter/nvim-treesitter#requirements)
requires Neovim 0.12, Tree-sitter CLI 0.26.1, `curl`, `tar`, and a C compiler;
[Mason](https://github.com/mason-org/mason.nvim#requirements) additionally
expects archive tools and shells out to language package managers such as
`npm`, `go`, and `cargo` when a selected package needs them.

On the Arch reference environment, the base can be installed with:

```sh
sudo pacman -S --needed \
  bash git stow base-devel neovim tree-sitter-cli \
  curl wget tar gzip unzip ripgrep fd fzf bat jq less \
  nodejs npm go
```

On Debian/Ubuntu or Fedora, install the packages exposing the same command
names. Two compatibility traps are common:

- Debian-family packages may expose `fdfind` instead of `fd` and `batcat`
  instead of `bat`. Add user-local wrappers or symlinks named `fd` and `bat`.
- A distribution's stable Neovim or Tree-sitter CLI may be below the required
  versions. Use current upstream binaries/packages when `nvim --version` is
  below 0.12 or `tree-sitter --version` is below 0.26.1. Do not install the
  Tree-sitter CLI from npm; the plugin's upstream instructions explicitly call
  for a system package.

### Install and bootstrap

```sh
git clone <repo-url> "$HOME/linux-config"
cd "$HOME/linux-config"

stow -n -v -t "$HOME" common
stow -t "$HOME" common

git config --global core.excludesfile "$HOME/.gitignore_global"
nvim
```

The first Neovim run clones `lazy.nvim`; `:Lazy sync` installs plugins and runs
their build hooks. Follow it with `:checkhealth mason` and `:checkhealth
nvim-treesitter`.

There is no `lazy-lock.json`, so plugin revisions are not pinned. A future first
install may differ from the audited machine even when the dotfiles commit is
identical.

### Rust is currently a shell requirement

The worktree version of `.bashrc` ends with an unconditional:

```sh
. "$HOME/.cargo/env"
```

Therefore a truly clean `common` install prints an error whenever that file is
absent. `.bash_profile` already has a guarded Rust source line, so the robust
choices are either to install Rust with `rustup` (which creates the file), or to
make the final `.bashrc` source conditional. Until that is changed, include a
Rustup installation in an exact reproduction.

Rust is otherwise optional for the base editor. It becomes required for the
Arachne and Zettel project integrations described below.

## Shared GUI layer

`gui` assumes these applications or interfaces:

| Feature | Requirement |
|---|---|
| Terminal | WezTerm |
| Launcher and prompts | rofi |
| Browser | Firefox, or edit the absolute browser references |
| Documents | zathura plus a PDF backend; `zathura-pdf-mupdf` on Arch |
| Direct PDF preview | MuPDF's `mupdf` command |
| Images/backgrounds | `feh` |
| Desktop integration | `xdg-utils`, GLib's `gio`, `desktop-file-utils`, a D-Bus session |
| Notifications | `notify-send` from libnotify plus the session daemon (Dunst or Mako) |
| JSON helpers | `jq`, `less` |
| Notes application | Obsidian, installed as a package, extracted AppImage, or AppImage |

An Arch installation for the shared layer is approximately:

```sh
sudo pacman -S --needed \
  wezterm rofi firefox feh zathura zathura-pdf-mupdf mupdf \
  libnotify xdg-utils desktop-file-utils glib2 jq
```

Fonts are not fatal—fontconfig substitutes—but the intended appearance uses
`DejaVu Sans Mono` in i3, `JetBrainsMono Nerd Font` in rofi, and `Fira Mono` in
Mako. The audited X11 host has DejaVu and ordinary JetBrains Mono, but not the
named Nerd Font or Fira Mono, so those two currently fall back to Noto Sans
Mono. Install `ttf-dejavu`, `ttf-jetbrains-mono-nerd`, and `ttf-fira-mono` on
Arch for the exact requested faces and prompt/icon glyphs.

## X11/i3 profile

### Session requirements

```sh
sudo pacman -S --needed \
  xorg-server xorg-xinit xorg-xrdb xorg-xset xorg-xsetroot \
  i3-wm polybar picom dunst rofi wezterm firefox feh \
  scrot xclip libnotify xdg-utils \
  wireplumber libpulse
```

The session starts from `.bash_profile` only when a matching host file exports
`AUTOSTART_SESSION=startx`; an empty value leaves the user at the console. X11
startup loads `.Xresources`, `.fehbg`, Picom, Dunst, `clipmenud`, and i3. The
first two files are not in the repository; `.fehbg` is normally generated by
`feh --bg-*`.

Feature-specific X11 tools:

- `scrot` + `xclip`: required by the screenshot bindings.
- `clipmenu`/`clipmenud`: clipboard history. The Arch package also installs its
  dmenu/xsel/clipnotify/xdotool dependencies.
- `pactl` or `wpctl`: volume control; the script prefers `wpctl`.
- `ibus`: only for the configured input-method restart binding.
- `mutt` and `newsboat`: only for their application bindings.
- `xborders`: optional rounded borders. It is not in the enabled official Arch
  repositories on the audited host and is currently missing. The configured
  binary must support `--border-width`, `--border-radius`, `--border-mode`, and
  `--border-rgba`; those flags are not a stable interface shared by every
  similarly named border utility.

Two X11 references are not satisfiable merely by installing the obvious
package:

- i3 calls `dex-autostart`, but the upstream/Arch `dex` package installs the
  `dex` command. The equivalent invocation is `dex -a -e i3`; as written, XDG
  autostart is skipped.
- `i3status` has a tracked config, but i3 starts Polybar and has no i3bar
  `status_command`. `i3status` is therefore not part of the active minimal
  session.

## Wayland/Hyprland profile

The config is a Lua `hyprland.lua` and needs Hyprland 0.55 or newer. It was
successfully parsed with `Hyprland --verify-config` on 0.56.2 during this audit.
Hyprland's current documentation confirms that Lua replaced the legacy
hyprlang configuration from 0.55 onward.

An Arch installation for the compositor-level features is approximately:

```sh
sudo pacman -S --needed \
  hyprland waybar mako grim slurp wl-clipboard cliphist \
  swaybg swayidle wireplumber libpulse \
  fcitx5 fcitx5-chinese-addons \
  xdg-desktop-portal xdg-desktop-portal-hyprland \
  dbus libnotify jq procps-ng psmisc
```

The session starts these components itself: the systemd graphical-session
target, Switchboard, Waybar, Mako, clipboard history, Swaybg, fcitx5, WezTerm,
Obsidian, and Firefox. Missing optional commands do not prevent Hyprland itself
from starting, but their autostart entries or bindings fail.

Wayland capture adds:

```sh
sudo pacman -S --needed wf-recorder ffmpeg gifsicle
```

`gif_record_start` hard-codes the FFmpeg encoder `libopenh264`. The official
FFmpeg build installed on the audited Arch host exposes `libx264` but not
`libopenh264`. Install an FFmpeg/OpenH264 build that exposes that encoder or
change the script's codec; otherwise GIF recording fails before the conversion
step.

Hardware and session values that must be changed on a generic box:

- Monitor outputs are `eDP-1` and `HDMI-A-1`, with fixed workspace placement.
  Inspect `hyprctl monitors all` and edit the rules.
- The Waybar battery is `macsmc-battery`/`macsmc-ac` (Apple Silicon/Asahi).
- The wallpaper is a machine-local file under `~/Photos/Wallpaper`.
- The autostarted Obsidian command pins
  `/home/tjmisko/AppImages/Obsidian-1.12.4.AppImage`, bypassing the otherwise
  portable `~/.config/scripts/obsidian` launcher.
- The top bar calls `~/Tools/Tasks/task timer` every second. Without that
  private binary the module continually fails and logs errors.

## Script dependency inventory

The repository puts `.config/scripts` on `PATH`. Many files define shell
functions and are sourced by `.bashrc`; others are standalone executables.

| Scripts/features | External requirements |
|---|---|
| `background` | `feh`, `fd`, `fzf` |
| `bcon`/`bdcon` | `bluetoothctl` (BlueZ), `fzf`, `pactl` for the hard-coded A2DP device |
| `context` | Neovim, `xclip`, GNU coreutils; X11 clipboard access even when invoked from a Wayland shell |
| `gcfzf`, `gsw`, Git prompt | Git, `fzf`, `xclip` for copying the commit reference |
| `gh*` | GitHub CLI `gh`, authenticated separately, plus `fzf` |
| `harpoon_files` | Neovim with Harpoon installed, `fzf` |
| `hist`/`freq` | `gawk`; `hist` additionally needs the Python `termgraph` package |
| `weather` | `curl`, `less`, network access to `wttr.in` |
| `music`/`video` | `fzf`, `fd`, `mpv`, populated media directories |
| `obsidian` | A packaged or executable AppImage Obsidian install |
| `htmlview` | Optional machine-local WebKitGTK viewer; otherwise Firefox, Chromium, or Brave |
| `readings` | `fd`, `fzf`/rofi/wofi, zathura, WezTerm, Neovim, `setsid`, HTML viewer/browser |
| `newsboat-bookmark` | Newsboat and one of the untracked `~/Tools/Newsboat/source_note*` helpers |
| Newsboat video macro / ytfzf | `yt-dlp`, `mpv`; `ytfzf` if that config is used |
| `remind` | `at`, a running `atd`, and `notify-send` in the job environment |
| `screenshot` | X11 `scrot`, `xclip`; notification is best-effort |
| `gif_record_*` | Hyprland, `hyprctl`, `jq`, `wf-recorder`, FFmpeg with the chosen H.264 encoder, `gifsicle`, rofi, `wl-copy`, `notify-send` |
| `hypr-float-center` | Hyprland Lua IPC, `hyprctl`, `jq`, `pgrep`, Waybar, WezTerm or Foot; Switchboard is optional for the bar reconciliation step |
| `volume-ctl` | `wpctl` (preferred) or `pactl`, plus `awk`; the matching audio daemon |
| `brightness` | Apple/Asahi `/sys/class/backlight/apple-panel-bl`, or a rewrite for the target device |
| `annotate` | rofi, zathura, WezTerm, Neovim, and specific note templates/directories |
| `daily`, `notes`, `retend`, `sch` | Neovim, GNU `date`, `sed`, `cp`, `rg`, `fd`, `fzf`, and the untracked Notes vault/template layout |
| `tasks`, `tasks-open`, `task_timer` | A machine-local task CLI named `task` or `tasks`, plus Neovim and `rg` |
| `claude-picker`, `claude-abbrev-edit` | Claude Code, Switchboard binaries, rofi; notifications are best-effort |
| `date_range_regex.py` | Python 3.12 or newer because it uses modern nested f-string parsing; currently no tracked caller |
| `makebins.awk`, `tab`, `duntil` | GNU awk/coreutils; `duntil` relies on GNU `date --date` |

`batt` is an empty tracked file. `claude-name-wrapper.sh` defines an optional
wrapper but is not currently sourced by `.bashrc`. The old Neofetch config is
also not used by the `neofetch="fastfetch"` alias because Fastfetch has its own
configuration format.

### Notes/task stack

The note and task workflows are not reproducible from this repository alone.
They assume a private vault and templates at paths such as:

```text
~/Notes/daily
~/Notes/retend
~/Notes/schedule
~/Notes/templates/{daily.md,atomic.md,template.retend}
~/Documents/Notes
```

The exact split is currently inconsistent: most tracked scripts use `~/Notes`,
while the machine-local Newsboat and task wrappers use `~/Documents/Notes`.
Choose one vault layout and update the paths before expecting those workflows
to operate on a new box.

`taskbuffer.nvim` also needs a compiled Go helper. Its upstream README requires
Go and recommends this Lazy build hook:

```lua
build = "cd go && go build -o task_bin ."
```

The tracked plugin spec does not include that hook. On a fresh host, build it
manually after Lazy installs the plugin:

```sh
cd "$HOME/.local/share/nvim/lazy/taskbuffer.nvim/go"
go build -o task_bin .
```

The current X11 machine's `~/Tools/Tasks/tasks` wrapper directly invokes that
generated binary, so copying only the wrapper is not enough.

## Custom projects and binaries

These integrations are first-class in the GUI configs but are not installed by
Stow.

### Switchboard

The daemon, CLI, TUI, and Waybar renderer come from
[`tjmisko/switchboard`](https://github.com/tjmisko/switchboard) and require Go
1.25 or newer:

```sh
git clone https://github.com/tjmisko/switchboard "$HOME/Projects/switchboard"
cd "$HOME/Projects/switchboard"
go install ./cmd/...
```

The dashboard and Arachne provider tools come from
[`tjmisko/switchboard-dashboard`](https://github.com/tjmisko/switchboard-dashboard),
also with Go 1.25 or newer:

```sh
git clone https://github.com/tjmisko/switchboard-dashboard "$HOME/Projects/switchboard-dashboard"
cd "$HOME/Projects/switchboard-dashboard"
go install . ./cmd/arachne-switchboard-recorder ./cmd/arachne-switchboard-ctl
```

The configs expect these names in `~/go/bin`:

```text
switchboard
switchboard-ctl
switchboard-waybar
switchboard-dashboard
arachne-switchboard-recorder
arachne-switchboard-ctl
```

`arachne-switchboard-recorder` additionally requires the Docker CLI, access to
a running Docker daemon, and Arachne containers. The dashboard needs
Switchboard history enabled; merged mode also needs the Arachne recorder and
provider CLI. These are optional integrations, not requirements for a minimal
desktop.

### Other machine-local integrations

The following are referenced but absent from the repository. Copy, rebuild,
replace, or remove their keybindings:

- `~/Tools/Tasks/task` or `~/Tools/Tasks/tasks`
- `~/Tools/cal_exec`
- `~/Tools/geonote/geonote`
- `~/Tools/omnisearch`
- `~/Tools/Bookmarks/marks`
- `~/Tools/Newsboat/source_note{,_i3,_hyprland}` and `video_download`
- optional sourced helpers `~/Tools/mp3ify` and `~/Tools/Chinese/{stroke,vocab}`
- `~/Resume/build` and `~/Resume/bin/resume-pick`
- the Rust Zettel CLI under `~/Projects/Zettel-LLM/.../target/release/zettel`
- `~/.local/bin/htmlview` (optional browser fallback exists)
- `~/.local/bin/battery-notify` (no fallback exists)

The `.bashrc` `src` helper makes the optional sourced files harmless when
missing. Keybindings and systemd units that execute an absent file do fail.

## Systemd user units

Stow installs unit files but does not enable them. The repository deliberately
ignores `default.target.wants` and `timers.target.wants`, so enablement is
machine state and must be recreated explicitly.

| Unit | Enable only when... | Runtime requirements |
|---|---|---|
| `switchboard.service` | Claude/Codex session tracking is wanted | `~/go/bin/switchboard`; Hyprland/WezTerm only for navigation tier |
| `switchboard-dashboard.service` | Local dashboard is wanted | dashboard + `switchboard-ctl`; provider config also needs Arachne CLI |
| `arachne-switchboard-recorder.service` | Arachne Docker sessions are running | recorder binary, Docker CLI/daemon/socket access |
| `swayidle.service` | Running the Wayland profile | `swayidle`, `switchboard-ctl`, imported Wayland environment |
| `backlight-floor.service` | Target really exposes `apple-panel-bl` and the user can write it | brightness script and suitable sysfs permissions |
| `battery-notify.timer` | A `~/.local/bin/battery-notify` implementation was supplied | that untracked executable and notifications |
| `arachne-disk-guard.timer` | Arachne exists at `~/Projects/Arachne` | Bash login environment, Rust/Cargo, repository script |

For selected units only:

```sh
systemctl --user daemon-reload
systemctl --user enable --now <chosen-unit>
```

Do not bulk-enable every tracked unit. In particular, the backlight unit is
Apple/Asahi-specific and its `sudo tee` fallback cannot obtain an interactive
password from a user service; arrange non-root sysfs write access or replace
the implementation.

## Portability blockers and current audit findings

These are the main differences between “clone and stow” and a reproducible
machine.

1. **The username is embedded.** There are 40 `/home/tjmisko` occurrences
   across 21 configuration files, including Hyprland, Waybar, i3, rofi,
   zathura, desktop entries, providers, and scripts. On another username, run
   `git grep -n /home/tjmisko -- common gui laptop wayland x11` and replace
   each executable/data path with the new home. Use `%h` in systemd units and
   `os.getenv("HOME")` in Lua where possible; desktop `Exec=` lines do not
   perform shell `$HOME` expansion.
2. **Private data and tools are intentionally excluded.** `~/Tools`, the Notes
   vault, Newsboat URLs, backgrounds/wallpaper, Obsidian state, GitHub/Claude
   authentication, secrets, and generated application state are not a part of
   the repository.
3. **Plugin and package versions are unpinned.** There is no Lazy lockfile and
   no OS package manifest. A clean install follows current plugin branches and
   current distribution packages.
4. **The laptop profile is not generic.** `brightness` is hard-coded to an
   Apple panel and the Waybar battery names are Asahi-specific.
5. **The Wayland Obsidian path bypasses the portable launcher.** The exact
   AppImage named in `hyprland.lua` was absent on the audited X11 host, although
   an extracted Obsidian install existed.
6. **The configured GIF codec is absent from the audited Arch FFmpeg build.**
   `libx264` is present; `libopenh264` is not.
7. **The X11 XDG-autostart command is wrong for upstream `dex`.** Install `dex`
   and change the command to `dex -a -e i3`, or remove it.
8. **The task plugin build is not automated.** Add the upstream build hook or
   run the Go build manually after a fresh Lazy install.
9. **Some tracked references have no implementation.** The `battery-notify`
   executable and the GitHub alias target `gh_issue_worktree_develop` are not
   tracked; `xborders` is also absent from the reference host.
10. **The JSON MIME handler is not a valid desktop entry.**
    `desktop-file-validate` rejects `json-terminal.desktop` because the `Exec=`
    line uses shell single quotes, `$1`, and a pipe in a form the desktop-entry
    grammar does not accept. JSON files cannot reliably launch through that
    association until the command is moved into a wrapper or correctly escaped.
11. **The current reference host is not a complete Wayland testbed.** Its active
    links are `common + gui + laptop + x11`, while many Wayland packages are
    absent. Hyprland 0.56.2 parses the Lua config successfully, but compositor
    startup and every Wayland integration still need verification on GooseBook.

Also note these lower-impact script issues when deciding whether to preserve or
trim features: `annotate` tests the misspelled variable `ANNOTE_TITLE`; the
one-argument path in `duntil` uses `date +s` instead of a timestamp; and the
current host lacks `at`, `termgraph`, `mpv`, and `dict`, so those commands are
present in the shell but not operational there.

### Validation performed

The audit used non-mutating checks against the current worktree:

- `bash -n` passed for `.bashrc`, `.bash_profile`, every non-empty tracked shell
  script, and the Waybar language helper.
- The AWK helper parsed successfully.
- Hyprland 0.56.2 reported `config ok` for `hyprland.lua`.
- A Stow simulation for `common gui laptop x11` was clean on the active host.
- `systemd-analyze --user verify` parsed the units and reported the expected
  missing local `battery-notify` and absent Wayland `swayidle` executable.
- `desktop-file-validate` produced only category hints except for the invalid
  `json-terminal.desktop` command described above.

Live Wayland startup, application keybindings, private vault workflows, and a
fresh Neovim network bootstrap were not executed by this static audit.

## Reproduction sequence

1. Install the `common` baseline and required version floors.
2. Clone to `~/linux-config` and adapt all `/home/tjmisko` paths if the username
   differs.
3. Create `common/.config/hosts/<lowercase-hostname>.env`. Set
   `AUTOSTART_SESSION` to empty until the intended desktop has been tested.
4. Dry-run and then Stow `common`.
5. Start Neovim, run `:Lazy sync`, build the taskbuffer helper if desired, and
   run the Mason and Tree-sitter health checks.
6. Install `gui` plus exactly one display profile and its package set. Provide
   monitor, battery, wallpaper, and Obsidian values for that machine.
7. Dry-run and Stow the selected profile, for example:

   ```sh
   stow -n -v -t "$HOME" common gui wayland
   stow -t "$HOME" common gui wayland
   ```

8. Install only the custom projects used on that host. Copy no authentication
   or secret material through the dotfiles repository.
9. Run `systemctl --user daemon-reload`, then enable only selected user units.
10. Log out and back in so the host environment and desktop inherit the new
    values.

Final checks:

```sh
bash -lc 'true'
stow -n -v -t "$HOME" common gui wayland   # substitute x11/headless profile
git config --global --get core.excludesfile
nvim --version | head -1
tree-sitter --version
command -v rg fd fzf bat node npm go
Hyprland --verify-config --config "$HOME/.config/hypr/hyprland.lua"  # Wayland only
systemctl --user --failed                                           # systemd only
```

A quiet Bash check, an empty Stow dry run, a successful Neovim health check,
and no failed selected units are the practical definition of a reproducible
minimal install for this repository.
