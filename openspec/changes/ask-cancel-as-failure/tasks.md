# Tasks

## 1. 内核：`AskCard`

- [x] 1.1 `server/core/effect/ask-card.lua`：加模块内 `isEmptyAnswer(value)`（没给牌、也没给声明）
- [x] 1.2 `server/core/effect/ask-card.lua`：加 `M:allowNone()`（= `condition.min` 为 `0`）
- [x] 1.3 `collectAnswer`：没人表态时 —— `allowNone` ⇒ 什么都不做（成立、空结果）；否则 `reject(cancelable and '取消' or '这次询问必须给出答复')`
- [x] 1.4 `collectAnswer`：空答复 ⇒ `allowNone` 才放行，否则 `reject('取消')`
- [x] 1.5 `checkAnswer` 那句「允许取消的询问：空答复就是『取消』，不算不合法」的注释改成新口径

## 2. 内核：其余询问类

- [x] 2.1 `server/core/effect/ask-player.lua`：加 `M:allowNone()`；`settle` 没人表态时按 `allowNone` 决定是否 `reject('取消')`
- [x] 2.2 `server/core/effect/ask-choice.lua`：`settle` 没人表态 ⇒ `reject('取消')`
- [x] 2.3 `server/core/effect/ask.lua`：`settle` 没人表态 ⇒ `reject('取消')`
- [x] 2.4 `server/core/effect/ask-use-skill.lua`：`settle` 没人表态 ⇒ `reject('取消')`

## 3. 内核：收编 `AskPlayCard`

- [x] 3.1 `server/core/effect/ask-play-card.lua`：删 `settle` 里的 `reject('没有打出')`（基类已管），类注释改「没答上就是『取消』」
- [x] 3.2 `server/core/effect/ask-play-card.lua`：删 `beforeResolve`（空答复统一由基类记 `'取消'`）
- [x] 3.3 `server/core/game.lua`：`askPlayCard` 的说明同步（「没答上就是『取消』」）

## 4. 用例

- [x] 4.1 `test/core/effect/ask-card.lua`：「默认允许取消」那条改断言（`'取消'` + `.success` 假 + 0 错误）；「`min 0` ⇒ 不给也算答复」改名点明口径；**新增**「`min` 给 0 时没人应答也算成立」
- [x] 4.2 `test/core/effect/ask.lua` / `ask-choice.lua`（2 条）/ `ask-player.lua` / `ask-use-card.lua` / `ask-use-card-to-card.lua` / `ask-card-with-target.lua` / `ask-use-skill.lua`：改断言 + 改名（「= 取消（记成失败）」）
- [x] 4.3 `test/core/effect/ask-player.lua`：`min` 给 0 那条改名点明「取消也是合法答复 ⇒ 算成立」
- [x] 4.4 `test/core/effect/ask-play-card.lua`：「没打出」那条的原因改 `'取消'` + 改名

## 5. 收尾

- [x] 5.1 `server/bin/moe-kill.exe --test` 全绿（**1053 → 1054**）
- [x] 5.2 问题面板 information 及以上 0
- [x] 5.3 反向验证三轮（见 `design.md` D7）：`allowNone` 钉死 ⇒ 2 红；`AskCard` 两处拒收去掉 ⇒ 65 红；其余四类去掉 ⇒ 5 红

## 6. 文档

- [x] 6.1 `moe-kill-dev/references/architecture.md`：`cancelable?` 那行、「询问与应答方」那条、`askPlayCard` / `askPlayer` / `ask` / `askChoice` 四行
- [x] 6.2 `moe-kill-dev/references/progress.md`：验收基线 1054、本批条目；上一批（【无双】）里「`AskPlayCard:beforeResolve` 作废空答复」那句注明已收编进基类
- [x] 6.3 变更工件（本目录）
