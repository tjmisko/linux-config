# GooseBook cutover to the stow layout

Written from nlessfun on 2026-09-09, for whoever does this on GooseBook.
Delete this file once GooseBook is migrated and both machines track one branch.

Everything here about nlessfun was checked on the machine. **Nothing here about
GooseBook was** — nlessfun cannot see it. The GooseBook-side facts in "Gather
first" are gaps, not details, and guessing at them is how this goes wrong.

## What happened

The two machines forked at `30118e4` on 2026-08-20 and ran a fortnight apart:

- **nlessfun** restructured the repo into stow packages and stayed on
  `fix/x11-machine-config` (39 commits).
- **GooseBook** kept working on the old root layout and pushed to `main` (10
  commits): the rofi picker restyle, `shots`, `readings` ctrl-y, `omnisearch`,
  XDG thumbnailers, waybar pills, and the hypr launcher rebind.

`origin/main` is still the **old root layout**. Do not treat it as canonical.

## The branch

`merge/goosebook-sync` carries both lines merged, plus fixes and docs. Its
merge commit explains the four resolutions git could not make on its own; the
one worth knowing up front is that git staged five of GooseBook's new files at
the **repo root**, without flagging a conflict, where the `/*` ignore rule
means they would have been tracked and deployed nowhere. They now live in `gui`.

Nothing has been merged into `main`, and nothing on nlessfun has been restowed
yet — see "Then nlessfun" at the end.

## Gather first, before touching anything

The pull moves every tracked file, so anything not committed becomes very hard
to place afterwards. In order:

```sh
cd ~/linux-config
git status --short                  # you said there is uncommitted work on main
git log --oneline origin/main..main # and check for unpushed commits
```

Commit or stash that **before** the pull, and say what it was — if it overlaps
the ten commits already merged here, this branch may need a follow-up.

Then answer these four. Each one changes what the cutover does:

1. **How is `~/Tools` wired?** A real directory, or a symlink into the repo?
   Stow folds a single `omnisearch` link into a real directory, but if `~/Tools`
   is itself a link, that is a conflict to clear first.
2. **How are `~/.local/bin` and `~/.local/share/thumbnailers` wired?** Same
   question. The old layout tracked these at the repo root, so they may be
   hand-made links that are about to dangle.
3. **Is `~/.config/btop/btop.conf` a real file or a link?** It is untracked now
   and stays on disk either way, but a dangling link needs removing.
4. **Are the values in `common/.config/hosts/goosebook.env` right?** That file
   says outright that they were derived from repo history and never verified on
   GooseBook. Check `ls /sys/class/power_supply/` and confirm
   `echo "${HOSTNAME,,}"` prints exactly `goosebook` — if it does not,
   `AUTOSTART_SESSION` never gets set and Hyprland stops starting on tty1.

## Then run the migration

[MIGRATION.md](MIGRATION.md) is the procedure and has been updated for this
merge — it now sweeps `~/.local/bin`, `~/.local/share/thumbnailers` and
`~/Tools` alongside `~/.config`, which the older version did not. Follow it,
with two substitutions:

- Step 3 pulls `merge/goosebook-sync`, not `main`.
- Step 6 is `stow -t ~ common gui laptop wayland`.

The running Hyprland session survives all of this — configs are read into
memory at startup — but a reload or a new terminal picks up half-migrated
state, so do it when you can afford to log out at the end.

## Known-degraded, expected

- **`magick` is missing on nlessfun**, so image thumbnails are blank there
  until `imagemagick` is installed. Check GooseBook has it; `shots` and
  `omnisearch` lose image previews without it and fail no other way.
- **`readings --copy-link` used to be Wayland-only.** It now dispatches on
  session type, so it works under X11 too. Behaviour on GooseBook is unchanged.
- **`btop.conf` is no longer tracked.** Expect the file to keep changing inside
  the repo checkout while `git status` stays clean.

## Rollback

MIGRATION.md's rollback section still applies unchanged. Nothing here is
one-way, provided step 2's snapshot was actually taken.

## Then nlessfun

Once GooseBook is up, nlessfun still needs, in this order:

1. `git merge merge/goosebook-sync` into `fix/x11-machine-config`.
2. `stow -R -t ~ common gui laptop x11` — this also repairs two switchboard
   drop-ins that are absolute symlinks stow does not recognise as its own.
3. `sudo pacman -S --needed imagemagick`.
4. Confirm `$mod+space` works: nlessfun binds it to `~/Tools/omnisearch`, which
   has never existed there, so that key is dead today and this merge fixes it.

Then decide where `main` goes. It currently points at the old root layout and
is the only branch GooseBook has ever tracked, which is misleading enough that
it should not stay that way for long.
