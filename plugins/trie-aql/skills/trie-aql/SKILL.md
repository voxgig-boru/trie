---
name: trie-aql
description: Use when writing or editing boru code that calls this trie / prefix-tree library — TrieSet / TrieMap and the RadixSet/RadixMap, TstSet/TstMap, BurstSet/BurstMap variants (TrieSet.add / has / with-prefix / longest-prefix / within / match, TrieMap.set / get / entries …), or any file that does `import "./trie.aql"` (or radix/tst/burst). Provides the boru forward-dispatch calling convention (which is not C/Python/JS) — the receiver (trie/set/map) is the LAST argument, so forward `TrieSet.add "cat" s` and pipe `s TrieSet.add "cat"` both bind but receiver-first `TrieSet.add s "cat"` misbinds — plus the persistent/immutable rebind rule, the shared Set/Map API across all four variants, verified copy-paste idioms, and fixes for the mistakes agents make most (mutating in place, foreign call syntax, the eq-vs-deq identity trap, reserved names like node/keys).
---

# Calling the trie utilities library (boru)

Fast prefix search, autocomplete, and longest-prefix matching over String
keys, as a **set** of keys or a **map** from keys to values, in four
interchangeable variants. Everything below is verified against boru main
@ `64c5ab2`.

## Import

```boru
import "./trie.aql"        # or radix.aql / tst.aql / burst.aql
```

- A relative import resolves against **the importing file's own directory**,
  not the directory you run `boru` from (a test in `test/` writes
  `import "../trie.aql"`).
- Each module pulls in its own dependency (`boru:struct-util`); a consumer
  imports nothing else.

## Pick a variant (all share one API)

| File | Namespaces | Use when |
|------|------------|----------|
| `trie.aql`  | `TrieSet` / `TrieMap`   | the default; the only one with `within`/`match` |
| `radix.aql` | `RadixSet` / `RadixMap` | long, sparse keys — fewer nodes |
| `tst.aql`   | `TstSet` / `TstMap`     | large/Unicode alphabets |
| `burst.aql` | `BurstSet` / `BurstMap` | flat, cache-friendly buckets |

## The calling rules

- **The receiver (`t`, the trie/set/map) is the LAST argument.** Every public
  word is declared receiver-last (`set-add [key:String t:Map]`,
  `map-set [val:Any key:String t:Map]`). A call fills parameters in signature
  order — forward args first, then the stack, top first — so these all bind:
  - **forward (canonical):** `TrieSet.add "cat" s` — key forward, receiver last.
  - **piping:** `s TrieSet.add "cat"` — receiver flows in from the left, key
    forward. Threads through chains and folds.
  Only **receiver-first, all-forward MISBINDS**: `TrieSet.add s "cat"` puts the
  trie in the key slot and is rejected before the run (`uncalled_function:
  call to 'set-add' matched no signature`). `TrieMap.set` follows the same
  shape: `TrieMap.set 1 "GET" m` (value, key, receiver-last).
- **Forward arguments have precedence.** A word grabs the tokens after it,
  stops at the next word or a closing paren, else takes what it needs from the
  stack — group a call in parens to use its result: `(s "x" TrieSet.has)`.
- **Print verb-first:** `print (value)`, one per statement. `print` collects
  forward, so `(a) print` followed by more code grabs the next token.
- **Tries are persistent (immutable).** `add` / `set` / `delete` return a
  **new** trie; the input is unchanged — **always rebind the result**
  (`def s2 (TrieSet.add "cat" s)`).
- **Disambiguate** only when a bare literal immediately follows a stack-form
  call: use parens, a trailing `end`, or the `/s` (force-stack) modifier.
- **A function value passes as data with `/v`** (`TrieSet.has/v`); a bare name
  holding a function calls wherever it appears. (`/v` replaced `/r`.)

## API at a glance

`…Set`: `make` · `add` · `has` · `delete` · `with-prefix` · `longest-prefix` ·
`keys` · `size` · `height` · `from-keys` · `encode` · `decode`
`…Map`: `make` · `set` · `get` · `has` · `delete` · `keys-with-prefix` ·
`entries-with-prefix` · `longest-prefix` · `keys` · `values` · `entries` ·
`size` · `height` · `from-entries` · `encode` · `decode`
`TrieSet`/`TrieMap` add `within` (fuzzy) and `match` (wildcard, `?`/`*`).

`keys`, `values`, `entries`, `with-prefix`, `keys-with-prefix` are **sorted**.
`get` returns `none` / `has` returns `false` for an absent key (never an error).

## Idioms (verified)

```boru
import "./trie.aql"

# Forward canonical (key forward, receiver LAST); rebind — tries are immutable.
def s0 (TrieSet.make)
def s1 (TrieSet.add "cat" s0)               # NOT `TrieSet.add s0 "cat"` (misbinds)
print (TrieSet.has "cat" s1)                # => true

def s ((TrieSet.make) ["apple" "app" "apply"] [ var [[w acc] acc w TrieSet.add end ] ] fold)
print (s "app"  TrieSet.has)                # => true
print (s "ap"   TrieSet.has)                # => false  (a prefix is not a member)
print (s "app"  TrieSet.with-prefix)        # => ["app", "apple", "apply"]
print (s "applesauce" TrieSet.longest-prefix)   # => apple

def m (((TrieMap.make) "GET" 1 TrieMap.set) "POST" 2 TrieMap.set)
print (m "GET"    TrieMap.get)              # => 1
print (m TrieMap.entries)                   # => [["GET", 1], ["POST", 2]]  (sorted)

def back ((m TrieMap.encode) TrieMap.decode)   # JSON snapshot round-trip
print (back "POST" TrieMap.get)             # => 2
```

## Common mistakes

| ✗ Don't | ✓ Do | Why |
|---------|------|-----|
| `t.add("x")` / `TrieSet.add(t,"x")` | `TrieSet.add "x" t` | boru has no call/method syntax. |
| `TrieSet.add t "x"` (receiver-first, all-forward) | `TrieSet.add "x" t` (receiver last) or `t TrieSet.add "x"` (pipe) | forward fills `key` first: receiver-first puts `t` in the key slot → `uncalled_function`. |
| reuse `t` after `TrieSet.add "x" t` | rebind: `def t2 (TrieSet.add "x" t)` | tries are persistent; `add` returns a new trie. |
| `(a) print` then more code on the next line | `print (a)` | `print` collects forward; the unterminated form grabs the next token. |
| `merge` to update a node | rebuild with the explicit `mk-*` constructor; `StructUtil.setpath` for one field | `StructUtil.merge` is a **deep, index-wise** merge (nested lists merge by index). |
| `["a"] ["a"] eq` to compare lists | `["a"] ["a"] deq` (structural) or `Assert.equal` | `eq` is **identity**; use `deq` for structural equality of Maps/Lists. |
| `def keys …` / `def node …` / `def eq …` | pick a non-reserved name (`ks`, `nd`) | `node keys vals has scan canon eq` are built-in (`[boru/reserved_word]`). |
| `def N 1000` for a number | `def n 1000` | a capitalised `def` binds a singleton **type**, not the value (`iota N` is `[]`). |
| `within`/`match` on a radix/tst/burst | pull `keys`/`entries`, rebuild a `TrieSet`/`TrieMap` | those queries exist on the standard trie only. |
| feed one variant's `encode` to another's `decode` | round-trip across variants via `keys`+`from-keys` / `entries`+`from-entries` | `decode` accepts only its own variant's snapshot and raises otherwise. |

## By design (not bugs)

- **Immutable, not mutable.** `set`/`add` return a new trie; for a genuinely
  **mutable** Map/List use `flex` (mutable Map) — don't expect `set` to mutate
  in place.
- **`each` is a MAP** — it must yield one value per element. For pure
  side-effects (no result), use `for`.
- **Integer overflow is fail-loud** — 63-bit; an overflow raises
  `integer_overflow` rather than wrapping. Intended.
- **One execution path.** `boru X` compiles to bytecode and runs on the VM
  (after a static pre-flight check); `--compile` / `--force-compile` are
  retired.

If the full repo is available, `AGENTS.md`, `api.json` (machine-readable
signatures), and `docs/reference.md` have the complete guide;
`test/trie_smoke_test.aql` is a runnable example across all four variants.
