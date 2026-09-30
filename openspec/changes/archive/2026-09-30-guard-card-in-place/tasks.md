# guard-card-in-place

## 1 内核

- [x] 1.1 `server/core/zone.lua`：`Zone:accept` 删掉虚拟牌那行 `Delete(card)`；**虚拟牌分支收成一句 `local physical = card.physical` + `table.move(…)`**（用户 2026-09-30 追加：有了 `Card.physical` 就不该在两处各写一遍），注释改成「收的是每张牌的实体牌」
- [x] 1.2 `package/@基础/伤害.lua`：`Damage` 加 `---@field private cardZones Zone[]`；`settle()` 开头按「实体牌（虚拟牌展开成 `subcards`）」快照一次；**读法 `Damage.cardsInPlace`**（`__getter`，按 `code-style` §143 **不写 `---@param self`**）= 还在原处的那些实体牌

- [x] 1.3 `server/core/card.lua`：新增 **`Card.physical`**（`__getter`：普通牌就是它自己、虚拟牌是它的素材）—— 把 `@基础/伤害.lua` 里那个局部纯函数挪上来（用户 2026-09-30 要求）；`Damage` 两处改读 `card.physical`、**`Zone:accept` 也改读它**

## 2 内容侧

- [x] 2.1 `package/标准/武将/曹操.lua`：【奸雄】读 `damage.cardsInPlace`，空表就 `return`（一张都拿不到 ⇒ 不问）；非空则照问、把那些牌一次移进手牌

## 3 用例

- [x] 3.1 `server/test/core/move.lua` 三条翻新：虚拟牌不进区但**不被注销** / 一批里混着虚拟牌同理 / 收虚拟牌就是收它的实体子牌
- [x] 3.2 `server/test/core/game.lua`：往弃牌区挪虚拟牌 ⇒ 虚牌自己不进去、也没被注销
- [x] 3.3 `server/test/rule/skill.lua` +3：「那张牌已经不在原处 ⇒ 拿不到也不问」（伤害结算里把牌挪给别人）、「虚拟牌的素材被挪走 ⇒ 一样拿不到」、「**素材只剩一张在原处 ⇒ 能拿的那张照拿**」

## 4 验收

- [x] 4.1 `server/bin/moe-kill.exe --test` 全绿（**810 用例 0 失败**）
- [x] 4.2 问题面板 information 及以上 0
- [x] 4.3 文档同步：`architecture.md`（`createVirtualCard` / `askPlayCard` / `Damage` / `Zone:accept` 四处）、`sanguosha-rules`（虚拟牌段 + §9.15）、`progress.md`
