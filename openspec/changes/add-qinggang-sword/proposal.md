# Proposal

## Why

标准版的【青釭剑】还没做：现文件叫 `package/标准/卡牌/青紅剑.lua`（写法是错的，2026-09-29 用户批准改成官方名「青釭剑」），内容只有一条 `: value('攻击范围', 2)`。

它的效果要三个刚规划好的能力：装备子区（`replace-slot-zone-with-equip-zones`）、区域禁用新语义（`rework-zone-disable`）、buff（`add-buff-system`）。顺带把【青釭剑】逼出来的两处收尾整理做掉。

## What Changes

- **改名**：`青紅剑.lua` → `青釭剑.lua`（文件名 / 牌定义 / 牌表 / 用例期望表 / 规则文档）。
- **青釭剑效果**：「被动」里订阅 `'卡牌-结算前'` —— 自己（剑主）使用【杀】时，对**每个目标**：`addBuff('防具无效')` + `buff:attach(target:getZone('防具'):disable())`；buff 自己订阅「这个目标那次生效的收尾」与「这次使用的收尾」，到点删自己。
- **效果收尾整理**（`server/core/effect/effect.lua`，本批逼出来的两件事）：
  1. `bindFinish` 去掉「没建过临时区就不发 `'效果-收尾'`」的闸门 —— 青釭剑要按目标的**生效收尾**松手，而没人应答【闪】的那次生效根本没建过区，现在不会发收尾；
  2. 默认收尾的弃牌改**批量**：`discard:accept(zone:list())` 一次收一批（不再逐张 `accept`）。

## Capabilities

### New Capabilities

无 —— 探索期的决策记录，不写规格增量（`.openspec.yaml` 设 `skip_specs: true`）。

### Modified Capabilities

无（同上）。

## Impact

- 内容：`package/标准/卡牌/青釭剑.lua`（重命名 + 效果）、`package/标准/牌表.lua`（牌名）
- 内核：`server/core/effect/effect.lua`（收尾闸门 + 批量弃牌）
- 用例：`server/test/rule/equip.lua`（青釭剑一组 + 期望表改名）、`core.effect`（收尾语义用例更新）、`rule.trick` 可能受批量弃牌影响的地方
- 依赖：`rework-zone-disable` / `replace-slot-zone-with-equip-zones` / `add-buff-system`（先落地）
- 文档：`sanguosha-rules`（§9.11 / 牌表）、`architecture.md`（收尾时机一条）、`progress.md`

## Non-goals

- **窗口内失去防具、其「失去时」技能也不能发动**（官方【白银狮子】裁定）—— 牌离区时区级压制就松了；军争牌到齐再补，先记为已知边界。
- 官方裁定里的配角（【藤甲】/【反馈】/【连环】……）—— 用例用等价的搬运 / 移除模拟。
- 【青釭剑】作为装备的其他通用行为（攻击范围、拆装、被动启停）—— 随装备模板一起已在。
