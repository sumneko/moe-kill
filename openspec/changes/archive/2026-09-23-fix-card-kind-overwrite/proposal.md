# Proposal

## Why

`CardDef:kind` 现在的口径是**重复调叠加**（去重 + 按声明顺序累加），`extends` 也因此把基类的分类**累加**到子定义上。这条口径支持的是「同一个分类名重复写几次」这种没用的情形，却让真正要做的事表达不出来：

- **要一张牌同时属于多个分类**时无从下手 —— 只能靠 `: kind 'A' : kind 'B'` 这种「顺手写了几次」的写法，而它是**累加**的：前面谁写过什么都会留在里面，语义含混（想「就这两类」做不到）。
- 马上要做的**锦囊牌**正面撞上这条：非延时锦囊要 `{ '锦囊', '非延时锦囊' }`、延时锦囊要 `{ '锦囊', '延时锦囊' }`（同属「锦囊」这一类，但判定 / 结算路径不同）；后面还会有「装备」里的武器 / 防具 / 坐骑，同一个形状。

用户 2026-09-23 定：**重复调改成覆盖，多个分类用一张列表给**。

## What Changes

- **`CardDef:kind(名字)` 的入参放宽成 `string | string[]`，并改成「一次调用覆盖」**：`: kind '基本'` 与 `: kind { '锦囊', '延时锦囊' }` 都行；**重复调以后写的为准**（不再叠加）；同一张列表里的重名仍去重、顺序按列表。
- **`extends` 抄基类的分类也改成覆盖**（一致的口径）：基类声明了分类 ⇒ 覆盖子定义自己的；**基类没声明 ⇒ 不动子定义自己的**（与 `zone` / `limit` 的「有才抄」同一口径）。
- **`isKind` / `getKinds` 形状不变**（快照、按声明顺序）。
- **明确不做**：分类名的取值校验（内核仍然只记录、不解释）、`zone` / `limit` 的形状调整、`getKinds` 的读法改动。

## Capabilities

### New Capabilities

无（探索期不写规格：见 `openspec/config.yaml` 与 `AGENTS.md` 的「工作流」，本变更在 `.openspec.yaml` 里设 `skip_specs: true`，契约以用例为准）。

### Modified Capabilities

无（同上）。

## Impact

- 内核：`server/core/game.lua`（`CardDef:kind` 的入参与覆盖语义、`extends` 里抄分类的那两行）、`server/core/loader/env-meta.lua`（`kind` 的签名放宽成 `string|string[]`）。
- 用例：`server/test/core/card-def.lua`（三条按新口径改写：列表 = 多分类、重复调覆盖、`extends` 覆盖且基类没分类时不清空）；`server/test/core/game.lua` 的继承分类两条回归。
- 文档：`.agents/skills/sanguosha-rules/SKILL.md`（§9.3 一带「定义上的三件套」的分类口径 + 锦囊两类用法的例子）、`moe-kill-dev` 的 `references/architecture.md`（§12 的 `CardDef:kind` 行）、`references/progress.md`（定义三件套那条）。
