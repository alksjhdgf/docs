# Cangjie-ArkTS Interop Test Review

## 1. Scope

This document reviews the test content in `/Users/ppp/Projects/arkcompiler_cangjie_ark_interop/test` that is directly related to Cangjie-ArkTS interoperability. The main focus is:

- `test/arkts_interop_testsuites`
- `test/CJInteropsTest`

`test/xts` is not the main focus here because it is broader OpenHarmony API/XTS validation rather than a dedicated Cangjie-ArkTS interop regression set.

## 2. High-Level Structure

The current interop tests are organized in two layers:

- Scenario-oriented integration suites: `test/arkts_interop_testsuites`
  Each testsuite is usually a complete Harmony project and validates a specific scenario such as import, dynamic load, IDL, reflection, threads, UTF-16, or worker threads.
- Core capability regression set: `test/CJInteropsTest`
  This is closer to a low-level regression project. It validates `JSContext`, `JSValue`, `JSModule`, exceptions, promises, BigInt, module registration, `newScope`, mixed stack behavior, and similar core interop features.

In practice:

- `arkts_interop_testsuites` is more feature/scenario oriented.
- `CJInteropsTest` is more low-level and behavior oriented.

## 3. Suite Overview

### 3.1 `test/arkts_interop_testsuites`

| Suite | Main Content | Purpose | Review Note |
| --- | --- | --- | --- |
| `testsuite_basic_import` | ArkTS imports `libohos_app_cangjie_entry.so` directly and calls `doAdd`, `doString`, `doBool`, and similar APIs | Validate the most basic ArkTS -> Cangjie import and invocation flow | Mostly a smoke test. `testAdd.test.ets` mainly checks that calls do not fail, with limited assertions |
| `testsuite_dynamic_load` | Main project plus a `dependency` subproject, with dynamic loading and dependency-side tests | Validate dynamic loading of Cangjie modules and dependency modules | `entry/src/main/cangjie/test_list.cj` is empty; the suite relies heavily on dependency-side tests and load flow verification |
| `testsuite_hybrid` | `Array`, `ArrayBuffer`, `BigInt`, `Exception`, `External`, `Function`, `Object`, `Promise`, `Register*`, path loading, thread mismatch, and more | Validate the major bidirectional interop capabilities | This is the broadest ArkTS-side integration regression suite |
| `testsuite_idl` | `async function`, `enum`, named parameters, `Option`, parameter count/type, return types, `JSArrayEx`, `JSMapEx`, `JSStringEx`, `BinaryTree`, `Zoo` | Validate generated IDL/declarative interfaces and type mapping on the ArkTS side | Covers a key area: whether generated declarations are correct and callable |
| `testsuite_load_cangjie_so` | Repeatedly loads the same Cangjie so via `requireCJLib` and checks global state | Validate so loading, repeated loading, and state persistence | Clear objective; useful for catching loader/init issues |
| `testsuite_pure_cj` | Cangjie-side tests for `JSArray`, `JSArrayBuffer`, `JSBigInt`, and similar basics | Validate base interop capability inside a pure Cangjie project | Small and focused; mostly sanity coverage |
| `testsuite_pure_manual_interop` | `Array`, `ArrayBuffer`, `BigInt`, `JSClass`, `JSError`, `Exception`, `External`, `IDLType`, `JSCallInfo`, `JSContext`, `JSValue`, `Object`, `Promise`, `String`, `Symbol`, `Utf16String` | Validate low-level behavior when interop code is written manually | The most systematic pure-Cangjie low-level regression set |
| `testsuite_reflect` | `TestReflect.cj` validates `TypeInfo`, annotations, constructors, and reflected members | Validate basic reflection capability inside an interop project | Narrow but important reflection baseline |
| `testsuite_reflection` | Many `testGetInstanceFunctions_*`, `testGetStaticFunctions_*`, `testPointApplyGenericGlobalFunction_*` cases | Validate reflective invocation, generic arguments, parameter count/type errors, and exception messages | The heaviest reflection boundary/negative suite |
| `testsuite_stringUtf16` | `compare`, `substr`, `split`, `indexOf`, `replace`, `contains`, `startsWith`, `endsWith` | Validate UTF-16 string handling across languages | Good at catching encoding and index-related bugs |
| `testsuite_threads` | `spawn(UIThread)`, click-triggered cases, event waiting | Validate ArkTS thread and UI-thread coordination in interop scenarios | Focused on scheduling/thread binding rather than type mapping |
| `testsuite_worker_thread` | ArkTS `worker`, page-driven interaction, UI automation, result-text assertions | Validate loading Cangjie modules and passing results in worker threads | Complements `testsuite_threads` with worker coverage |

### 3.2 `test/CJInteropsTest`

`CJInteropsTest` is best understood as a broader low-level regression project. It has two main parts:

- `entry/src/main/cangjie/src/pure`
  Pure Cangjie tests, with 22 `.cj` files covering:
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
  - `TestRequireArkModule` when `sdkApiVersion >= 23`

- `entry/src/ohosTest/ets/test`
  ArkTS-side tests, with 20 `.ets` files covering:
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
  - plus helper logic such as `PureWorker.ets`

Representative examples:

- `test_register_module.test.ets`
  Verifies that values exported from Cangjie to ArkTS cover `undefined`, `null`, `boolean`, `number`, `string`, `function`, `class`, `symbol`, `array`, `plain object`, `bigint`, `ArrayBuffer`, and `external`.
- `test_newScope.test.ets`
  Verifies `JSContext.newScope` related behavior, including memory leak fixes, out-of-scope references, and thread mismatch handling.
- `test_mixed_stack`
  Validates cross-language mixed stack behavior and exception propagation.

Overall, `CJInteropsTest` is the closest thing in this repository to a low-level interop regression baseline.

## 4. Main Validation Goals

From the current test content, the interop tests are mainly validating the following goals:

1. Module loading and import
   - Static ArkTS import of a Cangjie so
   - Runtime loading with `requireCJLib`
   - Repeated loading and dynamic loading
   - Requiring ArkTS modules from the Cangjie side

2. Bidirectional calls and exports
   - ArkTS calling Cangjie
   - Cangjie registering functions, modules, and classes for ArkTS
   - Callbacks, async functions, and posting JS tasks

3. Type mapping correctness
   - Primitive types: `bool`, `number`, `string`
   - Composite types: `Array`, `ArrayBuffer`, `Object`, `Map`
   - Special types: `BigInt`, `Symbol`, `Option`
   - Higher-order cases: function types, classes, interfaces, generic parameters

4. Runtime and context behavior
   - `JSContext`
   - `JSValue`
   - `JSCallInfo`
   - `JSType` / `IDLType`
   - `newScope`

5. Exceptions and edge cases
   - Parameter count mismatch
   - Parameter type mismatch
   - Generic argument count mismatch
   - Thread mismatch
   - Out-of-scope references
   - Mixed-stack exception propagation

6. Threading and scheduling
   - UI thread binding
   - `spawn(UIThread)`
   - Worker-thread message flow

7. Strings and encoding
   - UTF-16 comparison, slicing, searching, replacing, containment checks

8. Reflection
   - Type information lookup
   - Annotation lookup
   - Constructor invocation
   - Reflective member and static function calls
   - Generic `apply`

## 5. Review Notes

### Strengths

- Coverage is broad. The repository includes both ArkTS-side integration projects and low-level Cangjie-side regression cases.
- `testsuite_hybrid`, `testsuite_pure_manual_interop`, and `CJInteropsTest` form the main regression backbone for interop capability.
- Areas that commonly hide subtle bugs, such as reflection, threads, worker threads, and UTF-16 strings, already have dedicated suites.

### Current Characteristics

- Some suites are strong assertion-based tests, especially `testsuite_idl`, `testsuite_load_cangjie_so`, and many ArkTS-side cases in `CJInteropsTest`.
- Some suites are more smoke/sanity oriented, especially `testsuite_basic_import`, where success often means "the call does not crash".
- Some Cangjie-side suites are executed through `registerTestSuite` and `std.unittest` without an extra ArkTS assertion layer, so debugging often depends on reading Cangjie-side logs.

### Maintenance Caveats

- `testsuite_dynamic_load` is unusual because `entry/src/main/cangjie/test_list.cj` is empty. The real validation focus is the dependency project and the load path.
- `testsuite_reflect` and `testsuite_reflection` look similar in name but have different roles:
  - `reflect` focuses on basic reflection capability
  - `reflection` focuses on large-scale boundary, negative, and generic-invocation validation
- `CJInteropsTest` contains `sdkApiVersion`-gated behavior. Those branches should be rechecked when API-level expectations change.

## 6. Suggested Maintenance Strategy

1. When adding a new interop type or API, update these layers first:
   - `testsuite_hybrid`
   - `testsuite_pure_manual_interop`
   - `test/CJInteropsTest`

2. When adding declarative export or IDL-related capability, update `testsuite_idl` first.

3. When adding thread, scheduling, scope, or runtime lifecycle behavior, update:
   - `testsuite_threads`
   - `testsuite_worker_thread`
   - `test_newScope` / `post_jstask` in `CJInteropsTest`

4. For smoke-style suites, consider gradually strengthening explicit assertions, especially in:
   - `testsuite_basic_import`
   - some UTF-16 or import cases that currently only call APIs without validating returned values

## 7. Conclusion

The repository already has a clear two-layer test structure for Cangjie-ArkTS interop:

- `arkts_interop_testsuites` provides scenario-based integration validation
- `CJInteropsTest` provides low-level interface and edge-case regression coverage

If future maintenance or expansion is needed, the highest-value areas to track first are:

- `testsuite_hybrid`
- `testsuite_idl`
- `testsuite_pure_manual_interop`
- `testsuite_reflection`
- `test/CJInteropsTest`

These parts best represent the current depth of coverage for the core interop capability set.
