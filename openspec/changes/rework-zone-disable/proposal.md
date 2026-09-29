# Proposal

## Why

`Zone:disable()` 现在的语义是**把整个区冷冻**：不能放进、不能清空，`OrderedZone` 连洗牌都不给（`server/core/zone.lua:190`、`ordered-zone.lua:43`）。这套语义没有消费者（生产路径零调用，只有用例），代码里还挂着一条自认没做全的 TODO：「以后改成计数（多个禁用者各自加一 / 减一，减到 0 才恢复；现在的 boolean 只够一个人禁）」。

而真正要表达的是**逻辑禁用**：**这个区里的牌不能用、被动不生效**。第一个消费者是【青釭剑】——「使用【杀】时令目标的防具无效」= 把目标那个**防具子区**禁用（子区落地见 `replace-slot-zone-with-equip-zones`）。

「不准置入某区域」在官方规则集里另有一个名字 —— **封印**（「目标区域不处于封印状态的<牌>才置入」）；将来要做按那个名字另做，不混进 `disable`。

## What Changes

- **禁用 = 逻辑禁用**：`disable()` 时对区内每张牌 `card:disablePassive()`；恢复时 `enablePassive()`；**中途进区的牌同样被压**（进区事件跑完之后补一层）；**离区时只松开区级这一层**（牌自己的进出钩子照旧）。
- **计数可叠加 + 撤销函数**：多个禁用者各占一层；`disable()` 返回**幂等的撤销函数**；`enable()` 删掉；`isEnabled()` 保留（0 层才算启用）。
- **不再拦搬入搬出**：`Zone:accept` / `Zone:clear` / `OrderedZone:shuffle` / `SlotZone:accept`（两处）的禁用检查去掉 —— 物理搬运与逻辑状态分开。
- **「不能用」进校验**：`checkCardItself`（`server/core/game.lua`，`canUse` 与 `canUseToCard` 共用）加一条 —— 牌此刻所在区被禁用 ⇒ 用不了（`askUseCard` 的候选跟着少掉）。

## Capabilities

### New Capabilities

无 —— 探索期的决策记录，不写规格增量（`.openspec.yaml` 设 `skip_specs: true`）。

### Modified Capabilities

无（同上）。

## Impact

- `server/core/zone.lua`：`enabled` 字段 → 计数；`disable()` 改形；进 / 离区同步压制
- `server/core/ordered-zone.lua`、`server/core/slot-zone.lua`：禁用检查去掉（后者整个文件在下一个变更里删除）
- `server/core/game.lua`：`checkCardItself` 加「所在区被禁用」一条
- 用例：`core.zone`（禁用段重写 + 洗牌用例）、`core.move`（「被禁用的区收不下」改成「照收」）、`core.can-use`（新增）
- 文档：`moe-kill-dev/references/architecture.md`（`Zone` 行、`accept` 行）、`references/progress.md`

## Non-goals

- **封印**（「不准置入」的官方概念）—— 按那个名字另做。
- 禁用与其他状态的联动（可见性 / 洗牌限制）—— 没有需求。
