# Telegram / cj_telegram 多设备性能测试汇总报告

> 汇总三组数据,分别来自不同设备与不同被测应用。**跨组数字不是"谁快谁慢"的公平对比**,请先读第 0 节的口径说明。
> 最近更新:2026-07-02

---

## 0. ⚠️ 先读:三组之间的差异(都会影响结果)

三组在**设备、系统、芯片、内存、被测应用、采集工具**上均有不同,务必区分:

| 组 | 设备型号 | 系统 / API | 是否测试机 | 芯片(SoC) | 内存 | 屏幕 / 刷新率 | 被测应用 | 采集工具 |
|---|---|---|---|---|---|---|---|---|
| **组1(参照基线)** | 三星 Galaxy S23 Ultra(SM-S9180) | Android 15 / API 35 | 否(零售机,未 root) | 高通骁龙 8 Gen 2 | **12 GB** | 1080×2316,≤120 Hz | **官方 Telegram**(`org.telegram.messenger`) | adb(`am start -W` / `dumpsys`) |
| **组2** | 华为 ALN-AL80(Mate 70 系列) | HarmonyOS 6.1.0.100(C00E111R10P8**log**)/ API 23 | **是**(log 调试固件,debuggable=1) | 华为麒麟(平台标识 `kirin9000s`) | **12 GB**(MemTotal 11.1 GiB) | 1260×2720,≤120 Hz | **cj_telegram**(`com.example.ios2cj`,`parallel` 分支 41 MB) | hdc(hitrace / hidumper / SP_daemon) |
| **组3** | 华为 JUY-AL50(**畅享 90 Plus**,入门级) | HarmonyOS 6.0.0.155(SP5C00E150R2P2)/ API 22 | **否(零售机)** | 入门级 SoC(零售机未暴露型号) | **8 GB**(MemTotal 7.45 GiB) | 物理 1080×2406,≤90 Hz(当前开智能分辨率 720×1604 + 动态刷新 60/90) | **cj_telegram**(`parallel` 分支 41 MB,**已登录**) | hdc(同组2) |

**关键提醒:**
1. **被测应用不同**:组1 是**官方 Telegram**(原生 Android、多年优化的成熟产品),组2/3 是 **cj_telegram**(仓颉移植版,早期阶段)。组1 是参照标杆,不是同一个 App。
2. **平台与采集口径不同**:Android 冷启动是 `am start -W` 的 `TotalTime`;鸿蒙冷启动是 hitrace 的 `StartAbilityInner → 首帧`。两者定义相近但不完全等价,**跨平台冷启动数值不可直接相减比较**。
3. **芯片/系统/固件不同**:组2 是**工程 log 固件的测试机**,全系统带额外日志/断言,比零售固件明显慢 → 组2 冷启动绝对值偏高,**不代表零售机水平**。**本轮已被组3 实证**:入门级零售机 JUY-AL50(组3)冷启动 1659 ms,反而**快于**旗舰芯片但 log 固件的 ALN-AL80(组2)1869 ms —— 固件类型的影响盖过了芯片差距。
4. **内存与设备基本无关**:组2、组3 同为 parallel 包,同状态下 PSS 几乎一致(登录 136 / 130 MB,未登录 174 / 178 MB)——内存由 App 和页面内容决定,不由设备决定。
5. **相同项**:组1、组2 内存都是 12 GB;组3 为 8 GB。

---

## 1. 组1 — 三星 S23 Ultra · 官方 Telegram(参照基线)

> 测于 2026-07-02;真实登录态;自适应刷新率(≤120 Hz);未 root、未改应用。两次测试差异为使用后缓存增长所致。

| 指标 | 第一次(垂直上滑) | 第二次(左右横滑) |
|---|---|---|
| 冷启动 TotalTime(均值) | **305.6 ms**(292–349) | **416.4 ms**(393–462) |
| 冷启动内存 TOTAL PSS | **148 MB** | **242 MB** |
| 冷启动内存 TOTAL RSS | 276 MB | 380 MB |
| 滑动实测刷新率 | **120 fps** | **120 fps** |
| Janky 帧率(新算法) | 0.09%(1/1107 帧) | 0.19%(3/1602 帧) |
| 帧耗时 50/90/95/99 分位 | 17/17/17/18 ms | 17/18/18/19 ms |
| Missed Vsync | 0 | 0 |

- 冷启动均在 Google 建议的"良好"区间(< 500 ms);两次内存上升为账号数据/媒体缓存增长,无泄漏迹象。
- 滑动两次都极佳(Janky < 0.2%,Missed Vsync = 0);自适应刷新率按场景在 60/120 Hz 间切换。

---

## 2. 组2 — 华为 ALN-AL80 · cj_telegram(已登录 · parallel 包)

> 测于 2026-07-02;真实登录态;parallel 分支 Release 包(41 MB,含 Premium/Stripe 支付/内购等功能);设备为 **log 固件测试机**。

| 指标 | 数值 |
|---|---|
| **冷启动时长(中位)** | **1869 ms**(5 次:1820 / 1844 / 1869 / 1875 / 1908) |
| **冷启动内存 PSS** | **136 MB**(native 59.4 / 匿名 13.5 / .so 61.2) |
| **滑动帧率(频繁左右滑 = 切 Tab)** | **稳定 ~120 fps**(打满 120 Hz 屏) |

**冷启动**(AMS `StartAbilityInner` → 首帧 `ReportEventFirstFrame`):5 次抖动 < 90 ms,很稳。

**帧率(左右滑)**逐秒:`1 97 120 119 119 120 120 119 120 120`,刷新率整段 120 Hz —— App 能跟满 120 Hz 高刷,仅起滑瞬间一次 ~91 ms 抖动。

**同机同包「未登录 vs 已登录」对比**(单变量):

| 指标 | 未登录(引导页) | 已登录(Contacts 页) |
|---|---|---|
| 冷启动中位 | 1869 ms | 1869 ms |
| 内存 PSS | 174 MB | **136 MB** |
| 帧率(左右滑) | ~120 fps | ~120 fps |

- 冷启动、帧率与登录态基本无关(冷启动由进程创建 + Cangjie 运行时 + .so 加载主导)。
- 内存差异来自页面内容:引导页大图轮播匿名页 59.8 MB,登录后 Contacts 页仅 13.5 MB。

---

## 3. 组3 — 华为 JUY-AL50(畅享 90 Plus)· cj_telegram(已登录 · parallel 包)

> 测于 2026-07-02;**入门级零售机**(8 GB / 90 Hz);parallel 分支 Release 包(41 MB);已登录态(与组2 对齐)。

| 指标 | 数值 |
|---|---|
| **冷启动时长(中位)** | **1660 ms**(5 次:1635 / 1658 / 1660 / 1681 / 1684,极稳) |
| **冷启动内存 PSS** | **130 MB**(native 56 / 匿名 13.8 / .so 59.7) |
| **滑动帧率(频繁左右滑 = 切 Tab)** | **稳定 90 fps**(打满屏幕上限 90 Hz) |

**帧率(左右滑)**逐秒:`2 56 90 90 89 90 90 90 90 90`,滑动时刷新率升到 90 Hz(空闲态 60 Hz),流畅无卡顿。

**同机同包「未登录 vs 已登录」对比**:

| 指标 | 未登录(引导页) | 已登录(Contacts 页) |
|---|---|---|
| 冷启动中位 | 1659 ms | 1660 ms |
| 内存 PSS | 178 MB | **130 MB** |
| 帧率(左右滑) | ~90 fps | ~90 fps |

- 与组2 规律完全一致:冷启动、帧率与登录态无关;内存差异来自页面内容(引导页匿名页 65.9 MB → 登录后 Contacts 页 13.8 MB)。

**关键观察**:JUY-AL50 冷启动 **1660 ms**,比旗舰芯片的组2 ALN-AL80(1869 ms)**还快** —— 组2 是 log 调试固件、组3 是零售固件,**固件影响 > 芯片影响**。登录态内存 130 MB 与组2 的 136 MB 几乎相同(同包同页面,内存与设备无关)。

---

## 4. 核心指标横向速览(务必配合第 0 节口径阅读)

| | 组1 S23U · 官方TG | 组2 ALN-AL80 · cj_tg | 组3 JUY-AL50 · cj_tg |
|---|---|---|---|
| 应用 | 官方 Telegram | cj_telegram | cj_telegram |
| 芯片 / 内存 | 骁龙8Gen2 / 12GB | 麒麟kirin9000s / 12GB | 入门级 / 8GB |
| 系统 / 固件 | Android 15 / 零售 | HarmonyOS 6.1 / **log 测试机** | HarmonyOS 6.0 / 零售 |
| 状态 | 已登录 | 已登录 | 已登录 |
| 冷启动 | 416 ms(am start -W) | 1869 ms(hitrace) | **1660 ms**(hitrace) |
| 内存 PSS | 242 MB | 136 MB | **130 MB** |
| 滑动帧率 | 120 fps | ~120 fps(120Hz屏) | 90 fps(90Hz屏) |

**cj_telegram 设备横向对比(组2 vs 组3,均取「已登录 · parallel 包」同口径):**

| 指标 | 组2 ALN-AL80(旗舰/log固件) | 组3 JUY-AL50(入门/零售固件) |
|---|---|---|
| 冷启动中位 | 1869 ms | **1660 ms**(更快 ~210 ms) |
| 内存 PSS | 136 MB | 130 MB(基本一致) |
| 滑动帧率 | ~120 fps(打满120Hz) | 90 fps(打满90Hz) |

> ⚠️ 两点结论:
> 1. **冷启动:固件 > 芯片**。入门机(零售固件)反而比旗舰芯片(log 测试机)快 210 ms,说明组2 的偏慢主要是 log 固件的锅,不是仓颉代码本身在弱机上不行。要看真实冷启动,应以**零售固件**的组3(1659 ms)为准。
> 2. **跨应用不可直接比**:组1 官方 Telegram 冷启动 416 ms(am start -W 口径),与 cj_telegram 的 hitrace 口径不同、且 App 完全不同(成熟原生 vs 早期仓颉移植),**不能据此下"慢 N 倍"的结论**。仓颉运行时 + .so 加载确是移植版启动大头,但需同口径同 App 才可比。

---

## 5. 测试方法

### 5.1 鸿蒙侧(组2/组3,hdc)
工具:`SP_daemon`(SmartPerf)、`hidumper`、`hitrace`、`uitest`。`HDC` = `/Applications/DevEco-Studio.app/Contents/sdk/default/openharmony/toolchains/hdc`。命令均加 `-t <序列号>`。变量 `B=com.example.ios2cj`,主 Ability `EntryAbility`。

**冷启动**(hitrace 抓链,5 次取中位):
```bash
$HDC -t $S shell "aa force-stop $B"; sleep 2
$HDC -t $S shell "hitrace -b 40960 -t 6 --overwrite ability app ark graphic > /data/local/tmp/cs.ftrace 2>/dev/null &"
sleep 1; $HDC -t $S shell "aa start -a EntryAbility -b $B"; sleep 6
PID=$($HDC -t $S shell "pidof $B")
$HDC -t $S shell "grep -a -m1 StartAbilityInner /data/local/tmp/cs.ftrace"                 # T0
$HDC -t $S shell "grep -a 'ReportEventFirstFrame app pid $PID' /data/local/tmp/cs.ftrace"  # T1;冷启动=T1-T0
```
- 提取时间戳正则用 `[0-9]+\.[0-9]{6}`(ftrace 时间戳是开机秒数,刚重启的机器只有 3 位整数,不能假设 6+ 位)。

**冷启动内存**:冷启后静置 3 s,`hidumper --mem $PID` 读 Total 行 Pss Total。
**滑动帧率**:`SP_daemon -N 10 -PKG $B -f -OUT /data/local/tmp/fps.csv &`,同时 `uitest uiInput swipe x1 y1 x2 y2 speed` 驱动手势(左右滑 y 居中、x 往返);读 csv 每秒 `fps,帧间隔,刷新率`。

### 5.2 Android 侧(组1,adb)
`$pkg=org.telegram.messenger`,`$cmp=$pkg/.DefaultIcon`。
- 冷启动:`am force-stop` 后 `am start -W -n $cmp`,读 `TotalTime`,5 次取均值。
- 内存:启动稳定 6 s 后 `dumpsys meminfo $pkg`,读 App Summary 的 TOTAL PSS/RSS。
- 帧率:`dumpsys gfxinfo $pkg reset` → `input swipe` 滑动 → `dumpsys gfxinfo $pkg` 读 Janky/分位/Missed Vsync;`dumpsys display | grep mActiveRenderFrameRate` 确认实测刷新率。

### 5.3 通用注意
- 冷启动以中位数/均值为准;帧率首 1–2 秒为起滑爬坡,非卡顿。
- **测帧率前务必关闭屏幕录制/投屏**(会把刷新率锁到 60 Hz)。
- 内存/帧率与所处页面、交互类型强相关,跨轮对比须注明状态(登录态、Tab、滑动方向)。
- 跨组对比须同时注明:被测应用、芯片、系统/固件(是否 log 测试机)、采集工具 —— 见第 0 节。
