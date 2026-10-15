# CoolMall exploration: shared rules (every explorer must follow these)

Overall task: migrate the Android app CoolMall (`input/CoolMallKotlin`, Kotlin + Jetpack Compose + Hilt + Retrofit + Room + MMKV, multi-module) to HarmonyOS ArkTS (`output/CoolMallHM`).
Your output is **one assertion card** (Markdown), written to the `docDir/<file>.md` named in the task. A downstream parser reads the cards mechanically and enters them into the ledger, so the format must be exact.

## Card format (required)

```
# <Card name, e.g. "Home page (MainRoutesMain/Home tab)">

Route: <registered route name; for a domain card write "domain card, no page">
Sources: <main source files, absolute or input/CoolMallKotlin-relative paths>

## Assertions
- HOME-A01 [ui] When the home page loads, it shows the banner carousel and the `限时精选` section。锚点：feature/main/src/main/java/com/joker/coolmall/feature/main/view/HomeScreen.kt:123
- HOME-A02 [backend] Pull-to-refresh calls the home data API again and replaces the list。锚点：feature/main/.../HomeViewModel.kt:88

## Components and interactions (copy the enumerations from source: buttons/menu items/tabs/dialog options, one row each, with anchors)
## Data and APIs (endpoint paths, request/response fields, local storage keys)
## Cross-cutting notes (state machines/threading/startup timing; one paragraph max)
## Platform risks
```

Assertion line rules (the parser regex is exact):
- One per line: `- <ID> [ui|backend|on_device] <assertion text>。锚点：<file>:<line>`. The ID is a domain prefix (all caps, see your task) + `-A` + two-digit number, e.g. `ORD-A07`.
- The anchor path is relative to `input/CoolMallKotlin` (e.g. `feature/order/src/main/java/.../OrderListScreen.kt:57`), and the line number must be real.
- Wrap stable ids and **user-visible text** (Chinese, as in the source strings.xml/code) in backticks; the closure check verifies these literals appear in the build output. Do not put function signatures/annotations/API names in backticks.
- Each assertion is atomic and states a **result contract** (behavior the user can see / a data result), not implementation steps.
- Only record behavior whose absence counts as a failure. **Do not record** visual parameters/sizes/spacing/animation details.
- kind: `ui` = can be judged from UI/code reading; `backend` = data layer/logic/API calls; `on_device` **only** for contracts observable only on a device and not provable statically (real notification shown, runtime permission granted, real vibration/sound, still there after a cold restart, system capability actually invoked).
- The app is **edge-to-edge** (MainActivity.kt:42 `enableEdgeToEdge()`): every page card includes exactly one `[ui]` assertion "top content avoids the status bar".
- Login wall: many pages require a logged-in state; write that precondition into the relevant assertion text (e.g. "when not logged in, tapping goes to the login page").
- Faithful to source: do not invent features, and do not omit features the source has (including skeleton screens, empty states, error retry, pull-to-refresh/load-more, dark mode).
- Number of assertions: decide by page complexity, usually 6–20 per page and 8–25 per domain card. Merge where possible; keep it short rather than exhaustive.

## Collaboration
- Write only your own card file. Do not modify any file under `input/` or `output/CoolMallHM` (other than your card).
- Read only the sources needed for your area (core/ui shared components: just know their names and behavior; do not expand all of them).
- Return a summary of at most 40 lines (no need to paste the card back).
