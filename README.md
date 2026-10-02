# trie

A small, dependency-light set of **trie (prefix tree) utilities**
implemented in [boru](https://github.com/boru-lang/boru). One import gives
you fast prefix search, autocomplete, and longest-prefix matching over
String keys — as either a **set** of keys or a **map** from keys to
values — in four classic flavours.

```boru
import "./trie.aql"

def t (((TrieSet.make) "cat" TrieSet.add) "car" TrieSet.add)

print (t "car" TrieSet.has)                 # => true
print (t "ca"  TrieSet.with-prefix)         # => ["car", "cat"]
print (t "cartoon" TrieSet.longest-prefix)  # => car
```

> **Calling convention.** Forward args, receiver (the trie) **last**:
> `TrieSet.add key t`. Piping `t TrieSet.add key` also works; only
> `TrieSet.add t key` misbinds. Tries are **persistent** — rebind the result.

## The four variants

Each variant ships in its own file and exports **two namespaces** — a
`…Set` (membership) and a `…Map` (key → value) — over a shared engine.
They are behaviourally interchangeable (the property tests cross-check
them against the standard trie); pick one by its space/shape trade-off.

| File | Namespaces | What it is | Reach for it when… |
|------|------------|------------|--------------------|
| [`trie.aql`](trie.aql)   | `TrieSet` / `TrieMap`   | **Standard trie** — one node per character | the default; simplest and predictable |
| [`radix.aql`](radix.aql) | `RadixSet` / `RadixMap` | **Radix / PATRICIA tree** — single-child chains compressed into edge labels | keys are long and sparse; you want fewer nodes |
| [`tst.aql`](tst.aql)     | `TstSet` / `TstMap`     | **Ternary search tree** — BST-of-characters hybrid | the alphabet is large; you want few pointers per node |
| [`burst.aql`](burst.aql) | `BurstSet` / `BurstMap` | **Burst trie (HAT-trie family)** — flat buckets that burst into trie nodes | you want cache-friendly buckets over a shallow spine |

## The common API at a glance

Every namespace shares the same surface (set words on the left, the
extra map words on the right). `Xxx` is any of the eight namespaces.

| Set / map word | Purpose |
|----------------|---------|
| `Xxx.make`                    | build an empty trie |
| `t k Xxx.add` *(set)* / `t k v Xxx.set` *(map)* | insert a key (with a value) → new trie |
| `t k Xxx.has`                 | membership test → Boolean |
| `t k Xxx.get` *(map)*         | value for a key, or `none` |
| `t k Xxx.delete`              | remove a key → new trie |
| `t p Xxx.with-prefix` *(set)* / `Xxx.keys-with-prefix` *(map)* | all keys under prefix `p` |
| `t k Xxx.longest-prefix`      | longest stored key that prefixes `k` |
| `t Xxx.keys`                  | all keys, sorted |
| `t Xxx.values` / `Xxx.entries` *(map)* | all values / `[key, value]` pairs |
| `t Xxx.size` / `Xxx.height`   | key count / structural depth |
| `keys Xxx.from-keys` *(set)* / `entries Xxx.from-entries` *(map)* | rebuild a trie from extracted data (inverse of `keys`/`entries`) |
| `t Xxx.encode`                | JSON snapshot string |
| `s Xxx.decode`                | rebuild a trie from an `encode` snapshot (raises on a wrong-kind payload) |

The standard trie additionally offers two **advanced queries**:
`t query k TrieSet.within` (fuzzy / edit-distance search) and
`t pattern TrieSet.match` (wildcard search, `?` = one char, `*` = any run).

Tries are **persistent (immutable)**: every `add`/`set`/`delete` returns
a *new* trie and leaves the input untouched. Calls use boru's
forward-dispatch — arguments resolve at the next word or paren, so an
explicit `end` is rarely needed; the receiver (the trie) is always the
**last** parameter, so the stack forms in the table above and the forward
form `TrieSet.add "cat" t` bind the same way. Full details and the calling
convention are in the [Reference](docs/reference.md).

## Documentation

The docs follow the [Diátaxis](https://diataxis.fr) framework — four
modes, each serving a different need:

| | Mode | Read this when you want to… |
|--|------|----------------------------|
| 🎓 | **[Tutorial](docs/tutorial.md)** | learn by building your first trie step by step |
| 🔧 | **[How-to guides](docs/how-to.md)** | accomplish a task (autocomplete, choose a variant, persist, test…) |
| 📖 | **[Reference](docs/reference.md)** | look up exact words, signatures, and return types |
| 💡 | **[Explanation](docs/explanation.md)** | understand how each variant works and why it's built this way |

New here? Start with the [Tutorial](docs/tutorial.md). Just want the API?
Jump to the [Reference](docs/reference.md).

## For AI coding agents

If an agent will call this library, point it at **[AGENTS.md](AGENTS.md)** —
the boru calling convention, the four variants, verified idioms, and the common
mistakes to avoid. A machine-readable API manifest is in
[`api.json`](api.json); Claude Code also auto-loads `AGENTS.md` via
[`CLAUDE.md`](CLAUDE.md).

To make that guidance available in *another* project that uses this library,
install the bundled skill either way:

- **Copy the skill** — drop
  [`.claude/skills/trie-aql/`](.claude/skills/trie-aql/SKILL.md) into that
  project's `.claude/skills/` (or your `~/.claude/skills/`). It loads on demand
  whenever trie calls appear.
- **Install the plugin** — this repo is also a plugin marketplace:

  ```
  /plugin marketplace add voxgig-boru/trie
  /plugin install trie-aql@voxgig-boru
  ```

## Project layout

```
trie.aql                       standard trie        (TrieSet,  TrieMap)
radix.aql                      radix / PATRICIA     (RadixSet, RadixMap)
tst.aql                        ternary search tree  (TstSet,   TstMap)
burst.aql                      burst / HAT trie     (BurstSet, BurstMap)
test/<variant>_unit_test.aql   example-based unit tests — direct (one per variant)
test/trie_unit_spec.aql        example-based unit tests — declarative spec (standard trie)
test/<variant>_prop_spec.aql   property-based tests — declarative spec
test/trie_prop_test.aql        property-based tests — direct (Test.check-prop)
test/trie_smoke_test.aql       smoke demo across all four variants
test/divergence/run.sh         the test gate: every suite compiled + boru check
bench/                         perf workload (see PERF-BASELINE.md)
docs/                          Diátaxis documentation (above)
DX-REPORT.md                   developer-experience notes on building this in boru
BORU-MAIN-VERIFICATION.md      the log of retests against boru main
```

## Running it

Build `boru`, then run the demo or any test — see
[How-to → Install and run](docs/how-to.md#install-and-run-boru) and
[Run the tests](docs/how-to.md#run-the-tests). boru has one execution path:
each run compiles the program to bytecode and executes it on the VM.

```bash
boru test/trie_smoke_test.aql   # smoke demo across all variants
boru test/trie_unit_test.aql    # unit tests (standard trie; one suite per variant)
boru test/trie_prop_spec.aql    # property tests (standard trie)
test/divergence/run.sh          # every suite + boru check on every file (the CI gate)
```

A GitHub Actions workflow
([`.github/workflows/test.yml`](.github/workflows/test.yml), canonical copy in
[`ci/test.yml`](ci/test.yml)) builds boru at boru-lang/boru `main` HEAD and runs
the gate script — plus a `consistency` job (agent-skill drift and JSON
manifests) — on each push and pull request. Last verified by hand against boru
main @ `64c5ab2`.

## License

See [LICENSE](LICENSE).
