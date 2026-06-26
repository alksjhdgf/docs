# Forced-Cast Parsing Ambiguities

This document enumerates every syntactic form `(U)…` that is, or could be,
ambiguous between a **forced cast** and an **ordinary expression**, and states
how each of the two readings must be resolved.

## Background

A forced cast `(U)e` converts an `Extern<R>` handle to type `U`. It desugars to
`R.fromExtern<U>(e)`, where `R` is the runtime type taken from the operand's
`Extern<R>` type. Syntactically `(U)…` looks identical to a parenthesized value
`(U)` followed by a call / subscript / operator, so the two readings must be
disambiguated.

**Resolution rule (semantic):** a `(U)X` form is a forced cast **iff** `U` parses
as a *type* **and** the operand is of type `Extern<R>`. Otherwise it is the
ordinary reading. Note that a name like `User` parses as *both* a type and an
expression, so "the type reading succeeded" is **not** sufficient on its own — the
operand being `Extern<R>` is the deciding condition.

**AST representation:** every potentially-forced-cast site is parsed into a single
`AmbiguousForcedCastExpr { type, leftExpr, rightExpr }` node, where `type` is `U`
parsed as a type, `leftExpr` is `U` parsed as an expression (either may be
`nullptr` if that parse is not valid), and `rightExpr` is the operand, **parsed
once and shared** by both readings. Sema selects one reading and materializes it
(moving `rightExpr` into the chosen form); there is no second parse and no
exponential blow-up under nesting.

## Root cause: a semantic ambiguity, unlike Java's

Cangjie's forced-cast ambiguity and the cast ambiguity in C-style languages like Java come
from different causes and are resolved at different stages:

- **Java — a temporary, local parsing ambiguity.** Under the bounded (LALR(1)) lookahead
  that drives normal parsing, a `(Name)…` prefix is *momentarily* ambiguous, but reading a
  few more tokens ahead settles it entirely **within the parser** — no type information is
  needed. Java's only cast ambiguity, `(U)-e`, is then fixed by a grammar device (a
  reference-type cast may not take a `+`/`-` operand, `UnaryExpressionNotPlusMinus`). And
  Java has no `value(args)` call operator at all, so the cast-vs-call case never even
  arises.
- **Cangjie — a genuine semantic ambiguity.** Whether `(U)X` is a forced cast or an
  ordinary call depends on whether `U` resolves to a type *and* whether the operand is
  `Extern<R>` — facts unknown until type checking. No amount of lookahead can decide it; it
  is not resolvable in the parser at all.

So the scenario and the triggering cause are different: Java's is a lookahead artifact the
parser clears up locally, Cangjie's is semantic and cannot be. The chain is therefore
**root cause** (a semantic cast-vs-call ambiguity) → **how it shows up** (the forms table
below, with Java for contrast) → **resolution** (the parser only records the ambiguity and
sema decides; see *Deferred-decision design*).

## Ambiguous forms

| Syntactic form / example | Reading A — forced cast (`U` a type, operand `Extern<R>`) | Reading B — ordinary (`U` a value) | Selected when | In Java |
|---|---|---|---|---|
| `(U)(e)`  — e.g. `(User)(handle)` | `R.fromExtern<User>(handle)` (cast of the operand `handle`) | `User(handle)` — `CallExpr` (call `U` with arg `e`) | A if `U` is a type and `e` is `Extern<R>`; otherwise B | Not ambiguous: Java has no `value(args)` call operator. A bare **method name** is not an expression (you write `foo(e)`, never `(foo)(e)`), construction uses `new Foo(e)`, and a functional value is invoked through a method (`r.run()`). So `(U)(e)` can only be a cast of `(e)`; whether `U` is a type is settled by name resolution. |
| `(U)(e1, e2)` — e.g. `(User)(a, b)` | `R.fromExtern<User>((a, b))` (cast of the **tuple** `(a, b)`) | `User(a, b)` — `CallExpr` with args `a`, `b` | A if `U` is a type and the tuple operand is `Extern<R>` (rare); otherwise B. The shared `rightExpr` is the tuple; the call reading spreads its elements into arguments | No analogue — Java has no tuple expression, so `(a, b)` is not a valid operand. |
| `(U)[i]` — e.g. `(User)[0]` | `R.fromExtern<User>([0])` (cast of the **array literal** `[0]`) | `User[0]` — `SubscriptExpr` (index `U` by `i`) | A if `U` is a type and the array-literal operand is `Extern<R>` (rare); otherwise B | No analogue — Java has no array-literal operand; `[i]` cannot start an expression. |
| `(U)-e` — e.g. `(x)-makeExtern(1)` | *(would be)* `R.fromExtern<x>(-makeExtern(1))` — **never selected** | `x - makeExtern(1)` — `BinaryExpr` (subtraction) | **Always B, by language definition** (see note below) | Same outcome, resolved *syntactically*: Java's grammar forbids a **reference**-type cast from taking a `+`/`-` operand (`UnaryExpressionNotPlusMinus`, JLS §15.16), so `(Foo)-e` is binary `Foo - e`; only a **primitive** cast like `(int)-e` casts `-e`. |

### Note on `(U)-e`

`(U)-e` is **defined** to always parse as the binary expression `U - e`; it is
**never** treated as a forced cast of `-e`. This is deliberate: `-` is the only
token that is both a prefix-unary and a binary operator, so leaving `(U)-e`
ambiguous would be the one case that forces a genuine *structural* fork in the
AST (operand `-e` vs. binary `U - e`). By fixing it as binary, every remaining
ambiguity differs only in the *top* node (cast vs. call/subscript) while sharing
the same operand sub-tree, so no dual AST is ever needed.

To force a cast of a negated operand, parenthesize it explicitly:

```cangjie
(U)(-e)   // forced cast of (-e); this is the (U)(e) form with e = -e
```

## Unambiguous forms (for contrast — no dual reading)

These `(U)…` forms have only one valid reading and are listed only to make the
boundary explicit.

| Form / example | Sole reading |
|---|---|
| `(U)value` — juxtaposition, e.g. `(User)value` | Forced cast only. `(U) value` is not a valid expression (two adjacent expressions), so there is no ordinary reading |
| `(U)!e` — e.g. `(User)!flag` | Forced cast of `!e` only. `!` has no binary form, so there is no binary reading |
| `(U)+e`, `(U)*e`, `(U)/e`, `(U)<e`, `(U)==e`, … | Binary expression only. `+ * / < ==` … (and every binary-only operator) have no prefix-unary form, so `U` is necessarily a value |
| `(U).f` — e.g. `(holder).field` | Member access on `(U)` only. A forced-cast operand cannot begin with `.` |
| `(U)(name: e)` — labeled argument | Call only. A labeled argument list cannot be parsed as a tuple/expression operand, so the cast reading does not exist |

## Operand binding and trailing postfix

The two operand shapes bind trailing postfix differently, and this is what
distinguishes them in the AST:

- **Juxtaposition `(U)e…`** absorbs the *whole* postfix chain into the operand.
  `(U)e.f`, `(U)e.f()`, `(U)e[i]` parse as `(U)(e.f)`, `(U)(e.f())`, `(U)(e[i])` —
  the operand `rightExpr` is the full postfix expression `e.f`/`e.f()`/`e[i]`, so a
  forced cast applies `fromExtern` once to the fully-resolved operand.
- **Call/subscript form `(U)(e)…` / `(U)[i]…`** captures only the *immediate*
  `(e)` / `[i]`; any further postfix attaches to the **resolved** node. Thus
  `(consume)(e).f` is `(consume(e)).f` — call first, then member access — and
  `(User)(handle).f` is `(User.fromExtern(handle)).f`. This asymmetry is required
  so that a chained call like `(f)(a)(b)` reads as `((f a) b)` rather than trying
  to treat `(b)` as part of the operand.

## Diagnostics

Selection failures are reported according to which reading was attempted:

- **`U` is a type, operand is not `Extern<R>`, juxtaposition `(U)e`** — there is no
  ordinary reading, so this is reported as a malformed forced cast:
  *"invalid interoperation forced cast: `(U)e` requires `U` to be a type and `e` to
  be an expression of `Extern` type; use `as` for ordinary type conversions"*.
- **`U` is a type, operand is not `Extern<R>`, call form `(U)(args)`** — the
  ordinary reading `U(args)` is attempted first. If it type-checks (e.g. `args`
  matches a constructor) it is used; if it does **not** type-check, the construct is
  reported with the same forced-cast diagnostic (the malformed forced cast is the
  more specific explanation, since the `(U)(…)` shape signalled cast intent).
- **`U` is not a type** — there is no forced-cast candidate; the ordinary reading's
  own diagnostics apply (e.g. an undeclared-identifier or call-arity error).

## Deferred-decision design

The cast-vs-ordinary choice cannot be made at parse time — it depends on whether `U`
resolves to a type and whether the operand is `Extern<R>`, both known only in sema. So
the parser does not decide: it emits one node carrying the material for both readings,
and the type checker commits to one.

### The node (parser output)

```
AmbiguousForcedCastExpr {
    OwnedPtr<Type> type;       // `U` parsed as a type       (null if not a valid type)
    OwnedPtr<Expr> leftExpr;   // `U` parsed as an expression (null if not a valid expr)
    OwnedPtr<Expr> rightExpr;  // the operand, parsed once, shared by both readings
}
```

The parser speculatively parses the content of `(…)` as a type; on success it builds
this node. `leftExpr` is *derived* from `type` (not re-parsed) and `rightExpr` is parsed
exactly once. Whether an ordinary *call* reading exists is read back from `rightExpr`'s
kind — the call form `(U)(args)` yields a ParenExpr / TupleLit / unit; the juxtaposition
form `(U)e` never does.

### Selection (sema)

`SynAmbiguousForcedCastExpr` resolves `type` (under diagnostic suppression, since it may
legitimately not be a type) and then picks:

1. `type` is a type **and** the operand synthesises to `Extern<R>`
   → **forced cast**: desugar to `R.fromExtern<U>(operand)`.
2. else, call form `(U)(args)`
   → **ordinary call**: materialise `U(args)` from `leftExpr` + `rightExpr`.
3. else (juxtaposition, no valid cast)
   → **error** (the forced-cast diagnostic when `U` is a type).

The chosen reading is stored in the inherited `desugarExpr`; every later pass (including
CHIR) follows `desugarExpr`, and the ambiguous node itself is never lowered. The single
*shared* `rightExpr` is what keeps nesting linear — no second parse, nothing duplicated
per level. (This deferral is forced by the *semantic* nature of the ambiguity — see
*Root cause* above.)

## Benchmark

Compile times of `forced_cast/benchmark/` (from `generate_forced_cast_benchmarks.py`).
Breadth cases repeat a shape 10 000× (per-`(` speculation cost); depth cases scale nesting
depth.

**Measured stage — `cjc --emit-chir=raw` (front end only: lex → parse → sema → CHIR; no
LLVM back end).** This is deliberate. The forced-cast cost lives entirely in the *parse*
stage, but the LLVM back end's cost grows with the number of statements and, in a full
`cjc` compile of a 10 000-statement file, dominates the wall clock — it would swamp the
parse-stage difference (an early measurement with full `cjc` showed a misleading "×4–6"
that was almost all back end, since the produced AST is identical with or without the
feature). Stopping at CHIR isolates the front-end overhead the feature actually adds.

What each case generates (one line repeated `count`× for breadth; nested to depth `d`
for depth cases):

- `ordinary_parens` — `sink += (i + 1)`: a plain parenthesised arithmetic expression; no
  cast shape, but every `(` still triggers the speculative type parse.
- `type_shaped_parens` — `sink += (foo) + i`: `(foo)` *is* a valid type parse (a bare
  name), but the `+` after `)` rules out a cast — measures the cost of speculating and
  rewinding when the type reading exists yet is rejected.
- `ambiguous_fallback` — `sink += (foo)-i * 2`: the `(U)-e` form, always binary.
- `nested_same_type_parens` — `sink += ((((( i + 1 )))))`: five-deep redundant parens.
- `nested_mixed_parens` — `sink += (((foo + (i))) * ((bar - (i % 7))))`: mixed deep parens
  with arithmetic (heaviest breadth case).
- `deep_parens` — `(((( … 0 … ))))`: `d`-deep pure parens around `0`; the only case the
  no-feature baseline can also compile, so it isolates plain parenthesis-nesting cost.
- `nested_forced_cast` — `(Target)((Extern<DummyRuntime>)( … (value) … ))`: `d` nested
  *confirmed* forced casts unwrapping a `d`-deep `Extern` handle.
- `nested_ambiguous` — `(Target)((passExtern)( … (externValue) … ))`: a forced cast wrapped
  around `d` nested ordinary fallback calls `(passExtern)(…)`.

**Breadth** (10 000×, `--emit-chir=raw`, best of several runs):

| Case | This impl | No-feature baseline¹ | Overhead |
|---|---:|---:|---:|
| `ordinary_parens` | ~985 ms | 864 ms | +2 % |
| `type_shaped_parens` | ~865 ms | 691 ms | +13 % |
| `ambiguous_fallback` | ~1240 ms | 1105 ms | +13 % |
| `nested_same_type_parens` | ~1380 ms | 1129 ms | +13 % |
| `nested_mixed_parens` | ~2500 ms | 2178 ms | +5 % |

¹ a previously-captured no-feature build (same `--emit-chir=raw` method), not rebuilt
locally now, so treat the `%` as indicative. The per-`(` front-end overhead is
single-to-low-double-digit percent and tracks the case shape — lightest for plain
arithmetic parens, heaviest where a `(name)` type reading is speculated then rejected.

**Depth** (`--emit-chir=raw`, d = 8 / 20 / 30):

| Case | d8 | d20 | d30 |
|---|---:|---:|---:|
| `deep_parens` | 92 ms | 92 ms | 92 ms |
| `nested_forced_cast` | 97 ms | 95 ms | 95 ms |
| `nested_ambiguous` | 94 ms | 95 ms | 95 ms |

Reading: the per-`(` cost is a *constant* (one speculative type parse + a cheap rewind) and
does not compound with nesting — depth is **flat**, and `deep_parens` (pure parens, no
cast) is unaffected. The single shared `rightExpr` is what keeps it linear: nothing is
re-parsed or duplicated per nesting level.
