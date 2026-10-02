# CLAUDE.md

This repository is the `trie` prefix-tree utilities library, written in boru —
four interchangeable variants (`trie`, `radix`, `tst`, `burst`), each exporting
a Set and a Map over a shared engine.

## Using the library

See @AGENTS.md for how to call the trie API correctly from boru — the
forward-dispatch calling convention, the four variants, the persistent/immutable
rebind rule, copy-paste idioms, and the common mistakes to avoid. Every example
there is verified against boru main @ `64c5ab2`.

## Working on this repository

- A SessionStart hook (`.claude/settings.json` →
  `.claude/hooks/session-start.sh`) builds `boru` from boru-lang/boru `main` in
  remote sessions (codeload tarball, `git clone` fallback; `cmd/go` →
  `./boru`), so a fresh session can run the suites. Locally, build it once from
  source (there is no tagged release and `go install …/boru@latest` is blocked
  by replace directives) — see
  [docs/how-to.md](docs/how-to.md#install-and-run-boru).
- Tests live in `test/`, named `<subject>_<unit|prop>_<test|spec>.aql` plus a
  `trie_smoke_test.aql`: `_test` = imperative (`Test.test`/`Test.check-prop`),
  `_spec` = declarative spec; `unit` = example-based, `prop` = property-based.
  The standard trie ships all four surfaces as the reference; each variant ships
  at least the imperative-unit + declarative-property pair. Each
  assertion-bearing suite ends by asserting `Test.fail-count` is `0` and prints
  `all green`. Suites import the modules as `../<variant>.aql` — relative
  imports resolve against the importing file's own directory.
- The library tracks boru **`main`** (latest), not a "known-good" commit — we
  are on an iterative-improvement track with upstream, so always retest on the
  newest `main`. Record each retest in `BORU-MAIN-VERIFICATION.md` (latest:
  §13, boru main @ `64c5ab2`, 2026-10-01).
- **One execution path.** boru compiles every program to bytecode and runs it
  on the VM, or fails with `[boru/compile_failed] … compiler defect`; there is
  no interpreter fallback, and `--compile` / `--force-compile` / `--no-compile`
  are retired (usage errors). So "a suite runs" means "a suite fully compiles".
  The gate is `test/divergence/run.sh` (CI calls it): every suite exits 0
  under `boru <suite>` and prints `all green`, and `boru check` reports 0
  errors on every suite **and** every module. All 11 suites and 4 modules pass
  it on `64c5ab2`. `boru X` runs the static check first; never use `-no-check`
  to get green.
- Three library spots carry workarounds for open boru defects (each commented
  in place, minimal repros in `DX-REPORT.md`'s migration section): two compile
  refusals — `radix.aql` `common-len` and `tst.aql` `count-t` — and one
  call-path-dependent run-time failure (a loop-body `push` chain that raises
  when its fn is reached from another fn or through the export), the grouped
  `([] k push) v push` in `tst.aql`/`burst.aql` `entries-with-prefix`. Remove
  them when upstream fixes land.
- On boru main @ `64c5ab2`, `Assert.equal` passes a zero-valued `""`/`0`/
  `false` against `none` or another type (upstream defect). When the actual may
  be `none` (`get`, `longest-prefix`), assert type-strictly:
  `true ((x) "" eq) Assert.equal end`.
- Known boru-runtime gotchas are in `DX-REPORT.md`; the perf workload and its
  numbers are `bench/` and `PERF-BASELINE.md`. `BORU-CHECK-REPORT.md` is a
  historical record (its "false positives are unfixable" thesis was superseded:
  upstream fixed them).
