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

**Done on GooseBook, 2026-09-09 22:33.** `main` now *is* the stow layout: it
was fast-forwarded to `merge/goosebook-sync` at `488761b` and pushed, and it
contains every commit of `fix/x11-machine-config`. GooseBook's home is stowed
from `~/linux-config` on `main`, and the old `~/.git` is gone. Only the
nlessfun half remains — see "Then nlessfun" at the end.

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

## GooseBook answers, checked on the machine 2026-09-09

The four questions above, plus the one thing nlessfun could not have guessed:

**`$HOME` is the git worktree on GooseBook.** `~/.git` is the repository and
every tracked file is a real file at its deployed path. There are no symlinks
anywhere -- not `~/Tools`, not `~/.local/bin`, not the thumbnailers, not
`btop.conf`. So MIGRATION.md steps 4 and 5 do not apply as written: there are
no dangling links to sweep, and *every* tracked file is a "real file sitting
where a link should go". The stow conflict list would be the whole manifest.

Two consequences:

- **Never `git switch merge/goosebook-sync` in `~`.** It would relocate every
  live config into package directories under `~/common`, `~/gui`, ... while the
  session is running. Branch work happens in
  `~/.worktrees/merge/goosebook-sync`; the deployed clone goes in
  `~/linux-config` (already created, empty).
- The "resolve the real files" step collapses to one fact: the files in `~`
  are byte-identical to what main tracks (`git status` is clean), and main is
  now merged here. Nothing in them is at risk. They can be removed wholesale
  from the list `git -C ~ ls-files` prints, then stowed back.

The other answers: hostname is `goosebook`; power supply devices are
`macsmc-battery` and `macsmc-ac`; `magick` is installed; the only uncommitted
file is `.config/systemd/user/codex-clipboard-adapter.service`, an empty mask
that stays on disk untracked.

Six files main tracks have no counterpart here and **stay on disk, untracked**,
so the removal step must skip them: the four base Switchboard units
(`switchboard`, `switchboard-dashboard`, `switchboard-waybar`,
`switchboard-waybar-publisher`), which the project's deploy script owns;
`.config/astro/config.json` (the CLI is not installed); and
`.config/agent-session-switcher/config.yaml` (dropped on nlessfun on purpose).
Two more, `.config/wofi/*`, are tracked again in `wayland`.

Ignored files living inside tracked directories stay put and are unaffected:
`hypr/.env` and `.secrets`, `nvim/lazy-lock.json` and the spell file,
`switchboard/bin/` and `history.json`, `btop.conf`, `newsboat/urls`, and the
systemd `*.wants/` directories. Stow unfolds a directory that already exists
into per-file links, so a real `~/.config/hypr` with a `.env` inside is the
expected end state, not a conflict.

## GooseBook procedure

In place of MIGRATION.md steps 3 to 6. Needs a logout at the end; the running
Hyprland session survives everything before that.

```sh
# 1. Snapshot: manifest, commit, and a copy of every tracked file.
git -C ~ ls-files                       >| ~/pre-stow-manifest.txt
git -C ~ rev-parse HEAD                 >| ~/pre-stow-commit.txt
mkdir -p ~/pre-stow-backup
rsync -a --files-from=$HOME/pre-stow-manifest.txt ~ ~/pre-stow-backup/

# 2. Deploy clone, on this branch.
git clone https://github.com/tjmisko/linux-config.git ~/linux-config
git -C ~/linux-config switch merge/goosebook-sync

# 3. Remove the tracked files from ~ and stow in the same command, so the
#    window with no .bashrc is momentary. The grep drops the six keepers.
cd ~/linux-config
grep -vE '^\.config/(systemd/user/switchboard[^/]*\.service$|astro/|agent-session-switcher/)' \
    ~/pre-stow-manifest.txt | sed "s#^#$HOME/#" | xargs rm -- \
  && stow -t ~ common gui laptop wayland host-goosebook

# 4. Remove directories the manifest emptied (deepest first; non-empty ones
#    are left alone), then restow so stow can fold what it now owns outright.
xargs -n1 dirname < ~/pre-stow-manifest.txt | sort -ur | sed "s#^#$HOME/#" \
  | xargs rmdir --ignore-fail-on-non-empty 2>/dev/null
stow -R -t ~ common gui laptop wayland host-goosebook
stow -n -v -t ~ common gui laptop wayland host-goosebook   # must print nothing

# 5. Retire the old repository. ~/.worktrees and ~/.gitignore go with it.
mv ~/.git ~/pre-stow-git
rm -rf ~/.worktrees
```

Then MIGRATION.md steps 7 to 9 apply unchanged: `daemon-reload`, confirm the
nine enabled units (`arachne-disk-guard.timer`,
`arachne-switchboard-recorder`, `backlight-floor`, `battery-notify.timer`,
`swayidle`, and the four Switchboard units) still resolve, verify, log out.

Rollback before step 5: `stow -D` the five packages, `rsync -a
~/pre-stow-backup/ ~/`. After step 5, also `mv ~/pre-stow-git ~/.git` first.

## Then run the migration

[MIGRATION.md](MIGRATION.md) is the procedure and has been updated for this
merge — it now sweeps `~/.local/bin`, `~/.local/share/thumbnailers` and
`~/Tools` alongside `~/.config`, which the older version did not. Follow it,
with two substitutions:

- Step 3 pulls `merge/goosebook-sync`, not `main`.
- Step 6 is `stow -t ~ common gui laptop wayland host-goosebook`.

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

`main` already contains `fix/x11-machine-config` in full, so there is nothing
to merge on nlessfun -- just move it onto `main`:

```sh
cd ~/linux-config
git status --short                 # commit or stash anything here first
git switch main
git pull --ff-only
stow -R -t ~ common gui laptop x11 host-nlessfun
sudo pacman -S --needed imagemagick
```

Two switchboard drop-ins on nlessfun are *absolute* symlinks into `gui/`,
which stow does not recognise as its own ("Ignoring an absolute symlink"), and
the restow aborts on them as conflicts. Remove them by hand first; they are
links, so nothing is lost, and the restow recreates them from `host-nlessfun`:

```sh
rm ~/.config/systemd/user/switchboard-dashboard.service.d/override.conf \
   ~/.config/systemd/user/switchboard.service.d/20-machine.conf
stow -R -t ~ common gui laptop x11 host-nlessfun
stow -n -v -t ~ common gui laptop x11 host-nlessfun   # must print nothing
systemctl --user daemon-reload
```

Then confirm `$mod+space` works: nlessfun
binds it to `~/Tools/omnisearch`, which has never existed there, so that key is
dead today and this merge fixes it.

One gotcha seen on GooseBook: a program that watches its config with inotify
(Hyprland does; i3 and polybar may) keeps watching the *old inode* after the
restow replaces the file, and reports the config as missing until reloaded by
hand. `i3-msg reload` / `hyprctl reload` clears it; a re-login clears the rest.

Once nlessfun is on `main` and restowed, delete this file, drop its
`!CUTOVER.md` line from `.gitignore`, and delete `fix/x11-machine-config` and
`merge/goosebook-sync` on origin.
