# Using the trie library (agent guide)

Guidance for an AI coding agent **using** this boru trie library (in this repo or
a downstream project) and **extending** it. Human docs: `README.md`, `docs/`
(Diátaxis), full signatures in `docs/reference.md`, machine-readable API in
`api.json`, design notes and boru foot-guns in `DX-REPORT.md`.

The four modules depend only on the **standard `boru:struct-util` module**
(map enumeration + jsonic parse/serialise), which ships with `boru` — no
third-party dependencies. Every example below is verified against boru main
@ `64c5ab2` (2026-09-30).

---

## Getting the library into a project

**Vendor (simplest).** Copy the four module files (`trie.aql`, `radix.aql`,
`tst.aql`, `burst.aql`) into the consumer project, e.g. `lib/trie/`, then:

```boru
import "./lib/trie/trie.aql"
```

A relative import resolves **against the importing file's own directory**, not
the directory you run `boru` from — so a script at the project root writes
`./lib/trie/trie.aql`, and a test under `test/` writes `../lib/trie/trie.aql`.
(This changed upstream; older boru resolved against the working directory.)

**Registry.** If published: `boru install trie-<version>`, then `import "trie"`
loads the package `main` (`trie.aql` → `TrieMap`/`TrieSet`); import other
variants by their file.

Each module is self-contained — vendor only the variant(s) you use.

---

## Calling convention (read this first)

> **In one line.** Forward args, receiver (the trie) **last**:
> `TrieSet.add key t`. Piping `t TrieSet.add key` also works; only
> `TrieSet.add t key` misbinds. Tries are **persistent** — rebind the result.

- **One binding rule.** A call fills its parameters **in signature order**:
  first from the tokens written after the word (the forward arguments), then
  every remaining position from the value stack, top of stack first. A call
  form only chooses where that split falls.
- **The receiver (the trie) is the LAST parameter** of every Set/Map word, so
  three shapes bind identically: **forward (canonical)** `TrieMap.set value key t`
  — arguments forward, receiver last; **pipe** `t TrieMap.set value key` — the
  receiver flows in from the left; and **all-stack** `t key value TrieMap.set`.
  Only **receiver-first, all-forward** misbinds: `TrieMap.set t key value` puts
  the trie in the value slot, and boru rejects it before the run
  (`uncalled_function: call to 'map-set' matched no signature`). Each
  `add`/`set`/`delete` returns a new trie, so the receiver threads through
  chains and folds either way.
- **Forward arguments have precedence.** A word grabs the tokens *after* it,
  stops at the next function word or a closing paren, and otherwise takes what
  it needs from the stack. A paren group is therefore the clean way to use a
  call's result: `(t "x" TrieSet.has)`.
- **Disambiguate when a bare literal follows a call.** If a type-compatible
  literal sits immediately after a stack-form call with no word or paren
  between, forward precedence consumes it. Resolve it with parens, a trailing
  `end`, or the **`/s` modifier**, which pins that call to stack args:
  `5 5 cmp/s 9` compares `5` and `5` (leaving `9`), whereas `5 5 cmp 9`
  forward-grabs the `9`.
- **`print` collects forward too.** `5 print 6 print` prints `6` then `5` (the
  first `print` takes the `6` written after it), and a statement-level
  `(x) print` with more code after it grabs whatever comes next. Write
  **`print (value)`** — verb first, one value per statement — or terminate
  each statement (`5 print ; 6 print`, `(x) print end`). Every example here
  uses `print (…)`.
- **Don't "fully forward" a receiver-first call.** Mixed form (receiver before
  the word, trailing args forward — `key slice 0 1`, `nd ch find-kid`,
  `acc pfx push`) is already the *maximum safe* forward usage. Moving the
  receiver after the word changes the binding: forward fills `sig[0]` first, so
  operands of a non-commutative word **reverse** (`10 3 sub` is `7`,
  `sub 10 3` is `-7`); `get m "k"` matches no signature where `m "k" get`
  works; and a partial-arity native like `slice` fires on the receiver alone
  (`slice key 0 1` returns the whole string, stranding `0 1`). A terminator
  does **not** fix any of these — they are argument binding, not over-grab.
- **Tries are immutable.** `add` / `set` / `delete` return a *new* trie and
  leave the input unchanged — **always rebind the result**:

  ```boru
  def t1 (t0 "cat" TrieSet.add)   # t0 is unchanged; use t1
  ```

---

## Pick a variant (all share one API)

| Variant (file) | Namespaces | Use when |
|---|---|---|
| standard trie (`trie.aql`) | `TrieSet` / `TrieMap` | the default; also the only one with `within`/`match` |
| radix / PATRICIA (`radix.aql`) | `RadixSet` / `RadixMap` | long, sparse keys — fewer nodes |
| ternary search tree (`tst.aql`) | `TstSet` / `TstMap` | large/Unicode alphabets |
| burst / HAT (`burst.aql`) | `BurstSet` / `BurstMap` | flat, cache-friendly buckets |

The variants are behaviourally identical (the property suite cross-checks them);
**start with the standard trie.**

---

## Essential patterns (copy-paste, runnable)

```boru
import "./trie.aql"

# Forward canonical (key forward, receiver LAST); rebind — tries are immutable.
def s0 (TrieSet.make)
def s1 (TrieSet.add "cat" s0)          # NOT `TrieSet.add s0 "cat"` (misbinds)
print (TrieSet.has "cat" s1)           # => true

# Build a set from a list of keys (fold; each add returns the next trie).
# fold runs `init list [body] fold`; the body gets each key `w` and the
# accumulator `acc`, and returns the next trie.
def words ["apple" "app" "apply" "banana"]
def s ((TrieSet.make) words [ var [[w acc] acc w TrieSet.add end ] ] fold)

# Membership.
print (s "app" TrieSet.has)            # => true
print (s "ap"  TrieSet.has)            # => false  (a prefix is not a member)

# Autocomplete: every key under a prefix, sorted.
print (s "app" TrieSet.with-prefix)    # => ["app", "apple", "apply"]

# Longest stored key that prefixes a query.
print (s "applesauce" TrieSet.longest-prefix)   # => apple

# Delete (rebind; keys below the deleted one survive).
def s2 (s "app" TrieSet.delete)
print (s2 "app"   TrieSet.has)         # => false
print (s2 "apple" TrieSet.has)         # => true

# Map: bind values (any type) to keys.
def m (((TrieMap.make) "GET" 1 TrieMap.set) "POST" 2 TrieMap.set)
print (m "GET"    TrieMap.get)         # => 1
print (m "DELETE" TrieMap.get)         # => none  (absent — not an error)
print (m TrieMap.entries)              # => [["GET", 1], ["POST", 2]]  (sorted)

# Fuzzy (edit-distance) and wildcard search — STANDARD TRIE ONLY.
print (s "aple" 1 TrieSet.within)      # => ["apple"]  (Levenshtein distance ≤ 1)
print (s "ap*"  TrieSet.match)         # => ["app", "apple", "apply"]  (`?` one char, `*` any run)

# Persist + rebuild: encode/decode round-trip (decode raises a catchable
# error on a payload of the wrong kind).
def snapshot (m TrieMap.encode)        # JSON text — write it anywhere
def m2 (snapshot TrieMap.decode)       # …and rebuild later
print (m2 "POST" TrieMap.get)          # => 2
# Data-level round-trips also work: keys+from-keys, entries+from-entries.
```

---

## API at a glance

`Set` namespaces (`TrieSet`, `RadixSet`, `TstSet`, `BurstSet`):

`make` · `add` · `has` · `delete` · `with-prefix` · `longest-prefix` · `keys` ·
`size` · `height` · `from-keys` · `encode` · `decode`

`Map` namespaces (`TrieMap`, `RadixMap`, `TstMap`, `BurstMap`):

`make` · `set` · `get` · `has` · `delete` · `keys-with-prefix` ·
`entries-with-prefix` · `longest-prefix` · `keys` · `values` · `entries` ·
`size` · `height` · `from-entries` · `encode` · `decode`

`TrieSet`/`TrieMap` add `within` (fuzzy) and `match` (wildcard).

Exact call-forms, arg order, and return types: `api.json` (structured) and
`docs/reference.md` (prose).

---

## Rules the agent MUST follow

1. **Rebind** the result of `add`/`set`/`delete` — tries never mutate in place.
2. **Receiver (the trie) is the LAST argument** for the trie words: forward
   `Map.set value key t`, or pipe `t Map.set value key`. Only receiver-first
   all-forward (`Map.set t key value`) misbinds.
3. **Forward args have precedence**; a call resolves at the next function word
   or paren. Add parens, `end`, or `/s` (force stack) only to stop a bare
   following literal from being grabbed. Print with `print (value)`.
4. `keys`, `values`, `entries`, `with-prefix`, `keys-with-prefix`,
   `entries-with-prefix` are **key-sorted**.
5. `get` returns `none` and `has` returns `false` for an absent key — never an
   error. Use `has` to tell "absent" from "present with value `none`".
6. `within` / `match` exist on **`TrieSet`/`TrieMap` only**. For another
   variant, pull its `keys`/`entries` and rebuild a `TrieSet`/`TrieMap`.
7. **`decode` is strict about variants**: each namespace decodes only its own
   `encode` payloads and **raises** (catchable with `do […] error […]`) on any
   other kind. Cross-variant transfer goes through the data words
   (`keys`+`from-keys`, `entries`+`from-entries`).
8. An **empty `TstSet`/`TstMap` is `none`**, not a Map — only relevant if you
   inspect the raw trie value rather than calling namespace words.
9. To compare two key lists, use **`deq`** (structural deep equality) or
   `Assert.equal` in tests — **boru's `eq` on lists is identity, not structural**
   (`["a"] ["a"] eq` is `false`, `["a"] ["a"] deq` is `true`).
10. A value read back through `decode` compares equal under `eq`/`deq`, but a
    decoded `none` (JSON `null` hydrated) is **not** `Assert.equal` to the
    `none` literal — assert with `eq` in that one case.
11. **Pass a function as data with `/v`.** A bare name (or namespace member)
    that holds a function now **calls** wherever it appears; write
    `TrieSet.has/v` to hand the word over as a value. (`/v` replaced the old
    `/r` modifier.)

---

## Verifying your code

Build/locate `boru`, then run a scratch script or the suites:

```bash
boru path/to/your_script.aql        # compile + run your code (one path: bytecode VM)
boru check path/to/your_script.aql  # static check on its own
boru test/trie_smoke_test.aql       # library smoke demo across all variants
test/divergence/run.sh              # the full gate: every suite + boru check (see its README)
```

boru has **one execution path**: a program compiles to bytecode and runs on the
VM, or fails with `[boru/compile_failed] … this is a compiler defect`. The old
`--compile` / `--force-compile` / `--no-compile` flags are retired (usage
errors). `boru X` runs the static check first and refuses on a check error.

In this repo a SessionStart hook (`.claude/settings.json` →
`.claude/hooks/session-start.sh`) builds `boru` from boru-lang/boru `main` if
needed and runs the smoke check, so a fresh session is ready to verify.

---

## Extending the library (contributors)

Read `DX-REPORT.md` for the full account (its newest section is the migration to
boru main @ `64c5ab2`); the load-bearing boru traps are:

- **Children are computed-key Maps** (`{[k]: v}` literals, copy-returning
  `kids set (ch) child`, `StructUtil.items` enumeration — items is
  **key-sorted**, which is what makes traversal output sorted by
  construction). To drop a key the library rebuilds the map from its items,
  skipping the key; core `del` (copy-returning on a Map) now exists too and
  would be an equivalent, simpler spelling.
- **`StructUtil.items` sorts; the native map words do NOT.** Enumerate node
  children only with `StructUtil.items` (key-sorted). The native map-iteration
  words — `each`/`for-each`/`fold`/`filter` over a Map, plus `keys`/`vals` —
  walk entries in **insertion order**, and a node map built by repeated
  `kids set (ch) child` is in insertion order, not sorted. Swapping a sorted
  `StructUtil.items` fold for a native `m vals`/`m […] fold` therefore
  **silently breaks** the key-sorted guarantee (rule 4). Core `sort` on a Map
  sorts by **value**, not key, so it is no substitute. Verified at `64c5ab2`: a
  `set`-built `{c:3,a:1,b:2}` gives `StructUtil.items` `[[a 1][b 2][c 3]]` but
  `keys` `[c a b]`.
- **Never use `StructUtil.merge` to update a node** — it is a *deep,
  index-wise* merge (`merge` is no longer a core word). Rebuild nodes with the
  explicit `mk-*` constructor; `StructUtil.setpath` is the one-field update if
  you ever need it.
- **Signature order = reverse of all-stack call order** (with every argument
  on the stack, the first parameter is the top of the stack). A call that
  matches no signature is loud: `boru check` (and the pre-flight check every
  `boru X` run does) reports `uncalled_function` / `no_signature`.
- **Reserved binding names**: `end` (call terminator), **`node`** (a built-in
  word — this library names node bindings `nd`), **`keys`**, **`vals`**,
  **`has`**, **`scan`**, **`canon`** and **`eq`** (this library renamed its
  `keys`-list bindings to `ks`; `val` is *not* reserved, only the plural
  `vals`). Reserved names are loud at bind time (`[boru/reserved_word]`).
  **Capitalised names bind types**: `def N 1000` makes `N` a singleton
  literal type, not the Integer (so `iota N` is `[]`) — keep every value
  binding lowercase.
- **Index lists as `xs get (i)`**: a parenthesised key is always computed (JS
  `[expr]`). On boru main a bare def-bound word after `get` also resolves to
  its value, but the parenthesised form is unambiguous.
- **Build path strings with core `add`** (`pfx ch add`); `concat`/`indexof`/
  `contains` live in `boru:string-util`, which is **subject-last**
  (`StringUtil.contains needle haystack` forward; haystack pushed first in
  stack form).
- **`fold` binds `[element accumulator]`** (element first, accumulator on top).
- **A var-bound name does not resolve inside a nested list literal** —
  `var [[pair a] … a [(pair get 1)] push]` fails with `undefined word`;
  bind through `def` first (`def v (pair get 1)`, then `[v]`).
- **Initialise a `fold` accumulator with a plain map literal**, not
  `do {k: [v]}`: inside a fn body, a `do {…}` at the head of a paren that then
  reads a fn-local def loses that def (an open boru compiler defect —
  `radix.aql`'s `common-len` carries the workaround).
- **`filter` takes a `[…]` quotation** like `each`/`fold` (var-destructure
  bodies included), so keep-folds are only needed when the predicate must see
  the accumulator.
- **Receiverless Reach lenses** (`$.field`, `$.0`) are inert `Reach` values
  that `each`/`filter` apply per element — `(t map-entries) each $.1` plucks
  the value column, and `radix.aql` plucks `items` pairs with `each $.1`.
- **`raise "message"`** raises a catchable error (`do […] error […]`); in the
  handler `e "message" get` compares equal to a String (it is a
  `ProperString`); the library still passes it through `convert String`,
  which is harmless.
- **Serialise with `StructUtil.jsonify`, parse with `StructUtil.parse`.**
  String-interpolating a structure (`` `${payload}` ``) is a display form, not
  JSON; `jsonify` writes JSON `null` for `none`, which `parse` hydrates back.

To add a variant: mirror an existing module's structure, export a `…Set` and a
`…Map`, add `test/<variant>_unit_test.aql` plus `test/<variant>_prop_spec.aql`
(keep the trie-equivalence cross-check; import the modules as `../<variant>.aql`),
and add the new suites to `SUITES` in `test/divergence/run.sh` (CI runs that
script).
Test files follow `<subject>_<unit|prop>_<test|spec>.aql`: `_test` = imperative
(`Test.test`/`Test.check-prop`), `_spec` = declarative; the standard trie ships
all four surfaces (`trie_unit_test`, `trie_unit_spec`, `trie_prop_test`,
`trie_prop_spec`) as the reference, plus one `trie_smoke_test.aql`.
