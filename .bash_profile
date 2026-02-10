# .bash_profile

# Get the aliases and functions
if [ -f ~/.bashrc ]; then
    . ~/.bashrc
fi

# User specific environment and startup programs
[[ -z $DISPLAY ]] && [[ $(tty) == /dev/tty1 ]] && exec Hyprland
# [[ -z $DISPLAY ]] && [[ $(tty) == /dev/tty1 ]] && exec startx
