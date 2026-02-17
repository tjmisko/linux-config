#!/usr/bin/env bash
# fzf-based Claude session picker
# Usage: claude-picker.sh <tempfile>
# Writes to tempfile: line 1 = key pressed (empty or ctrl-n), line 2 = selected session

OUTFILE="$1"
[ -z "$OUTFILE" ] && exit 1

LIST_CMD="tmux list-sessions -F '#{session_name}' 2>/dev/null | grep '^claude-\|^[^claude]' | sort"

sessions=$(eval "$LIST_CMD")

if [ -z "$sessions" ]; then
    echo "ctrl-n" > "$OUTFILE"
    echo "" >> "$OUTFILE"
    exit 0
fi

result=$(echo "$sessions" | fzf \
    --header 'enter:attach | ctrl-n:new | ctrl-x:kill | ctrl-r:rename' \
    --expect=ctrl-n \
    --bind "ctrl-x:execute-silent(tmux kill-session -t {})+reload($LIST_CMD)" \
    --bind "ctrl-r:execute(read -p 'Rename to: ' name < /dev/tty; tmux rename-session -t {} \"\$name\")+reload($LIST_CMD)" \
    --no-multi \
    --reverse \
    --border=none \
    --margin=0 \
    --padding=0 \
    --color=fg:green,header:green,pointer:green,prompt:green \
)

echo "$result" > "$OUTFILE"
