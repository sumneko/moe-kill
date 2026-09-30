# Tasks

## 1. ask 家族（内核）

- [x] 1.1 `server/core/effect/ask-card.lua`：条件加 `min?` / `max?`；答复收 `Card | Card[]`、入库归一成 `Card[]`；`.cards` / `.card` 读法；张数 / 选项 / 重复三项拒收 —— 以 3.1 验证
- [x] 1.2 `server/core/effect/ask-choice.lua`（新）：`AskChoice` + `moe.askChoice`；`game:askChoice` 入口；`init.lua` 装载；`env-meta` 的 `'决策-询问'` / `'决策-答复'` 载荷加 `AskChoice` —— 以 3.2 验证

## 2. 性别与卡牌（内容）

- [x] 2.1 `package/@基础/meta.lua`：`基础.性别` + `player.sex` 字段声明 —— 以 2.2 的读写点面板无报错验证
- [x] 2.2 `package/标准/卡牌/雌雄双股剑.lua`：『被动』订 `'卡牌-结算前'` → 逐目标判异性 → `askChoice` 发动 → 目标 `askCard`（0..1）：给牌弃置 / 给不出摸牌 —— 以 3.3 / 3.4 验证

## 3. 用例

- [x] 3.1 `server/test/core/effect/ask-card.lua`：+4（2、2 收两张与 `.cards` / `.card`；张数超了拒收；min 0 空表合法；重复拒收）；既有「空表答复」用例的原因文案随升级更新 —— `--test core.effect.ask-card` 全绿
- [x] 3.2 `server/test/core/effect/ask-choice.lua`（新）+ `server/test.lua` 注册：+6（往返 / 乱序 / 不在选项 / 没答 / 答复 nil 等同没答 / 重复应答）—— `--test core.effect.ask-choice` 全绿
- [x] 3.3 `server/test/rule/equip.lua` 雌雄一组 +9：给牌弃置（含顺序断言）/ 不给摸牌 / 没手牌归一化 / 答错归一化 / 不发动 / 同性 / 缺性别 / 旁人用【杀】/ 拆下 —— `--test rule.equip` 全绿
- [x] 3.4 全量回归：`server/bin/moe-kill.exe --test` 0 失败（记录新基线）

## 4. 收尾

- [x] 4.1 问题面板：information 及以上清到 0（内核 / 卡牌 / 用例；必要时 `lua.startServer` 重启）
- [x] 4.2 文档：`architecture.md`（ask 家族表 + 说明）、`sanguosha-rules` §9.11（雌雄 + 性别口径）、`progress.md`
- [x] 4.3 `openspec validate add-cixiong-swords --strict` 通过；勾选全部 tasks 后 `openspec archive add-cixiong-swords --yes`
