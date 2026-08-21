# claude-name-wrapper.sh — project-prefix the startup session name.
#
# Source from ~/.bashrc:
#     source ~/.config/scripts/claude-name-wrapper.sh
#
# Wraps `claude` so a startup name passed with -n/--name is run through
# `switchboard-ctl name resolve` (project abbreviation + dedup) before launch —
# e.g. inside ~/Projects/Arachne, `claude -n assess` starts as `arachne-assess`.
# Everything else is passed through untouched: `--resume`/`--continue`, and the
# no-name case (so Claude's own auto-title still appears). If switchboard-ctl is
# missing or errors, the original name is used unchanged.
claude() {
  local ctl=/home/tjmisko/go/bin/switchboard-ctl
  local args=("$@") i resolved
  for ((i = 0; i < ${#args[@]}; i++)); do
    case "${args[i]}" in
      -n | --name)
        if ((i + 1 < ${#args[@]})); then
          resolved=$("$ctl" name resolve --cwd "$PWD" --name "${args[i + 1]}" 2>/dev/null) || resolved=""
          [[ -n "$resolved" ]] && args[i + 1]="$resolved"
        fi
        ;;
      --name=*)
        resolved=$("$ctl" name resolve --cwd "$PWD" --name "${args[i]#--name=}" 2>/dev/null) || resolved=""
        [[ -n "$resolved" ]] && args[i]="--name=$resolved"
        ;;
    esac
  done
  command claude "${args[@]}"
}
