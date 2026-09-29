# Tasks

## 1. 内核：拆槽位机制

- [x] 1.1 删 `server/core/slot-zone.lua`；`server/core/init.lua` 去掉装载
- [x] 1.2 `server/core/zone.lua`：`Zone.Move` 去 `slot` / `fromSlot`；`takeIn` 去 slots 参数；`accept` 只剩一个参数；`remove` 去槽位段；`notifyEnter` / `notifyLeave` 回 `(card, zone)`；删 `slotNameOf`
- [x] 1.3 `server/core/game.lua` 删 `moveCardWithSlot`；`server/core/effect/move-card.lua` 删 `slot` 字段 / `create` 参数 / 相关注释
- [x] 1.4 `server/core/player.lua`：`__init` 不建 `装备`；`getZone` 重载去掉 `'装备'`；`server/core/loader/env-meta.lua` 的基础牌区注释改成四个、两条区域钩子签名去 slot

## 2. 内容：四个装备子区

- [x] 2.1 `package/@基础/装备.lua` 重写：`'游戏-开始'` 建四个子区 + 帮助（`Player:equipZoneOf` / `Player:equipCard` / `Player.equipCards`）
- [x] 2.2 `package/@基础/卡牌/装备牌.lua`：进 / 离区钩子按子区判（`zone.owner:equipZoneOf(card) == zone`）；「使用」钩子改 `useCard.user:equipCard(useCard.card)`
- [x] 2.3 `package/标准/卡牌/借刀杀人.lua`（直接取 `'武器'` 子区）、`package/身份场/奖惩.lua`（用 `player.equipCards`）改寻址

## 3. 用例

- [x] 3.1 `core.zone`：槽位区整段删除（7 条，含 `moveCardWithSlot` / 未声明槽位 / 弃牌堆被禁用那几条）；`core.game` 的 `moveCardWithSlot` 那一条删；`core.move` 的「不是槽位区却给槽位名」删；`core.card-def` 的槽位断言改写（另删「同槽换新」一条）
- [x] 3.2 `core.player`：改成「内核建 `手牌` / `判定`；装备子区不由内核建」（四个子区由内容建那半在 `rule.equip` 开头的用例里验）
- [x] 3.3 `rule.equip` 大改：进对应子区生效 / 同子区换装（旧牌进弃牌堆）/ 拆走回落 / 压制恢复 / 进错子区不启用被动 / 装备区是四个普通区
- [x] 3.4 `rule.trick` / `rule.game-over` 的寻址同步；全量 `server/bin/moe-kill.exe --test` 全绿、面板 information 及以上为 0

## 4. 文档

- [x] 4.1 `architecture.md`：第 12 节基础牌区（改成四个）、删 `SlotZone` 与 `moveCardWithSlot` 两条（后者换成内容侧 `equipZoneOf` / `equipCard` / `equipCards` 那一行）、`accept` / `notifyMoved` 行、装备段
- [x] 4.2 `sanguosha-rules`（§9 牌区建法 / §9.11 装备一节）、`code-style.md`（`slot` 回调参数与槽位例子）、`progress.md`

## 5. 收尾（用户追加）

- [x] 5.1 子区名单挪到共享袋：装载器每轮装载建一张新空表 `rule` 并当注入项发给内容（`env-meta.lua` 声明 `Loader.Rule`、`loader/init.lua` 两边都注入、每轮换新），`@基础/装备.lua` 只往 `rule.equipZones` 写默认四条、`@基础/meta.lua` 声明字段
- [x] 5.2 内容侧过度防御的 `assert` 清掉 5 处：一律**顺着可空走**（拿不到子区就不装 / 不进列表，没有 `owner` 就不订阅），既不 `assert` 也不 `---@cast`；内核的 `assert` / `error` 未动
- [x] 5.3 用例补齐：`rule.equip` 加「别的包加载期追加子区」的扩展用例（探针包写 `rule.equipZones` + `addKind '宝物'`）、`rule.init` 加「共享袋每轮重装换新」；最终 **643 用例 / 0 失败**、面板 information 及以上为 0
