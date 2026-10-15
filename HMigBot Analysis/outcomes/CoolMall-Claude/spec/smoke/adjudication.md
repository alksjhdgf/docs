# Smoke case rulings (before 4a)
| Wave | Route | Verdict | Ruling |
|---|---|---|---|
| w1-0 | LaunchRoutesSplash | forwarded → LaunchRoutesGuide | waive: on a fresh install `guide_shown` is unset; the source behaves the same way (LAUNCH-A06, the app's own forwarding chain) |
| w1-0 | GoodsRoutesDetail | hollow (`暂无数据`) | waive (with a note): direct entry has no goodsId → the empty state required by conventions §E; the real path is walked from home in 4b. **Gap: the empty state has no back button** (§E asks for "message + back button"); handed to the 4a acceptance unit page-goods-detail |
| w0 | MainRoutesCart / MainRoutesMain | ok | — |
| w1-1 | OrderRoutesDetail / AuthRoutesRegister | ok | — |
