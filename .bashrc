# Set vim options for terminal to make it usable
# set -o vi
alias vim=nvim
VISUAL=nvim
EDITOR=nvim

# Set noclobber option to avoid accidental overwrites when piping output: overwrite with >|
set -o noclobber

# Set Default terminal to wezterm
TERMINAL=wezterm

# Import and alias useful scripts
alias fox=firefox
alias cat=bat
alias rss=newsboat
alias obsidian=~/AppImages/Obsidian-1.6.5.AppImage
alias fug='vim "+G | wincmd w | :q"'
alias clip="xclip -selection clipboard"
alias json="jq -C | less -R"
alias ai="claude"

source ~/.secrets/openai_api_key
source ~/.secrets/footprintnetwork_api_key
source ~/.config/scripts/background
source ~/.config/scripts/bcon
source ~/.config/scripts/context
source ~/.config/scripts/duntil
source ~/.config/scripts/gh
source ~/.config/scripts/gsw
source ~/.config/scripts/gcfzf
source ~/.config/scripts/harpoon_files
source ~/.config/scripts/hist
source ~/.config/scripts/notes
alias readings='~/.config/scripts/readings'
alias books='~/.config/scripts/readings --books'
alias articles='~/.config/scripts/readings --articles'
source ~/.config/scripts/tab
source ~/.config/scripts/video
source ~/.config/scripts/weather
source ~/Tools/mp3ify
source ~/Tools/Chinese/stroke
source ~/Tools/Chinese/vocab

# Configure Source Prompt
source ~/.git-prompt.sh
PS1="\
\[\e[1;34m\]\u\[\e[90m\]─┬─\[\e[0m\]\[\e[33m\]\$PWD\[\e[0m\]\[\e[35m\] \$(__git_ps1 ' %s')\[\e[0m\]\
\n\[\e[90m\]        │\[\e[0m\]\
\n\[\e[90m\]        └─\[\e[0m\]► "
# PS1="\[\033]0;$TITLEPREFIX:$PWD\007\]\[\033[32m\]\u \[\033[33m\]\W\[\033[35m\]\$(__git_ps1) \[\033[0m\]$ " ## original prompt
PROMPT_COMMAND='echo'
#
# Set fzf default options
export FZF_DEFAULT_OPTS="--reverse --color gutter:-1,bg+:-1,fg+:yellow --height 20"

# Set CDPATH
export CDPATH=.:~:~/Projects:~/Documents/Notes:~/Documents:~/Tools

# Source global definitions
if [ -f /etc/bashrc ]; then
    . /etc/bashrc
fi

# -------------------------------------------------------------------
# User specific environment (DROP-IN, idempotent PATH management)
# -------------------------------------------------------------------
path_prepend() {
  case ":$PATH:" in
    *":$1:"*) ;;                # already present
    *) PATH="$1:$PATH" ;;
  esac
}
path_append() {
  case ":$PATH:" in
    *":$1:"*) ;;
    *) PATH="$PATH:$1" ;;
  esac
}

path_prepend "$HOME/.local/bin"
path_prepend "$HOME/bin"
path_prepend "$HOME/.rbenv/shims"
path_append "$HOME/.config/scripts"
path_append "$HOME/Tools"
path_append "$HOME/Tools/Tasks"
path_append "$HOME/Tools/Remind"
path_append "$HOME/Tools/ChallengeLog"
path_append "$HOME/Tools/Music"
path_append "$HOME/Tools/Bookmarks"
path_append "$HOME/.cargo/bin"
path_append "/usr/local/go/bin"

export PATH
export GTK_IM_MODULE=ibus
export QT_IM_MODULE=ibus
export XMODIFIERS=@im=ibus

# Update window size after every command
shopt -s checkwinsize

# Automatically trim long paths in the prompt (requires Bash 4.x)
PROMPT_DIRTRIM=2

# Turn on recursive globbing (enables ** to recurse all directories)
shopt -s globstar 2> /dev/null

## SMARTER TAB-COMPLETION (Readline bindings) ##
if [[ $- == *i* ]]; then
    # Perform file completion in a case insensitive fashion
    bind "set completion-ignore-case on"
    # Treat hyphens and underscores as equivalent
    bind "set completion-map-case on"
    # Display matches for ambiguous patterns at first tab press
    bind "set show-all-if-ambiguous on"
fi

## SANE HISTORY DEFAULTS ##
shopt -s histappend # Append to the history file, don't overwrite it
shopt -s cmdhist # Save multi-line commands as one command
# PROMPT_COMMAND='history -a' # Record each line as it gets issued
HISTSIZE=500000 # Huge history. Doesn't appear to slow things down, so why not?
HISTFILESIZE=100000 # Huge history. Doesn't appear to slow things down, so why not?
HISTCONTROL="erasedups:ignoreboth" # Avoid duplicate entries
export HISTIGNORE="&:[ ]*:exit:ls:bg:fg:history:clear:vim:vim ." # Don't record some commands
HISTTIMEFORMAT='%F %T ' # Use standard ISO 8601 timestamp

if [[ $(pwd) == *"sspi-data-webapp"* ]]; then
    source env/bin/activate
fi

# Agent Session Switcher
export PATH="/home/tjmisko/Projects/agent-session-switcher/bin:$PATH"
