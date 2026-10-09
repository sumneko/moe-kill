# Proposal

## Why

现在「问谁」没有落点：内核的询问一律通过**全局时机**交出（`game:fire('卡牌-询问', self)` 的返回值就是答复），应答方拿到询问后**自己从 `ask.to` 认领**。于是 `server/test/` 里约 40 个文件、300 余处 `game:on('卡牌-询问', …)` 都在手写这份认领；而 `server/session/` 是「还没有 User 概念时为了跑测试临时加的外壳」（用户 2026-10-09 定：**之后去掉**）。

把「谁在回答这个座位的询问」提成一等对象（**User**）之后：

- **分派有落点**：询问**先问被问者的 User**，它不表态才回落到全局时机（调试 / 兜底 / 现有测试夹具照旧可用）；
- **来源可替换**：真实玩家（`ClientUser`，将来走协议）与电脑（将来的 `AIUser`）只是 `User` 的子类；
- **生命周期可管理**：`Player` 可以**没有** User（无头 / 未接线），也可以**中途更换**（将来的托管 / 掉线接管）。

本批是**骨架**：`User` 基类 + `ClientUser` 占位，加上内核那条「优先问 User」的通道。

## What Changes

- 新增 **`User`**：一个**座位控制者**。基类**每类询问一个方法**（11 个，与内核 11 个 `Ask*` 类一一对应），默认**全部不表态**（返回空）；子类只重写自己关心的。
- `Player` 增加 **`user` 字段**（可空）+ **`Player:setUser(user)`**（绑定 / 更换 / 传空解绑）。
- **询问优先问 User**：内核 11 个询问类把问题交给应答方时，**先问 `to.user`**，返回空**才**走原来的全局时机（`'卡牌-询问'` / `'决策-询问'` / `'技能-询问'` / `'武将-询问'` / `'面板-询问'`）。顺序（User 先于全局订阅者）与「返回空 = 不表态」都写进 design。
- 新增 **`ClientUser`**：只留接口（各方法先照基类返回空），协议接线是后续批次。
- 落点 `server/user/`（与 `server/session/` 同层）—— `init.lua` 只做装载、`user.lua` 是基类、`client-user.lua` 是真实玩家；走 `require`（不参与热重载）；没有工厂，不挂门面。
- **本批不做**：`AIUser`（真 AI 是另一个功能点 —— 它引入不确定性，不适合跟这层骨架混）、`AskPanel` 的多轮接口形状、`ClientUser` 的协议实现、删除 `server/session/`、迁移现有测试的应答方式。

## Capabilities

### New Capabilities

无。本变更属探索期的**决策记录**，不写规格增量（`.openspec.yaml` 设 `skip_specs: true`）。理由见 `AGENTS.md`「工作流」：探索期只留决策记录，可执行契约由用例承担。

### Modified Capabilities

无。内核现有语义不变（「第一个给出答复的胜出」「没人表态就是取消」照旧）—— 本变更只是在全局时机**之前**接一段「问本人的 User」。`openspec/specs/` 已冻结，不回头改。

## Impact

- 内核：`server/core/player.lua`（`user` 字段 + `setUser`）；11 个询问类的取值点（`core/effect/ask.lua` 的 `settle`、`ask-card.lua` 的 `collectAnswer`、`ask-player.lua` / `ask-choice.lua` / `ask-hero.lua` / `ask-use-skill.lua` / `ask-panel.lua` 各自的取值处）+ 共用的「取答复」逻辑。
- 新增：`server/user/`（`init.lua` 只做装载 / `user.lua` 的 `User` 基类 / `client-user.lua` 的 `ClientUser`）、`server/test/core/user.lua`（新套件）。
- 文档：`references/architecture.md`（新增一节：User 与询问的分派）、`references/progress.md`（§1 新条目 + 基线）。
- **不动**：`server/session/`（保留，之后单独做删除）、现有测试的应答方式、`openspec/specs/`（冻结）。
