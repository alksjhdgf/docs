# Cangjie-ArkTS Interop 测试审阅

## 1. 范围

本文档审阅 `/Users/ppp/Projects/arkcompiler_cangjie_ark_interop/test` 下与 Cangjie-ArkTS interop 直接相关的测试，重点覆盖两部分：

- `test/arkts_interop_testsuites`
- `test/CJInteropsTest`

未将 `test/xts` 作为本文重点，因为它更偏向 OpenHarmony API/XTS 场景验证，而不是专门的 Cangjie-ArkTS interop 回归集。

## 2. 测试分层结论

当前 interop 测试大致分成两层：

- 场景化集成样例：`test/arkts_interop_testsuites`
  以 testsuite 为单位组织，通常是一个完整 Harmony 工程，覆盖导入、动态加载、IDL、反射、线程、UTF-16、worker 等具体场景。
- 核心能力回归集：`test/CJInteropsTest`
  更像底层能力回归仓，覆盖 `JSContext`、`JSValue`、`JSModule`、异常、Promise、BigInt、module register、newScope、mixed stack 等核心接口行为。

这两层的关系是：

- `arkts_interop_testsuites` 更偏“功能/产品场景验证”
- `CJInteropsTest` 更偏“底层接口/行为回归验证”

## 3. testsuite 总览

### 3.1 `test/arkts_interop_testsuites`

| Suite | 主要内容 | 目的 | 审阅结论 |
| --- | --- | --- | --- |
| `testsuite_basic_import` | ArkTS 直接导入 `libohos_app_cangjie_entry.so`，调用 `doAdd`、`doString`、`doBool` 等 | 验证最基础的 ArkTS -> Cangjie 导入与调用链路 | 偏 smoke test，`testAdd.test.ets` 主要验证调用不崩溃，断言强度较弱 |
| `testsuite_dynamic_load` | 主工程 + `dependency` 子工程，包含动态加载与依赖模块测试 | 验证动态加载 Cangjie 模块/依赖模块的工程组织和运行链路 | `entry/src/main/cangjie/test_list.cj` 为空，更多依赖 `dependency/src/ohosTest/cangjie` 侧用例，结构较特殊 |
| `testsuite_hybrid` | `Array`、`ArrayBuffer`、`BigInt`、`Exception`、`External`、`Function`、`Object`、`Promise`、`Register*`、路径加载、线程错误等 | 验证最主要的双向 interop 能力 | 是 ArkTS 侧最核心、覆盖面最广的一组集成回归 |
| `testsuite_idl` | `async function`、`enum`、`named parameter`、`Option`、参数数量/类型、返回值、`JSArrayEx`、`JSMapEx`、`JSStringEx`、`BinaryTree`、`Zoo` | 验证 IDL/声明式接口生成后的 ArkTS 可用性和类型映射 | 覆盖“声明生成结果是否正确可调用”这一关键面 |
| `testsuite_load_cangjie_so` | 通过 `requireCJLib` 反复加载同一个 so，并检查全局状态 | 验证 Cangjie so 加载、重复加载和状态保持 | 目标明确，能发现加载器/初始化相关问题 |
| `testsuite_pure_cj` | `JSArray`、`JSArrayBuffer`、`JSBigInt` 等仓颉侧单测 | 验证纯仓颉工程内的 interop 基础能力 | 覆盖面较小，偏基础 sanity check |
| `testsuite_pure_manual_interop` | `Array`、`ArrayBuffer`、`BigInt`、`JSClass`、`JSError`、`Exception`、`External`、`IDLType`、`JSCallInfo`、`JSContext`、`JSValue`、`Object`、`Promise`、`String`、`Symbol`、`Utf16String` | 验证手写 interop API 时各基础类型和运行时接口行为 | 是纯仓颉侧最系统的一组底层回归 |
| `testsuite_reflect` | `TestReflect.cj` 中验证 `TypeInfo`、注解、构造、成员反射 | 验证 reflect 基础能力在 interop 工程中的可用性 | 覆盖较聚焦，强调基础反射能力 |
| `testsuite_reflection` | 大量 `testGetInstanceFunctions_*`、`testGetStaticFunctions_*`、`testPointApplyGenericGlobalFunction_*` | 验证反射调用、泛型实参、参数数量/类型错误、异常消息 | 是反射场景下最重的一组边界/异常回归 |
| `testsuite_stringUtf16` | `compare`、`substr`、`split`、`indexOf`、`replace`、`contains`、`startsWith`、`endsWith` | 验证 UTF-16 字符串跨语言处理 | 覆盖字符串细节多，适合发现编码/索引类问题 |
| `testsuite_threads` | `spawn(UIThread)`、点击触发、事件等待 | 验证 interop 场景下 ArkTS 线程/UI 线程协同 | 重点在调度与线程绑定，不是类型转换测试 |
| `testsuite_worker_thread` | ArkTS `worker`、页面按钮触发、UI 自动化断言结果文本 | 验证 worker 线程中加载 Cangjie 模块和消息回传 | 覆盖 worker 场景，和 `testsuite_threads` 互补 |

### 3.2 `test/CJInteropsTest`

`CJInteropsTest` 可以理解为一个更底层的综合回归工程，主要分为两部分：

- `entry/src/main/cangjie/src/pure`
  纯仓颉侧测试，共 22 个 `.cj` 文件，覆盖：
  - `TestArray`
  - `TestArrayBuffer`
  - `TestBigInt`
  - `TestJSClass`
  - `TestJSError`
  - `TestException`
  - `TestExternal`
  - `TestIDLType`
  - `TestJSCallInfo`
  - `TestJSContext`
  - `TestJSType`
  - `TestJSValue`
  - `TestObject`
  - `TestPrime`
  - `TestPromise`
  - `TestString`
  - `TestSymbol`
  - `TestUtf16String`
  - `sdkApiVersion >= 23` 时额外验证 `TestRequireArkModule`

- `entry/src/ohosTest/ets/test`
  ArkTS 侧测试，共 20 个 `.ets` 文件，覆盖：
  - `array_buffer_01`
  - `promise_00` / `promise_01`
  - `post_jstask_01`
  - `function_01`
  - `exception_01`
  - `test_big_int_00` / `test_big_int_01`
  - `test_type_value_00`
  - `test_register_class`
  - `test_register_func`
  - `test_register_module`
  - `test_register_override`
  - `test_register_after_static_init`
  - `test_external_00`
  - `test_newScope`
  - `test_mixed_stack`
  - 以及 `PureWorker.ets` 等辅助逻辑

其中比较有代表性的内容：

- `test_register_module.test.ets`
  验证 Cangjie 侧注册给 ArkTS 的导出值是否覆盖 `undefined`、`null`、`boolean`、`number`、`string`、`function`、`class`、`symbol`、`array`、`plain object`、`bigint`、`ArrayBuffer`、`external` 等类型。
- `test_newScope.test.ets`
  验证 `JSContext.newScope` 相关的内存泄漏修复、超出作用域引用、线程不匹配等问题。
- `test_mixed_stack`
  用于验证跨语言混合调用栈及异常传播。

整体上，`CJInteropsTest` 是仓内最接近“底层能力回归基线”的测试集合。

## 4. 主要测试目的归纳

从测试内容看，当前仓库的 interop 测试主要在验证以下目标：

1. 模块加载与导入
   - ArkTS 静态导入 Cangjie so
   - 运行时 `requireCJLib`
   - 重复加载/动态加载
   - ArkTS 模块反向被仓颉侧 `require`

2. 双向函数调用与导出
   - ArkTS 调 Cangjie
   - Cangjie 注册函数/模块/类给 ArkTS
   - 回调、异步函数、post JS task

3. 类型映射正确性
   - 基础类型：`bool`、`number`、`string`
   - 复合类型：`Array`、`ArrayBuffer`、`Object`、`Map`
   - 特殊类型：`BigInt`、`Symbol`、`Option`
   - 高阶类型：函数类型、类、接口、泛型参数

4. 运行时与上下文行为
   - `JSContext`
   - `JSValue`
   - `JSCallInfo`
   - `JSType` / `IDLType`
   - `newScope`

5. 异常与边界条件
   - 参数数量不匹配
   - 参数类型不匹配
   - 泛型实参数量不匹配
   - 线程不匹配
   - 越界/超出作用域引用
   - 混合栈异常传播

6. 线程与调度
   - UIThread 绑定
   - `spawn(UIThread)`
   - worker 线程消息传递

7. 字符串与编码
   - UTF-16 比较、截取、查找、替换、包含判断等

8. 反射
   - 类型信息获取
   - 注解查询
   - 构造调用
   - 反射式成员函数/静态函数调用
   - 泛型函数 `apply`

## 5. 审阅观察

### 优点

- 覆盖面比较完整，既有 ArkTS 侧集成样例，也有仓颉侧底层回归。
- `hybrid`、`pure_manual_interop`、`CJInteropsTest` 三组用例基本构成了 interop 主干能力的回归骨架。
- `reflection`、`threads`、`worker_thread`、`stringUtf16` 这些容易出细节问题的方向都有单独 testsuite。

### 当前特点

- 一部分用例是强断言测试，例如 `testsuite_idl`、`testsuite_load_cangjie_so`、`CJInteropsTest` 中的 ArkTS 侧测试。
- 一部分用例更偏 smoke/sanity test，例如 `testsuite_basic_import` 中仅调用接口、默认以“不崩溃”为通过条件。
- 一部分仓颉侧 testsuite 通过 `registerTestSuite` + `std.unittest` 运行，没有额外 ArkTS 断言层，这意味着排障时需要结合仓颉测试日志阅读。

### 需要维护时特别注意的点

- `testsuite_dynamic_load` 的入口 `test_list.cj` 为空，测试重点在依赖工程和加载链路，不要按普通 testsuite 理解。
- `testsuite_reflect` 与 `testsuite_reflection` 名字接近，但定位不同：
  - `reflect` 偏基础反射能力
  - `reflection` 偏大量边界/异常/泛型调用验证
- `CJInteropsTest` 中存在 `sdkApiVersion` 条件分支，升级 API level 时需要复查条件覆盖。

## 6. 后续维护建议

1. 新增 interop 类型或 API 时，优先同步更新以下三层：
   - `testsuite_hybrid`
   - `testsuite_pure_manual_interop`
   - `test/CJInteropsTest`

2. 如果新增的是声明式导出/IDL 相关能力，优先补 `testsuite_idl`。

3. 如果新增的是线程、调度、scope、runtime 生命周期相关能力，优先补：
   - `testsuite_threads`
   - `testsuite_worker_thread`
   - `CJInteropsTest` 中的 `test_newScope` / `post_jstask`

4. 对 smoke test 场景，建议后续逐步补强显式断言，尤其是：
   - `testsuite_basic_import`
   - 部分仅调用不校验返回值的 UTF-16 / 基础导入用例

## 7. 结论

这个仓库的 Cangjie-ArkTS interop 测试体系已经具备比较清晰的“双层结构”：

- `arkts_interop_testsuites` 负责按功能场景做集成验证
- `CJInteropsTest` 负责做底层接口和边界行为回归

如果后续要维护或扩展 interop 测试，最值得优先关注的是：

- `testsuite_hybrid`
- `testsuite_idl`
- `testsuite_pure_manual_interop`
- `testsuite_reflection`
- `test/CJInteropsTest`

这几部分最能代表当前仓库对 interop 核心能力的覆盖深度。
