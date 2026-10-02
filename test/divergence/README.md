# `test/divergence/run.sh` — the single-path test gate

Runs every trie suite, and `boru check`s every suite and every module, on the
two surfaces boru main has, and fails on any error:

| Column | Command | Gate |
|---|---|---|
| RUN | `boru test/<suite>.aql` | exit 0; an assertion-bearing suite must also print `all green` |
| CHECK | `boru check <file>` | 0 errors (warnings and infos do not fail) |

The four modules (`trie.aql`, `radix.aql`, `tst.aql`, `burst.aql`) are
checked only: a module has no top-level program to run.

## Why there is no interpreter / `--compile` / `--force-compile` lane any more

Since boru main 2026-09-19 there is **one execution path**: a program compiles
to bytecode and runs on the VM, or it fails with
`[boru/compile_failed] … this is a compiler defect`. There is no interpreter
fallback. The flags this library's CI used to compare — the interpreter lane,
`--compile` (silent-fallback) parity and the advisory `--force-compile` lane,
plus `--no-compile` and the `BORU_COMPILE` / `BORU_FORCE_COMPILE` /
`BORU_NO_COMPILE` env vars — are retired upstream, and passing one is a usage
error. So "the suite runs" now *means* "the suite fully compiles", and the
old divergence columns have nothing left to compare.

`boru X` runs the static pre-flight check by default (a check error blocks the
run). The harness never passes `-no-check`.

## Running it

```bash
test/divergence/run.sh                          # builds boru @ main HEAD (cached), then gates
BORU=$HOME/.local/bin/boru test/divergence/run.sh   # use an existing binary; no build
BORU_REF=<sha> test/divergence/run.sh           # build a specific boru commit
SUITES="test/tst_unit_test.aql" BORU=boru test/divergence/run.sh   # a subset
```

Without `BORU`, the script resolves boru-lang/boru `main` HEAD, fetches it as a
codeload tarball (falling back to `git clone`), builds `cmd/go/boru` into
`~/.cache/boru-trie/boru-<sha>`, and reuses that binary on later runs. It needs
`go` and network for the one-time build.

CI (`ci/test.yml`, mirrored in `.github/workflows/test.yml`) builds boru once
and calls this script with `BORU` set, so CI and a local run gate identically.
