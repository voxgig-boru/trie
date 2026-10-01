# How-to guides

Task-oriented recipes. Each assumes you know roughly what a trie is; if
not, start with the [Tutorial](tutorial.md). For the *why*, follow the
links into the [Explanation](explanation.md); for exact signatures, the
[Reference](reference.md).

- [Install and run boru](#install-and-run-boru)
- [Choose a variant](#choose-a-variant)
- [Build a trie from a list of keys](#build-a-trie-from-a-list-of-keys)
- [Autocomplete a prefix](#autocomplete-a-prefix)
- [Do longest-prefix matching](#do-longest-prefix-matching)
- [Use it as a map](#use-it-as-a-map)
- [Delete keys](#delete-keys)
- [Switch between variants](#switch-between-variants)
- [Serialize a trie](#serialize-a-trie-and-read-it-back)
- [Fuzzy and wildcard search (standard trie)](#fuzzy-and-wildcard-search-standard-trie)
- [Use a trie from your own script](#use-a-trie-from-your-own-script)
- [Run the tests](#run-the-tests)

---

## Install and run boru

The library is written in boru, which has no tagged release, so build `boru`
from source (`go install …/cmd/go/boru@latest` fails on the repo's replace
directives). The library tracks boru-lang/boru **`main`** — there is no pinned
commit:

```bash
git clone https://github.com/boru-lang/boru /tmp/boru-source
cd /tmp/boru-source/cmd/go
GOWORK=off GOFLAGS=-mod=mod go build -o "$HOME/.local/bin/boru" ./boru
```

(Where a raw `git clone` is blocked, fetch
`https://codeload.github.com/boru-lang/boru/tar.gz/main` instead — the
SessionStart hook and `test/divergence/run.sh` do exactly that.) Put
`$HOME/.local/bin` on your `PATH`, then check and run:

```bash
boru -version
boru test/trie_smoke_test.aql
```

boru has **one execution path**: `boru X` runs a static pre-flight check, then
compiles the program to bytecode and runs it on the VM. There is no
interpreter fallback, and the old `--compile` / `--force-compile` /
`--no-compile` flags are retired (passing one is a usage error). This library
was last verified against boru main @ `64c5ab2` (see
[BORU-MAIN-VERIFICATION.md](../BORU-MAIN-VERIFICATION.md)); CI resolves and
builds `main` HEAD on every run.

---

## Choose a variant

All four behave identically through the API; pick by shape:

| Pick | When |
|------|------|
| **standard trie** (`trie.aql`)  | the default — simplest, predictable, one node per character |
| **radix tree** (`radix.aql`)    | keys are long and don't share much — compression saves many nodes |
| **ternary search tree** (`tst.aql`) | the alphabet is large/Unicode — three pointers per node beats a per-node child map |
| **burst trie** (`burst.aql`)    | you want flat, cache-friendly buckets over a shallow trie spine |

When in doubt, start with the standard trie and switch later — it is a
one-line change (see [Switch between variants](#switch-between-variants)).
See [Explanation](explanation.md) for the trade-offs behind each.

---

## Build a trie from a list of keys

Fold the keys into a fresh trie. Each `add` returns the next trie, so the
accumulator threads through:

```boru
import "./trie.aql"

def words ["apple" "app" "apply" "banana"]
def t ((TrieSet.make) words [ var [[w acc] acc w TrieSet.add end ] ] fold)
```

`fold` runs as `init list [body] fold` — here the empty trie is the
initial accumulator and the body receives each key `w` and the
accumulator `acc`, returning the next trie. For a map, carry a value too:
`acc w v TrieMap.set end`.

---

## Autocomplete a prefix

`with-prefix` (set) / `keys-with-prefix` (map) returns every key beneath a
prefix, sorted — exactly an autocomplete list:

```boru
def t (((( TrieSet.make) "app" TrieSet.add) "apple" TrieSet.add) "apply" TrieSet.add)
print (t "app" TrieSet.with-prefix)     # => ["app", "apple", "apply"]
print (t "z"   TrieSet.with-prefix)     # => []
```

An empty prefix returns all keys. To autocomplete *and* show values, use
`…Map.entries-with-prefix`, which returns the `[key, value]` pairs, key-sorted.

---

## Do longest-prefix matching

Find the longest stored key that is a prefix of a query — e.g. dictionary
tokenization or routing:

```boru
def t ((( TrieSet.make) "car" TrieSet.add) "card" TrieSet.add)
print (t "cartoon" TrieSet.longest-prefix)   # => car
print (t "zebra"   TrieSet.longest-prefix)   # => none
```

`none` means no stored key prefixes the query. (If the empty key `""` is
stored, it prefixes everything, so the answer is then `""` rather than `none`.)

---

## Use it as a map

Swap `…Set` for `…Map`, and bind values with `set`:

```boru
import "./trie.aql"

def m (((TrieMap.make) "GET" 1 TrieMap.set) "POST" 2 TrieMap.set)

print (m "GET"    TrieMap.get)     # => 1
print (m "DELETE" TrieMap.get)     # => none  (absent)
print (m TrieMap.entries)          # => [["GET", 1], ["POST", 2]]
```

Values may be any type, including Strings that happen to be boru words
(`"if"`, `"do"` …). Use `has` if you need to tell an absent key from a key
whose stored value is `none`.

---

## Delete keys

`delete` returns a new trie without the key, and preserves keys that sit
below it:

```boru
def t ((( TrieSet.make) "car" TrieSet.add) "card" TrieSet.add)
def t2 (t "car" TrieSet.delete)
print (t2 "car"  TrieSet.has)     # => false
print (t2 "card" TrieSet.has)     # => true   (survives)
print (t  "car"  TrieSet.has)     # => true   (original unchanged)
```

Deleting an absent key is a no-op.

---

## Switch between variants

The API is identical across variants, so switching is mechanical: change
the import and the namespace prefix. From standard to ternary search tree:

```diff
- import "./trie.aql"
- def t ((TrieSet.make) "cat" TrieSet.add)
+ import "./tst.aql"
+ def t ((TstSet.make) "cat" TstSet.add)
```

Every word (`add`, `has`, `with-prefix`, `longest-prefix`, `keys`, …)
keeps its name and behaviour. The property suite cross-checks each variant
against the standard trie, so the swap is safe.

---

## Serialize a trie (and read it back)

`encode` produces a JSON snapshot string — kind, size, and the sorted keys
(sets) or entries (maps), pretty-printed — and `decode` rebuilds a trie from
it:

```boru
def t (((TrieMap.make) "a" 1 TrieMap.set) "b" 2 TrieMap.set)
def snapshot (t TrieMap.encode)    # JSON: {"entries": [["a", 1], ["b", 2]], "kind": "triemap", "size": 2}
def t2 (snapshot TrieMap.decode)
print (t2 "b" TrieMap.get)          # => 2
```

`decode` is strict about the payload's `kind`: each namespace reads only
its own snapshots and **raises** a catchable error on any other (so a
`triemap` snapshot fed to `RadixMap.decode` fails loudly, not quietly).
Inside the handler the error is bound by `var`; read its fields with dot
access (`e.message`, `e.code`) — `get` evaluates its key, so a bare
`e get message` is an `undefined word`:

```boru
import "./radix.aql"
def msg (do [RadixMap.decode snapshot] error [ var [[e] e.message ] ])
print (msg)   # => RadixMap.decode: expected kind 'radixmap', got 'triemap'
```

To move keys **between variants** — or to serialize some other way — use
the data-level round-trip instead; `from-keys`/`from-entries` accept plain
lists and are available on every variant:

```boru
def ks (t TrieMap.keys)              # not `def keys …` — `keys` is a reserved word
def r  (ks RadixSet.from-keys)       # same keys, different variant
print (r RadixSet.keys)              # => ["a", "b"]
```

---

## Fuzzy and wildcard search (standard trie)

The standard trie adds two advanced queries. **Fuzzy** search returns every
key within a Levenshtein edit distance:

```boru
def t (((TrieSet.make) "cat" TrieSet.add) "car" TrieSet.add)
print (t "cat" 1 TrieSet.within)   # => ["car", "cat"]
```

**Wildcard** search matches a pattern where `?` is any single character and
`*` is any run of characters:

```boru
print (t "ca?" TrieSet.match)      # => ["car", "cat"]
print (t "*t"  TrieSet.match)      # => ["cat"]
```

Both work on `TrieMap` too (returning keys). To run them over data held in
another variant, extract its `keys`/`entries` and rebuild a `TrieSet`
/`TrieMap` with `from-keys`/`from-entries`.

---

## Use a trie from your own script

Import the variant by relative path — resolved against **the importing
file's own directory**, not the directory you run `boru` from (a script in
`test/` writes `import "../radix.aql"`). You do **not** need to import
anything else — each module pulls in its own dependencies:

```boru
import "./radix.aql"
def t (RadixSet.make)
# … use the RadixSet namespace …
```

Forward arguments have precedence and a call resolves at the next function
word or paren, so you rarely need a terminator; add `end`, parens, or the
`/s` modifier only to stop a bare following literal from being grabbed.
Print verb-first — `print (value)`, one per statement: `print` collects its
argument forward, so a postfix chain like `(a) print` followed by
`(b) print` prints `b` first. `test/trie_smoke_test.aql` is a complete worked
example you can copy from.

---

## Run the tests

Each variant ships an example-based unit suite and a declarative property
suite. The standard trie additionally ships the other two framework
surfaces — a declarative unit spec and an imperative property suite — so
all four are demonstrated:

```bash
boru test/trie_unit_test.aql    # unit tests — standard trie (direct)
boru test/trie_unit_spec.aql    # unit tests — standard trie (declarative spec)
boru test/radix_unit_test.aql   # unit tests — radix
boru test/tst_unit_test.aql     # unit tests — ternary search tree
boru test/burst_unit_test.aql   # unit tests — burst trie

boru test/trie_prop_spec.aql    # property tests — standard trie (declarative spec)
boru test/trie_prop_test.aql    # property tests — standard trie (direct Test.check-prop)
boru test/radix_prop_spec.aql   # property tests — radix (with trie cross-check)
boru test/tst_prop_spec.aql     # property tests — tst   (with trie cross-check)
boru test/burst_prop_spec.aql   # property tests — burst (with trie cross-check)
```

boru compiles each suite to bytecode and runs it on the VM (the one
execution path). Each assertion-bearing file ends by asserting
`Test.fail-count` is `0` and printing `all green`, so a failure makes `boru`
exit non-zero. The gate script runs every suite **and** `boru check`s every
suite and module (0 errors required):

```bash
test/divergence/run.sh                          # builds boru @ main HEAD (cached), then gates
BORU=$HOME/.local/bin/boru test/divergence/run.sh   # reuse an existing binary
```

That script is what the [CI workflow](../ci/test.yml) runs on every push and
pull request.
