#!/usr/bin/env bash
# An agent's side of external_player.gd, one call a turn:
#   test/sim/turn.sh <dir> <seat> [plan]
# With a plan (a JSON list of moves), hands it in first. Then waits for this
# seat's next state (or the game's end) and prints it.
set -eu

dir=$1
seat=$2
if [ $# -ge 3 ]; then
    printf '%s' "$3" > "$dir/plan_$seat.json.tmp"
    mv "$dir/plan_$seat.json.tmp" "$dir/plan_$seat.json"
    # Until the game's taken it
    while [ -e "$dir/plan_$seat.json" ]; do
        sleep 0.5
    done
fi
# Up to nine minutes, while the other side plays
for _ in $(seq 1 1080); do
    if [ -e "$dir/state_$seat.json" ]; then
        cat "$dir/state_$seat.json"
        exit 0
    fi
    sleep 0.5
done
echo "No state after nine minutes: is the game still running?" >&2
exit 1
