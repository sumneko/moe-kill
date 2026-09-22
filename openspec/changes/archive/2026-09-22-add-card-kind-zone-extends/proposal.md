# Proposal

## Why

内容侧现在给卡牌定义只能写「钩子」与「限额」两类东西，缺三样：

- **分类**（基本 / 锦囊 / 装备…）没有地方写 —— 前端牌面、AI 判断、将来的规则分支都需要它。
- **从哪个牌区用**没有地方写：现在 `canUse` 只要求「牌在使用者名下某个牌区里」；而【杀】这类基本牌按口径必须从**手牌**用，装备牌与将来的技能还各有各的区。
- **重复的公共部分没法复用**：每张基本牌都要重复写同一份公共声明（分类、牌区，将来还有公共钩子）。

## What Changes

（三条都长在内核 `CardDef` 上；阶段限额 `CardDef:limit` 的先例已落地，形状沿用「链式、内核只当值存」）

- **`kind`：分类，内核只记录、不解释**
  - `CardDef:kind(名字)` —— 链式、可多次调、**累加**（同一个名字重复写只算一次）。
  - 读：`CardDef:isKind(名字)` / `CardDef:getKinds()`（快照，改不动内核状态）。
  - 口径修正（用户 2026-09-22）：取值**省略「牌」字** —— `'基本'` / `'锦囊'` / `'装备'`。
- **`zone`：这张牌必须从哪个牌区用，由 `canUse` 的内建条目判**
  - `CardDef:zone(区名)`（单值，重复调后者覆盖）+ `CardDef:getZone()`。
  - `game:canUse` 的内建条目改成：**牌得在使用者名下某个牌区里**（现状不变）；若定义**声明了 `zone`**，还要求牌就在**那个名字的牌区**里（没有这个区或牌不在里面 ⇒ 用不了，给明确原因）。
  - **没声明 `zone` = 沿用现状**（在使用者任一牌区里就行）。
- **`extends`：把基类的定义复制过来**
  - `CardDef:extends(名字)`（链式）—— 按名字经内置名字路由取基类定义（支持限定名，如 `标准.杀`），**当场**把基类的
    **钩子**（放在本定义自己的钩子**前面** ⇒ 基类先跑）与**字段**（`kind` / `zone` / 限额表）**深拷贝**成本定义自己的。
  - **拍平、快照**：复制完就与基类脱钩 —— 之后再给基类加东西，已复制过的子定义不跟着变（值语义）。
  - 基类必须已经定义（找不到就报错）：`@基础` 这类默认包排在最前，所以「标准包里的牌继承默认包里的模板」天然成立。
  - 多次 `extends` 按顺序依次合并（钩子依次追加、`kind` 累积、`zone` 与限额表后者覆盖）。
- **内容侧采用**（用户已改好的两处，本批补上内核接口后即可跑通）
  - `package/@基础/基本牌.lua`：`Card '基本牌' : kind '基本' : zone '手牌'`（模板条目，不在牌表里 ⇒ 不会被真的造出来）。
  - `package/标准/卡牌/杀.lua`：`: extends '基本牌'`（新增的公共模板在前，`limit` 与两个钩子仍写在【杀】自己身上）。

## Capabilities

### New Capabilities

无（探索期不写规格：见 `openspec/config.yaml` 与 `AGENTS.md` 的「工作流」，本变更在 `.openspec.yaml` 里设 `skip_specs: true`，契约以用例为准）。

### Modified Capabilities

无（同上）。

## Impact

- 内核：`server/core/game.lua`（`CardDef` 的 `kind` / `zone` / `extends` 与读接口、`canUse` 的 `zone` 内建条目）、`server/core/loader/env-meta.lua`（`CardDef` 的类型收窄）。
- 内容侧：`package/@基础/基本牌.lua`（`kind` 取值改成 `'基本'`）、`package/标准/卡牌/杀.lua`（已有 `: extends '基本牌'`）。
- 用例：`server/test/core/game.lua`（定义的 kind / 继承）与 `server/test/core/can-use.lua`（zone 的三条：声明且在区内 / 声明但不在 / 没声明保持现状）。
- 文档：`moe-kill-dev` 的 `references/architecture.md`（§12 接口表补三条）、`references/progress.md`；`sanguosha-rules` 的 §9.2（示例加 `extends`）。
