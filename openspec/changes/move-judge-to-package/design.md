# Design

## Context

- 判定链现状与分工见 `proposal.md`。补充机制细节：
  - **实例化路径**：内核一律写 `New 'X' (args)` —— `class.new(name)` 造表 + `setmetatable(tbl, class)`，再**调用实例**触发 `class.__call` → `Config:runInit`（跑继承链上的 `__init`）。类表自己的 `mt.__call` 要求类上有 `__alloc`，**全仓没有任何类定义过它**。
  - **继承**：`Class(name, super)` 的第二个参数就是 super（`M.declare(name, super, superInit)`）⇒ 内容侧声明 `Effect` 子类**不需要** `Extends`。
  - **`Effect` 基类给的东西**（内容侧子类照样能拿）：`createTempZone()`（公开）、`getTempZone()`（默认沿 `parent` 继承，子类可重写为自建）、`apply()`/`await()` 驱动、`parent`/`result`/`err`/`success`/标签袋；**收尾**在基类里——结完时 fire `'效果-收尾'`，然后把临时区剩下的牌送 `弃牌`；记牌器（`game.effects`）由 `game.lua` 记**根效果**。
  - `game:judge` 现在**只有用例在调**（`rule.judge` / `rule.game-over` / `core.effect.judge`），没有内核内部调用点。
  - 先例：**窗口**这件事内容侧已经会做 —— `package/标准/卡牌/无懈可击.lua` 的响应窗口就是纯内容侧写的（订阅 `'效果-能否生效'` + 按行动顺序问一圈）。

## Goals / Non-Goals

**Goals:**

- 判定（阶段顺序 + 改判窗口 + 入口）全部住进 `package/@基础/判定.lua`；内核不再认识「判定」。
- 打开「**内容侧自定义一次结算**」这条能力（判定是第一个用户，将来的技能结算、延时锦囊同路）。
- 行为不变：判定仍是「一次结算」—— 临时区、收尾送弃牌、`parent`、记牌器照旧。

**Non-Goals:**

- 不改 `Effect` 基类的机制，不改结算驱动与收尾。
- 不给 `Extends` / `Delete` / `Type` / `Presize`（继承用 `Class` 的第二个参数）。
- 不做延时锦囊（乐不思蜀 / 闪电）本身 —— 本变更只把**判定**这把工具挪到内容侧。

## Decisions

### D1. 注入 `New`（与 `Class` 配对）

| 备选 | 评价 |
| --- | --- |
| **注入 `New`**（选它） | 就是内核自己实例化的那一步（`class.new`），一行改动、与内核同形；内容侧写法与内核完全一致：`New '判定' (game, player, reason)` |
| 窄口子（如 `game:createEffect(...)`） | 要多造一个概念、还得为每个效果子类各开一条；内核多一层转发 |
| 改照搬件 `class.lua` 给类补 `__alloc`（让类表可调用） | 动 `tools/`（照搬件，不能随便改），且改了也只是把「实例化」换个写法 |

### D2. 判定**整体**搬走（不做「类留在内核」的折中）

既然 `New` 开了，「内核仍保留一个判定专用类」就没有理由 —— 那个类的全部内容（阶段顺序、窗口、账）本来就是规则。内核只剩 `Effect` 这一层机制。

### D3. 类怎么声明

内容侧直接 `local Judge = Class('判定', 'Effect')`：类名用中文（与内容命名口径一致 —— 中文只用于难翻译的内容名），继承走 `Class` 的第二个参数。

### D4. 时机名保持不变，但改由内容侧 fire

`'判定-亮牌'` / `'判定-前'` / `'判定-后'` 三个名字**不改**（调用点、既有用例、将来的改判技能都用它们），改的只是**谁发射**：从「内核发射的接缝」变成「`@基础` 发射、依赖它的包订阅」。

- `env-meta.lua` 里那三条 `Game:on/fire` 重载**删掉**（内核不再认识这些名字）。
- 想要类型收窄就把重载写进 `package/@基础/meta.lua`（重声明 `---@class Game` + `---@field on ...`；配方与两个坑见 `architecture.md` §9.6）。
- **这是本变更的真实代价**，要写进文档：判定阶段**不再是内核保证的接缝**，而是包之间的约定（`Depends` + 同名时机 + 包自己的 `meta.lua`）。

### D5. `moe.judge.create` 门面删掉

内容侧拿不到 `moe`，也不需要：直接在 `Game:judge` 里 `New '判定' (game, player, reason)`。内核少一个门面。

### D6. 判定仍是「一次结算」

内容侧的 `判定` 子类重写 `getTempZone()` 为自建（调 `createTempZone()`），与现在的 `Judge` 一模一样 ⇒ 临时区、收尾、`parent`、记牌器全部保留，行为不变。

### D7. 用例与基线

- **删** `server/test/core/effect/judge.lua` 与 `server/test.lua` 里的套件行（「一个效果类一套」的惯例 —— 类没了就不该留）。
- **保留** `server/test/rule/judge.lua` 与 `rule/game-over.lua`（它们测的就是内容侧行为，是本次的回归网）。
- 加一条内容侧能力用例：`Class('X', 'Effect')` + `New` 能造出实例，而 `Extends` / `Delete` / `Type` / `Presize` 仍够不着。
- 基线（2026-09-28）：565 用例 / 0 失败；本批 `core.effect.judge` 那几条会消失、新增 1 条。

## Risks / Trade-offs

- [内容侧现在能造**任意**内核类的实例（`New 'Player' (...)）] → 与 `Class` 同一条口径：**没有护栏**，靠文档提醒 + VM 隔离兜底（`add-worker-mode` 落地后一个包写坏最坏只坏它那一局）。
- [判定阶段从「内核保证」降级为「包之间的约定」] → 名字不变、`@基础/meta.lua` 声明类型、文档写明；将来它若成为冻结的对外契约，再单独写规格。
- [内容侧声明的类进的是**同一个** VM 级类注册表（`M._classes`），类名可能撞内核类] → 暂无护栏；先靠命名约定（内容侧用内容名），将来若需要再考虑加检查。
- [删内核套件会掉覆盖] → `rule.judge` / `rule.game-over` 覆盖的是行为，本次原样保留；内核套件测的是「类本身」（`kind` / `replaced` / 窗口守卫），这些断言随实现一起搬到内容侧用例里更合适（`rule.judge` 已有对应几条）。
- [搬完之后收尾时机照旧发给判定] → 不变，内容侧可用可不用。

## Migration Plan

1. 注入 `New` + 内容侧能力用例（造实例成功 / 其余类表工具仍够不着）。
2. **一次到位**搬判定：写 `@基础/判定.lua` 的新版与删内核那份必须在同一批（`game:judge` 会撞名）⇒ 跑 `--test rule.judge` 与 `rule.game-over` 验证行为不变。
3. 迁移/删除内核套件与 `test.lua` 的套件行。
4. 文档：`architecture.md` §9.6（注入五项）、§12（效果族表里去掉 `judge`）、`progress.md`。

回滚：`git` 恢复即可（本批不涉及数据迁移）。
