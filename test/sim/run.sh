#!/usr/bin/env bash
# Plays every pair of simulate.gd's personas against each other, in both
# seats, GAMES times each, several at once, and gathers the results into one
# JSON-lines file.
#   test/sim/run.sh <out.jsonl> [games per pairing] [at once] [mirrors]
# With "mirrors", only each persona against itself, to measure the seats.
set -eu

cd "$(dirname "$0")/../.."
out=$1
games=${2:-8}
jobs=${3:-16}
mirrors=${4:-}
personas=(standard turtle brawler airboss wolfpack)
# Each game writes its own file, beside the results, so none interleave
parts="$out.parts"
mkdir -p "$parts"

for a in "${personas[@]}"; do
    for b in "${personas[@]}"; do
        if [ -n "$mirrors" ] && [ "$a" != "$b" ]; then
            continue
        fi
        for i in $(seq 1 "$games"); do
            echo "$a $b $i"
        done
    done
done | xargs -P "$jobs" -L 1 sh -c '
    timeout 900 godot --headless --path . -s res://test/sim/simulate.gd -- \
        "$0/$1-$2-$3.jsonl" "$3" "$1" "$2" 2>/dev/null | grep -E " won| draw" || true
' "$parts"

cat "$parts"/*.jsonl > "$out"
rm -r "${parts:?}"
wc -l < "$out"
