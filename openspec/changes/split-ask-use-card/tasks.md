# Tasks

## 1. 内核：`AskCard` 瘦身 + 两个可覆写钩子

- [x] 1.1 `server/core/effect/ask-card.lua`：`Condition` 去掉 `target?`；`makeOption(card)`（基类：`{ card = card }`）与 `checkOption(option, value)`（基类：答复给了目标就拒收）两个钩子；`collectOptions()` / `checkAnswer(value)` 改成实例方法（用 `self:makeOption` / `self:checkOption`）；删掉 `reason == '使用'` 特判与 `canUse` 分支；`__getter.targets` 移到子类；验证：`--test core.effect.ask-card` 全绿
- [x] 1.2 核对：`AskCard` 的答复多给目标 ⇒ 拒收（`.err` = 「这次答复不该给目标」）

## 2. 内核：`AskUseCard`

- [x] 2.1 `server/core/effect/ask-use-card.lua`（新）：`AskUseCard : AskCard`，`kind` = `'askUseCard'`；`AskUseCard.Condition : AskCard.Condition` 加 `target?`、`AskUseCard.Option : AskCard.Option` 把 `targets` 收成必填、`AskUseCard.Answer : AskCard.Answer`；覆写 `makeOption`（跑 `canUse`、带 `targets`（有 `target` 时取交集））与 `checkOption`（必须给目标且落在可用目标里）；`__getter.targets`；`moe.askUseCard.create`；验证：`--test core.effect.ask-use-card` 全绿
- [x] 2.2 `server/core/effect/init.lua` 装载新模块；`server/core/game.lua` 加 `game:askUseCard(被问者, 缘由, 条件?)`（与 `askCard` 同形）；`server/core/loader/env-meta.lua` 的 `'卡牌-询问'` / `'卡牌-答复'` / `'卡牌-答复后'` 载荷类型写成 `AskCard|AskUseCard`；验证：面板 0 问题

## 3. 内容侧调用点

- [x] 3.1 `package/@基础/回合.lua`：出牌阶段改 `game:askUseCard(player, '出牌', { zone = '手牌' })`；验证：`--test rule.turn` 全绿
- [x] 3.2 `package/@基础/濒死.lua`：改 `game:askUseCard(current, '濒死', { name = '桃', target = player })`；验证：`--test rule.dying` 全绿
- [x] 3.3 其余调用点（打出 / 五谷丰登 / 过河拆桥 / 顺手牵羊）写法不变，确认仍然可用；验证：`--test rule.trick` / `--test rule.slash` 全绿

## 4. 用例

- [x] 4.1 新套件 `server/test/core/effect/ask-use-card.lua` + 在 `server/test.lua` 注册：只收能用的牌且选项带可用目标 / `target` 交集（含空名单）/ 答复必须给目标、名单外目标被拒 / 答复目标给单个或列表 / 没人应答不算失败
- [x] 4.2 `server/test/core/effect/ask-card.lua`：把跟目标 / 使用语义有关的用例**搬到新套件**，补一条「`AskCard` 多给目标会被拒收」；验证：全量 0 失败
- [x] 4.3 `server/test/rule/turn.lua`：应答方的缘由判断改回 `'出牌'`；验证：`--test rule.turn` 全绿

## 5. 文档与验收

- [x] 5.1 `.agents/skills/moe-kill-dev/references/architecture.md`：§12 的 `askCard` 行拆成两行（`askCard` / `askUseCard`）、`canUse` 行与「询问与应答方」「决策询问」两条同步、濒死示例与测试清单补 `core.effect.ask-use-card`；`SKILL.md` 的效果族子类清单、`references/infrastructure.md` 的命令速查
- [x] 5.2 `.agents/skills/sanguosha-rules/SKILL.md`：§3 的出牌阶段、§6 / §7 的询问写法、§9.4 的求桃示例、§9.10 的五谷丰登条件（`cards` → `card`）；`.agents/skills/moe-kill-dev/references/progress.md` 同步
- [x] 5.3 验收：`server/bin/moe-kill.exe --test` 全量 **483 用例 0 失败**、问题面板 information 及以上 0；提交（`【AI】` 前缀）并归档变更
