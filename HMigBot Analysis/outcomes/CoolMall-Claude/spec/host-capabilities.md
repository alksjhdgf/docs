# Host capability inventory (stage 1, step 2): Claude Code desktop session

| Capability | Expected host tool | Measured in this session | Fallback used |
|---|---|---|---|
| Project creation | `devecocli create` | Available: devecocli 1.3.0 (needs Node ≥ 20; Homebrew node v26 first on PATH); created `output/CoolMallHM` at API 24 | — |
| Build | build_project | No build_project tool | `hvigorw assembleHap` (6.24.4) exit code |
| Static checks | arkts_check / codelinter | No session tool | closure-suite + hvigor |
| UI verification | verify_ui | No session tool | `scripts/smoke/walk.mjs` |
| Device control | start_app / devecocli device/run | devecocli device/run/ui available; hdc in PATH | hdc + uitest |
| Emulator | Emulator | `127.0.0.1:5555` connected (not used); smoke and walkthrough use phone `77UYD26331000973` (JUY-AL50, API 24) | — |
| Crash logs | faultlogger | None | hdc shell + walk.mjs crashDetail |
| Official docs search | retriever skill | `devecocli docs search` | references/ corpus |
| Workflow engine | `deveco run` named templates | Workflow tool exists but has no built-in templates or check/readSection | `.deveco/adapter/build.mjs` wraps the suite templates verbatim → `*.adapted.js` → Workflow scriptPath |
| Signing | ensure-sign / devecocli auth | Logged in (team 70086000310382470); official signing materials generated | — |
