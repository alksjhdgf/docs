# Minimal-Change Diagnostic Suppression Plan for Forced Cast

## Background

The forced-cast parser implementation needs to handle the ambiguity between the new `(U)e` syntax and the existing parenthesized-expression path. The current design builds both a forced-cast candidate branch and a fallback branch in the parser, then lets sema choose the final branch based on real type information.

This requires speculative parsing. During speculative parsing, the parser may call existing entry points such as `ParseType()`, `ParseBaseExpr()`, and `ParseExpr()`. These entry points may write diagnostics directly into `DiagnosticEngine` when parsing fails or enters error recovery.

However, a speculative branch may not be the branch selected in the end. If diagnostics from a discarded branch are preserved immediately, users may see errors from a branch that was never actually chosen. Therefore, the forced-cast parser needs a local mechanism to temporarily suppress diagnostics during speculative parsing and discard them when that speculative branch is abandoned.

## Goals

This plan aims to reduce the code-change surface of the forced-cast PR while avoiding an improper module dependency.

The concrete goals are:

- Keep `DiagSuppressor` in its original `Sema` location.
- Do not include the `Sema` `DiagSuppressor` from `Parser`.
- Define a small local RAII guard inside `ParseAtom.cpp` only for forced-cast speculative parsing.
- Let this local guard directly use the existing `DiagnosticEngine::DisableDiagnose()` and `DiagnosticEngine::EnableDiagnose(origin)` APIs.
- Discard speculative parser diagnostics at the end of the speculative branch so they do not affect user-visible diagnostics.

## Plan

Define a local guard in `ParseAtom.cpp`, for example:

```cpp
struct ForcedCastDiagGuard {
    explicit ForcedCastDiagGuard(DiagnosticEngine& diag) : diag(diag)
    {
        originDiags = diag.DisableDiagnose();
    }

    ~ForcedCastDiagGuard()
    {
        diag.EnableDiagnose(originDiags);
    }

    void DropSpeculativeDiags()
    {
        (void)diag.ConsumeStoredDiags();
    }

    DiagnosticEngine& diag;
    std::vector<Diagnostic> originDiags;
};
```

The usage would look like this:

```cpp
OwnedPtr<Expr> fallbackExpr;
{
    ForcedCastDiagGuard guard(diag);
    auto fallbackBase = ParseConventionalLeftParenExprInKind(ek, leftParenPos);
    fallbackExpr = ParseExpr(Token{TokenKind::DOT}, std::move(fallbackBase), ek);
    guard.DropSpeculativeDiags();
}
```

The guard works as follows:

1. On entry, it calls `diag.DisableDiagnose()`, temporarily disabling immediate diagnostic emission and saving the diagnostics that existed before entering this scope.
2. The speculative parser logic runs as usual. Any diagnostics produced during this period are stored inside `DiagnosticEngine` instead of becoming final user-visible diagnostics.
3. At the end of the speculative branch, `DropSpeculativeDiags()` discards the diagnostics produced by this speculative attempt.
4. On scope exit, the guard calls `diag.EnableDiagnose(originDiags)` and restores the diagnostic state that existed before the scope.

## Why Parser Cannot Simply Return “AST or Failure” and Defer Diagnostics to Sema

That direction does not fit the current code structure.

The existing parser entry points are not pure return-value APIs. Functions such as `ParseType()`, `ParseExpr()`, and `ParseBaseExpr()` may record diagnostics through `DiagnosticEngine` when they fail, recover from errors, or see invalid tokens. Therefore, a parser failure is not merely a `nullptr` or `INVALID_EXPR` result. It may already have produced diagnostic side effects.

Also, sema does not reparse source code. If a speculative parser branch fails and does not leave a usable AST behind, sema cannot naturally reconstruct that branch, nor can it automatically recreate the parser diagnostics that would have been produced at that point.

To truly make parser produce no diagnostics and defer them entirely to sema, a much larger parser diagnostic redesign would be needed, such as:

- Adding a pure speculative parse mode where parser failures only return status and never write diagnostics.
- Caching parser diagnostics on AST nodes or another intermediate structure, then releasing them after sema chooses a branch.
- Allowing sema to drive a second parser pass over the relevant source fragment.

All of these would significantly expand the change scope and are not suitable as a prerequisite for the current forced-cast task.

## Comparison with Moving DiagSuppressor to Basic

### Moving DiagSuppressor to Basic

Moving `DiagSuppressor` from `Sema` to `Basic` is the cleaner long-term design. It lets parser and sema share one diagnostic suppression utility, avoids duplicated logic, and avoids a reverse `Parser -> Sema` dependency.

Pros:

- A single shared implementation.
- Consistent diagnostic suppression behavior across parser and sema.
- Clean module boundaries without introducing a `Parser -> Sema` dependency.

Cons:

- Larger change surface.
- Requires adding or moving public headers and implementation files.
- Requires updating the `Basic` build configuration.
- Adds a common-utility move to the PR, which is related to but not exactly the core forced-cast logic.

### Keeping DiagSuppressor in Sema and Using a Local Parser Guard

This plan keeps the existing `DiagSuppressor` in `Sema` and adds only a narrow forced-cast-specific guard in `ParseAtom.cpp`.

Pros:

- Smaller change surface.
- No changes to the existing sema code structure.
- No new `Parser -> Sema` dependency.
- No need to update the `Basic` build configuration.
- Easier to explain as a local speculative parsing mechanism for forced cast.

Cons:

- Parser and sema will each have an RAII wrapper around `DiagnosticEngine::DisableDiagnose()` / `EnableDiagnose()`.
- If the semantics of `DiagnosticEngine` diagnostic suppression APIs change in the future, both call sites should be reviewed.
- From a long-term maintenance perspective, this is less clean than extracting a shared utility.

## Other Options

### Including Sema DiagSuppressor Directly from Parser

This option has the smallest code change, but it is not recommended.

It introduces a `Parser -> Sema` dependency. Parser belongs to an earlier compiler phase and should not depend on sema internals. This dependency would blur module boundaries and may create future include, build-layering, or cyclic-dependency issues.

### Fully Duplicating DiagSuppressor in Parser

This avoids the cross-module dependency, but full duplication is not recommended.

It would create two nearly identical utility implementations. If one behavior is changed later and the other is missed, parser and sema diagnostic suppression behavior could diverge.

The local guard proposed here keeps only the minimum capability required by forced-cast parser logic. It does not copy sema-side APIs such as `ReportDiag()` or `HasError()`, so the duplication surface is much smaller.

### Redesigning the Parser Diagnostic Model

This would be the most complete architectural solution, but it is too broad for the current task.

If more speculative parser scenarios appear in the future, it may be worth designing a unified parser speculative diagnostic mechanism. That would involve parser error recovery, diagnostic lifetime, and intermediate AST state, and should not be required as part of the forced-cast implementation.

## Conclusion

If long-term module boundaries and reuse are the highest priority, moving `DiagSuppressor` into `Basic` is the cleanest design.

If the immediate priority is PR friendliness and minimizing the change surface, this document proposes a smaller alternative: keep `DiagSuppressor` in `Sema`, avoid any `Parser -> Sema` dependency, and use a forced-cast-specific local guard inside `ParseAtom.cpp` to temporarily suppress and discard speculative parser diagnostics.

This preserves the diagnostic isolation required by forced-cast dual-branch parsing while avoiding broader changes to common compiler modules.
