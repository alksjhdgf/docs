# Forced Cast 诊断压制方案对比

forced cast 的 parser 需要进行试探性解析。试探分支可能产生诊断，但该分支之后可能不会被采用，因此这些诊断需要被临时压制并在分支丢弃时清除。

## 当前方案：Parser 局部 Guard

`DiagSuppressor` 保留在 `Sema` 原位置，`Parser` 不 include `Sema`。在 `ParseAtom.cpp` 内部定义一个只服务 forced-cast speculative parsing 的局部 RAII guard，直接调用 `DiagnosticEngine::DisableDiagnose()` 和 `DiagnosticEngine::EnableDiagnose(origin)`。

该方案的核心形态如下：

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

优点：

- 修改面更小。
- 不移动 `DiagSuppressor`，不影响 sema 原有结构。
- 不引入 `Parser -> Sema` 依赖。
- 不需要新增 `Basic` 头文件、实现文件或构建配置。
- 更容易作为 forced-cast parser 的局部实现提交和评审。

缺点：

- parser 和 sema 会各有一份基于 `DiagnosticEngine` 诊断开关的 RAII 包装。
- 长期看不如公共工具层统一。
- 如果未来 `DiagnosticEngine::DisableDiagnose()` / `EnableDiagnose()` 语义变化，需要同时检查 parser 局部 guard 和 sema 的 `DiagSuppressor`。

## 原先方案：移动 DiagSuppressor 到 Basic

将 `DiagSuppressor` 从 `Sema` 移到 `Basic`，让 parser 和 sema 共用同一个公共诊断压制工具。

优点：

- 只有一份公共实现。
- parser 和 sema 的诊断压制行为保持一致。
- 模块边界更工整，不需要让 parser 依赖 sema。
- 更适合后续如果有更多编译阶段需要复用诊断压制能力的情况。

缺点：

- 修改面更大。
- 需要新增或移动公共头文件与实现文件。
- 需要调整 `Basic` 的构建配置。
- PR 中会出现一个公共工具层移动，评审范围会比 forced cast 主逻辑更宽。

## 结论

如果优先考虑长期结构，移动 `DiagSuppressor` 到 `Basic` 更工整。

如果当前优先考虑合入便利性和最小修改面，则采用 parser 局部 guard 更合适。它保留了 forced cast 双分支解析所需的诊断隔离能力，同时避免扩大公共模块修改范围。
