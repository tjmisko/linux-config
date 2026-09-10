# Migrating an existing machine to stow

These dotfiles used to sit at the repo root (`.config/`, `.bashrc`, `.xinitrc`)
and were deployed by hand-made symlinks. They now live in stow packages
(`common/`, `gui/`, `laptop/`, `x11/`, `wayland/`) and are deployed with
`stow`. Every tracked file moved, so **the moment a machine pulls, its existing
symlinks point at paths that no longer exist.**

This guide is written for GooseBook (Wayland / Hyprland), but the only
GooseBook-specific part is the package list in step 6 — an X11 machine
substitutes `x11` for `wayland`, a server uses `common` alone.

## Before you start

Your running session is safe. Hyprland, waybar and wezterm read their configs
into memory at startup, so moving files on disk does not disturb them until
something reloads. But a **logout, a reload, or a new terminal will pick up the
half-migrated state**, so do this when you can afford to log out at the end
rather than in the middle of something.

Install stow first:

```sh
sudo pacman -S --needed stow
```

Stow's only dependency is perl, which git already pulls in, so this is free on
any machine that can clone this repo.

## 1. Check the hostname first

This is the one step that silently changes behaviour if you skip it. Per-host
settings are loaded from `.config/hosts/<hostname>.env`, lowercased:

```sh
echo "${HOSTNAME,,}"
```

It must print exactly `goosebook`. If it prints something else, rename the file
to match before continuing:

```sh
git mv common/.config/hosts/goosebook.env "common/.config/hosts/$(echo "${HOSTNAME,,}").env"
```

If the name does not match, `AUTOSTART_SESSION` never gets set and **Hyprland
stops starting automatically on a tty1 login**. That failure is recoverable —
you land at a shell and `start-hyprland` still works by hand — but it is
confusing if you are not expecting it.

While you are in that file, confirm the values were guessed correctly. They
were written from this repo's history, not read off GooseBook:

```sh
cat common/.config/hosts/goosebook.env
ls /sys/class/power_supply/          # confirm the battery/adapter names
```

## 2. Record the current state

Cheap insurance, and it makes the rollback in the last section possible:

```sh
find ~ -maxdepth 1 -type l -printf '%p -> %l\n'          >| ~/pre-stow-symlinks.txt
find ~/.config ~/.local/bin ~/.local/share ~/Tools -maxdepth 2 -type l \
    -printf '%p -> %l\n'                                >> ~/pre-stow-symlinks.txt
git -C ~/linux-config rev-parse HEAD                     >| ~/pre-stow-commit.txt
```

`~/.local/bin`, `~/.local/share/thumbnailers` and `~/Tools` are in that list
because the repo reaches outside `.config` in three places now -- the
thumbnailer shims, the `.thumbnailer` entries that exec them, and
`Tools/omnisearch`. A migration written against `.config` alone will walk past
all three.

Anything you have not committed is about to become very hard to find, because
every tracked file moves. Check before you pull:

```sh
git -C ~/linux-config status --short
git -C ~/linux-config log --oneline @{upstream}..HEAD    # unpushed commits
```

## 3. Pull

```sh
cd ~/linux-config
git fetch origin
git switch <the branch carrying the stow layout>
```

Use `--ff-only` if you are pulling into a branch you already track. The repo
root should now contain only `common`, `gui`, `laptop`, `wayland`, `x11`,
`README.md`, `MIGRATION.md` and `TOOLCHAIN.md`. From this point your old
symlinks are dangling — expected, and fixed by step 6.

## 4. Find what the old deployment left behind

Stow will tell you itself. This changes nothing:

```sh
stow -n -v -t ~ common gui laptop wayland host-goosebook
```

Two kinds of complaint come back, and they need different fixes:

**`existing target is not owned by stow: .config/hypr`** — an old hand-made
directory symlink. It is now dangling and simply needs removing. List them all:

```sh
find ~ -maxdepth 1 -xtype l
find ~/.config ~/.local/bin ~/.local/share ~/Tools -maxdepth 3 -xtype l
```

Every one of those pointing into `~/linux-config` is safe to delete: it is a
symlink, so removing it cannot touch any real content.

**`cannot stow ... over existing target X since neither a link nor a
directory`** — a real file sitting where a link should go. These need judgement,
because a real file may hold changes that never made it into the repo.

## 5. Resolve the real files

For each one, compare it against what the repo would install before deleting
anything. Substitute the path stow named:

```sh
f=.bashrc                                  # the path stow complained about
diff ~/"$f" ~/linux-config/common/"$f"     # or gui/, laptop/, wayland/
```

Read the diff in the direction that matters: **lines present only in your home
copy are the ones at risk.** This is not hypothetical — on the X11 machine this
check found `$HOME/go/bin` on `PATH`, which existed only in the un-symlinked
`~/.bashrc` and holds the `switchboard-ctl` binaries the switchboard units
invoke. It would have been silently lost.

```sh
grep -vxF -f ~/linux-config/common/"$f" ~/"$f" | grep -vE '^\s*(#|$)'
```

If that prints nothing, the repo version is a superset and the file is safe to
remove. If it prints something you want, fold it into the repo file and commit
it *before* continuing.

Then move the strays aside rather than deleting them:

```sh
mkdir -p ~/pre-stow-backup
mv ~/"$f" ~/pre-stow-backup/
```

Re-run `stow -n -v -t ~ common gui laptop wayland host-goosebook` until it reports nothing.

## 6. Stow

```sh
cd ~/linux-config
stow -t ~ common gui laptop wayland host-goosebook
```

If `.bashrc` is among the files you moved aside, there is a brief window with no
shell config. Chain the move and the stow into one command so the window is
momentary rather than however long you get distracted for.

## 7. Reload systemd

Enablement survives the migration — the symlinks in `default.target.wants/`
point at `~/.config/systemd/user/<unit>`, which stow recreates, rather than at
the repo path. But systemd cached the old resolution, so tell it to look again:

```sh
systemctl --user daemon-reload
systemctl --user list-unit-files --state=enabled | grep -E 'switchboard|swayidle|backlight|battery'
```

Any unit showing as `bad` or `not-found` means its symlink did not get
recreated — re-run the stow command and check for conflicts.

## 8. Verify

```sh
bash -lc 'true'          # must print nothing at all
echo "${AUTOSTART_SESSION}"   # must print: hyprland
stow -n -v -t ~ common gui laptop wayland host-goosebook   # must print nothing: idempotent
find ~/.config ~/.local/bin ~/.local/share ~/Tools -maxdepth 3 -xtype l
```

That last one must find no dangling links. Then check a few resolve where you
expect — one per package, including the three that land outside `.config`:

```sh
readlink -f ~/.config/hypr ~/.config/waybar ~/.config/scripts ~/.bashrc \
           ~/.local/bin/thumb-image ~/.local/share/thumbnailers ~/Tools/omnisearch
```

Then confirm the two pickers actually draw, since they are the only things here
with a dependency chain that fails silently:

```sh
shots        # rows carry thumbnails; blank rows mean magick/ffmpeg is missing
omnisearch -f rofi
```

## 9. Log out and back in

Two things only take effect in a session started *after* the migration, because
they are environment variables exported by the login shell:

- `WEZTERM_FONT_SIZE` — until you re-login, wezterm windows launched from a
  Hyprland keybinding inherit the old environment and use the fallback size.
- `AUTOSTART_SESSION` — this is what makes Hyprland start on tty1.

## Rollback

Nothing here is one-way. To back out:

```sh
cd ~/linux-config
stow -D -t ~ common gui laptop wayland host-goosebook     # remove every symlink stow made
cp -a ~/pre-stow-backup/. ~/                # restore the files you moved aside
git switch --detach "$(cat ~/pre-stow-commit.txt)"
```

Then recreate the old symlinks from `~/pre-stow-symlinks.txt`.

## Gotchas worth knowing

**`hostname(1)` is not installed on a base Arch system.** It lives in
`inetutils`. `.bashrc` uses bash's own `$HOSTNAME` for exactly this reason —
do not "fix" it back to `hostname -s`.

**`~/Tools` is gitignored except for one file.** It is otherwise machine-local
and the two laptops genuinely diverge; `tasks-open` and `obsidian` detect what
the host has rather than hardcoding a path, and anything else you add there
should follow that pattern. The exception is `omnisearch`, a plain script both
window managers bind, which lives at `gui/Tools/omnisearch` and is re-included
by a `!**/Tools/omnisearch` negation. Since `~/Tools` already exists as a real
directory on both laptops, stow folds a single file link into it rather than
replacing the directory -- but on a machine where `~/Tools` does *not* exist,
stow will symlink the whole directory to the package, and adding a real tool
later then means unfolding it by hand.

**btop rewrites its config on exit, so it is not tracked.** The `common`
package still owns the `.config/btop` *directory*, so btop's regenerated file
lands inside the repo checkout and `.gitignore` keeps it untracked. Expect
`git status` to stay clean and the file to keep changing; that is working
correctly, not drift.

**Anything that varies by session rather than by host belongs in a runtime
check, not a host file** — GooseBook can boot either session, so a checkout
cannot know which one you are in. See `.config/scripts/newsboat-bookmark`.

**Stow refuses rather than clobbers.** A conflict is the tool working
correctly. Never reach for `--adopt` to silence one: it moves your existing
file *into* the repo, overwriting the version there, which is the opposite of
what you want when the repo version is the newer one.

**Programs that watch their config file keep watching the old inode.** Hyprland
reloaded the instant step 6 deleted the real file, recorded "cannot open
hyprland.lua", and never noticed the symlink stow created a moment later, so
`hyprctl configerrors` kept showing a stale error. Run `hyprctl reload` (or
`i3-msg reload`) once after stowing; the logout in step 9 clears everything else.

**Stow only owns relative symlinks.** A hand-made *absolute* link into the repo
is reported as "Ignoring an absolute symlink" and then blocks the restow as a
conflict ("existing target is not owned by stow"), which aborts the whole run.
Delete such links by hand before stowing; stow recreates them as relative ones.
