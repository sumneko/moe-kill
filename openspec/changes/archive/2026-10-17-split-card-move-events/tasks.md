# Tasks

## 1 内核：三个时机

- [x] 1.1 `server/core/zone.lua`：`notifyMoved` 在「离开 / 进入」两段之间夹三个时机（`'卡牌-批量移动前'` / `'卡牌-批量移动时'` / `'卡牌-批量移动后'`），验证：`server/bin/moe-kill.exe --test` 全量 0 失败
- [x] 1.2 `server/core/loader/env-meta.lua`：`'卡牌-批量移动'` 换成三条 `on` / `fire` 声明，注释写清各自用途（表现起点 / 让出 / 落位），验证：问题面板 information 及以上 0

## 2 协议层：通知分两段

- [x] 2.1 `server/user/card-sync.lua`：`watchEvent` 订「前」（发 `Card.Move` + `Card.Remove`）与「后」（发 `Card.Create`），搬牌路径不再 `markDirty`，验证：日志里 `搬牌` 与 `发 Card.Move` 同一毫秒（改前相差 1001 ms）
- [x] 2.2 `server/user/card-sync.lua`：`V:removeCards` / `V:createCards` 按「账里的区 vs 新区」判换区（协议名相同的无名区之间互移不算换区、但账里没有的新牌要建号），并在「后」洗一次目标区的暗号，验证：`server/test/user/card-sync.lua` 全绿
- [x] 2.3 `server/user/card-sync.lua`：加 `Game.CardSync.moving`（「前」登记 / 「后」清除），`markDirty` 跳过在途的牌（节拍让出期间那笔老调度不得抢建号），验证：用例全绿
- [x] 2.4 `server/user/card-sync.lua`：`updateCards` 收尾抽出 `sendRemoves` / `sendCreates` 两条出口共用，`updateCards` 只留「没换区」与兜底换区两类，验证：用例全绿、`Card.Create` 的明暗分组行为不变
- [x] 2.5 `server/user/user.lua` 与 `client-user.lua`：加 `removeCards` / `createCards`（基类空实现、`ClientUser` 转发给视图），验证：用例全绿

## 3 内容侧与前端

- [x] 3.1 `package/@基础/动画.lua`：节拍从订 `'卡牌-批量移动'` 改订 `'卡牌-批量移动时'`（`BEAT` 表不动），验证：真链路里摸牌 / 弃牌的节拍仍是 1 秒（`Card.Create` 比 `Card.Move` 晚 1001 ms）
- [x] 3.2 `client/src/state/agent.ts`：退掉「`Card.Move` 到场就删旧号」那个补丁（现在由后端的 `Card.Remove` 负责），验证：`npm --prefix client run build` 过、真链路里手牌立刻少一张

## 4 用例与验收

- [x] 4.1 `server/test/core/zone.lua`：新增「搬动的三个时机夹在「离开 / 进入」两段事件之间」（断言顺序 `前 → 离开 → 时 → 进入 → 后`），验证：单条通过
- [x] 4.2 `server/test/user/card-sync.lua`：新增「撤离通知在节拍之前发、落位通知在节拍之后发」（订「时」读快照：`Card.Move` / `Card.Remove` 已到、`Card.Create` 未到），验证：单条通过
- [x] 4.3 全量：`server/bin/moe-kill.exe --test` **1334 用例 0 失败**（基线 1332 → +2），问题面板 information 及以上 0，验证：实跑
- [x] 4.4 真链路（4 人局，重启后端 + 刷新页面）：日志里 `搬牌` / `发 Card.Move` 同毫秒、`发 Card.Create` 在 1001 ms 后，验证：`server/log/service.log` 实读

## 5 文档

- [x] 5.1 `references/architecture.md` §16：通知表（`Card.Move` / `Card.Remove` / `Card.Create` 的时机）、「订四个时机」、新增「搬动为什么拆三段」一条、「判定口径」补「搬牌那一路不走 flush」、出口改成四条，验证：与代码逐条对得上
- [x] 5.2 `references/architecture.md` §12：`Zone:accept` 那条补一句「两段之间夹着三个表现时机」，验证：同上
- [x] 5.3 `references/progress.md`：新增本次条目（形状、两个坑、验收数据），并把上一批那条前端补丁的记录改成「已退掉」，验证：读一遍对得上
