# Forced-Cast Parsing Ambiguities

This document enumerates every syntactic form `(U)…` that is, or could be,
ambiguous between a **forced cast** and an **ordinary expression**, and states
how each of the two readings must be resolved.

## Background

A forced cast `(U)e` converts an `Extern<R>` handle to type `U`. It desugars to
`R.fromExtern<U>(e)`, where `R` is the runtime type taken from the operand's
`Extern<R>` type. Syntactically `(U)…` overlaps with a parenthesized value followed
by a call, and sits next to ordinary subscript/operator forms whose boundaries must
remain unchanged.

**Resolution rule (semantic):** branch selection depends only on what `U` resolves
to. If `U` resolves to a type, `(U)X` unconditionally takes the forced-cast branch;
`X` must then type-check as `Extern<R>`, otherwise the forced-cast diagnostic is
reported. If `U` does not resolve to a type, only the call form `(U)(args)` has an
ordinary reading, which is materialised as `U(args)`.

This distinction is intentional. In particular, `(User)(arg)` must not silently
fall back to the constructor call `User(arg)` when `User` is a type and `arg` is not
`Extern<R>`. Constructors use the canonical, unambiguous `User(arg)` spelling.

**AST representation:** every potentially-forced-cast site is parsed into a single
`AmbiguousForcedCastExpr { type, leftExpr, rightExpr }` node, where `type` is the
syntactic type candidate for `U`, `leftExpr` is the expression form derived from
that type candidate when one exists, and `rightExpr` is the operand, **parsed once
and shared** by both readings. Sema resolves `type` and materialises either the
forced-cast call or, for a non-type call form, the ordinary call. There is no
second operand parse and no exponential blow-up under nesting.

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
- **Cangjie — a genuine semantic ambiguity.** Whether the syntactic type candidate `U`
  denotes a type or a callable value is unknown until name and type resolution. No amount
  of token lookahead can decide it. The operand's `Extern<R>` type validates a selected
  forced cast; it does not decide whether to fall back to an ordinary call.

So the scenario and the triggering cause are different: Java's is a lookahead artifact the
parser clears up locally, Cangjie's is semantic and cannot be. The chain is therefore
**root cause** (a semantic cast-vs-call ambiguity) → **how it shows up** (the forms table
below, with Java for contrast) → **resolution** (the parser only records the ambiguity and
sema decides; see *Deferred-decision design*).

## Ambiguous forms

| Syntactic form / example | Reading A — forced cast (`U` a type, operand `Extern<R>`) | Reading B — ordinary (`U` a value) | Selected when | In Java |
|---|---|---|---|---|
| `(U)(e)`  — e.g. `(User)(handle)` | `R.fromExtern<User>(handle)` (cast of the operand `handle`) | `User(handle)` — `CallExpr` (call value `U` with arg `e`) | A whenever `U` resolves to a type; a non-`Extern` operand is then an error. B only when `U` does not resolve to a type | Not ambiguous: Java has no `value(args)` call operator. A bare **method name** is not an expression (you write `foo(e)`, never `(foo)(e)`), construction uses `new Foo(e)`, and a functional value is invoked through a method (`r.run()`). So `(U)(e)` can only be a cast of `(e)`; whether `U` is a type is settled by name resolution. |
| `(U)(e1, e2)` — e.g. `(f)(a, b)` | A forced-cast attempt with tuple operand `(e1, e2)` | `f(a, b)` — `CallExpr` with args `a`, `b` | A whenever `U` resolves to a type (normally rejected because the tuple is not `Extern<R>`); B when `U` is a callable value. The ordinary reading spreads the tuple elements into arguments | No analogue — Java has no tuple expression, so `(a, b)` is not a valid operand. |
| `(U)-e` — e.g. `(x)-makeExtern(1)` | *(would be)* `R.fromExtern<x>(-makeExtern(1))` — **never selected** | `x - makeExtern(1)` — `BinaryExpr` (subtraction) | **Always B, by language definition** (see note below) | Same outcome, resolved *syntactically*: Java's grammar forbids a **reference**-type cast from taking a `+`/`-` operand (`UnaryExpressionNotPlusMinus`, JLS §15.16), so `(Foo)-e` is binary `Foo - e`; only a **primitive** cast like `(int)-e` casts `-e`. |

### Note on `(U)-e`

`(U)-e` is **defined** to always parse as the binary expression `U - e`; it is
**never** treated as a forced cast of `-e`. This is deliberate: `-` is the only
token that is both a prefix-unary and a binary operator, so leaving `(U)-e`
ambiguous would be the one case that forces a genuine *structural* fork in the
AST (operand `-e` vs. binary `U - e`). By fixing it as binary, every remaining
ambiguity differs only in the *top* node (cast vs. call) while sharing
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
| `(U)[i]` — e.g. `(holder)[0]` | Subscript on the parenthesised expression `U`. `[` is explicitly excluded from forced-cast recognition |
| `(U)+e`, `(U)*e`, `(U)/e`, `(U)<e`, `(U)==e`, … | Binary expression only. `+ * / < ==` … (and every binary-only operator) have no prefix-unary form, so `U` is necessarily a value |
| `(U).f` — e.g. `(holder).field` | Member access on `(U)` only. A forced-cast operand cannot begin with `.` |
| `(U)(name: e)` — labeled argument | No forced-cast reading exists because a labeled argument list is not an expression operand. This spelling remains invalid for both type and function callees; constructors and named function calls must use the direct callee forms `Type(name: e)` and `func(name: e)` |

## Operand binding and trailing postfix

The two operand shapes bind trailing postfix differently, and this is what
distinguishes them in the AST:

- **Juxtaposition `(U)e…`** absorbs the *whole* postfix chain into the operand.
  `(U)e.f`, `(U)e.f()`, `(U)e[i]` parse as `(U)(e.f)`, `(U)(e.f())`, `(U)(e[i])` —
  the operand `rightExpr` is the full postfix expression `e.f`/`e.f()`/`e[i]`, so a
  forced cast applies `fromExtern` once to the fully-resolved operand.
- **Call form `(U)(e)…`** captures only the *immediate* `(e)`; any further postfix
  attaches to the **resolved** node. Thus
  `(consume)(e).f` is `(consume(e)).f` — call first, then member access — and
  `(User)(handle).f` is `(User.fromExtern(handle)).f`. This asymmetry is required
  so that a chained call like `(f)(a)(b)` reads as `((f a) b)` rather than trying
  to treat `(b)` as part of the operand.

The immediate form `(U)[i]` is not one of these operand shapes: it remains a normal
subscript on `(U)` and never creates `AmbiguousForcedCastExpr`.

## Diagnostics

Selection failures are reported according to the resolved role of `U`:

- **`U` is a type, operand is not `Extern<R>`, juxtaposition `(U)e`** — there is no
  ordinary reading, so this is reported as a malformed forced cast:
  *"invalid interoperation forced cast: `(U)e` requires `U` to be a type and `e` to
  be an expression of `Extern` type; use `as` for ordinary type conversions"*.
- **`U` is a type, operand is not `Extern<R>`, call form `(U)(args)`** — report the
  forced-cast diagnostic immediately. Do not try `U(args)`, even if `U` has a matching
  constructor. The constructor spelling is `U(args)`.
- **`U` is not a type, call form `(U)(args)`** — materialise the ordinary call and
  use its normal diagnostics (for example, undeclared callee or call-arity errors).
- **`U` is not a type, juxtaposition `(U)e`** — there is no ordinary reading; keep
  the node invalid and allow the operand/name-resolution diagnostics to surface.

## Deferred-decision design

The cast-vs-ordinary choice cannot be made at parse time because it depends on whether
`U` resolves to a type. The parser therefore emits one node carrying the material for
both readings, and the type checker commits to one. Whether the operand is `Extern<R>`
is checked only after the forced-cast branch has been selected.

### The node (parser output)

```
AmbiguousForcedCastExpr {
    OwnedPtr<Type> type;       // syntactic type candidate for `U`
    OwnedPtr<Expr> leftExpr;   // expression form derived from `U` (null if unavailable)
    OwnedPtr<Expr> rightExpr;  // the operand, parsed once, shared by both readings
}
```

The parser speculatively parses the content of `(…)` as a type; on success it builds
this node. `leftExpr` is *derived* from `type` (not re-parsed) and `rightExpr` is parsed
exactly once. Whether an ordinary *call* reading exists is read back from `rightExpr`'s
kind — the call form `(U)(args)` yields a ParenExpr / TupleLit / unit; the juxtaposition
form `(U)e` never does.

### Selection (sema)

`SynAmbiguousForcedCastExpr` resolves `type` under diagnostic suppression, since the
candidate may legitimately name a value, and then picks:

1. `type` resolves to a type
   → select **forced cast** unconditionally; if the operand synthesises to
   `Extern<R>`, desugar to `R.fromExtern<U>(operand)`, otherwise report the
   forced-cast diagnostic.
2. `type` does not resolve to a type, and this is call form `(U)(args)`
   → **ordinary call**: materialise `U(args)` from `leftExpr` + `rightExpr`.
3. otherwise (non-type juxtaposition, no ordinary reading)
   → keep an invalid result and surface the relevant operand/name diagnostics.

On successful selection the chosen reading is stored in the inherited `desugarExpr`;
every later pass (including CHIR) follows `desugarExpr`, and the ambiguous node itself
is never lowered. The single
*shared* `rightExpr` is what keeps nesting linear — no second parse, nothing duplicated
per level. Call-form operands are parsed with the outer forced-cast attempt disabled, so
trailing `(args)`, `[i]`, and `.member` bind to the resolved result and continuous call
chains remain left-associative.

## Macro / `std.ast` support

`AmbiguousForcedCastExpr` is part of the macro AST round-trip rather than a
compiler-private dead end:

- the compiler serialises the target type, parentheses, and operand through the
  FlatBuffers macro schema;
- `std.ast` exposes `AmbiguousForcedCastExpr` with mutable `targetType`, `lParen`,
  `rParen`, and `expr` properties, plus `toTokens`, `traverse`, and `dump`;
- `parseExpr`, generic node parsing, macro position updates, and `Visitor` dispatch all
  recognise the node;
- declaration and expression macros may preserve it, construct it from tokens, remove
  or add wrappers, retarget it, and rewrite it through a visitor.

After macro expansion the same semantic rule still applies: a type-valued target selects
forced-cast semantics, and a non-`Extern` operand produces the normal forced-cast
diagnostic rather than falling back to construction.

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
