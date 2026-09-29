# Tasks

## 1. 内核

- [ ] 1.1 `server/core/zone.lua`：`enabled` → `private disabled: integer`；`disable()` 计数 +1 并返回幂等 disposer；删 `enable()`；`isEnabled()` 读计数；`__init` 初值 0
- [ ] 1.2 同处：0 → 1 层时对区内每张牌 `disablePassive()`、1 → 0 层时 `enablePassive()`；`notifyEnter` 在钩子之后补压、`notifyLeave` 先松区级再跑钩子
- [ ] 1.3 `server/core/zone.lua` / `ordered-zone.lua` / `slot-zone.lua`：删掉「被禁用 ⇒ 收不下 / 清不掉 / 洗不了」四处检查
- [ ] 1.4 `server/core/game.lua` `checkCardItself`：牌所在区被禁用 ⇒ `nil, '「{}」在的牌区被禁用了，用不了'`
- [ ] 1.5 用例：`core.zone` 禁用段重写（层数 / disposer 幂等 / 进区被压 / 离区松开 / 恢复重放 / 搬入搬出不再被拦 + 洗牌照洗）；`core.move` 的「被禁用的区收不下」改成「照收」；`core.can-use` 新增「禁用区里的牌用不了」
- [ ] 1.6 文档：`architecture.md`（`Zone` 行、`accept` 行的禁用口径）、`progress.md`
- [ ] 1.7 `server/bin/moe-kill.exe --test` 全绿 + 问题面板 information 及以上为 0
