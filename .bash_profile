# .bash_profile

# Get the aliases and functions. This also loads .config/hosts/<host>.env,
# which is what sets AUTOSTART_SESSION below.
if [ -f ~/.bashrc ]; then
    . ~/.bashrc
fi

# Rust toolchain, when this host has one.
[ -r "$HOME/.cargo/env" ] && . "$HOME/.cargo/env"

# Start a graphical session on a tty1 console login, if this host opts in.
# Set AUTOSTART_SESSION in .config/hosts/<host>.env to hyprland or startx;
# leave it empty to land at a shell and start one by hand.
#
# The tty1 guard means an SSH login (/dev/pts/N) never triggers this, so
# servers are unaffected regardless of the setting.
if [[ -z $DISPLAY && -z $WAYLAND_DISPLAY && $(tty) == /dev/tty1 ]]; then
    case "${AUTOSTART_SESSION:-}" in
        hyprland) exec start-hyprland ;;
        startx)   exec startx ;;
    esac
fi
