# Proposal

## Why

「抽牌 / 弃置 / 获得 / **判定**」这组常用动作（约定见 `sanguosha-rules` §9.5）里，**只剩判定没做**：

- 内核**没有任何「翻一张牌出来」的入口**：`sanguosha-rules` §7 把「装备与判定」列在还没做；归档的多个变更（`add-turn-flow`、`add-slash`、`add-dying`…）都写着「判定与装备不做」。
- 回合流程里的**判定阶段**现在什么都不做（只进/出阶段、触发时机），因为没有可调的动作。
- 接下来几个功能点都要它当垫脚石：延时锦囊（【乐不思蜀】【闪电】【兵粮寸断】）、装备【八卦阵】、技能改判（【鬼才】这一类）—— 它们共同的形状就是「**从抽牌堆顶翻一张牌 → 别人有机会把它换掉 → 这张牌进弃牌堆 → 按牌面结算**」。这件事现在谁也做不了，每个包只能自己写一遍。

现在做它的理由：它是常用动作约定里最后一个缺口，且**不依赖别的东西**（不需要牌面数据、不需要延时锦囊、不需要技能系统）。用户 2026-09-23 定：**本批只做判定动作**，牌面（花色 / 点数）留给第一个真正消费判定的批次。

## What Changes

- **内核：`Judge : Effect`（`kind` = `'judge'`）+ `game:judge(玩家, 缘由?)` 入口**（与 `draw` / `damage` / `heal` 同形：当场结算、返回结完的实例、失败读 `.err`）。
- **内核：三个时机**（内核负责次序，不靠注册顺序）
  - `'判定-亮牌'`：翻出判定牌（内容侧把牌放进 `judge.card`）。
  - `'判定-前'`：**改判窗口** —— `judge:replace(新牌)` 换掉判定牌（被换下的旧牌记进 `judge.replaced`）；**这个接口只在窗口内有效**：不在 `'判定-前'` 里调直接报错。
  - `'判定-后'`：结果已定（调用方在这之后读 `judge.card`；内容侧在这里处理判定牌的去向）。
- **内核：有序区取顶 + 「牌不足」的补牌回调**
  - `OrderedZone:draw(n)`：从区顶取 n 张（不够就少给、不报错）—— 摸牌 / 判定 / 将来别的取顶动作用同一个底层接口（`game:getZone('抽牌'):draw(1)`）。
  - `OrderedZone:setShortageHandler(fn)`：区里取空了就调一次这个回调补牌（内容侧挂「把弃牌全部洗回抽牌」），补到了接着取、补不到就少给。
- **内核不认识区名与牌面**：内核不搬牌（亮牌 / 收牌都在内容侧），也不认识花色点数 —— **判定「结果」就是那张判定牌**。
- **内容侧：`@基础/牌堆.lua` 挂上「不足就洗回」的回调**（弃牌全部挪回抽牌 + 洗牌），`@基础/抽牌.lua` 与 `@基础/判定.lua` 都改调 `game:getZone('抽牌'):draw(n)` —— 判定与摸牌共用一份取顶 / 洗回语义（`抽牌.lua` 里那套局部 `recycleDiscard` 随之退休）。
- **内容侧：`@基础/判定.lua`（新）** —— 亮牌时从抽牌堆顶翻一张；`'判定-后'` 把判定牌与被换下的牌一起送进弃牌堆。
- **明确不做**：牌面（花色 / 点数）与逐张牌表、判定区与延时锦囊、判定阶段的结算、技能的改判实现（【鬼才】等）、判定牌的可见性 / 前端表现、超时。

## Capabilities

### New Capabilities

无（探索期不写规格：见 `openspec/config.yaml` 与 `AGENTS.md` 的「工作流」，本变更在 `.openspec.yaml` 里设 `skip_specs: true`，契约以用例为准）。

### Modified Capabilities

无（同上）。

## Impact

- 内核：`server/core/effect/judge.lua`（新效果）、`server/core/init.lua`（挂载 `core.effect.judge`）、`server/core/game.lua`（`game:judge` 入口）、`server/core/ordered-zone.lua`（取顶 `draw` 与不足回调）、`server/core/loader/env-meta.lua`（三个时机 + `Judge` 上下文）。
- 内容：`package/@基础/判定.lua`（新）、`package/@基础/牌堆.lua`（挂不足回调）、`package/@基础/抽牌.lua`（改调 `OrderedZone:draw`，局部 `recycleDiscard` 退休）。
- 用例：`server/test/core/effect/judge.lua`（新：入口 / 三时机次序 / 窗口内的改判与记账 / 窗口外报错）、`server/test/core/zone.lua`（补：取满 / 不够少给 / 不足回调补牌后接着取 / 回调补不到就少给）、`server/test/rule/judge.lua`（新：判定牌来自抽牌堆顶且结完进弃牌堆 / 抽牌堆空时洗回 / 改判后新旧牌都进弃牌堆）、`server/test/rule/draw.lua` 与 `server/test/rule/turn.lua` 回归（摸牌改走有序区取顶）。
- 文档：`moe-kill-dev` 的 `references/architecture.md`（§12 的 `judge` / `game:judge` 行 + 判定实现段 + 时机清单）、`references/progress.md`（内核现状与新用例数）；`sanguosha-rules` 的 §7（判定从「还没做」改成动作已落地）、§9.5 一带（新增判定一节：形状与写法）、§3（判定阶段仍不结算）。
