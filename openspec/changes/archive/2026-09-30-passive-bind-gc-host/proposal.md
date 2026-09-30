# Proposal

## Why

`'被动'` 是目前**唯一要求返回 disposer** 的钩子（`env-meta`：`fun(card: Card, zone: Zone): (fun()?)`）。而项目里"挂资源、随寿命释放"的既有模式是 **`bindGC`** —— `Buff` 用 `buff:bindGC(...)`（`'获得'` 里挂了什么，不用写反向的"失去时撤什么"），`Card:withZone` 也是「懒建 `GCHost` → `bindGC` → 离开区时 `Delete`」。于是同一个目的有两种写法，而且一个被动要挂**多份**资源时得自己串撤销链。

改成传 `GCHost` 之后：回调**不必有返回值**（它是"应用效果"的钩子，不是问句），挂多份资源就是多调几次 `bindGC`，内核侧也只剩"建容器 / 释放容器"两句。

## What Changes

- **`'被动'` 钩子加第三个参数 `host: GCHost`**：内核在应用被动时懒建一个容器、跑回调、**停用时 `Delete` 它**（挂进去的东西随之释放）。
- **内容侧 11 处改写**：`return X` → `host:bindGC(X)`（`武器牌` / `坐骑牌` 两个模板 + 9 张牌）。
- **删掉 `Card:withZone`（与 `zoneGCHost` 字段）**：内容侧零用户（装备已全走被动），机制与新的被动容器重复 —— 用户 2026-09-30 定。
- `ViewAs` 补 `__del`（`Delete(viewAs)` ⇒ `remove()`），于是『被动』里可以 `host:bindGC(viewAs)`，与 `Delete(buff)` 同形。

## Capabilities

无。探索期的**决策记录**，不写规格增量（`.openspec.yaml` 设 `skip_specs: true`）。

## Impact

- 内核：`server/core/card.lua`（`passiveUndo` → `passiveHost`；删 `withZone` / `zoneGCHost`）、`server/core/loader/env-meta.lua`（`'被动'` 签名）、`server/core/view-as.lua`（`__del`）。
- 内容侧：`@基础/卡牌/武器牌.lua` / `坐骑牌.lua` + `标准/卡牌/` 的 9 张牌。
- 测试：`core.card`（被动探针与用例改成 `bindGC`）、`core.move`（删两条 `withZone` 用例）。
- 文档：`architecture.md` / `progress.md` / `sanguosha-rules`（装备被动的写法）。
