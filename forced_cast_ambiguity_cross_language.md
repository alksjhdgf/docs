# Forced-cast `(X)(Y)(Z)`: cast-vs-call across C, Java, and Cangjie

Companion to `forced_cast_ambiguities.md`, focused on how the `(X)(Y)` cast-vs-call
ambiguity is handled in C and Java, and how Cangjie preserves ordinary call
associativity while deferring the type/value decision to Sema.

## The ambiguity

`(a)(b)` is a forced cast of `b` to `a` when `a` resolves to a type, or an ordinary
call `a(b)` when `a` resolves to a callable value. The two readings naturally pull in
different directions:

- a cast prefix `(U)` consumes an expression to its right;
- postfix calls chain from left to right.

Consequently, a naive speculative parse of `(X)(Y)(1)` can accidentally change an
ordinary call chain from `((X)(Y))(1)` into `X(Y(1))`.

## C — decided during parsing (the “lexer hack”)

C commonly classifies typedef names using symbol-table information supplied to the
lexer/parser. At each `(` the parser can therefore distinguish a type-name from a value
name and choose cast or call syntax immediately.

| `(X)(Y)(1)` | grouping | meaning |
|---|---|---|
| X type, Y type | `(X)((Y)(1))` | nested casts |
| X type, Y function | `(X)(Y(1))` | cast of a call |
| X function, Y function | `((X)(Y))(1)` | chained calls |
| X function, Y type | error | `Y` used as a bare argument |

This works because the parser already knows the relevant type/value classification.

## Java — avoided by construction

Java does not support invoking an arbitrary expression with `(callee)(args)`. A method
is called as `method(args)`, object construction uses `new Type(args)`, and a functional
object is invoked through a method. Therefore `(a)(b)` has no value-call reading and the
cast-vs-call ambiguity considered here does not arise. Java separately constrains cast
operands to resolve forms such as `(a)-b`.

## Cangjie — speculative syntax, semantic selection

Cangjie supports both parenthesised expression calls `(callee)(args)` and forced casts
`(U)e`, while its parser runs before name/type resolution can determine whether `U` is
a type. The parser therefore:

1. speculatively parses `(U)` as a type candidate;
2. derives the corresponding expression-form callee when possible;
3. parses the operand once into an `AmbiguousForcedCastExpr`;
4. leaves the type/value decision to Sema.

Sema resolves `U` under diagnostic suppression and applies a strict rule:

- if `U` resolves to a type, select forced-cast semantics; the operand must be
  `Extern<R>`, otherwise report the forced-cast diagnostic;
- if `U` does not resolve to a type and the syntax is `(U)(args)`, materialise the
  ordinary call `U(args)`;
- a non-type juxtaposition `(U)e` has no ordinary reading.

The operand's type validates a forced cast but does not choose between cast and call.
This prevents `(Type)(arg)` from silently becoming the constructor call `Type(arg)`.

## Preserving left-associative call chains

For call form `(U)(args)`, the parser captures only the immediate `(args)` as the
ambiguous operand and disables another forced-cast attempt at that outer operand
boundary. Subsequent postfix operations attach to the resolved result. Thus:

```cangjie
(curry)(1)(2)       // ((curry)(1))(2)
(Target)(handle).f  // ((Target)(handle)).f
(Array<Int64>)(handle)[0] // ((Array<Int64>)(handle))[0]
```

Nested expressions inside the argument group are still parsed normally, so explicit
nesting such as `(foo)((curry)(1)(2))` keeps its inner call chain intact.

## Historical failure modes and their resolution

The first deferred implementation exposed two real problems:

1. **Associativity divergence.** It greedily parsed the operand as another ambiguous
   forced cast, so `(foo)(foo)(1)` became `foo(foo(1))` instead of stock Cangjie's
   left-associated `((foo)(foo))(1)`.
2. **Nested desugar leak / ICE.** An inner unresolved `AmbiguousForcedCastExpr` could
   retain an invalid speculative `RefType`, reach `ASTTypeValidator`, and cause an ICE
   in debug builds or an invalid checked AST in release builds.

These are no longer current limitations. Shallow call-form parsing restores left
association, every ambiguous node receives either a materialised `desugarExpr` or a
normal invalid/error result, and cloned nodes with a stale invalid desugar type are
re-synthesised. Ill-formed chains now produce ordinary parse/type diagnostics rather
than an ICE.

## Behaviour matrix

| Form | Result |
|---|---|
| `(callable)(arg)` | ordinary call, because the callee name is not a type |
| `(callable)(externArg)` | still an ordinary call; operand type does not select forced cast |
| `(Type)(externArg)` | forced cast |
| `(Type)(ordinaryArg)` | forced-cast diagnostic; no constructor fallback |
| `Type(ordinaryArg)` | canonical constructor call |
| `(curry)(1)(2)` | left-associated ordinary call chain |
| `(foo)(foo)(1)` | left-associated and normally rejected by type checking; never an ICE |
| `(Type)((OtherType)(externArg))` | explicit nested casts; outer cast fails if the inner result is not `Extern` |

The final design therefore keeps Cangjie's phase separation, preserves the existing
meaning of parenthesised call chains, and gives type-shaped forced casts a deterministic
error path.
