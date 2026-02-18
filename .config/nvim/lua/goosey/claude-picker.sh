#!/usr/bin/env bash
# fzf-based Claude session picker
# Usage: claude-picker.sh <tempfile> [cwd]
# Writes to tempfile: line 1 = key pressed (empty or ctrl-n), line 2 = selected session name
# If cwd is provided, defaults to showing only sessions scoped to that directory.
# ctrl-s toggles between scoped and all sessions.
#
# Internally lists sessions as "session_id\tsession_name" so that all tmux
# operations use the stable session ID (survives renames).

OUTFILE="$1"
[ -z "$OUTFILE" ] && exit 1
FILTER_CWD="$2"

STATEFILE=$(mktemp)
cleanup() { rm -f "$STATEFILE" "$LIST_SCRIPT" "$TOGGLE_SCRIPT" "$HEADER_SCRIPT" "$PROMPT_SCRIPT"; }
trap cleanup EXIT

# List script: reads state and outputs "id\tname" lines
LIST_SCRIPT=$(mktemp)
cat > "$LIST_SCRIPT" << LISTEOF
#!/usr/bin/env bash
scope=\$(cat "$STATEFILE" 2>/dev/null)
if [ "\$scope" = "all" ]; then
    tmux list-sessions -F "#{session_id}$(printf '\t')#{session_name}" 2>/dev/null | sort -t$'\t' -k2
else
    while IFS=$'\t' read -r sid sname; do
        sess_cwd=\$(tmux show-environment -t "\$sid" CLAUDE_CWD 2>/dev/null | sed 's/^CLAUDE_CWD=//')
        [ "\$sess_cwd" = "$FILTER_CWD" ] && printf '%s\t%s\n' "\$sid" "\$sname"
    done < <(tmux list-sessions -F "#{session_id}$(printf '\t')#{session_name}" 2>/dev/null | sort -t$'\t' -k2)
fi
LISTEOF
chmod +x "$LIST_SCRIPT"

# Toggle script: flips state
TOGGLE_SCRIPT=$(mktemp)
cat > "$TOGGLE_SCRIPT" << TOGEOF
#!/usr/bin/env bash
scope=\$(cat "$STATEFILE" 2>/dev/null)
if [ "\$scope" = "all" ]; then
    echo "cwd" > "$STATEFILE"
else
    echo "all" > "$STATEFILE"
fi
TOGEOF
chmod +x "$TOGGLE_SCRIPT"

# Header script: outputs header based on state
HEADER_SCRIPT=$(mktemp)
cat > "$HEADER_SCRIPT" << HDREOF
#!/usr/bin/env bash
scope=\$(cat "$STATEFILE" 2>/dev/null)
if [ "\$scope" = "all" ]; then
    echo "enter:attach | ctrl-n:new | ctrl-x:kill | ctrl-r:rename | ctrl-s:cwd"
else
    echo "enter:attach | ctrl-n:new | ctrl-x:kill | ctrl-r:rename | ctrl-s:all"
fi
HDREOF
chmod +x "$HEADER_SCRIPT"

# Prompt script: outputs prompt based on state
PROMPT_SCRIPT=$(mktemp)
cat > "$PROMPT_SCRIPT" << PRMEOF
#!/usr/bin/env bash
scope=\$(cat "$STATEFILE" 2>/dev/null)
if [ "\$scope" = "all" ]; then
    echo "all> "
else
    echo "cwd> "
fi
PRMEOF
chmod +x "$PROMPT_SCRIPT"

# Set initial scope
if [ -n "$FILTER_CWD" ]; then
    echo "cwd" > "$STATEFILE"
else
    echo "all" > "$STATEFILE"
fi

sessions=$(bash "$LIST_SCRIPT")

if [ -z "$sessions" ]; then
    echo "ctrl-n" > "$OUTFILE"
    echo "" >> "$OUTFILE"
    exit 0
fi

fzf_args=(
    --header "$(bash "$HEADER_SCRIPT")"
    --prompt "$(bash "$PROMPT_SCRIPT")"
    --expect=ctrl-n
    --delimiter '\t'
    --with-nth 2
    --bind "ctrl-x:execute-silent(tmux kill-session -t {1})+reload(bash $LIST_SCRIPT)"
    --bind "ctrl-r:execute(read -p 'Rename to: ' name < /dev/tty; tmux rename-session -t {1} \"\$name\")+reload(bash $LIST_SCRIPT)"
    --no-multi
    --reverse
    --border=none
    --margin=0
    --padding=0
    --color=fg:green,header:green,pointer:green,prompt:green
)

if [ -n "$FILTER_CWD" ]; then
    fzf_args+=(
        --bind "ctrl-s:execute-silent(bash $TOGGLE_SCRIPT)+reload(bash $LIST_SCRIPT)+transform-header(bash $HEADER_SCRIPT)+transform-prompt(bash $PROMPT_SCRIPT)"
    )
fi

result=$(echo "$sessions" | fzf "${fzf_args[@]}")

# result has two lines: line 1 = key pressed, line 2 = "id\tname"
# Extract the session name for the caller
{
    echo "$result" | head -n1
    echo "$result" | tail -n1 | cut -f2
} > "$OUTFILE"
