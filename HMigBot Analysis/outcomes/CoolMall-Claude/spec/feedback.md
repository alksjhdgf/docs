# CoolMallHM migration: feedback to maintainers (candidates only; the suite was not changed)

## Pitfalls found in this run

1. **convert-resources does not namespace multi-module resources: duplicate names keep only the first**
   - Symptom: CoolMall has 11 res modules; 6 keys conflict (`total`/`confirm`×2/`alipay`/`address_edit`/`phone_number`), and resource-manifest.json only notes "kept first". The address form label became `手机号` (feature/main) instead of `手机号码` (feature/user), so acceptance flagged USER-A19 as failed.
   - Evidence: spec/front/resource-manifest.json conflicts[]; acceptance round 1 page-address verdict.
   - Suggested fix: when values differ, generate module-prefixed keys for the losing variant (e.g. `user_phone_number`) and print the conflict list as a 2a yellow warning; or treat a same-name-different-value conflict as soft case in closure.

2. **The ledger render output for degradations includes the original disposition text "实现期登记·待裁决" (registered during implementation, pending), which misleads the acceptance judges**
   - Symptom: after the main session adjudicated with `status --to open`, the render line still ends with "（实现期登记（切片 X）·待裁决）". Judges in 3 of 5 units treated open degradations as pending and failed them, wasting a full fix+reverify round.
   - Evidence: wf_90f91429-434 accept-prior.json (page-main-shell-home / page-order-confirm-pay / page-auth-login).
   - Suggested fix: on status adjudication, have `ledger status` rewrite the disposition (or append "→ ruled open: <reason>"); or have render drop the original disposition for open items and show the ruling reason.

3. **The ArkTS build only compiles files reachable from an entry point, so the foundation-wave gate is weak**
   - Symptom: after the fnd wave, 34 core files were not referenced by any page; hvigor was green but these files were never type-checked. When the main session temporarily imported all core files, 2 more compile errors appeared (`Context.config`, a `borderColor` param clashing with a built-in attribute).
   - Suggested fix: add an "aggregate import of all foundation files" build to the implement waveGate, or have closure provide a probe that generates a temporary aggregate import.

4. **The feasibility adjudication table (Alipay → @cashier_alipay/cashiersdk) does not reach slice implementers**
   - Symptom: the page-order-confirm-pay implementer could not edit oh-package.json5/module.json5, so it fell back to Payment Kit ThirdPayClient (which needs a Huawei Pay token and was bound to fail); only after acceptance did the main session switch to the official SDK.
   - Suggested fix: in 2b, turn ohpm dependencies with `equivalent` + ohpm in lib-adjudications into a foundation-wave task (install the dependency + querySchemes) and have conventions name the package.

5. **Assertion extraction error: HOME-A19 claims `没有更多了` text is shown**
   - The source LoadMore.kt:121-140 NoMore state draws only divider + dot + divider. The explorer guessed the text from the existence of the string resource. Suggestion: explore-instructions should require literals in backticks to point to an actual render site (stringResource call), not just a resource declaration.

6. **front.mjs has no `--device` parameter**: with multiple devices (emulator + phone) it defaults to the first target; this run could only specify the device via the HMIG_HDC_TARGET environment variable.

## Host adaptation (Claude Code desktop)
- The Workflow engine has no built-in named templates or check/readSection; the four suite templates are wrapped verbatim by `.deveco/adapter/build.mjs` and run through scriptPath (template bodies untouched).
- devecocli 1.3.0 needs Node ≥ 20 (the `/v` regex flag); with DevEco's bundled node v18 first on PATH it crashes, so the adapter run.sh puts Homebrew node first (hvigorw picks its node via NODE_HOME and is unaffected).

7. **walk.mjs `type` produces wrong input on InputType.Number + inputFilter + maxLength fields**
   - Symptom: typing `5190`/`9761` into the captcha field gave `7519`/`7976` (a `7` prepended, the last digit truncated by maxLength); `hdc shell uitest uiInput text 9134` into the same focused field was correct.
   - Suggested fix: walk.mjs type should tap to focus first, then use `uiInput text`; or provide a typeFocused op.

8. **The verification-code notification does not pop up a banner by default (4b user feedback "can't get the code")**
   - Notifications in the SOCIAL_COMMUNICATION slot only enter the shade, so users think nothing was sent. Suggestion: add to the system-capabilities table that verification-code apps relying on local notifications are a yellow item, and in the report prompt users to pull down the shade or enable banners in settings.
