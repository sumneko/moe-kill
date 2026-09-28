# Tasks

## 1. 内核

- [x] 1.1 `server/core/effect/use-card.lua`：`UseCard:settle` 在 `zone:take` 之后 `game:moveCard(self.card, self:getTempZone())`，再 `fire('卡牌-结算前')`
- [x] 1.2 `server/core/effect/use-card-to-card.lua`：同形改造
- [x] 1.3 删 `package/@基础/使用.lua`

## 2. 用例

- [x] 2.1 `core.effect.play`：「零目标也跑完使用钩子与收尾」的断言改成「收尾后落在弃牌堆」（探针局里没有 `@基础`，如今内核也会安置）
- [x] 2.2 `core.effect.play`：「牌出手前触发一次时机」的说明文本对齐（此刻牌已在临时区）

## 3. 文档与验收

- [x] 3.1 文档同步：`architecture.md`（`useCard` / `useCardToCard` 行、§12「牌的安置与去向」、测试清单）、`code-style.md`（文件顶部说明的例子换一个）、`progress.md`（`@基础` 文件表 + 新条目）、`sanguosha-rules`（§9.2「两套去向」/「牌的去向」）
- [x] 3.2 `server/bin/moe-kill.exe --test` ⇒ 全绿；问题面板 information 及以上 0

## 4. 收尾修复：逐目标生效漏了「等它结完」（同日，用户发现）

- [x] 4.1 `server/core/effect/use-card.lua` / `server/core/effect/use-card-to-card.lua`：逐目标（对牌使用是一支）的 `effect:apply()` 改成 `effect:apply():await()`
- [x] 4.2 两条回归用例：`core.effect.play`「上一个生效结完（哪怕它让出）才轮到下一个」、`core.effect.use-card-to-card`「窗口里让出时，父结算也等它结完」
- [x] 4.3 对照验证：撤掉 `await` 重跑，两条都按预期失败（实际 `开始2开始3收尾` / `'卡牌-结算后'` 先于窗口原因）⇒ 用例抓得住
- [x] 4.4 验收：**584 用例 0 失败**；问题面板 0
