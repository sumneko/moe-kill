# Tasks

## 1. 内核：拆槽位机制

- [ ] 1.1 删 `server/core/slot-zone.lua`；`server/core/init.lua` 去掉装载
- [ ] 1.2 `server/core/zone.lua`：`Zone.Move` 去 `slot` / `fromSlot`；`takeIn` 去 slots 参数；`accept` 回两参数；`remove` 去槽位段；`notifyEnter` / `notifyLeave` 回 `(card, zone)`；删 `slotNameOf`
- [ ] 1.3 `server/core/game.lua` 删 `moveCardWithSlot`；`server/core/effect/move-card.lua` 删 `slot` 字段 / `create` 参数 / 相关注释
- [ ] 1.4 `server/core/player.lua`：`__init` 不建 `装备`；`getZone` 重载去掉 `'装备'`；`server/core/loader/env-meta.lua` 的基础牌区注释与两条区域钩子签名（去 slot）

## 2. 内容：四个装备子区

- [ ] 2.1 `package/@基础/装备.lua` 重写：`'游戏-开始'` 建四个子区 + 帮助（分类 → 子区名 / `isEquipZoneOf` / `equipCard` / `equipCardsOf`）
- [ ] 2.2 `package/@基础/卡牌/装备牌.lua`：进 / 离区钩子按子区判；「使用」钩子改 `equipCard`
- [ ] 2.3 `package/标准/卡牌/借刀杀人.lua`（直接取 `'武器'` 子区）、`package/身份场/奖惩.lua`（遍历四个子区）改寻址

## 3. 用例

- [ ] 3.1 `core.zone`：槽位区整段删除（含 `moveCardWithSlot` / 未声明槽位 / 弃牌堆被禁用那几条）；`core.game` / `core.move` / `core.card-def` 的槽位断言删除或改写
- [ ] 3.2 `core.player`：改成「内核建 `手牌` / `判定`；四个装备子区由内容在 `'游戏-开始'` 建好」
- [ ] 3.3 `rule.equip` 大改：进对应子区生效 / 同子区换装（旧牌进弃牌堆）/ 拆走回落 / 压制恢复 / 进错子区不启用被动 / 装备区是四个普通区
- [ ] 3.4 `rule.trick` / `rule.game-over` 的寻址同步；全量 `server/bin/moe-kill.exe --test` 全绿 + 面板 information 及以上为 0

## 4. 文档

- [ ] 4.1 `architecture.md`：第 12 节基础牌区（改成四个）、删 `SlotZone` 与 `moveCardWithSlot` 两条、`accept` / `takeIn` / `notifyMoved` 行、装备段（§472 / §485 / §517 / §518 附近）
- [ ] 4.2 `sanguosha-rules`（§9.3 装备相关说明 / §9.11 装备一节 / 牌表说明）、`code-style.md`（回调参数名的 `slot` 条目）、`progress.md`
