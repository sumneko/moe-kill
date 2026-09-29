# Tasks

## 1. 内核：收集式触发与目标数量

- [x] 1.1 `server/tools/simple-event.lua` 加 `collect`（跑全部回调、收集非 nil 返回值；执行顺序与报错隔离同 `fire`）—— `--test core.event`（新用例）
- [x] 1.2 `server/core/event.lua` 加 `Event:collect`；`server/core/game.lua` 加 `game:collect` 转发 —— 面板（information 及以上）无新问题
- [x] 1.3 `server/core/game.lua` 的 `CardDef`：加 `targetCount(min, max)` / 读法（默认 `1, 1`；`extends` 带上）；删 `noTarget` / `isNoTarget` —— `--test core.card-def`（新用例）
- [x] 1.4 `Game:canUse` 改成区间校验（给了目标时：`最少 ≤ 个数 ≤ min(上限 + Σ「卡牌-目标数修正」, 合法目标数量)`；上限 0 的牌给了目标即拒、且不收集合法目标）—— `--test core.can-use`（新用例）
- [x] 1.5 验证 `AskUseCard` 的「无目标选项不带 targets」判据（`canUse` 对 `(0,0)` 牌返回的合法目标为空 ⇒ 选项自然不带 `targets`，无需改代码）—— `--test core.effect.ask-use-card` 全绿
- [x] 1.6 `server/core/loader/env-meta.lua` 加 `'卡牌-目标数修正'` 的专用声明 + `string` 兜底 —— 面板无新问题

## 2. 内容：目标数量适配

- [x] 2.1 `package/@基础/卡牌/装备牌.lua`：`noTarget()` → `targetCount(0, 0)` —— `--test rule.equip` 全绿
- [x] 2.2 多目标锦囊声明：`package/标准/卡牌/{南蛮入侵,万箭齐发,五谷丰登,桃园结义}.lua` 各加 `: targetCount(1, 1000)` —— `--test rule.trick` 全绿

## 3. 用例

- [x] 3.1 `server/test/core/{event,can-use,card-def}.lua` 加用例：收集式触发（全部取回 / 报错隔离 / 返回 nil 不收）；`targetCount` 声明与 `extends` 抄递、默认 1..1；区间两端 / `(0,0)` / 修正放宽与收紧 / 取较小值 / 未给目标不收集 —— 各套件全绿
- [x] 3.2 `server/test/rule/slash.lua` 适配：原多目标用例改成负例「没有放宽时不能指定 2 名目标」（逐目标机制由 `core.effect.play` 的探针用例继续覆盖）—— `--test rule.slash` 全绿
- [x] 3.3 探针适配：`core/effect/{play,ask-use-card}.lua` 里多目标使用的探针补声明、`noTarget()` 写法换成 `(0,0)` —— 相关套件全绿
- [x] 3.4 全量回归：`server/bin/moe-kill.exe --test` 0 失败（记录新基线）

## 4. 收尾

- [x] 4.1 问题面板：information 及以上清到 0（内核 / 内容 / 用例全部改动文件）
- [x] 4.2 文档：`architecture.md`（`targetCount` 与「无目标 = (0,0)」、`collect` 原语与「何时 collect / 何时 fire」判据）；`infrastructure.md`（`simple-event` 改动记账）；`progress.md`（本批记录与基线）；`sanguosha-rules`（§9.2 目标口径与批次边界、§9.11 同步）
- [x] 4.3 `openspec validate add-target-count --strict` 通过；勾选全部 tasks 后 `openspec archive add-target-count --yes`
