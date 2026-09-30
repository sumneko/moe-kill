# add-cast

## 1 内核

- [x] 1.1 `server/core/effect/cast.lua`（新）：`Cast : Effect`（`kind = 'cast'`，字段 `source` / `body`，`settle()` 跑 `body` 并把它的返回值当结果）
- [x] 1.2 `server/core/effect/init.lua`：`include 'core.effect.cast'`
- [x] 1.3 `server/core/skill.lua`：**`Skill:cast(函数)`**（造 `Cast`，`from = self.owner`，`apply():await()` 后返回实例）
- [x] 1.4 `server/core/card.lua`：**`Card:cast(函数)`**（同上，`from = self:getZone()?.owner`）

## 2 内容侧

- [x] 2.1 `package/标准/武将/曹操.lua`：【奸雄】确认发动后包一层 `skill:cast(function () game:moveCard(…) end)`
- [x] 2.2 装备牌里「发动后做事」的 6 张包上 `card:cast(…)`：`麒麟弓` / `青釭剑` / `雌雄双股剑` / `青龙偃月刀` / `贯石斧` / `八卦阵`（另外 4 张没有那一段：`方天画戟` / `诸葛连弩` / `仁王盾` / `丈八蛇矛`）

## 3 用例

- [x] 3.1 新套件 `server/test/core/effect/cast.lua`（+3）：① 里面那次挪牌的 `parent` 是这次发动、`source` / `from` 对得上、body 里能让出；② 在父效果里调 ⇒ **不进记牌器**（平地调则记一条）；③ `Card:cast` 的 `source` 是那张牌、`from` 是持牌的人

## 4 验收

- [x] 4.1 `server/bin/moe-kill.exe --test` 全绿（**813 用例 0 失败**）
- [x] 4.2 问题面板 information 及以上 0
- [x] 4.3 文档同步：`architecture.md`（`Skill` 行 + 第 12 节效果表新增 `Cast` 行）、`sanguosha-rules` §9.15、【奸雄】描述、`progress.md` §1
