#!/usr/bin/env bash
# Waybar clock. The bar shows the dimmed date and the bold time; the tooltip
# adds the weekday, seconds and zone, then the ISO week and the day of the year
# with the days left in it -- arithmetic the built-in clock module cannot do.
#
# Usage: clock.sh            stream one JSON line per second, on the second
#        clock.sh --at EPOCH print the line for EPOCH once (for tests)
#
# Every date field comes from bash's printf %(...)T, so the stream forks only
# its sleep.

set -u

USAGE="Usage: clock.sh [--at EPOCH]"

render() {
    local at=$1 date clock_time headline week day_of_year year days_in_year
    printf -v date '%(%Y-%m-%d)T' "$at"
    printf -v clock_time '%(%H:%M)T' "$at"
    printf -v headline '%(%A, %Y-%m-%d %H:%M:%S %Z)T' "$at"
    printf -v week '%(%V)T' "$at"
    printf -v day_of_year '%(%j)T' "$at"
    printf -v year '%(%Y)T' "$at"

    # %V and %j are zero-padded; 10# keeps "08" and "009" from reading as octal.
    week=$((10#$week))
    day_of_year=$((10#$day_of_year))
    year=$((10#$year))

    days_in_year=365
    if (( year % 4 == 0 && (year % 100 != 0 || year % 400 == 0) )); then
        days_in_year=366
    fi

    printf '{"text": "<span alpha=\\"60%%\\">%s</span> <b>%s</b>", "tooltip": "%s\\nWeek %d, Day %d / %d (%d To Go)"}\n' \
        "$date" "$clock_time" "$headline" \
        "$week" "$day_of_year" "$days_in_year" $((days_in_year - day_of_year))
}

# Sleeps until the next whole second so the seconds never skip or lag.
sleep_to_next_second() {
    local micros remainder pause
    micros=${EPOCHREALTIME#*[.,]}
    remainder=$((1000000 - 10#$micros))
    printf -v pause '%d.%06d' $((remainder / 1000000)) $((remainder % 1000000))
    sleep "$pause"
}

case "${1:-}" in
    --at)
        if [[ ! "${2:-}" =~ ^-?[0-9]+$ ]]; then
            echo "$USAGE" >&2
            exit 2
        fi
        render "$2"
        ;;
    "")
        # A failed write means waybar closed the pipe; stop instead of spinning.
        while render "$EPOCHSECONDS"; do
            sleep_to_next_second
        done
        ;;
    *)
        echo "$USAGE" >&2
        exit 2
        ;;
esac
