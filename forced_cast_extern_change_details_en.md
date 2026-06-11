# Forced Cast Extern Change Notes

This document describes the current implementation of forced casts for `Extern` on the `feature/forced_cast_extern` branch. It covers the implementation boundary, AST changes, parser ambiguity handling, sema/desugar logic, diagnostics, tests, and benchmark results.

The parser ambiguity strategy has been updated to preserve both branches and search for a shared right boundary. It no longer uses the older approach of treating an initial right-boundary mismatch as a single forced-cast branch.

Related commits:

- `cangjie_compiler`: `80868d9a feat: add forced extern cast support`
- `cangjie_compiler`: `e4562578 fix: require std interop extern for forced casts`
- `cangjie_compiler`: `e8b15e3a fix: preserve forced cast ambiguous branches`
- `cangjie_test`: `46b1f3efb5 test: add forced extern cast samples`
- `cangjie_test`: `62dae09adc test: use std interop extern in forced cast cases`
- `cangjie_sdk`: `3172c48 chore: update forced cast extern submodules`
- `cangjie_sdk`: `7fd9762 chore: update forced cast compiler submodule`

## 1. Goal And Scope

The implemented syntax is:

```cj
let x = (U)e
```

At this stage it only supports interop forced casts:

- `U` must semantically be a real type.
- `e` must semantically be an expression of type `std.interop.Extern<T>`.
- The expression is desugared to `T.fromExtern<U>(e)`.
- Ordinary type conversion does not use this syntax and should still use `as`.
- If `(U)e` is parsed as a pure forced-cast path and does not satisfy the requirements, a dedicated forced-cast diagnostic is reported.
- If the parser preserves the original expression path as well, sema selects the forced-cast path only when the forced-cast conditions fully hold; otherwise it selects the fallback path and preserves the original behavior and diagnostics.

`Extern` checking is intentionally strict. It is not enough for a type to be named `Extern`; it must be the standard-library `std.interop.Extern`. A user-defined type with the same name is not accepted as a forced-cast operand.

## 2. AST Changes

Touched files:

- `cangjie_sdk/cangjie_compiler/include/cangjie/AST/ASTKind.inc`
- `cangjie_sdk/cangjie_compiler/include/cangjie/AST/Node.h`
- `cangjie_sdk/cangjie_compiler/src/AST/Node.cpp`
- `cangjie_sdk/cangjie_compiler/src/AST/Clone.cpp`
- `cangjie_sdk/cangjie_compiler/src/AST/PrintNode.cpp`
- `cangjie_sdk/cangjie_compiler/src/AST/Walker.cpp`
- `cangjie_sdk/cangjie_compiler/src/Parse/ASTHasher.cpp`
- `cangjie_sdk/cangjie_compiler/src/Parse/ASTChecker.cpp`
- `cangjie_sdk/cangjie_compiler/src/CHIR/Serializer/CHIRSerializer.cpp`

Two AST kinds were added:

```cpp
ASTKIND(FORCED_CAST_EXPR, "forced_cast_expr", ForcedCastExpr, 496)
ASTKIND(AMBIGUOUS_FORCED_CAST_EXPR, "ambiguous_forced_cast_expr", AmbiguousForcedCastExpr, 512)
```

New AST nodes:

```cpp
struct ForcedCastExpr : Expr {
    OwnedPtr<Type> targetType;
    Position leftParenPos;
    OwnedPtr<Expr> expr;
    Position rightParenPos;
};

struct AmbiguousForcedCastExpr : Expr {
    OwnedPtr<Expr> forcedExpr;
    OwnedPtr<Expr> fallbackExpr;
};
```

`ForcedCastExpr` represents a candidate that has been parsed as forced-cast syntax, for example `(Foo)e`.

`AmbiguousForcedCastExpr` represents a source range that can be parsed in two ways:

- `forcedExpr`: the complete forced-cast candidate AST.
- `fallbackExpr`: the complete original parenthesized-expression AST.

The implementation stores two complete subtrees instead of saving tokens for later reparsing. This avoids sending sema back into parser and preserves source locations, diagnostic context, and trailing expression structure.

## 3. Parser Entry Point

Touched files:

- `cangjie_sdk/cangjie_compiler/src/Parse/ParseAtom.cpp`
- `cangjie_sdk/cangjie_compiler/src/Parse/ParseExpr.cpp`
- `cangjie_sdk/cangjie_compiler/src/Parse/ParserImpl.h`

Entry logic:

```cpp
OwnedPtr<AST::Expr> ParserImpl::ParseLeftParenExprInKind(ExprKind ek)
{
    auto leftParenPos = lastToken.Begin();
    if (!disableForcedCastParse) {
        if (auto forcedCastExpr = ParseForcedCastExpr(ek, leftParenPos); forcedCastExpr) {
            return forcedCastExpr;
        }
    }
    return ParseConventionalLeftParenExprInKind(ek, leftParenPos);
}
```

Meaning:

- `leftParenPos = lastToken.Begin()` records the current `(` position.
- `!disableForcedCastParse` means this is not a fallback parse. The normal parser tries the forced-cast candidate first.
- `ParseForcedCastExpr(ek, leftParenPos)` tries to parse a `(Type)expr` candidate and builds an `AmbiguousForcedCastExpr` when needed.
- If the forced-cast candidate succeeds, the parser returns either `ForcedCastExpr` or `AmbiguousForcedCastExpr`.
- If it fails, the parser falls back to `ParseConventionalLeftParenExprInKind` and preserves the old parenthesized-expression behavior.

`disableForcedCastParse` prevents a fallback parser from parsing the same source as forced cast again. It is only enabled while parsing the fallback branch.

`enableForcedCastOnlyParse` is an internal switch used by speculative forced-branch parsers. It builds only the forced branch and does not recursively build fallback branches, preventing nested AFC loops for cases such as `(foo)(x)`.

## 4. Parser: Current `ParseForcedCastExpr` Implementation

### 4.1 Diagnostic Suppression

The implementation introduces a local guard:

```cpp
struct DiagnoseStatusGuard {
    explicit DiagnoseStatusGuard(DiagnosticEngine& diag) : suppressor(diag) {}
    ~DiagnoseStatusGuard()
    {
        (void)suppressor.GetSuppressedDiag();
    }

    DiagSuppressor suppressor;
};
```

Purpose:

- Forced/fallback dual parsing is speculative and should not expose diagnostics from failed branches.
- `diag.Prepare()/ClearTransaction()` controls handler submission but does not reliably roll back all diagnostic counters.
- `DiagSuppressor` uses `DisableDiagnose/EnableDiagnose` to actually suppress speculative diagnostics.
- The destructor calls `GetSuppressedDiag()` to discard suppressed diagnostics instead of replaying them.

Current include:

```cpp
#include "../Sema/DiagSuppressor.h"
```

This reuses an existing RAII diagnostic suppressor. It is a cross-directory include; if we want to reduce `Parse` depending on `Sema`, this RAII can be moved to `Basic` or a common utility layer later.

### 4.2 Basic Helpers

```cpp
auto hasSameSourcePosition = [](const Position& lhs, const Position& rhs) {
    return lhs.line == rhs.line && lhs.column == rhs.column;
};

auto isBeforeSourcePosition = [](const Position& lhs, const Position& rhs) {
    return lhs.line < rhs.line || (lhs.line == rhs.line && lhs.column < rhs.column);
};

auto isValidExpr = [](const OwnedPtr<Expr>& expr) {
    return expr && expr->astKind != ASTKind::INVALID_EXPR;
};
```

Meaning:

- `hasSameSourcePosition` checks whether forced/fallback branches reach the same shared right boundary.
- `isBeforeSourcePosition` detects fallback branches that only parse a prefix of the forced candidate, for example only `(foo)`.
- `isValidExpr` normalizes the validity check for expression nodes.

`assignCurrentFile` walks ASTs created by speculative parsers and fills `curFile`:

```cpp
auto assignCurrentFile = [this](Ptr<Node> node) {
    if (!node || currentFile == nullptr) {
        return;
    }
    Walker walker(node, [this](Ptr<Node> curNode) {
        curNode->curFile = currentFile;
        return VisitAction::WALK_CHILDREN;
    });
    walker.Walk();
};
```

This is important because ASTs created by source sub-parsers do not always naturally carry the main parser's `curFile` context.

### 4.3 Candidate Parsing

```cpp
auto parseForcedCastCandidate = [this, ek]() -> std::tuple<OwnedPtr<Type>, Position, OwnedPtr<Expr>, bool> {
    auto candidateTargetType = ParseType();
    if (!candidateTargetType || candidateTargetType->astKind == ASTKind::INVALID_TYPE || !Skip(TokenKind::RPAREN) ||
        newlineSkipped || !SeeingExpr()) {
        return {nullptr, Position{}, nullptr, false};
    }

    auto rightParenPos = lastToken.Begin();
    bool mayHaveConventionalFallback = SeeingExprOperator() || SeeingAny({TokenKind::LPAREN, TokenKind::LSQUARE,
        TokenKind::DOT, TokenKind::LCURL});
    auto candidateOperandExpr = ParseBaseExpr(nullptr, ek);
    if (!candidateOperandExpr || candidateOperandExpr->astKind == ASTKind::INVALID_EXPR) {
        return {nullptr, Position{}, nullptr, false};
    }
    return {std::move(candidateTargetType), rightParenPos, std::move(candidateOperandExpr),
        mayHaveConventionalFallback};
};
```

Branch behavior:

- `ParseType()` first parses the content after `(` as a type. At parser time this only proves that it can syntactically be parsed as a type; it does not prove that the referenced name is semantically a type declaration.
- If `candidateTargetType` is null or `INVALID_TYPE`, this is not a forced-cast candidate.
- If `)` is missing, the `(U)` shape is not formed.
- If a newline was skipped, forced cast is not recognized across the newline, avoiding accidental consumption of the next line.
- If no expression can start after `)`, the candidate fails.
- `rightParenPos` stores the `)` position.
- `mayHaveConventionalFallback` only checks whether the old path may continue syntactically. Tokens such as `(`, `[`, `.`, `{`, or a binary operator may turn `(foo)` into a call, subscript, member access, trailing closure, or binary expression. A plain identifier/literal directly after `(foo)` does not form an old path, so `(foo)externValue` can be a pure forced-cast form.
- `ParseBaseExpr(nullptr, ek)` parses only the base form of the forced-cast operand. Later full forced-branch parsing attaches postfix or binary operators if they exist.

Important: `mayHaveConventionalFallback` does not use semantic information to filter forced casts. It only avoids unnecessary speculative parsing for pure forced-cast shapes.

### 4.4 Building `ForcedCastExpr`

```cpp
auto makeForcedCastExpr = [&leftParenPos](OwnedPtr<Type> targetType, const Position& rightParenPos,
                              OwnedPtr<Expr> operandExpr) {
    if (!targetType || !operandExpr) {
        return OwnedPtr<ForcedCastExpr>{};
    }
    auto ret = MakeOwned<ForcedCastExpr>();
    ret->leftParenPos = leftParenPos;
    ret->targetType = std::move(targetType);
    ret->expr = std::move(operandExpr);
    ret->rightParenPos = rightParenPos;
    ret->begin = leftParenPos;
    ret->end = ret->expr->end;
    return ret;
};
```

This helper centralizes `ForcedCastExpr` construction so that pure FC, AFC forced branch, and forced-only sub-parser paths all use the same field initialization.

### 4.5 Initial Candidate Probe

```cpp
ParserScope startScope(*this);
std::tuple<OwnedPtr<Type>, Position, OwnedPtr<Expr>, bool> forcedCastCandidate;
{
    DiagnoseStatusGuard guard(diag);
    forcedCastCandidate = parseForcedCastCandidate();
}
auto candidateTargetType = std::move(std::get<0>(forcedCastCandidate));
auto rightParenPos = std::get<1>(forcedCastCandidate);
auto candidateOperandExpr = std::move(std::get<2>(forcedCastCandidate));
bool mayHaveConventionalFallback = std::get<3>(forcedCastCandidate);
if (!candidateTargetType || !candidateOperandExpr) {
    startScope.ResetParserScope();
    return nullptr;
}
```

Meaning:

- `ParserScope startScope(*this)` saves the parser state before speculative parsing.
- Initial candidate parsing is guarded by `DiagnoseStatusGuard`, so failure diagnostics do not leak.
- On candidate failure, the parser state is restored and `nullptr` is returned; the caller then uses the old parenthesized-expression parser.
- On candidate success, the target, operand, and right-paren position are preserved for later forced-branch construction.

### 4.6 Pure Forced-Cast Fast Path

```cpp
auto initialForcedEnd = candidateOperandExpr->end;
if (enableForcedCastOnlyParse) {
    return makeForcedCastExpr(std::move(candidateTargetType), rightParenPos, std::move(candidateOperandExpr));
}
if (!mayHaveConventionalFallback) {
    return makeForcedCastExpr(std::move(candidateTargetType), rightParenPos, std::move(candidateOperandExpr));
}
```

Two fast paths:

- `enableForcedCastOnlyParse`: this parser is a forced-branch sub-parser, so it builds only forced AST and does not create a fallback.
- `!mayHaveConventionalFallback`: the token after `)` cannot make `(U)` continue as an old parenthesized-expression path, so the parser returns a pure `ForcedCastExpr`.

Examples:

```cj
let x = (Foo)externValue
let y = (Foo)1
```

Both are pure forced-cast shapes. If the operand in `(Foo)1` is not `std.interop.Extern<T>`, sema reports the dedicated forced-cast diagnostic.

### 4.7 Parser Decision Tree

The parser route after seeing `(` is:

```text
see '('
|
+-- disableForcedCastParse == true
|   |
|   +-- parse as old parenthesized expression
|
+-- disableForcedCastParse == false
    |
    +-- ParseForcedCastExpr
        |
        +-- parse FC candidate: (Type)expr-base
        |   |
        |   +-- candidate fails
        |   |   |
        |   |   +-- reset parser scope
        |   |   +-- return nullptr
        |   |   +-- outer parser falls back to old parenthesized expression
        |   |
        |   +-- candidate succeeds
        |       |
        |       +-- current parser is enableForcedCastOnlyParse sub-parser
        |       |   |
        |       |   +-- return ForcedCastExpr directly
        |       |
        |       +-- no clear old fallback possibility on the right
        |       |   |
        |       |   +-- return pure ForcedCastExpr directly
        |       |
        |       +-- old fallback path may exist on the right
        |           |
        |           +-- source sub-parser parses full fallback
        |           |
        |           +-- source sub-parser parses full forced branch
        |           |
        |           +-- forced end == fallback end
        |           |   |
        |           |   +-- build AmbiguousForcedCastExpr
        |           |
        |           +-- forced end != fallback end
        |               |
        |               +-- enter same-parser fallback rescue
        |                   |
        |                   +-- fallback invalid
        |                   |   |
        |                   |   +-- replay and return pure ForcedCastExpr
        |                   |
        |                   +-- fallback valid and end == initialForcedEnd
        |                   |   |
        |                   |   +-- build AmbiguousForcedCastExpr
        |                   |
        |                   +-- fallback valid and end != initialForcedEnd
        |                       |
        |                       +-- replay complete forced branch
        |                       |
        |                       +-- forced end == fallback end
        |                       |   |
        |                       |   +-- build AmbiguousForcedCastExpr
        |                       |
        |                       +-- forced end != fallback end
        |                           |
        |                           +-- reset parser scope
        |                           +-- return nullptr
        |                           +-- outer parser falls back to old parenthesized expression
```

This decision tree reflects three boundaries:

- If the FC candidate fails, no FC information is kept and the parser fully returns to old parsing.
- If the FC candidate succeeds but no old fallback seems possible, the parser returns a pure `ForcedCastExpr`; sema later checks whether `U` is a real type and `e` is `std.interop.Extern<T>`.
- If the FC candidate succeeds and an old fallback may exist, `AmbiguousForcedCastExpr` is built only when both complete expression paths reach the same final right boundary.

When there is no shared right boundary, the implementation does not force two ASTs with different source ranges into one AFC. The outer parser can continue from only one token position. If the forced and fallback branches consume different source ranges, the AFC itself would not provide a unique outer parse boundary. The current strategy therefore conservatively returns to old parsing and avoids stealing existing syntax.

### 4.8 Source Sub-Parser Dual Parse

The main AFC construction path uses source sub-parsers:

```cpp
auto& source = sourceManager.GetSource(leftParenPos.fileID);
if (!source.buffer.empty()) {
    auto startOffset = source.PosToOffset(leftParenPos);
    auto lineEndOffset = source.buffer.find('\n', startOffset);
    auto content = lineEndOffset == std::string::npos ? source.buffer.substr(startOffset)
                                                      : source.buffer.substr(startOffset, lineEndOffset - startOffset);
    ...
}
```

Meaning:

- The source slice starts from the current `(`.
- The slice stops at the end of the current line, preventing speculative parsers from consuming later `}`, declarations, or statements.
- This path builds two complete ASTs instead of stopping at the initial forced operand boundary.

Fallback sub-parser:

```cpp
ParserImpl fallbackParser(content, diag, sourceManager, leftParenPos, false, false);
fallbackParser.currentFile = currentFile;
fallbackParser.disableForcedCastParse = true;
fallbackExprFromSource = fallbackParser.ParseExpr();
```

Meaning:

- A new parser starts from the same `leftParenPos` over the same source slice.
- `disableForcedCastParse = true` prevents the fallback branch from parsing as forced cast again.
- `ParseExpr()` parses as much old syntax as possible, such as `(foo)(1)` or `(foo)-1 * 2`.

Forced sub-parser:

```cpp
ParserImpl forcedParser(content, diag, sourceManager, leftParenPos, false, false);
forcedParser.currentFile = currentFile;
forcedParser.enableForcedCastOnlyParse = true;
forcedExprFromSource = forcedParser.ParseExpr(ek);
```

Meaning:

- The forced sub-parser starts from the same source position.
- `enableForcedCastOnlyParse = true` builds the forced branch without recursively creating fallback branches.
- `ParseExpr(ek)` lets the forced branch consume a full expression, not just the initial operand. For example, both branches of `(foo)-1 * 2` can become complete expression ASTs.

Shared right-boundary rule:

```cpp
if (isValidExpr(forcedExprFromSource) &&
    hasSameSourcePosition(forcedExprFromSource->end, fallbackExprFromSource->end)) {
    ...
}
```

If both complete parse paths end at the same right boundary, `AmbiguousForcedCastExpr` is built. This is not “the initial forced operand boundary must match fallback”; it is “the full forced and fallback expressions must align at a common end”.

If the initial forced operand boundary differs from the full common boundary, the main parser silently replays the forced branch to advance its state:

```cpp
if (!hasSameSourcePosition(forcedExprFromSource->end, initialForcedEnd)) {
    startScope.ResetParserScope();
    auto oldEnableForcedCastOnlyParse = enableForcedCastOnlyParse;
    enableForcedCastOnlyParse = true;
    {
        DiagnoseStatusGuard guard(diag);
        (void)ParseExpr(Token{TokenKind::DOT}, parseForcedCastBase(), ek);
    }
    enableForcedCastOnlyParse = oldEnableForcedCastOnlyParse;
}
```

This fixes the earlier issue where `(foo)-1 * 2` could not be decided at the initial forced operand boundary `-1`. The main parser naturally advances to the full expression boundary by replaying the forced branch.

AFC construction:

```cpp
auto ret = MakeOwned<AmbiguousForcedCastExpr>();
ret->forcedExpr = std::move(forcedExprFromSource);
ret->fallbackExpr = std::move(fallbackExprFromSource);
ret->begin = leftParenPos;
ret->end = ret->forcedExpr ? ret->forcedExpr->end : ret->fallbackExpr->end;
assignCurrentFile(ret->forcedExpr.get());
assignCurrentFile(ret->fallbackExpr.get());
return ret;
```

### 4.9 Same-Parser Fallback Rescue

If the source buffer is unavailable or the source sub-parser path cannot produce a shared right boundary, the implementation has a same-parser fallback rescue path:

```cpp
startScope.ResetParserScope();
auto oldDisableForcedCastParse = disableForcedCastParse;
disableForcedCastParse = true;
OwnedPtr<Expr> fallbackExpr;
{
    DiagnoseStatusGuard guard(diag);
    auto fallbackBase = ParseConventionalLeftParenExprInKind(ek, leftParenPos);
    newlineSkipped = false;
    fallbackExpr = ParseExpr(Token{TokenKind::DOT}, std::move(fallbackBase), ek);
}
disableForcedCastParse = oldDisableForcedCastParse;
assignCurrentFile(fallbackExpr.get());
```

Purpose:

- If source-buffer parsing is unavailable or insufficient, the current parser state still attempts to construct the old path.
- `disableForcedCastParse = true` prevents recursive forced-cast parsing in the fallback branch.
- `newlineSkipped = false` allows same-line postfix calls such as `(foo)(x)` to continue.

This fallback does not stop after parsing a parenthesized expression. It calls `ParseExpr(Token{TokenKind::DOT}, fallbackBase, ek)` to try old syntax continuations including postfix, call, member access, subscript, trailing closure, and binary operations.

If, after that old-syntax expansion, the fallback still ends before the initial forced operand boundary, it is discarded:

```cpp
if (fallbackExpr && isBeforeSourcePosition(fallbackExpr->end, initialForcedEnd)) {
    fallbackExpr = nullptr;
}
```

This prevents partial fallback ASTs from being treated as complete old paths. For example, in `(foo)bar`, the forced candidate can treat `bar` as the operand, so the initial forced end is after `bar`. The old syntax can only parse `(foo)`, because a bare identifier `bar` cannot legally continue it. Keeping that fallback would incorrectly combine an AST covering only `(foo)` with a forced AST covering `(foo)bar`.

If fallback is invalid, the parser replays and returns a pure forced branch:

```cpp
if (!isValidExpr(fallbackExpr)) {
    startScope.ResetParserScope();
    OwnedPtr<ForcedCastExpr> forcedExpr;
    {
        DiagnoseStatusGuard guard(diag);
        forcedExpr = parseForcedCastBase();
    }
    assignCurrentFile(forcedExpr.get());
    return forcedExpr;
}
```

If the fallback end matches the initial forced operand end exactly, an AFC is built directly:

```cpp
if (hasSameSourcePosition(fallbackExpr->end, initialForcedEnd)) {
    auto ret = MakeOwned<AmbiguousForcedCastExpr>();
    ret->forcedExpr = makeForcedCastExpr(std::move(candidateTargetType), rightParenPos, std::move(candidateOperandExpr));
    ret->fallbackExpr = std::move(fallbackExpr);
    ...
    return ret;
}
```

Otherwise, the parser replays a full forced branch and builds AFC only if both final boundaries match:

```cpp
auto forcedExpr = ParseExpr(Token{TokenKind::DOT}, parseForcedCastBase(), ek);
bool canBuildAmbiguousExpr = isValidExpr(forcedExpr) && isValidExpr(fallbackExpr) &&
    hasSameSourcePosition(forcedExpr->end, fallbackExpr->end);
if (!canBuildAmbiguousExpr) {
    startScope.ResetParserScope();
    return nullptr;
}
```

`return nullptr` means the forced-cast attempt cannot safely build AFC, so control returns to the caller and the source is parsed with the old parenthesized-expression path. This is a compatibility guard.

## 5. Binary Operator Propagation In Parser

File:

- `cangjie_sdk/cangjie_compiler/src/Parse/ParseExpr.cpp`

Core logic:

```cpp
if (lExpr->astKind == ASTKind::AMBIGUOUS_FORCED_CAST_EXPR) {
    auto ambiguousExpr = OwnedPtr<AmbiguousForcedCastExpr>(StaticCast<AmbiguousForcedCastExpr*>(lExpr.release()));
    auto forcedLeft = std::move(ambiguousExpr->forcedExpr);
    auto fallbackLeft = std::move(ambiguousExpr->fallbackExpr);
    auto ret = MakeOwned<AmbiguousForcedCastExpr>();
    ret->begin = ambiguousExpr->begin;
    ret->forcedExpr = MakeOperatorExpr(forcedLeft, oTok);
    ret->fallbackExpr = MakeOperatorExpr(fallbackLeft, oTok);
    ret->end = ret->forcedExpr ? ret->forcedExpr->end : ret->fallbackExpr->end;
    return ret;
}
```

Meaning:

- If the left-hand side is already AFC, later binary operators must not be attached to only one branch.
- `forcedLeft` and `fallbackLeft` are extracted separately.
- `MakeOperatorExpr` is applied to both branches.
- A new AFC is returned so the binary expression structure is extended consistently across both ASTs.

Example:

```cj
let value = (foo)-1 * 2
```

The old fallback path follows existing precedence and becomes:

```text
(foo) - (1 * 2)
```

The root is therefore `SUB`, with `MUL` as the right child. The latest tests assert this structure.

## 6. Sema And Desugar

Touched files:

- `cangjie_sdk/cangjie_compiler/src/Sema/TypeCheckExpr/ForcedCastExpr.cpp`
- `cangjie_sdk/cangjie_compiler/src/Sema/TypeCheckExpr/CMakeLists.txt`
- `cangjie_sdk/cangjie_compiler/src/Sema/TypeChecker.cpp`
- `cangjie_sdk/cangjie_compiler/src/Sema/TypeCheckerImpl.h`
- `cangjie_sdk/cangjie_compiler/src/Sema/Collector.cpp`

### 6.1 Target Type Confirmation

```cpp
bool IsConfirmedForcedCastTargetType(const Type& type)
```

Branch behavior:

- `PRIMITIVE_TYPE`, `THIS_TYPE`, `CONSTANT_TYPE`: syntactically clear type forms; return true.
- `INVALID_TYPE`: return false.
- `REF_TYPE`: require `ref.target` to exist and be `IsTypeDecl()`, and recursively confirm all type arguments.
- `PAREN_TYPE`: recursively confirm the inner type.
- `QUALIFIED_TYPE`: require `target` to exist and be `IsTypeDecl()`, and recursively confirm type arguments.
- `OPTION_TYPE`: recursively confirm the component type.
- `VARRAY_TYPE`: recursively confirm element type and constant type.
- `FUNC_TYPE`: recursively confirm return type and all parameter types.
- `TUPLE_TYPE`: recursively confirm all fields.
- Other AST kinds: return false.

This function is the sema-stage check for whether `U` is truly a type. Parser can only know that `U` can syntactically be parsed as a type; the real type declaration target can only be confirmed after semantic analysis.

### 6.2 Extern Operand Check

```cpp
bool IsExternOperandTy(Ptr<Ty> ty, Ptr<Ty>& runtimeTy)
{
    if (!Ty::IsTyCorrect(ty) || ty->typeArgs.size() != 1) {
        return false;
    }
    auto decl = Ty::GetDeclOfTy(ty);
    if (!decl || decl->identifier.Val() != "Extern" || decl->fullPackageName != INTEROP_PACKAGE_NAME) {
        return false;
    }
    runtimeTy = ty->typeArgs.front();
    return Ty::IsTyCorrect(runtimeTy);
}
```

Meaning:

- `!Ty::IsTyCorrect(ty)`: operand type is invalid, so forced cast cannot be selected.
- `ty->typeArgs.size() != 1`: `Extern<T>` must have exactly one runtime type argument.
- `Ty::GetDeclOfTy(ty)`: get the declaration behind the type.
- `!decl`: no declaration found, so forced cast cannot be selected.
- `decl->identifier.Val() != "Extern"`: the type name must be `Extern`.
- `decl->fullPackageName != INTEROP_PACKAGE_NAME`: the declaration must come from `std.interop`.
- `runtimeTy = ty->typeArgs.front()`: extract `T` from `Extern<T>` for `T.fromExtern`.
- `return Ty::IsTyCorrect(runtimeTy)`: the runtime type must also be valid.

This fixes the earlier name-only `Extern` check. A user-defined type named `Extern` no longer enters the forced-cast branch.

### 6.3 Forced-Cast Selection Condition

```cpp
bool CanSelectForcedCast(const Type& targetType, Ptr<Ty> targetTy, Ptr<Ty> operandTy, Ptr<Ty>& runtimeTy)
{
    if (!Ty::IsTyCorrect(targetTy) || !IsConfirmedForcedCastTargetType(targetType)) {
        return false;
    }
    return IsExternOperandTy(operandTy, runtimeTy);
}
```

Forced cast is selected only when:

- `targetTy` is correct.
- the target type AST is confirmed as a type.
- the operand is `std.interop.Extern<T>`.

AFC branch selection depends strictly on this function. Only when `U` is confirmed as a type and `e` is confirmed as `std.interop.Extern<T>` does sema select the forced branch; otherwise it selects fallback.

### 6.4 Desugar Construction

```cpp
OwnedPtr<CallExpr> BuildForcedCastCall(
    Expr& sourceExpr, Type& targetTypeAst, Ty& targetTy, Ty& runtimeTy, Expr& operandExpr, TypeManager& typeManager)
```

Core behavior:

- `Ty::GetDeclOfTy(&runtimeTy)`: find the declaration for `T` in `Extern<T>`.
- `CreateRefExpr(*runtimeDecl, sourceExpr)`: build a reference to the runtime type.
- `runtimeRef->isAlone = false`: mark it as the base of member access, not an isolated reference.
- `GetMemberDecl<FuncDecl>(*runtimeDecl, "fromExtern", {operandExpr.GetTy()}, typeManager)`: find `T.fromExtern`, whose parameter must accept the operand `Extern<T>`.
- `ASTCloner::Clone(Ptr(&operandExpr))`: clone operand instead of moving or damaging the original AST.
- `CreateMemberCall(...)`: build `T.fromExtern(operand)`.
- `memberAccess->SetTy(typeManager.GetFunctionTy({operandExpr.GetTy()}, &targetTy))`: set the callee function type so later CHIR/codegen does not rely only on final call type.
- `memberAccess->instTys.push_back(&targetTy)`: record instantiated generic target type.
- `memberAccess->typeArguments.push_back(targetTypeClone)`: preserve source-level type argument AST.
- `callExpr->resolvedFunction = fromExternDecl`: bind the resolved function declaration.
- `callExpr->callKind = CALL_DECLARED_FUNCTION`: mark it as a normal declared function call.
- `callExpr->SetTy(&targetTy)`: the forced-cast expression has result type `U`.
- `callExpr->sourceExpr = &sourceExpr`, `begin/end`, and `PropagateGeneratedContext`: preserve source locations and generated context.

### 6.5 Direct Forced-Cast Synthesis

```cpp
Ptr<Ty> TypeChecker::TypeCheckerImpl::SynForcedCastExpr(ASTContext& ctx, ForcedCastExpr& fce)
```

Branch behavior:

- Ensure `targetType` and `expr` are non-null.
- Synthesize target type to get `targetTy`.
- Synthesize operand to get `operandTy`.
- Call `CanSelectForcedCast`.
- If forced cast cannot be selected and target/operand types are otherwise valid, report the dedicated forced-cast diagnostic.
- If selection fails, set the expression type to invalid and return.
- If selection succeeds, call `BuildForcedCastCall`.
- If desugar construction fails, set invalid.
- Use `SynthesizeWithoutRecover` to check the generated call.
- If generated call type is correct, `fce.SetTy(targetTy)`: the result type is fixed to `U`.

### 6.6 Ambiguous Forced-Cast Synthesis

```cpp
Ptr<Ty> TypeChecker::TypeCheckerImpl::SynAmbiguousForcedCastExpr(ASTContext& ctx, AmbiguousForcedCastExpr& afce)
```

Branch behavior:

- Ensure `forcedExpr` and `fallbackExpr` both exist.
- `GetLeadingForcedCastExpr(afce.forcedExpr.get())` finds the leftmost `ForcedCastExpr` in the forced branch. This supports forced branches that have already been extended by binary operators, calls, member access, and similar structures.
- `PropagateAmbiguousCandidateContext` propagates AFC context to the forced candidate.
- `DiagSuppressor` is used while trying the forced candidate target and operand, preventing candidate diagnostics from leaking.
- If `CanSelectForcedCast` is true, sema checks the forced branch for real and sets `afce.desugarExpr` to the forced branch.
- If `CanSelectForcedCast` is false, sema checks fallback for real and sets `afce.desugarExpr` to fallback.

This preserves the old function-call path for `(foo)(1)` when `foo` is a function, and selects forced cast for `(foo)(externValue)` when `foo` is a type and `externValue` is `std.interop.Extern<T>`.

### 6.7 Ambiguous Forced-Cast Check

```cpp
bool TypeChecker::TypeCheckerImpl::ChkAmbiguousForcedCastExpr(ASTContext& ctx, Ty& targetTy, AmbiguousForcedCastExpr& afce)
```

This is similar to `SynAmbiguousForcedCastExpr`, but runs in `Check` mode when a contextual target type exists.

Branch rules:

- If `CanSelectForcedCast` is true, check `afce.forcedExpr` against `targetTy`.
- If the forced branch succeeds, AFC type is the forced branch type and `desugarExpr` points to the forced branch.
- If `CanSelectForcedCast` is false, check `afce.fallbackExpr` against `targetTy`.
- If fallback succeeds, AFC type is the fallback type and `desugarExpr` points to fallback.
- If fallback fails, the original fallback diagnostics are preserved.

## 7. Diagnostics

Touched files:

- `cangjie_sdk/cangjie_compiler/include/cangjie/Basic/DiagnosticSema.def`
- `cangjie_sdk/cangjie_compiler/include/cangjie/Basic/DiagRefactor/DiagnosticSema.def`

Current diagnostic:

```text
invalid interoperation forced cast: '(U)e' requires 'U' to be a type and 'e' to be an expression of 'std.interop.Extern' type; use 'as' for ordinary type conversions
```

Meaning:

- This is an interop-only forced-cast syntax.
- `U` must be a type.
- `e` must be standard-library `std.interop.Extern<T>`.
- Ordinary type conversion should use `as`.

## 8. Ambiguity Strategy

The implementation does not solve the problem purely through grammar rewrite as Java syntax descriptions may do. It stores dual-branch ASTs in parser and lets sema choose with real type information.

Reasons:

- Parser cannot reliably know whether `foo` is a type, function, or variable.
- If `foo` is a function, `(foo)(1)` is an old function-call or parenthesized-expression call path and must not be stolen by forced cast.
- If `foo` is a type and `externValue` is `std.interop.Extern<T>`, `(foo)(externValue)` should select forced cast.
- For expressions such as `(foo)-1 * 2`, the initial forced operand right boundary and the full expression right boundary may differ, so fallback must not be dropped at the initial boundary.

Final branch rules:

- Pure forced-cast AST: no fallback exists; sema checks only forced-cast rules and reports the forced-cast diagnostic if they fail.
- Pure fallback AST: parser did not form a forced-cast candidate, so old logic is used completely.
- AFC AST: both paths are stored; sema selects forced only if `U` is a type and `e` is `std.interop.Extern<T>`, otherwise it selects fallback.

Key parser principles:

- The initial forced operand boundary does not have to equal fallback.
- Source sub-parsers parse complete forced/fallback expressions and look for a later shared right boundary.
- If two complete expression paths end at the same boundary, AFC is built.
- If AFC cannot be built safely, parser state is restored and the old parse path wins, prioritizing compatibility.

## 9. Why `std.interop.Extern` Is Required

Early tests used local definitions:

```cj
interface Runtime<T> where T <: Runtime<T> { ... }
struct Extern<T> where T <: Runtime<T> { ... }
```

This reduced runtime/stdlib dependency and focused tests on parser/sema/desugar. But if implementation only checks whether the type is named `Extern`, it creates a real correctness bug:

```cj
struct Extern<T> { ... }
let value: Foo = (Foo)myExtern
```

Any user-defined type named `Extern` with a similar shape could be incorrectly treated as interop `Extern`. The implementation now checks:

```cpp
decl->identifier.Val() == "Extern" && decl->fullPackageName == INTEROP_PACKAGE_NAME
```

`INTEROP_PACKAGE_NAME` is `std.interop`, so only standard-library `std.interop.Extern<T>` can enter the forced-cast branch.

## 10. Test Changes

### 10.1 ParserTest

File:

- `cangjie_sdk/cangjie_compiler/unittests/Parse/ParserTest.cpp`

Coverage:

- `direct = (foo)externValue`: pure `ForcedCastExpr`.
- `generic = (Box<Int64>)externValue`: pure `ForcedCastExpr` with generic target.
- `directNonExtern = (foo)1`: pure `ForcedCastExpr`; sema reports the dedicated diagnostic later.
- `ambiguousCall = (foo)(x)`: must parse as `AmbiguousForcedCastExpr`.
- `ambiguousBinary = (foo)-1 * 2`: must parse as `AmbiguousForcedCastExpr`.
- `normalCall = (foo + bar)(x)`: not a forced-cast candidate; remains a normal `CALL_EXPR`.
- `parenOnly`, `parenExpr`, `unitValue`: keep old parenthesized-expression or unit behavior.

This test no longer asserts `diag.GetErrorCount() == 0` for the whole string-source case, because the parser-only input contains undeclared names and ambiguity probing may leave recoverable diagnostic counts. The test purpose is limited to AST shape.

### 10.2 TypeCheckerTest

File:

- `cangjie_sdk/cangjie_compiler/unittests/Sema/TypeCheckerTest.cpp`

Core tests:

- `ForcedCastDirectDesugarsToFromExtern`: `(foo)externValue` parses as `ForcedCastExpr` and desugars to `DummyRuntime.fromExtern<foo>(externValue)`.
- `ForcedCastGenericTargetDesugarsToFromExtern`: generic target `(Box<Int64>)externValue` correctly sets type argument.
- `ForcedCastDirectNonExternOperandReportsInteropDiagnostic`: `(foo)1` is pure forced-cast syntax but operand is not `std.interop.Extern<T>`, so the dedicated diagnostic is reported.
- `ForcedCastRejectsUserDefinedExternWithSameName`: user-defined `Extern` with the same name is rejected, proving the `std.interop.Extern` restriction works.
- `ForcedCastAmbiguousFallbackKeepsOriginalCallPath`: `(foo)(1)` selects fallback when `foo` is a function.
- `ForcedCastAmbiguousFallbackKeepsOriginalBinaryPath`: `(foo)-1` selects fallback when `foo` is a variable.
- `ForcedCastAmbiguousFallbackKeepsOriginalExtendedBinaryPath`: `(foo)-1 * 2` keeps the old path. The test asserts root operator `SUB` and right child `MUL`, i.e. old semantics `(foo) - (1 * 2)`.
- `ForcedCastAmbiguousExprSelectsForcedCast`: `(foo)(externValue)` selects forced when `foo` is a type and `externValue` is `std.interop.Extern<T>`.
- `ForcedCastAmbiguousFallsBackAndKeepsOriginalFailureForTypeCall`: `(foo)(1)` with `foo` as type and non-Extern operand does not select forced; it preserves the old-path diagnostic.

### 10.3 `cangjie_test` Samples

Directory:

`cangjie_sdk/cangjie_test/testsuites/LLT/Runtime/CJNative/extern/forced_cast`

These samples use the real `cjc` build artifact to cover visible compile scenarios:

- Old fallback syntax: function call, binary expression, and normal parenthesized expression.
- New direct FC syntax: `(foo)externValue`, generic target, operand as call expression.
- AFC selection: `(foo)(externValue)` selects FC when target is type and operand is `Extern<T>`, and falls back otherwise.
- Expected failures: non-`Extern<T>` operand, and member/subscript cases not yet supported by the current runtime stub.
- Class member operand: `holder.item: Extern<DummyRuntime>` can be a forced-cast operand.

Samples and benchmarks now use:

```cj
import std.interop.*
```

This keeps tests aligned with production semantics.

### 10.4 Benchmark

Generator:

`cangjie_sdk/cangjie_test/testsuites/LLT/Runtime/CJNative/extern/forced_cast/benchmark/generate_forced_cast_benchmarks.py`

Covered dimensions:

- ordinary parentheses.
- type-shaped parentheses.
- ambiguous fallback.
- nested parentheses.
- confirmed forced-cast.

The benchmark prelude also uses `import std.interop.*`, avoiding non-production paths.

## 11. Current Validation Results

### 11.1 Targeted Unit Tests

Latest targeted build and test commands:

```sh
cmake --build build/build --target ParserTest TypeCheckerTest cjc -j6
./build/build/bin/ParserTest --gtest_filter='ParserTest2.ForcedCastExpr'
./build/build/bin/TypeCheckerTest --gtest_filter='TypeCheckerTest.ForcedCast*'
```

Results:

- `ParserTest2.ForcedCastExpr`: passed.
- `TypeCheckerTest.ForcedCast*`: 9/9 passed.
- `cjc` target: build passed.

Negative tests print the expected diagnostic, for example:

```text
invalid interoperation forced cast: '(U)e' requires 'U' to be a type and 'e' to be an expression of 'std.interop.Extern' type; use 'as' for ordinary type conversions
```

### 11.2 `cangjie_test` Sample Validation

Current build artifact:

```sh
export CANGJIE_HOME=cangjie_sdk/cangjie_compiler/output
export CANGJIE_PATH=cangjie_sdk/cangjie_compiler/output/modules/darwin_aarch64_cjnative
CJC=cangjie_sdk/cangjie_compiler/build/build/bin/cjc
DIR=cangjie_sdk/cangjie_test/testsuites/LLT/Runtime/CJNative/extern/forced_cast
```

Positive samples passed:

- `interop_forced_cast_01.cj`: `foo` is a function in `(foo)(1)`, so the old function-call path is preserved.
- `interop_forced_cast_02.cj`: `foo` is a function in `(foo)(externValue)`, so fallback is preserved even with an `Extern<T>` argument.
- `interop_forced_cast_03.cj`: direct `(foo)externValue` forced-cast, CHIR generation passes.
- `interop_forced_cast_04.cj`: ambiguous `(foo)(externValue)` selects forced-cast.
- `interop_forced_cast_05.cj`: generic target `(Box<Int64>)externValue`.
- `interop_forced_cast_08.cj`: `foo` is a variable in `(foo)-1 * 2`, so the old binary path is preserved.
- `interop_forced_cast_09.cj`: `(foo)makeExtern()`, operand is a call expression.
- `interop_forced_cast_12.cj`: `(foo + bar)` does not enter forced-cast.
- `interop_forced_cast_14.cj`: `(foo)holder.item`, where a class member of type `Extern<DummyRuntime>` can be used as operand.

Expected-failure samples failed as expected:

- `interop_forced_cast_06.cj`: `(foo)1` enters pure FC path, but operand is not `std.interop.Extern<T>`, so the forced-cast diagnostic is reported.
- `interop_forced_cast_07.cj`: `(foo)(1)` with `foo` as type and non-Extern operand falls back to old path and preserves old call/type-name diagnostics.
- `interop_forced_cast_10.cj`: `(foo)externValue.name`; current runtime stub does not provide member access, so existing member-not-found semantics apply.
- `interop_forced_cast_11.cj`: `(foo)externValue[0]`; current runtime stub does not provide subscript access, so existing subscript failure applies.
- `interop_forced_cast_13.cj`: `(Box<Int64>)1` enters pure FC path, but operand is not `std.interop.Extern<T>`, so the forced-cast diagnostic is reported.

Failure diagnostic summary:

```text
06: invalid interoperation forced cast: '(U)e' requires 'U' to be a type and 'e' to be an expression of 'std.interop.Extern' type; use 'as' for ordinary type conversions
07: no matching function for operator '()' function call
07: expected member name or constructor call after 'foo' type name
10: 'name' is not a member of struct 'Extern<Class-DummyRuntime>'
11: invalid subscript operator [] on type 'Struct-Extern<Class-DummyRuntime>' with index type 'Int64'
13: invalid interoperation forced cast: '(U)e' requires 'U' to be a type and 'e' to be an expression of 'std.interop.Extern' type; use 'as' for ordinary type conversions
```

`07` is the key fallback-diagnostic preservation case. `06` and `13` are pure forced-cast paths, so they must report the dedicated forced-cast diagnostic.

### 11.3 Latest Benchmark Results

The latest benchmark was rerun after the current changes. Each file contains 10000 generated expressions. Each case was run 5 times. Timing uses Python `time.perf_counter()` around `cjc --emit-chir=raw`, in milliseconds. Current results are stored under `<bench_out>/forced_cast_bench_latest_results.json`; baseline results are stored under `<bench_out>/forced_cast_bench_latest_baseline_results.json`.

Compiler artifacts:

```text
baseline cjc: baseline build artifact from pre-forced-cast compiler
current  cjc: cangjie_sdk/cangjie_compiler/build/build/bin/cjc
```

Run command:

```sh
python3 cangjie_sdk/cangjie_test/testsuites/LLT/Runtime/CJNative/extern/forced_cast/benchmark/generate_forced_cast_benchmarks.py <bench_out>/forced_cast_bench_latest 10000

export CANGJIE_HOME=cangjie_sdk/cangjie_compiler/output
export CANGJIE_PATH=cangjie_sdk/cangjie_compiler/output/modules/darwin_aarch64_cjnative
cangjie_sdk/cangjie_compiler/build/build/bin/cjc \
  <bench_out>/forced_cast_bench_latest/<case>.cj --emit-chir=raw -o <bench_out>/forced_cast_bench_latest/<case>.chir
```

Comparison:

| case | baseline 5 runs | baseline avg | current 5 runs | current avg | delta |
| --- | --- | ---: | --- | ---: | ---: |
| `ordinary_parens` | 993.3, 791.8, 909.3, 786.3, 838.3 | 863.8 | 989.2, 861.2, 841.3, 834.7, 887.9 | 882.9 | +19.1ms / +2.2% |
| `type_shaped_parens` | 696.5, 684.8, 681.8, 706.4, 686.1 | 691.1 | 801.7, 762.4, 868.7, 739.3, 733.4 | 781.1 | +90.0ms / +13.0% |
| `ambiguous_fallback` | 1048.1, 1048.2, 1036.4, 1078.5, 1315.0 | 1105.3 | 1253.1, 1213.8, 1293.1, 1229.5, 1265.3 | 1250.9 | +145.6ms / +13.2% |
| `nested_same_type_parens` | 1029.6, 1036.5, 1175.0, 1287.8, 1117.7 | 1129.3 | 1240.2, 1449.1, 1251.2, 1225.1, 1211.5 | 1275.4 | +146.1ms / +12.9% |
| `nested_mixed_parens` | 2222.5, 2081.7, 2245.8, 2119.0, 2221.5 | 2178.1 | 2288.1, 2288.3, 2395.5, 2253.1, 2240.4 | 2293.1 | +115.0ms / +5.3% |
| `confirmed_forced_cast` | baseline parser failed with `expected ';' or '<NL>', found 'externValue'` | N/A | 1211.9, 1160.9, 1148.1, 1174.3, 1310.2 | 1201.1 | new syntax only |

Observations:

- `ordinary_parens` overhead is about 2.2%, showing that normal parenthesized expressions only pay a lightweight candidate-probing cost.
- `type_shaped_parens`, `ambiguous_fallback`, and `nested_same_type_parens` show about 13% overhead, which is expected because they more often trigger type-shaped probing, FC candidates, or dual-branch parsing.
- `nested_mixed_parens` overhead is about 5.3%; the expression itself is more complex, so forced-cast overhead is a smaller fraction of total time.
- `confirmed_forced_cast` has no comparable baseline timing because baseline cannot parse the new syntax. Current compiler completes parser, sema, desugar, and CHIR frontend path.

## 12. Future Options

Possible future work:

- Generalize forced-cast syntax from interop-only to broader type conversion. This would change the current boundary that ordinary conversion uses `as`, so it requires separate semantic and diagnostic design.
- Once runtime team completes the full interop runtime path, more `cangjie_test` samples can be converted to executable/run validation.
- Move `DiagSuppressor` from `Sema` to a common utility layer to reduce `Parse` including private `Sema` headers. `DiagSuppressor` is an existing diagnostic suppression utility, not a new class added by this task. It currently lives in `Sema` because its historical users are mostly type checking and type inference speculative paths. Parser speculative parsing now reuses it, creating structural coupling that can be cleaned up later.
- If cross-line expressions need to participate in AFC in the future, the source sub-parser slicing strategy should be upgraded from “current line” to “statement/expression boundary”, instead of simply stopping at newline.
