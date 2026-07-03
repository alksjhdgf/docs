# Forced-cast `(X)(Y)(Z)`: cast-vs-call across C, Java, Cangjie

Companion to `forced_cast_ambiguities.md`, focused on how the `(X)(Y)` cast-vs-call
ambiguity is handled in C and Java, and where Cangjie's implementation diverges and breaks.

## The ambiguity

`(a)(b)` is a **cast** of `b` to `a` when `a` is a type, or a **call** `a(b)` when `a` is
a value. The two readings have opposite associativity:

- a cast prefix `(U)` grabs the expression to its right → **right-associative**;
- a postfix call chains left → **left-associative**.

So the grouping of `(X)(Y)(1)` depends on what `X` and `Y` are.

## C — decided at parse time (the "lexer hack")

C's lexer consults the symbol table, so at each `(` the parser already knows whether the
next token is a type-name (`typedef`) or a value. The decision is deterministic, no
backtracking. `X`'s classification at the *first* `(` alone fixes cast-mode (right-assoc)
vs value-mode (left-assoc):

| `(X)(Y)(1)` | grouping | meaning |
|---|---|---|
| X type, Y type | `(X)((Y)(1))` | nested casts (right-assoc) |
| X type, Y func | `(X)(Y(1))` | cast of a call |
| X func, Y func | `((X)(Y))(1)` | chained calls (left-assoc) |
| X func, Y type | error | `Y` used as a bare argument |

C's grammar is therefore context-sensitive.

## Java — avoided by construction

Java has no "call an arbitrary expression" syntax: you cannot write `(x)(y)` to invoke
`x`. So `(a)(b)` can only be a cast (`a` must be a type) — the cast-vs-call ambiguity does
not exist. (Java still restricts cast operands to avoid cast-vs-arithmetic ambiguity, e.g.
`(a)-b` is subtraction for a reference type.)

## Cangjie — speculative parse, and two problems

Cangjie has both expression calls `(e)(args)` and the forced cast `(U)e`, so it inherits
C's ambiguity. But it parses **before** symbols are collected, so the parser cannot
classify `X`. It instead *speculatively* parses `(X)` as a type (any identifier parses as
a `RefType`), commits to the cast / right-associative grouping (`AmbiguousForcedCastExpr`),
and defers the real decision to Sema. Two consequences:

1. **Associativity divergence from stock.** For `(foo)(foo)(1)` (both functions), stock
   Cangjie groups left-associatively as `((foo)(foo))(1)` (a type error), while the
   forced-cast parser groups right-associatively as `foo(foo(1))`. The same source has a
   different meaning depending on whether the feature is present.

2. **Nested desugar leak / ICE.** When the outer operand is itself an
   `AmbiguousForcedCastExpr` (not a `ParenExpr`), the `isCall` heuristic in
   `SynAmbiguousForcedCastExpr` is false; and since the speculative type is not a real
   type, the node falls into a dead-end branch and is left un-desugared. Its speculative
   `RefType` (invalid — the identifier is a function) survives into the checked AST and
   trips `ASTTypeValidator`: an ICE in a debug build, a silently-invalid node in release.
   Minimal repro: `(foo)(foo)(1)`.

## Fix directions

- **Stop the leak (robustness, small):** never leave an un-desugared node carrying an
  invalid speculative type; emit a clean diagnostic instead.
- **Match stock associativity (medium):** re-associate the call chain in Sema when it is
  not a forced cast, or make the forced-cast syntax unambiguous (as Java does).
- **Parse-time resolution (large):** give the parser symbol information like C, which
  changes the phase-separated architecture.
