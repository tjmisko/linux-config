#!/usr/bin/env bash
# Waybar language indicator for fcitx5.
# Prints a short label for non-default input methods; prints nothing for
# keyboard-us so the module collapses (no indicator in the default state).
case "$(fcitx5-remote -n 2>/dev/null)" in
  pinyin)                printf '拼\n' ;;
  keyboard-gr-polytonic) printf 'Ω\n'  ;;
  *)                     printf '\n'   ;;
esac
