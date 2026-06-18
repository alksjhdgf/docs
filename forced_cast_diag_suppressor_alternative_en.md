# Forced Cast Diagnostic Suppression Plan Comparison

The forced-cast parser needs speculative parsing. A speculative branch may produce diagnostics, but that branch may later be discarded, so those diagnostics need to be temporarily suppressed and cleared if the branch is not selected.

## Current Plan: Local Parser Guard

Keep `DiagSuppressor` in its original `Sema` location, and do not include it from `Parser`. Define a small local RAII guard inside `ParseAtom.cpp` only for forced-cast speculative parsing. The guard directly calls `DiagnosticEngine::DisableDiagnose()` and `DiagnosticEngine::EnableDiagnose(origin)`.

The core shape is:

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

Pros:

- Smaller change surface.
- Does not move `DiagSuppressor` or affect the existing sema structure.
- Does not introduce a `Parser -> Sema` dependency.
- Does not require new `Basic` headers, implementation files, or build configuration changes.
- Easier to submit and review as a local forced-cast parser implementation detail.

Cons:

- Parser and sema will each have an RAII wrapper around the `DiagnosticEngine` diagnostic switch.
- Less unified than a shared common utility in the long term.
- If the semantics of `DiagnosticEngine::DisableDiagnose()` / `EnableDiagnose()` change later, both the parser-local guard and sema `DiagSuppressor` need to be checked.

## Previous Plan: Move DiagSuppressor to Basic

Move `DiagSuppressor` from `Sema` to `Basic`, so parser and sema can share the same common diagnostic suppression utility.

Pros:

- A single shared implementation.
- Consistent diagnostic suppression behavior between parser and sema.
- Cleaner module boundaries without making parser depend on sema.
- Better if more compiler phases need to reuse diagnostic suppression later.

Cons:

- Larger change surface.
- Requires adding or moving public headers and implementation files.
- Requires updating the `Basic` build configuration.
- Adds a common-utility move to the PR, making the review scope broader than the forced-cast core logic.

## Conclusion

If long-term structure is the priority, moving `DiagSuppressor` to `Basic` is cleaner.

If PR friendliness and minimal change surface are the priority, the parser-local guard is more suitable. It preserves the diagnostic isolation required by forced-cast dual-branch parsing while avoiding broader changes to common compiler modules.
