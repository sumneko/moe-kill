# Tasks

## 1. 内核

- [x] 1.1 `server/core/draw.lua`（新）：`Draw : Effect`（`kind` = `draw`，字段 `player` / `count`），`settle()` 只 `fire('摸牌', self)`；门面 `moe.draw`
- [x] 1.2 `server/core/game.lua`：`game:draw(player, count)` 便利入口（照 `M:heal` 写）
- [x] 1.3 `server/core/init.lua`：`include 'core.draw'`；`env-meta.lua` 补 `'摸牌'` 时机的按名收窄
- [x] 1.4 `server/test/core/draw.lua`（新，2 例）：用**空来源目录**造一个「不装任何内容包」的局 ⇒ 断言内核只发时机、**不碰抽牌区与手牌**；以及没人订阅时照常结完

## 2. 规则与内容

- [x] 2.1 `package/@基础/抽牌.lua`（新）：订阅 `'摸牌'` —— 从 `抽牌` 逐张取顶、两边都空就停、整批 `game:moveCard` 进 `手牌`；`recycleDiscard`（弃牌洗回抽牌）一并搬来
- [x] 2.2 `package/@基础/回合.lua`：删掉局部 `draw` / `recycleDiscard`，摸牌阶段改成 `game:draw(player, DRAW_COUNT)`
- [x] 2.3 `server/test/rule/draw.lua`（新，3 例）：摸 3 张（手牌 +3、抽牌 -3）/ 抽牌只剩 1 张而弃牌有牌时洗回后摸够且弃牌清空 / 两边都空时能摸多少摸多少且不报错
- [x] 2.4 `server/test.lua`：登记 `test.core.draw` 与 `test.rule.draw`
- [x] 2.5 全量 `server/bin/moe-kill.exe --test`：**344 用例 0 失败**（339 + 5），`rule.turn` 的两条摸牌用例照旧通过（搬家没改语义）
  - **踩到的坑**：`deck:move(card, assert(zone, '没有处理'))` 报「位置必须是整数」—— `assert(v, msg)` **多返回值**把 msg 当成了第三个参数；赋成局部变量再传就好了

## 3. 约定与文档

- [x] 3.1 `moe-kill-dev/references/architecture.md` §12：新增 `Draw` / `game:draw` 行 + 三条说明（内核只发 `'摸牌'`、语义在 `@基础/抽牌.lua`），并写下**「常用动作的形状」**约定
- [x] 3.2 `sanguosha-rules`：新增 **§9.5 常用动作：抽牌**（入口 + 内核与规则的分工 + 约定）
- [x] 3.3 `infrastructure.md` 命令速查补 `--test core.draw` / `rule.draw`
- [x] 3.4 问题面板 0（information 及以上）
- [x] 3.5 提交（`【AI】` 前缀）并勾完本文件；归档变更 `add-draw`
