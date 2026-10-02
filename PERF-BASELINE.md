# Performance baseline — `voxgig-boru/trie`

**Date:** 2026-10-01 (first baseline 2026-07-11)
**boru:** `main` @ `64c5ab2` (built from source; see `BORU-MAIN-VERIFICATION.md`
§13 for the build and the retest)
**Harness:** `bench/trie_bench.aql` + `bench/run.sh` (reproducible; no RNG)

This is a **wall-clock baseline** for the trie library so future changes — in
this repo or upstream `boru` — can be measured against a fixed workload. Numbers
are single-run wall time on the session's remote container (shared CPU), so
treat them as *ratios and orders of magnitude*, not absolute constants; re-run
`bench/run.sh` on the target host for local figures.

## Workload

`bench/trie_bench.aql` builds a `TrieSet` of `N` deterministic keys
(`k<i>x<i*7 mod 1000>`) via a `fold`, then exercises the hot paths:

| Phase | Work |
|---|---|
| build | `N` immutable `TrieSet.add`s (fold; each returns the next trie) |
| membership | `N` `TrieSet.has` lookups (full-key trie walks) |
| prefix | 4 `TrieSet.with-prefix` autocomplete collections |
| keys | one full sorted `TrieSet.keys` dump |

## Results — the single execution path (boru main @ `64c5ab2`)

Since boru main 2026-09-19 there is one execution path: every program compiles
to bytecode and runs on the VM (no interpreter fallback; `--compile` /
`--no-compile` are retired), so there is no interpreter-vs-compiled column any
more. `bench/run.sh` times that path and checks each run really built `N` keys
(a capitalised `def N` silently became a *type* in boru's Stage 2 type flip, so
the bench once timed an empty trie — it is `def n` now).

| N (keys) | wall (best of 2) | status |
|---------:|-----------------:|:------:|
| 500 | 2.99 s | ok |
| 1000 | 5.50 s | ok |
| 2000 | 18.07 s | ok |

(boru @ `64c5ab2`, 2026-10-01; the container was shared with other build
agents — load average 5–7.5 on 4 CPUs — so the second run was 30–45% slower and
these are upper bounds. Re-run `bench/run.sh` on an idle host for real figures.)

Against the July baseline below, the whole program — including the recursive
trie walks that used to fall back to the interpreter — now runs compiled, and
the N=500/1000 figures sit between the old compiled-driver numbers and the old
interpreter. The N=2000 step (3.3× the N=1000 time for 2× the keys) is more
superlinear than in July; given the load it is not yet a measured regression,
but it is the number to re-check on an idle host.

## Historical — interpreter vs bytecode compiler (boru `6185620`, 2026-07-11)

Run with `SIZES="500 1000 2000" bench/run.sh`. The compiler (`boru --compile`)
**soundly falls back to the interpreter for the recursive trie module fns that
still refuse** (see `BORU-MAIN-VERIFICATION.md` §compile), yet the compiled
top-level driver loops (the build `fold` and the membership/prefix `each`
sweeps) still deliver a solid speedup:

| N (keys) | interpreter | compiled | speedup |
|---------:|------------:|---------:|:-------:|
| 500 | 6.63 s | 1.95 s | 3.40× |
| 1000 | 14.06 s | 3.78 s | 3.72× |
| 2000 | 34.88 s | 11.86 s | 2.94× |

(single clean run, `boru` @ `6185620`; re-run `bench/run.sh` for local figures)

Scaling is roughly linear in `N` (slightly superlinear because `with-prefix`
collects a growing key set). The **~3× compiled speedup comes entirely from the
driver loops**; closing the remaining `--force-compile` refusals in the
recursive module fns (the `body result of unknown provenance` / dynamic-receiver
dispatch frontier catalogued in `BORU-MAIN-VERIFICATION.md`) is the path to
compiling the trie walks themselves and widening this margin.

## Per-suite runtimes — single path (boru main @ `64c5ab2`)

Wall time of `boru <suite>.aql` (compile + run) in the final gate run of the
2026-10-01 migration (`test/divergence/run.sh`; same shared-host caveat):

| Suite | time |
|---|---|
| `tst_unit_test` | 2.0 s |
| `trie_unit_spec` | 2.6 s |
| `trie_unit_test` | 2.9 s |
| `radix_unit_test` | 4.3 s |
| `trie_prop_test` | 4.5 s |
| `burst_unit_test` | 4.8 s |
| `trie_smoke_test` | 8.8 s |
| `burst_prop_spec` | 11.3 s |
| `trie_prop_spec` | 13.1 s |
| `radix_prop_spec` | 16.3 s |
| `tst_prop_spec` | 23.3 s |

The whole gate (11 suites run + 15 files checked) takes about 1.5 minutes.

## Historical — per-suite interpreter runtimes (boru `6185620`)

Reference cost of the CI suites under the then-interpreter (`boru <suite>.aql`):

| Suite | ~time |
|---|---|
| `trie_unit_spec` | 0.9 s |
| `tst_unit_test` | 0.9 s |
| `radix_unit_test` | 1.8 s |
| `burst_unit_test` | 1.9 s |
| `trie_unit_test` | 1.9 s |
| `trie_smoke_test` | 5.4 s |
| `trie_prop_test` | 8.4 s |
| `radix_prop_spec` | 18 s |
| `trie_prop_spec` | 37 s |
| `tst_prop_spec` | 38 s |
| `burst_prop_spec` | ~38 s |

The `*_prop_spec` declarative property **generators** dominate — they are the
slow lane in CI (each runs many generated cases). The imperative unit/`_test`
suites are all under ~2 s except the multi-variant `trie_smoke_test`.

## Reproducing

```bash
# from the repo root, with `boru` on PATH
bench/run.sh                       # SIZES defaults to "500 1000 2000"
SIZES="1000" bench/run.sh          # single size
```
