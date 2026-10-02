#!/bin/bash
# Time the trie benchmark across a series of key counts. Reports best-of-1
# wall time.
#
# boru has ONE execution path: a program compiles to bytecode and runs on the
# VM, or fails with `[boru/compile_failed] … compiler defect`. The old
# interpreter-vs-compiled comparison (`--no-compile` / `--compile`) is gone —
# those flags are retired upstream and are now usage errors — so this times
# the single path and checks that each run actually built N keys.
#
# Uses `boru` from PATH, or $BORU if set (e.g. BORU=/path/to/boru). Run from
# anywhere: imports resolve against the importing file's own directory.
set -uo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BORU="${BORU:-boru}"
BENCH="$ROOT/bench/trie_bench.aql"
SIZES="${SIZES:-500 1000 2000}"
tmp="$ROOT/bench/.trie_bench_run.aql"   # beside the bench so ../trie.aql resolves
trap 'rm -f "$tmp"' EXIT
printf "%-8s %-12s %-8s\n" "N" "wall(s)" "status"
fail=0
for n in $SIZES; do
  sed "s/^def n .*/def n $n/" "$BENCH" > "$tmp"
  s=$(date +%s.%N)
  out=$("$BORU" "$tmp" 2>&1); rc=$?
  e=$(date +%s.%N)
  size=$(printf '%s\n' "$out" | sed -n '/^size:/{n;p;}')
  status=ok
  if [ $rc -ne 0 ]; then status="FAIL(rc=$rc)"; fail=1; elif [ "$size" != "$n" ]; then status="WRONG(size=$size)"; fail=1; fi
  printf "%-8s %-12s %-8s\n" "$n" "$(awk "BEGIN{printf \"%.2f\", $e-$s}")" "$status"
done
# A failed or wrong-size run fails the script, so callers cannot mistake it for a timing.
exit $fail
