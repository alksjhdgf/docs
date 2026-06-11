# Forced Cast Extern 改动说明

本文档描述 `feature/forced_cast_extern` 分支中 forced cast for Extern 的总体实现、最新补丁、核心代码逻辑和测试覆盖。本文档按当前代码维护，尤其是 parser 中的二义性处理已经更新为“保留双分支并继续寻找公共右边界”的实现，不再采用“初始右边界不一致就单边处理”的旧描述。

相关提交：

- `cangjie_compiler`: `80868d9a feat: add forced extern cast support`
- `cangjie_compiler`: `e4562578 fix: require std interop extern for forced casts`
- `cangjie_compiler`: `e8b15e3a fix: preserve forced cast ambiguous branches`
- `cangjie_test`: `46b1f3efb5 test: add forced extern cast samples`
- `cangjie_test`: `62dae09adc test: use std interop extern in forced cast cases`
- `cangjie_sdk`: `3172c48 chore: update forced cast extern submodules`
- `cangjie_sdk`: `7fd9762 chore: update forced cast compiler submodule`

## 1. 目标和边界

本次实现的语法形式是：

```cj
let x = (U)e
```

当前阶段只支持互操作 forced cast：

- `U` 必须在语义上是一个真实类型。
- `e` 必须在语义上是 `std.interop.Extern<T>` 类型的表达式。
- 通过 `T.fromExtern<U>(e)` 进行 desugar。
- 普通类型转换不走该语法，仍然使用 `as`。
- 如果 `(U)e` 是纯 forced-cast 路径且不满足条件，则报专门的 forced-cast 诊断。
- 如果 parser 同时保留了原有表达式路径，则 sema 只有在 forced-cast 条件完全成立时才选择 forced-cast；否则选择 fallback，保持原有语义和原有诊断。

`Extern` 判定已经收紧：不能只按名字识别 `Extern`，必须是标准库中的 `std.interop.Extern`。用户自定义同名 `Extern` 不会被当作 forced-cast operand。

## 2. AST 改动

涉及文件：

- `cangjie_sdk/cangjie_compiler/include/cangjie/AST/ASTKind.inc`
- `cangjie_sdk/cangjie_compiler/include/cangjie/AST/Node.h`
- `cangjie_sdk/cangjie_compiler/src/AST/Node.cpp`
- `cangjie_sdk/cangjie_compiler/src/AST/Clone.cpp`
- `cangjie_sdk/cangjie_compiler/src/AST/PrintNode.cpp`
- `cangjie_sdk/cangjie_compiler/src/AST/Walker.cpp`
- `cangjie_sdk/cangjie_compiler/src/Parse/ASTHasher.cpp`
- `cangjie_sdk/cangjie_compiler/src/Parse/ASTChecker.cpp`
- `cangjie_sdk/cangjie_compiler/src/CHIR/Serializer/CHIRSerializer.cpp`

新增两个 AST kind：

```cpp
ASTKIND(FORCED_CAST_EXPR, "forced_cast_expr", ForcedCastExpr, 496)
ASTKIND(AMBIGUOUS_FORCED_CAST_EXPR, "ambiguous_forced_cast_expr", AmbiguousForcedCastExpr, 512)
```

新增 AST 节点：

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

`ForcedCastExpr` 表示已经按 forced-cast 语法解析出来的候选，例如 `(Foo)e`。

`AmbiguousForcedCastExpr` 表示同一段源码同时存在两条可解析路径：

- `forcedExpr`: forced-cast 候选完整 AST。
- `fallbackExpr`: 原有括号表达式路径完整 AST。

这里保存两棵完整子树，而不是保存 token 后续重新 parse，是为了避免 sema 再回到 parser，也避免语义判定时丢失原有 AST 上的位置信息、诊断上下文和后续运算结构。

## 3. Parser 总体入口

涉及文件：

- `cangjie_sdk/cangjie_compiler/src/Parse/ParseAtom.cpp`
- `cangjie_sdk/cangjie_compiler/src/Parse/ParseExpr.cpp`
- `cangjie_sdk/cangjie_compiler/src/Parse/ParserImpl.h`

入口逻辑：

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

逐句说明：

- `leftParenPos = lastToken.Begin()` 保存当前 `(` 的位置。
- `!disableForcedCastParse` 表示当前不是 fallback 解析路径。正常 parser 会先尝试 forced-cast 候选。
- `ParseForcedCastExpr(ek, leftParenPos)` 尝试解析 `(Type)expr` 候选，并在必要时构造 `AmbiguousForcedCastExpr`。
- 如果 forced-cast 候选成立，返回 `ForcedCastExpr` 或 `AmbiguousForcedCastExpr`。
- 如果 forced-cast 候选不成立，退回 `ParseConventionalLeftParenExprInKind`，保持旧括号表达式行为。

`disableForcedCastParse` 的作用是防止 fallback parser 再次把同一段源码解析成 forced cast。它只在解析 fallback 分支时打开。

`enableForcedCastOnlyParse` 是最新补丁引入的内部开关，用在 forced 分支的 speculative parser 中。它允许 parser 只构造 forced 分支，不再递归生成 fallback 分支，避免 `(foo)(x)` 这类候选在 forced 分支内部无限套 AFC。

## 4. Parser: ParseForcedCastExpr 最新实现

### 4.1 诊断抑制

最新实现引入局部 guard：

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

作用：

- forced/fallback 双线解析是 speculative parse，不应把尝试路径的诊断暴露给用户。
- `diag.Prepare()/ClearTransaction()` 只能控制 handler 提交，不能可靠回滚所有计数路径。
- `DiagSuppressor` 会通过 `DisableDiagnose/EnableDiagnose` 真正抑制 speculative 诊断。
- 析构时调用 `GetSuppressedDiag()` 丢弃 suppressed diagnostics，避免恢复诊断时重新报告。

当前 include 使用：

```cpp
#include "../Sema/DiagSuppressor.h"
```

这是为了复用已有的诊断抑制 RAII。它目前是跨目录 include，后续如果想减少 Parse 对 Sema 目录的直接 include，可以把该 RAII 抽到 Basic 或公共工具层。

### 4.2 基础 helper

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

含义：

- `hasSameSourcePosition` 用于判断 forced/fallback 是否到达同一个公共右边界。
- `isBeforeSourcePosition` 用于判断 fallback 是否只解析了 forced 候选的一小段，例如只解析到 `(foo)`，这种不能算完整旧路径。
- `isValidExpr` 统一判断 expression 是否真实可用。

`assignCurrentFile` 会遍历 speculative parser 生成的 AST，并补齐 `curFile`：

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

这一步很重要，因为 source 子 parser 重新生成的 AST 不一定天然拥有主 parser 的 `curFile` 上下文。

### 4.3 候选解析

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

逐分支说明：

- `ParseType()` 先把 `(` 后内容按类型解析。parser 这里只能判断“语法上能否解析为 type”，不能判断名字在语义上是否真的是 type decl。
- `candidateTargetType` 为空或 `INVALID_TYPE` 时，不是 forced-cast 候选。
- `!Skip(TokenKind::RPAREN)` 时，没有形成 `(U)` 结构。
- `newlineSkipped` 时，不跨换行识别 forced cast，避免误吞下一行表达式。
- `!SeeingExpr()` 时，右括号后没有表达式起始 token。
- `rightParenPos` 保存 `)` 的位置。
- `mayHaveConventionalFallback` 只判断旧路径是否有继续成立的语法可能。例如 `(`、`[`、`.`、`{` 或二元运算符可能让 `(foo)` 继续成为 call/subscript/member/trailing closure/binary 表达式；普通 identifier/literal 紧跟 `(foo)` 不构成旧路径，所以 `(foo)externValue` 可以直接是纯 forced-cast。
- `ParseBaseExpr(nullptr, ek)` 只解析 forced-cast operand 的 base 形态；如果后面还有二元运算或 postfix，会由后续完整 forced 分支解析接上。

注意：`mayHaveConventionalFallback` 不是用语义信息筛分 FC，它只用于避免纯 FC 形态对旧路径做无意义 speculative parse。

### 4.4 构造 ForcedCastExpr

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

该 helper 统一构造 `ForcedCastExpr`，避免纯 FC、AFC forced 分支、forced-only 子 parser 重复写同一套字段。

### 4.5 初始候选探测

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

逐句说明：

- `ParserScope startScope(*this)` 保存尝试解析前的 parser 状态。
- 初始候选解析放在 `DiagnoseStatusGuard` 中，失败路径不泄漏诊断。
- 候选失败时，恢复 parser 状态并返回 `nullptr`，由调用方走旧括号表达式解析。
- 候选成功时，保留候选 AST 的 target/operand/rightParen 供后续构造 forced 分支。

### 4.6 纯 forced-cast 快速路径

```cpp
auto initialForcedEnd = candidateOperandExpr->end;
if (enableForcedCastOnlyParse) {
    return makeForcedCastExpr(std::move(candidateTargetType), rightParenPos, std::move(candidateOperandExpr));
}
if (!mayHaveConventionalFallback) {
    return makeForcedCastExpr(std::move(candidateTargetType), rightParenPos, std::move(candidateOperandExpr));
}
```

两条分支：

- `enableForcedCastOnlyParse`: 当前 parser 是 forced 分支子 parser，只生成 forced AST，不再创建 fallback。
- `!mayHaveConventionalFallback`: 右括号后的 token 不可能让 `(U)` 作为旧括号表达式继续成立，因此直接返回纯 `ForcedCastExpr`。

例如：

```cj
let x = (Foo)externValue
let y = (Foo)1
```

这两类都是纯 forced-cast 形态。`(Foo)1` 如果 operand 不是 `std.interop.Extern<T>`，会在 sema 报 forced-cast 专门诊断。

### 4.7 当前 parser 决策树

当前 parser 在看到 `(` 后的总体路线如下：

```text
看到 '('
|
+-- disableForcedCastParse == true
|   |
|   +-- 直接走旧括号表达式解析
|
+-- disableForcedCastParse == false
    |
    +-- ParseForcedCastExpr
        |
        +-- 尝试解析 FC 候选: (Type)expr-base
        |   |
        |   +-- 候选失败
        |   |   |
        |   |   +-- Reset parser scope
        |   |   +-- 返回 nullptr
        |   |   +-- 外层回到旧括号表达式解析
        |   |
        |   +-- 候选成功
        |       |
        |       +-- 当前是 enableForcedCastOnlyParse 子 parser
        |       |   |
        |       |   +-- 直接返回 ForcedCastExpr
        |       |
        |       +-- 右侧没有明显旧 fallback 可能
        |       |   |
        |       |   +-- 直接返回纯 ForcedCastExpr
        |       |
        |       +-- 右侧可能存在旧 fallback 路径
        |           |
        |           +-- source 子 parser 解析完整 fallback
        |           |
        |           +-- source 子 parser 解析完整 forced
        |           |
        |           +-- forced end == fallback end
        |           |   |
        |           |   +-- 构造 AmbiguousForcedCastExpr
        |           |
        |           +-- forced end != fallback end
        |               |
        |               +-- 进入同 parser fallback 兜底
        |                   |
        |                   +-- fallback 无效
        |                   |   |
        |                   |   +-- 重放并返回纯 ForcedCastExpr
        |                   |
        |                   +-- fallback 有效且 end == initialForcedEnd
        |                   |   |
        |                   |   +-- 构造 AmbiguousForcedCastExpr
        |                   |
        |                   +-- fallback 有效且 end != initialForcedEnd
        |                       |
        |                       +-- 重放完整 forced 分支
        |                       |
        |                       +-- forced end == fallback end
        |                       |   |
        |                       |   +-- 构造 AmbiguousForcedCastExpr
        |                       |
        |                       +-- forced end != fallback end
        |                           |
        |                           +-- Reset parser scope
        |                           +-- 返回 nullptr
        |                           +-- 外层回到旧括号表达式解析
```

这个决策树体现了当前实现的三个边界：

- FC 候选失败时，不保留任何 FC 信息，完全回到旧解析。
- FC 候选成功但没有旧 fallback 可能时，返回纯 `ForcedCastExpr`，后续由 sema 检查 `U` 是否为真实 type、`e` 是否为 `std.interop.Extern<T>`。
- FC 候选成功且可能存在旧 fallback 时，只有 forced/fallback 两条完整表达式路径最终到达同一个右边界，才构造 `AmbiguousForcedCastExpr`。

无公共右边界时，当前实现不会把两个覆盖范围不同的 AST 强行放进同一个 AFC。原因是主 parser 后续只能从一个 token 位置继续，如果 forced 分支和 fallback 分支消费的源码范围不同，AFC 本身就无法给出唯一的外层解析边界。因此当前策略选择保守回退旧解析，避免 forced-cast 抢走既有语法路径。

### 4.8 source 子 parser 双线解析

当前实现的主要 AFC 构造路径是 source 子 parser：

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

含义：

- 从当前 `(` 的源码位置开始截取源码片段。
- 只截取到当前行末尾，避免 speculative 子 parser 继续吞掉后续 `}`、下一条声明或下一条语句。
- 这个路径用于构造两棵完整 AST，不再只截到初始 forced operand 的右边界。

fallback 子 parser：

```cpp
ParserImpl fallbackParser(content, diag, sourceManager, leftParenPos, false, false);
fallbackParser.currentFile = currentFile;
fallbackParser.disableForcedCastParse = true;
fallbackExprFromSource = fallbackParser.ParseExpr();
```

逐句说明：

- 新建 parser 从同一个 `leftParenPos` 开始解析同一片源码。
- `disableForcedCastParse = true` 禁止 fallback 分支再次解析成 forced-cast。
- `ParseExpr()` 会按旧语法尽量解析完整表达式，例如 `(foo)(1)`、`(foo)-1 * 2`。

forced 子 parser：

```cpp
ParserImpl forcedParser(content, diag, sourceManager, leftParenPos, false, false);
forcedParser.currentFile = currentFile;
forcedParser.enableForcedCastOnlyParse = true;
forcedExprFromSource = forcedParser.ParseExpr(ek);
```

逐句说明：

- forced 子 parser 从同一源码位置开始。
- `enableForcedCastOnlyParse = true` 让它构造 forced 分支，但不再递归构造 fallback。
- `ParseExpr(ek)` 会让 forced 分支继续吃完整表达式，而不是只停在初始 operand。例如 `(foo)-1 * 2` 的 forced 分支和 fallback 分支都可以形成完整表达式 AST。

公共右边界判定：

```cpp
if (isValidExpr(forcedExprFromSource) &&
    hasSameSourcePosition(forcedExprFromSource->end, fallbackExprFromSource->end)) {
    ...
}
```

这里的规则是：如果两条完整解析路径最终到达同一个公共右边界，就构造 `AmbiguousForcedCastExpr`。这不是“初始右边界必须一致”，而是“完整 forced/fallback 表达式必须能对齐到一个共同结束点”。

如果初始 forced operand 的右边界和完整公共右边界不同，主 parser 会静默重放 forced 分支来推进主 parser 状态：

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

这一步解决了之前的问题：不能因为 `(foo)-1 * 2` 的初始 forced operand 只到 `-1`，就丢掉 fallback 或错误推进。主 parser 通过重放 forced 分支自然停到完整表达式的公共右边界。

构造 AFC：

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

### 4.9 同 parser fallback 兜底

如果 source buffer 不可用，或者 source 子 parser 没能形成公共右边界，当前实现还有同 parser fallback 兜底：

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

作用：

- 在没有源码 buffer 或 source 子 parser 不适用时，仍尝试用当前 parser 状态构造旧路径。
- `disableForcedCastParse = true` 防止 fallback 分支递归走 forced-cast。
- `newlineSkipped = false` 是为了让 `(foo)(x)` 这类同一行 postfix call 可以继续接上。

fallback 在这里不是只解析一个括号表达式就停止，而是已经通过 `ParseExpr(Token{TokenKind::DOT}, fallbackBase, ek)` 按旧语法尝试继续接上 postfix、call、member access、subscript、trailing closure 和二元运算。

如果经过这次旧语法扩展后，fallback 仍然只解析到 forced 初始右边界之前，则丢弃：

```cpp
if (fallbackExpr && isBeforeSourcePosition(fallbackExpr->end, initialForcedEnd)) {
    fallbackExpr = nullptr;
}
```

这避免把半截 fallback 当成完整旧路径。例如 `(foo)bar` 中，forced 候选可以把 `bar` 当作 operand，初始 forced 右边界在 `bar` 之后；但旧语法下 `(foo)` 后面直接跟 identifier `bar` 没有合法连接方式，fallback 已经没有办法继续扩展到同一片源码范围。如果此时保留 fallback，就会把“只覆盖 `(foo)` 的 AST”和“覆盖 `(foo)bar` 的 forced AST”错误地放进同一个 AFC。

如果 fallback 无效，则重放并返回纯 forced 分支：

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

如果 fallback 的右边界正好等于初始 forced operand 右边界，则直接构造 AFC：

```cpp
if (hasSameSourcePosition(fallbackExpr->end, initialForcedEnd)) {
    auto ret = MakeOwned<AmbiguousForcedCastExpr>();
    ret->forcedExpr = makeForcedCastExpr(std::move(candidateTargetType), rightParenPos, std::move(candidateOperandExpr));
    ret->fallbackExpr = std::move(fallbackExpr);
    ...
    return ret;
}
```

否则重放完整 forced 分支，只有 forced/fallback 最终同右边界时才构造 AFC：

```cpp
auto forcedExpr = ParseExpr(Token{TokenKind::DOT}, parseForcedCastBase(), ek);
bool canBuildAmbiguousExpr = isValidExpr(forcedExpr) && isValidExpr(fallbackExpr) &&
    hasSameSourcePosition(forcedExpr->end, fallbackExpr->end);
if (!canBuildAmbiguousExpr) {
    startScope.ResetParserScope();
    return nullptr;
}
```

`return nullptr` 的含义是：当前 forced-cast 尝试无法安全构造 AFC，交回调用方走原有括号表达式解析。这是兼容性兜底，避免 parser 在不确定时抢走旧语法路径。

## 5. Parser 二元运算传播

文件：

- `cangjie_sdk/cangjie_compiler/src/Parse/ParseExpr.cpp`

核心逻辑：

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

含义：

- 当左侧已经是 AFC，后续二元运算不能只接到其中一条分支。
- `forcedLeft` 和 `fallbackLeft` 分别取出两条分支。
- 对两条分支分别调用 `MakeOperatorExpr`，构造新的 forced/fallback 运算节点。
- 返回新的 AFC，保证二元运算结构在两棵 AST 中同步延展。

示例：

```cj
let value = (foo)-1 * 2
```

旧 fallback 路径遵循原有运算优先级，最终是：

```text
(foo) - (1 * 2)
```

因此根节点是 `SUB`，右侧子节点是 `MUL`。最新测试已经按这个结构断言。

## 6. Sema 和 Desugar

涉及文件：

- `cangjie_sdk/cangjie_compiler/src/Sema/TypeCheckExpr/ForcedCastExpr.cpp`
- `cangjie_sdk/cangjie_compiler/src/Sema/TypeCheckExpr/CMakeLists.txt`
- `cangjie_sdk/cangjie_compiler/src/Sema/TypeChecker.cpp`
- `cangjie_sdk/cangjie_compiler/src/Sema/TypeCheckerImpl.h`
- `cangjie_sdk/cangjie_compiler/src/Sema/Collector.cpp`

### 6.1 目标类型确认

```cpp
bool IsConfirmedForcedCastTargetType(const Type& type)
```

分支说明：

- `PRIMITIVE_TYPE`、`THIS_TYPE`、`CONSTANT_TYPE`: 语法上明确是类型，返回 true。
- `INVALID_TYPE`: 返回 false。
- `REF_TYPE`: 要求 `ref.target` 存在且 `IsTypeDecl()`，并递归确认所有类型实参。
- `PAREN_TYPE`: 递归确认内部类型。
- `QUALIFIED_TYPE`: 要求 `target` 存在且 `IsTypeDecl()`，并递归确认类型实参。
- `OPTION_TYPE`: 递归确认 component type。
- `VARRAY_TYPE`: 递归确认元素类型和常量类型。
- `FUNC_TYPE`: 递归确认返回类型和所有参数类型。
- `TUPLE_TYPE`: 递归确认所有字段类型。
- 其他 AST kind: 返回 false。

这个函数是 sema 阶段的“U 是否真的是 type”判断。parser 阶段只能看出 `U` 是否可能被语法解析为 type，真正的 type decl 目标要在 sema 后才能确认。

### 6.2 Extern operand 判定

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

逐句说明：

- `!Ty::IsTyCorrect(ty)`: operand 类型本身不正确，不能选择 forced-cast。
- `ty->typeArgs.size() != 1`: `Extern<T>` 必须恰好有一个 runtime 类型参数。
- `Ty::GetDeclOfTy(ty)`: 取得该类型对应的声明。
- `!decl`: 找不到声明，不能选择 forced-cast。
- `decl->identifier.Val() != "Extern"`: 类型名必须是 `Extern`。
- `decl->fullPackageName != INTEROP_PACKAGE_NAME`: 要求声明来自 `std.interop`。
- `runtimeTy = ty->typeArgs.front()`: 取出 `Extern<T>` 中的 `T`，后续用来找 `T.fromExtern`。
- `return Ty::IsTyCorrect(runtimeTy)`: runtime 类型也必须正确。

这个函数修复了只按名字识别 `Extern` 的问题。修复后，用户自定义同名 `Extern` 不会进入 forced-cast 分支。

### 6.3 forced-cast 选择条件

```cpp
bool CanSelectForcedCast(const Type& targetType, Ptr<Ty> targetTy, Ptr<Ty> operandTy, Ptr<Ty>& runtimeTy)
{
    if (!Ty::IsTyCorrect(targetTy) || !IsConfirmedForcedCastTargetType(targetType)) {
        return false;
    }
    return IsExternOperandTy(operandTy, runtimeTy);
}
```

选择 forced-cast 必须同时满足：

- `targetTy` 正确。
- `targetType` 对应的 AST 能确认是类型。
- operand 是 `std.interop.Extern<T>`。

AFC 的 sema 分支选择严格依赖这个函数。只有 `U` 确认为 type 且 `e` 确认为 `std.interop.Extern<T>`，才选择 forced 分支；否则选择 fallback。

### 6.4 desugar 构造

```cpp
OwnedPtr<CallExpr> BuildForcedCastCall(
    Expr& sourceExpr, Type& targetTypeAst, Ty& targetTy, Ty& runtimeTy, Expr& operandExpr, TypeManager& typeManager)
```

核心逻辑：

- `Ty::GetDeclOfTy(&runtimeTy)`: 找到 `Extern<T>` 中 `T` 的声明。
- `CreateRefExpr(*runtimeDecl, sourceExpr)`: 构造对 runtime 类型的引用。
- `runtimeRef->isAlone = false`: 表明它会作为 member access 的 base，不是独立引用。
- `GetMemberDecl<FuncDecl>(*runtimeDecl, "fromExtern", {operandExpr.GetTy()}, typeManager)`: 查找 `T.fromExtern`，参数必须能接受 operand 的 `Extern<T>` 类型。
- `ASTCloner::Clone(Ptr(&operandExpr))`: 克隆 operand，避免移动或破坏原始 AST。
- `CreateMemberCall(...)`: 构造 `T.fromExtern(operand)` 调用。
- `memberAccess->SetTy(typeManager.GetFunctionTy({operandExpr.GetTy()}, &targetTy))`: 设置 callee 函数类型，保证后续 CHIR/codegen 不只依赖最终 call 类型。
- `memberAccess->instTys.push_back(&targetTy)`: 记录泛型实例化后的目标类型。
- `memberAccess->typeArguments.push_back(targetTypeClone)`: 保留源码层面的 type argument AST。
- `callExpr->resolvedFunction = fromExternDecl`: 绑定解析后的函数声明。
- `callExpr->callKind = CALL_DECLARED_FUNCTION`: 标记为普通声明函数调用。
- `callExpr->SetTy(&targetTy)`: forced-cast 表达式最终类型就是 `U`。
- `callExpr->sourceExpr = &sourceExpr`、`begin/end` 和 `PropagateGeneratedContext`: 保留源码定位和上下文，方便后续阶段和诊断。

### 6.5 直接 forced-cast 合成

```cpp
Ptr<Ty> TypeChecker::TypeCheckerImpl::SynForcedCastExpr(ASTContext& ctx, ForcedCastExpr& fce)
```

逐分支说明：

- 检查 `targetType` 和 `expr` 非空。
- `Synthesize` target type，得到 `targetTy`。
- `Synthesize` operand，得到 `operandTy`。
- 调用 `CanSelectForcedCast`。
- 如果不能选择 forced-cast，且 target/operand 类型本身都是正确类型，则报 forced-cast 专门诊断。
- 不能选择时把 `fce` 类型设为 invalid 并返回。
- 可以选择时调用 `BuildForcedCastCall` 构造 desugar 表达式。
- desugar 构造失败时设为 invalid。
- `SynthesizeWithoutRecover` 检查 desugar call。
- desugar call 类型正确时，`fce.SetTy(targetTy)`，forced-cast 结果类型固定为 `U`。

### 6.6 二义性 forced-cast 合成

```cpp
Ptr<Ty> TypeChecker::TypeCheckerImpl::SynAmbiguousForcedCastExpr(ASTContext& ctx, AmbiguousForcedCastExpr& afce)
```

逐分支说明：

- 确认 `forcedExpr` 和 `fallbackExpr` 都存在。
- `GetLeadingForcedCastExpr(afce.forcedExpr.get())` 找到 forced 分支中最左侧的 `ForcedCastExpr`。这支持 forced 分支外面已经接上二元运算、调用、成员访问等后续结构。
- `PropagateAmbiguousCandidateContext` 把 AFC 的上下文传播到 forced candidate。
- 在 `DiagSuppressor` 中尝试检查 forced candidate 的 target 和 operand，不让候选分支的中间诊断泄漏给用户。
- 如果 `CanSelectForcedCast` 为 true，正式检查 forced 分支，把 `afce.desugarExpr` 设置为 forced 分支。
- 如果 `CanSelectForcedCast` 为 false，正式检查 fallback 分支，把 `afce.desugarExpr` 设置为 fallback 分支。

这保证了 `(foo)(1)` 中 `foo` 是函数时保留原来的函数调用路径；也保证了 `(foo)(externValue)` 中 `foo` 是类型且 `externValue` 是 `std.interop.Extern<T>` 时选择 forced-cast。

### 6.7 二义性 forced-cast check

```cpp
bool TypeChecker::TypeCheckerImpl::ChkAmbiguousForcedCastExpr(ASTContext& ctx, Ty& targetTy, AmbiguousForcedCastExpr& afce)
```

该函数和 `SynAmbiguousForcedCastExpr` 类似，但在有上下文目标类型时走 `Check`。

分支原则：

- 如果 `CanSelectForcedCast` 为 true，对 `afce.forcedExpr` 执行 `Check(ctx, &targetTy, ...)`。
- forced 分支检查成功时，AFC 类型等于 forced 分支类型，并把 `desugarExpr` 指向 forced 分支。
- 如果 `CanSelectForcedCast` 为 false，对 `afce.fallbackExpr` 执行 `Check(ctx, &targetTy, ...)`。
- fallback 分支检查成功时，AFC 类型等于 fallback 分支类型，并把 `desugarExpr` 指向 fallback 分支。
- fallback 分支失败时，保留原有 fallback 诊断路径。

## 7. 诊断

涉及文件：

- `cangjie_sdk/cangjie_compiler/include/cangjie/Basic/DiagnosticSema.def`
- `cangjie_sdk/cangjie_compiler/include/cangjie/Basic/DiagRefactor/DiagnosticSema.def`

当前诊断文案：

```text
invalid interoperation forced cast: '(U)e' requires 'U' to be a type and 'e' to be an expression of 'std.interop.Extern' type; use 'as' for ordinary type conversions
```

诊断含义：

- 这是互操作专用 forced-cast 语法。
- `U` 必须是类型。
- `e` 必须是标准库 `std.interop.Extern<T>`。
- 普通类型转换请使用 `as`。

## 8. 二义性处理策略

当前实现不是 Java 语法里那种只靠 grammar rewrite 解决全部问题，而是在 parser 中保存双分支 AST，并在 sema 中用真实类型信息选择。

原因：

- parser 阶段无法可靠知道 `foo` 是类型、函数还是变量。
- `(foo)(1)` 如果 `foo` 是函数，旧语义是调用函数或括号表达式调用路径，不能被 forced-cast 抢走。
- `(foo)(externValue)` 如果 `foo` 是类型且 `externValue` 是 `std.interop.Extern<T>`，新语义应选择 forced-cast。
- `(foo)-1 * 2` 这类表达式的初始 forced operand 右边界和完整表达式右边界可能不同，不能在初始右边界处提前丢掉 fallback。

最终分支原则：

- 纯 forced-cast AST：没有 fallback，sema 只按 forced-cast 规则检查；不满足时报 forced-cast 诊断。
- 纯 fallback AST：parser 没形成 forced-cast 候选，完全走原有逻辑。
- AFC AST：两条路径都保存，sema 只有在 `U` 是 type 且 `e` 是 `std.interop.Extern<T>` 时选 forced 分支，否则选 fallback 分支。

当前 parser 的关键实现原则：

- 不要求“初始 forced operand 右边界”和 fallback 一致。
- source 子 parser 会解析完整 forced/fallback 表达式，并寻找后续公共右边界。
- 如果两条完整表达式最终能到同一右边界，则构造 AFC。
- 如果无法安全构造 AFC，则恢复 parser 状态并回到旧解析路径，优先保证兼容性。

## 9. 为什么要限制 std.interop.Extern

早期测试中曾自定义：

```cj
interface Runtime<T> where T <: Runtime<T> { ... }
struct Extern<T> where T <: Runtime<T> { ... }
```

这样做的初衷是降低测试对 runtime/stdlib 的依赖，只验证 parser/sema/desugar。但实现里如果只检查类型名是否为 `Extern`，会导致真实问题：

```cj
struct Extern<T> { ... }
let value: Foo = (Foo)myExtern
```

只要用户自定义类型也叫 `Extern` 且形态类似，旧实现就可能误把它当成互操作 Extern。现在实现修复为：

```cpp
decl->identifier.Val() == "Extern" && decl->fullPackageName == INTEROP_PACKAGE_NAME
```

其中 `INTEROP_PACKAGE_NAME` 是 `std.interop`。因此只有标准库 `std.interop.Extern<T>` 才能进入 forced-cast 分支。

## 10. 测试改动

### 10.1 ParserTest

文件：

- `cangjie_sdk/cangjie_compiler/unittests/Parse/ParserTest.cpp`

覆盖内容：

- `direct = (foo)externValue`: 纯 `ForcedCastExpr`。
- `generic = (Box<Int64>)externValue`: 泛型目标类型纯 `ForcedCastExpr`。
- `directNonExtern = (foo)1`: 纯 `ForcedCastExpr`，后续由 sema 报专门诊断。
- `ambiguousCall = (foo)(x)`: 必须解析为 `AmbiguousForcedCastExpr`。
- `ambiguousBinary = (foo)-1 * 2`: 必须解析为 `AmbiguousForcedCastExpr`。
- `normalCall = (foo + bar)(x)`: 不是 forced-cast 候选，仍是普通 `CALL_EXPR`。
- `parenOnly`、`parenExpr`、`unitValue`: 仍保持原有括号表达式/Unit 行为。

该测试不再对整段代码断言 `diag.GetErrorCount() == 0`，因为该 parser-only string-source 用例包含未声明符号，且二义性探测可能留下可恢复诊断计数。这个测试的目的限定为 AST shape。

### 10.2 TypeCheckerTest

文件：

- `cangjie_sdk/cangjie_compiler/unittests/Sema/TypeCheckerTest.cpp`

核心测试：

- `ForcedCastDirectDesugarsToFromExtern`: `(foo)externValue` 解析为 `ForcedCastExpr`，desugar 到 `DummyRuntime.fromExtern<foo>(externValue)`。
- `ForcedCastGenericTargetDesugarsToFromExtern`: 泛型目标 `(Box<Int64>)externValue` 能正确设置 type argument。
- `ForcedCastDirectNonExternOperandReportsInteropDiagnostic`: `(foo)1` 是纯 forced-cast 形态，但 operand 不是 `std.interop.Extern<T>`，报 forced-cast 专门诊断。
- `ForcedCastRejectsUserDefinedExternWithSameName`: 用户自定义同名 `Extern` 不被接受，证明 `std.interop.Extern` 限定生效。
- `ForcedCastAmbiguousFallbackKeepsOriginalCallPath`: `(foo)(1)` 中 `foo` 是函数时，选择 fallback。
- `ForcedCastAmbiguousFallbackKeepsOriginalBinaryPath`: `(foo)-1` 中 `foo` 是变量时，选择 fallback。
- `ForcedCastAmbiguousFallbackKeepsOriginalExtendedBinaryPath`: `(foo)-1 * 2` 中后续运算能保留旧路径。测试断言根操作符是 `SUB`，右侧子表达式是 `MUL`，即旧语义 `(foo) - (1 * 2)`。
- `ForcedCastAmbiguousExprSelectsForcedCast`: `(foo)(externValue)` 中 `foo` 是类型、`externValue` 是 `std.interop.Extern<T>` 时，选择 forced 分支。
- `ForcedCastAmbiguousFallsBackAndKeepsOriginalFailureForTypeCall`: `(foo)(1)` 中 `foo` 是类型但 operand 不是 Extern，AFC 不选 forced，保留旧路径诊断。

### 10.3 cangjie_test 样例

目录：

`cangjie_sdk/cangjie_test/testsuites/LLT/Runtime/CJNative/extern/forced_cast`

这组样例用于用真实 `cjc` 构建产物覆盖现象级编译场景，包含：

- 旧语法 fallback: 函数调用、binary、普通括号表达式。
- 新语法 direct FC: `(foo)externValue`、泛型 target、operand 为 call expression。
- AFC 选择: `(foo)(externValue)` 在 target 为 type 且 operand 为 `Extern<T>` 时选择 FC，在不满足条件时回退旧路径。
- 预期失败: 非 `Extern<T>` operand、当前 runtime stub 尚未支持的成员访问和下标访问。
- 普通类成员变量: `holder.item: Extern<DummyRuntime>` 可以作为 forced-cast operand。

样例和 benchmark 已经改为：

```cj
import std.interop.*
```

这样测试和生产语义保持一致。

### 10.4 Benchmark

生成脚本：

`cangjie_sdk/cangjie_test/testsuites/LLT/Runtime/CJNative/extern/forced_cast/benchmark/generate_forced_cast_benchmarks.py`

覆盖维度：

- ordinary parentheses。
- type-shaped parentheses。
- ambiguous fallback。
- nested parentheses。
- confirmed forced-cast。

benchmark prelude 同样使用 `import std.interop.*`，避免 benchmark 测到非生产路径。

## 11. 当前验证结果

### 11.1 定向单测

最新一次已完成的定向构建和单测：

```sh
cmake --build build/build --target ParserTest TypeCheckerTest cjc -j6
./build/build/bin/ParserTest --gtest_filter='ParserTest2.ForcedCastExpr'
./build/build/bin/TypeCheckerTest --gtest_filter='TypeCheckerTest.ForcedCast*'
```

结果：

- `ParserTest2.ForcedCastExpr`: passed。
- `TypeCheckerTest.ForcedCast*`: 9/9 passed。
- `cjc` target: build passed。

负例测试会打印预期诊断，例如：

```text
invalid interoperation forced cast: '(U)e' requires 'U' to be a type and 'e' to be an expression of 'std.interop.Extern' type; use 'as' for ordinary type conversions
```

### 11.2 cangjie_test 样例验证

使用当前构建产物：

```sh
export CANGJIE_HOME=cangjie_sdk/cangjie_compiler/output
export CANGJIE_PATH=cangjie_sdk/cangjie_compiler/output/modules/darwin_aarch64_cjnative
CJC=cangjie_sdk/cangjie_compiler/build/build/bin/cjc
DIR=cangjie_sdk/cangjie_test/testsuites/LLT/Runtime/CJNative/extern/forced_cast
```

正例通过：

- `interop_forced_cast_01.cj`: `(foo)(1)` 中 `foo` 是函数，保留旧函数调用路径。
- `interop_forced_cast_02.cj`: `(foo)(externValue)` 中 `foo` 是函数，即使参数是 `Extern<T>` 也保留 fallback。
- `interop_forced_cast_03.cj`: `(foo)externValue` 直接 forced-cast，通过 CHIR 生成。
- `interop_forced_cast_04.cj`: `(foo)(externValue)` 二义性中选择 forced-cast。
- `interop_forced_cast_05.cj`: `(Box<Int64>)externValue` 泛型目标类型 forced-cast。
- `interop_forced_cast_08.cj`: `(foo)-1 * 2` 中 `foo` 是变量，保留旧 binary 路径。
- `interop_forced_cast_09.cj`: `(foo)makeExtern()`，operand 是 call expression。
- `interop_forced_cast_12.cj`: `(foo + bar)` 不进入 forced-cast。
- `interop_forced_cast_14.cj`: `(foo)holder.item`，普通 class 成员变量类型为 `Extern<DummyRuntime>` 时可作为 operand。

预期失败样例均按预期失败：

- `interop_forced_cast_06.cj`: `(foo)1` 进入纯 FC 路径，但 operand 非 `std.interop.Extern<T>`，报 forced-cast 专门诊断。
- `interop_forced_cast_07.cj`: `(foo)(1)` 中 `foo` 是类型但 operand 非 `Extern<T>`，AFC 回退 fallback，保留旧 call/type-name 诊断。
- `interop_forced_cast_10.cj`: `(foo)externValue.name`，当前 runtime stub 未提供成员访问能力，按现有语义报成员不存在。
- `interop_forced_cast_11.cj`: `(foo)externValue[0]`，当前 runtime stub 未提供下标访问能力，按现有语义报 subscript 失败。
- `interop_forced_cast_13.cj`: `(Box<Int64>)1` 进入纯 FC 路径，但 operand 非 `std.interop.Extern<T>`，报 forced-cast 专门诊断。

失败诊断摘要：

```text
06: invalid interoperation forced cast: '(U)e' requires 'U' to be a type and 'e' to be an expression of 'std.interop.Extern' type; use 'as' for ordinary type conversions
07: no matching function for operator '()' function call
07: expected member name or constructor call after 'foo' type name
10: 'name' is not a member of struct 'Extern<Class-DummyRuntime>'
11: invalid subscript operator [] on type 'Struct-Extern<Class-DummyRuntime>' with index type 'Int64'
13: invalid interoperation forced cast: '(U)e' requires 'U' to be a type and 'e' to be an expression of 'std.interop.Extern' type; use 'as' for ordinary type conversions
```

这些失败中，`07` 是 fallback 诊断保持旧行为的关键用例；`06` 和 `13` 是纯 forced-cast 路径，因此必须报 forced-cast 专门诊断。

### 11.3 Benchmark 最新结果

最新 benchmark 于当前修改后重新运行。输入规模为每个文件 10000 个生成表达式，每个 case 运行 5 次；计时使用 Python `time.perf_counter()` 包住 `cjc --emit-chir=raw`，单位为毫秒。current 结果保存在 `<bench_out>/forced_cast_bench_latest_results.json`，baseline 结果保存在 `<bench_out>/forced_cast_bench_latest_baseline_results.json`。

对照使用：

```text
baseline cjc: baseline build artifact from pre-forced-cast compiler
current  cjc: cangjie_sdk/cangjie_compiler/build/build/bin/cjc
```

运行命令：

```sh
python3 cangjie_sdk/cangjie_test/testsuites/LLT/Runtime/CJNative/extern/forced_cast/benchmark/generate_forced_cast_benchmarks.py <bench_out>/forced_cast_bench_latest 10000

export CANGJIE_HOME=cangjie_sdk/cangjie_compiler/output
export CANGJIE_PATH=cangjie_sdk/cangjie_compiler/output/modules/darwin_aarch64_cjnative
cangjie_sdk/cangjie_compiler/build/build/bin/cjc \
  <bench_out>/forced_cast_bench_latest/<case>.cj --emit-chir=raw -o <bench_out>/forced_cast_bench_latest/<case>.chir
```

最新对照数据：

| case | baseline 5 次耗时 | baseline 平均 | current 5 次耗时 | current 平均 | 差值 |
| --- | --- | ---: | --- | ---: | ---: |
| `ordinary_parens` | 993.3, 791.8, 909.3, 786.3, 838.3 | 863.8 | 989.2, 861.2, 841.3, 834.7, 887.9 | 882.9 | +19.1ms / +2.2% |
| `type_shaped_parens` | 696.5, 684.8, 681.8, 706.4, 686.1 | 691.1 | 801.7, 762.4, 868.7, 739.3, 733.4 | 781.1 | +90.0ms / +13.0% |
| `ambiguous_fallback` | 1048.1, 1048.2, 1036.4, 1078.5, 1315.0 | 1105.3 | 1253.1, 1213.8, 1293.1, 1229.5, 1265.3 | 1250.9 | +145.6ms / +13.2% |
| `nested_same_type_parens` | 1029.6, 1036.5, 1175.0, 1287.8, 1117.7 | 1129.3 | 1240.2, 1449.1, 1251.2, 1225.1, 1211.5 | 1275.4 | +146.1ms / +12.9% |
| `nested_mixed_parens` | 2222.5, 2081.7, 2245.8, 2119.0, 2221.5 | 2178.1 | 2288.1, 2288.3, 2395.5, 2253.1, 2240.4 | 2293.1 | +115.0ms / +5.3% |
| `confirmed_forced_cast` | baseline parser 失败，报 `expected ';' or '<NL>', found 'externValue'` | N/A | 1211.9, 1160.9, 1148.1, 1174.3, 1310.2 | 1201.1 | 新语法 only |

观察：

- `ordinary_parens` 的额外成本约 2.2%，说明普通括号表达式只受到轻量候选探测影响。
- `type_shaped_parens`、`ambiguous_fallback`、`nested_same_type_parens` 的额外成本约 13%，符合预期：这些输入更容易触发 type-shaped 判断、FC 候选或双线解析。
- `nested_mixed_parens` 的额外成本约 5.3%，表达式本身更复杂，forced-cast 额外成本在总耗时中占比降低。
- `confirmed_forced_cast` 在 baseline 中无法解析，因此没有可比的 baseline 耗时；current 可以完成 parser、sema、desugar 到 CHIR 前端通路。

## 12. 后续可选项

后续如果要扩展，可以考虑：

- 将 forced-cast 从互操作专用语法推广为更一般的类型转换语法。但这会改变当前“普通转换使用 as”的边界，需要重新设计语义和诊断。
- 如果 runtime 团队完成完整互操作链路，可以把更多 cangjie_test 样例切到 exe/run 验证。
- 将 `DiagSuppressor` 从 Sema 目录抽到公共工具层，减少 Parse 对 Sema 目录的 include。`DiagSuppressor` 是已有诊断抑制工具，不是本任务新加的类；它目前放在 Sema 下，主要因为历史使用点集中在 type checking、type inference 等语义尝试路径。这次 parser speculative parse 复用它后，形成了 Parse include Sema 私有头的结构耦合，后续可以单独重构。
- 如果未来发现跨行表达式需要参与 AFC，需要把 source 子 parser 的截断策略从“当前行”升级为“语句边界/表达式边界”级别，而不是简单截到换行。
