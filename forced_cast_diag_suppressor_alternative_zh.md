# Forced Cast 诊断压制的最小改动方案

## 背景

forced cast 的 parser 实现需要处理 `(U)e` 与既有括号表达式路径之间的歧义。当前设计会在 parser 阶段构造 forced-cast 候选分支和 fallback 分支，之后在 sema 阶段根据真实类型选择最终采用的分支。

这个过程需要进行试探性解析。试探性解析可能调用现有 parser 入口，例如 `ParseType()`、`ParseBaseExpr()`、`ParseExpr()`。这些入口在失败或恢复时可能会直接向 `DiagnosticEngine` 写入诊断信息。

但是，试探性分支并不一定会成为最终采用的分支。如果在试探过程中立即保留这些诊断，用户可能会看到来自“最终被丢弃分支”的错误信息。因此，forced-cast parser 需要一种局部机制，在试探解析期间临时收起诊断，并在该试探分支结束后丢弃这些诊断。

## 目标

该方案的目标是减少 forced cast PR 的代码修改面，同时避免不合理的模块依赖。

具体目标如下：

- `DiagSuppressor` 继续保留在 `Sema` 原位置，不移动到 `Basic`。
- `Parser` 不 include `Sema` 目录下的 `DiagSuppressor`。
- `ParseAtom.cpp` 内部定义一个只服务 forced-cast speculative parsing 的局部 RAII guard。
- 该局部 guard 直接使用 `DiagnosticEngine` 已有的 `DisableDiagnose()` 和 `EnableDiagnose(origin)` 能力。
- 试探性 parser 诊断在分支结束后被丢弃，不影响最终用户可见诊断。

## 方案

在 `ParseAtom.cpp` 中定义一个局部 guard，例如：

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

使用方式如下：

```cpp
OwnedPtr<Expr> fallbackExpr;
{
    ForcedCastDiagGuard guard(diag);
    auto fallbackBase = ParseConventionalLeftParenExprInKind(ek, leftParenPos);
    fallbackExpr = ParseExpr(Token{TokenKind::DOT}, std::move(fallbackBase), ek);
    guard.DropSpeculativeDiags();
}
```

该 guard 的执行逻辑如下：

1. 进入作用域时调用 `diag.DisableDiagnose()`，暂时关闭即时诊断输出，并保存进入前已有的诊断状态。
2. 试探性 parser 逻辑继续执行。期间产生的诊断会暂存在 `DiagnosticEngine` 内部，而不是立即成为最终诊断。
3. 试探性分支结束后调用 `DropSpeculativeDiags()`，丢弃本次试探产生的诊断。
4. 离开作用域时析构 guard，调用 `diag.EnableDiagnose(originDiags)`，恢复进入该作用域之前的诊断状态。

## 为什么不能简单做到 “Parser 只返回 AST 或失败，诊断到 Sema 再出现”

该方向不适合当前代码结构。

现有 parser 入口不是纯返回值模型。`ParseType()`、`ParseExpr()`、`ParseBaseExpr()` 等函数在解析失败、错误恢复或遇到非法 token 时，会直接通过 `DiagnosticEngine` 记录诊断。因此，parser 中的失败并不是一个单纯的 `nullptr` 或 `INVALID_EXPR` 状态，它已经带有诊断副作用。

此外，sema 阶段不会重新 parse 源码。如果 parser 试探分支失败时没有保留下可用 AST，sema 无法自然地重新生成该分支，也无法自动还原 parser 当时应该产生的诊断。

因此，如果要真正实现“parser 完全不产生诊断，只把诊断延迟到 sema”，需要较大规模地重构 parser 诊断模型，例如：

- 为 parser 增加纯 speculative parse 模式，使解析失败只返回状态而不写诊断。
- 将 parser 诊断缓存到 AST 节点或其他中间结构中，等 sema 选择分支后再释放。
- 让 sema 能够重新驱动 parser 对源代码片段进行二次解析。

这些方案都会显著扩大修改面，不适合作为当前 forced cast 任务的落地方案。

## 与移动 DiagSuppressor 到 Basic 的比较

### 移动到 Basic

将 `DiagSuppressor` 从 `Sema` 移到 `Basic` 是长期更工整的方案。它可以让 parser 和 sema 共用同一个诊断压制工具，避免重复实现，也避免 `Parser -> Sema` 的反向依赖。

优点：

- 只有一份公共实现。
- parser 和 sema 的诊断压制行为保持一致。
- 模块边界清晰，不会引入 `Parser -> Sema` 依赖。

缺点：

- 修改面更大。
- 需要新增或移动公共头文件与实现文件。
- 需要调整 `Basic` 的构建配置。
- PR review 中会引入一个与 forced cast 主逻辑不完全同层级的公共工具移动。

### 保留在 Sema，Parser 使用局部 guard

该方案保留 `Sema` 中原有的 `DiagSuppressor`，只在 `ParseAtom.cpp` 中增加一个 forced-cast 专用的窄用途 guard。

优点：

- 修改面更小。
- 不改变 sema 原有代码结构。
- 不新增 `Parser -> Sema` 依赖。
- 不需要调整 `Basic` 构建配置。
- 更容易解释为 forced-cast parser 内部的局部 speculative parse 机制。

缺点：

- parser 和 sema 会各有一份基于 `DiagnosticEngine::DisableDiagnose()` / `EnableDiagnose()` 的 RAII 包装。
- 如果未来 `DiagnosticEngine` 的诊断压制接口语义发生变化，需要同时检查这两处使用。
- 从长期维护角度看，不如抽公共工具层工整。

## 其他可选方案

### Parser 直接 include Sema 的 DiagSuppressor

该方案修改量最小，但不推荐。

它会引入 `Parser -> Sema` 的依赖。parser 属于更早的编译阶段，不应依赖 sema 内部工具。该依赖会让模块边界变得不清晰，也可能带来后续 include、构建层级或循环依赖问题。

### Parser 中完整复制一份 DiagSuppressor

该方案可以避免跨模块依赖，但不推荐完整复制。

完整复制会形成两个几乎相同的工具实现，后续如果一处行为调整，另一处可能遗漏，导致 parser 和 sema 的诊断压制行为不一致。

相比之下，局部 guard 只保留 forced-cast parser 需要的最小能力，不复制 `ReportDiag()`、`HasError()` 等 sema 侧当前使用的完整接口，重复面更小。

### 重构 parser 诊断模型

该方案从架构上最彻底，但不适合当前任务。

如果未来 parser 需要更多 speculative parse 场景，可以考虑设计统一的 parser speculative diagnostic 机制。但这会涉及 parser 错误恢复、诊断生命周期、AST 中间状态等更大范围的设计，不应作为 forced cast 的前置工作。

## 结论

如果优先考虑长期模块边界和复用性，将 `DiagSuppressor` 抽到 `Basic` 是更工整的方案。

如果当前更看重 PR 的合入便利性和最小修改面，则可以采用本文方案：`DiagSuppressor` 保留在 `Sema`，`Parser` 不依赖 `Sema`，并在 `ParseAtom.cpp` 内部使用一个 forced-cast 专用局部 guard 来临时压制并丢弃试探性 parser 诊断。

该方案保留了 forced cast 双分支解析所需的诊断隔离能力，同时避免扩大公共模块修改范围。
