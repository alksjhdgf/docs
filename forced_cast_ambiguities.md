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

## Ambiguous forms

| Syntactic form / example | Reading A — forced cast (`U` a type, operand `Extern<R>`) | Reading B — ordinary (`U` a value) | Selected when |
|---|---|---|---|
| `(U)(e)`  — e.g. `(User)(handle)` | `R.fromExtern<User>(handle)` (cast of the operand `handle`) | `User(handle)` — `CallExpr` (call `U` with arg `e`) | A if `U` is a type and `e` is `Extern<R>`; otherwise B |
| `(U)(e1, e2)` — e.g. `(User)(a, b)` | `R.fromExtern<User>((a, b))` (cast of the **tuple** `(a, b)`) | `User(a, b)` — `CallExpr` with args `a`, `b` | A if `U` is a type and the tuple operand is `Extern<R>` (rare); otherwise B. The shared `rightExpr` is the tuple; the call reading spreads its elements into arguments |
| `(U)[i]` — e.g. `(User)[0]` | `R.fromExtern<User>([0])` (cast of the **array literal** `[0]`) | `User[0]` — `SubscriptExpr` (index `U` by `i`) | A if `U` is a type and the array-literal operand is `Extern<R>` (rare); otherwise B |
| `(U)-e` — e.g. `(x)-1` | *(would be)* `R.fromExtern<x>(-1)` — **never selected** | `x - 1` — `BinaryExpr` (subtraction) | **Always B, by language definition** (see note below) |

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
