# Tasks

## 1. 装载器：一份共享环境（`server/core/loader/init.lua`）

- [x] 1.1 `Loader.Context` 增 `env` / `injected` 两个字段（各带一行说明）
- [x] 1.2 `install` 里一次建好：`ctx.injected = { game, Card, Depends, util }` → `ctx.env = makeEnv(ctx.injected)`
- [x] 1.3 `loadFile` 用 `ctx.env`，并在 `load` 之前**把注入项刷回**
- [x] 1.4 试跑那一趟也共用一份 `probeEnv`（每个文件刷回它的 probe 注入项）
- [x] 1.5 验证：`--test rule` / 全量 `--test` 0 失败（既有用例里「重装 / 清空 / 互斥」这些行为都不变）

## 2. 用例（`server/test/rule/init.lua`）

- [x] 2.1 「整轮装载共用一份环境，包之间可以共享全局函数」：甲包写 `function 打招呼() end`，乙包调它
- [x] 2.2 「注入的 `game` / `Card` / `util` 每个文件都会刷回」：甲包把它们置 `nil`，乙包照常声明条目、写规则数值
- [x] 2.3 「重装换一份新环境，上一轮写的全局不再可见」

## 3. 文档

- [x] 3.1 `architecture.md` §9.6：把「注入面只有四个 + 没有共享函数通道」改成「整轮共用一份环境（包之间可共享全局函数，注意加载顺序；注入项每文件刷回）」，并写明沙箱口径不变
- [x] 3.2 `sanguosha-rules` §9.1：补一条「包之间共享函数 = 直接写全局函数」（附顺序提醒）

## 4. 验收

- [x] 4.1 全量 `--test` 0 失败（358 用例）
- [x] 4.2 问题面板 information 及以上为 0
