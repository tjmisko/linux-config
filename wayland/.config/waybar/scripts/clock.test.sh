#!/usr/bin/env bash
# Tests for clock.sh, which sits next to this file.
# Usage: clock.test.sh   (exit status is the number of failures)

set -u

CLOCK="$(dirname "$0")/clock.sh"
failures=0

# render ZONE LOCAL_TIME FIELD prints FIELD (text or tooltip) of the clock's
# JSON for LOCAL_TIME in ZONE. jq doubles as the check that the line is JSON.
render() {
    local zone=$1 local_time=$2 field=$3 epoch
    epoch=$(TZ=$zone date -d "$local_time" +%s) || return 1
    TZ=$zone "$CLOCK" --at "$epoch" | jq -er ".$field"
}

expect() {
    local name=$1 actual=$2 expected=$3
    if [[ "$actual" == "$expected" ]]; then
        echo "ok   - $name"
        return 0
    fi
    echo "FAIL - $name"
    echo "       expected: $(printf '%q' "$expected")"
    echo "       actual:   $(printf '%q' "$actual")"
    failures=$((failures + 1))
}

la=America/Los_Angeles

expect "should show weekday, seconds and zone, then week and day count when mid-year" \
    "$(render $la '2026-09-30 18:18:05' tooltip)" \
    $'Wednesday, 2026-09-30 18:18:05 PDT\nWeek 40, Day 273 / 365 (92 To Go)'

expect "should render the bar text as dimmed date and bold time when mid-year" \
    "$(render $la '2026-09-30 18:18:05' text)" \
    '<span alpha="60%">2026-09-30</span> <b>18:18</b>'

expect "should strip the zero padding without octal errors when the day of year is 008" \
    "$(render $la '2026-01-08 09:09:09' tooltip)" \
    $'Thursday, 2026-01-08 09:09:09 PST\nWeek 2, Day 8 / 365 (357 To Go)'

expect "should count 364 to go when it is the first day of a common year" \
    "$(render $la '2026-01-01 00:00:00' tooltip)" \
    $'Thursday, 2026-01-01 00:00:00 PST\nWeek 1, Day 1 / 365 (364 To Go)'

expect "should use the ISO week of the previous year when Jan 1 falls on a Friday" \
    "$(render $la '2027-01-01 12:00:00' tooltip)" \
    $'Friday, 2027-01-01 12:00:00 PST\nWeek 53, Day 1 / 365 (364 To Go)'

expect "should count 366 days and none to go when it is Dec 31 of a leap year" \
    "$(render $la '2028-12-31 23:59:59' tooltip)" \
    $'Sunday, 2028-12-31 23:59:59 PST\nWeek 52, Day 366 / 366 (0 To Go)'

expect "should treat a century year as common when it is not divisible by 400" \
    "$(render $la '2100-03-01 08:00:00' tooltip)" \
    $'Monday, 2100-03-01 08:00:00 PST\nWeek 9, Day 60 / 365 (305 To Go)'

expect "should treat a century year as leap when it is divisible by 400" \
    "$(render $la '2000-03-01 08:00:00' tooltip)" \
    $'Wednesday, 2000-03-01 08:00:00 PST\nWeek 9, Day 61 / 366 (305 To Go)'

expect "should follow TZ when the zone is not Los Angeles" \
    "$(render Europe/London '2026-07-04 15:30:00' tooltip)" \
    $'Saturday, 2026-07-04 15:30:00 BST\nWeek 27, Day 185 / 365 (180 To Go)'

usage_status=0
"$CLOCK" --at >/dev/null 2>&1 || usage_status=$?
expect "should exit with usage status 2 when --at has no epoch" "$usage_status" 2

usage_status=0
"$CLOCK" --at tomorrow >/dev/null 2>&1 || usage_status=$?
expect "should exit with usage status 2 when --at is not an integer" "$usage_status" 2

streamed=$(timeout 3 "$CLOCK" | head -n 2 | jq -er .tooltip | rg -c '^[A-Z][a-z]+day, [0-9]{4}-[0-9]{2}-[0-9]{2} [0-9]{2}:[0-9]{2}:[0-9]{2} [A-Z]+$')
expect "should stream one JSON line per second when run without arguments" "$streamed" 2

exit "$failures"
