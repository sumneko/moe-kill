# Proposal

## Why

【青釭剑】要一个「防具无效」窗口：**可见**（将来重连的全量同步读得到）、**可查**（技能可以问「这个人的防具还有效吗」）、**到点自己收**（对每个目标结算完就结束；「剑被拿走 / 使用者死亡」窗口不消失 —— 官方裁定）。

讨论里先拟过临时方案（buff 用闭包：自己 `game:on`、删除时注销）；用户 2026-09-29 定：**把 buff 实际做了**，不搞临时方案。

## What Changes

- **内核新增 `Buff`**（`server/core/buff.lua`）：挂在玩家身上的**有名状态**，名字由内容侧起（如 `'防具无效'`）；**同名可以并存**（每个窗口一个实例，各自的生命周期）。
- **宿主侧入口**：`player:addBuff(名字, 载荷?) -> Buff`（载荷内核只存不解释，`'获得'` 里读 `buff.payload` —— 有些状态得知道「自己为什么挂上」才能自己收掉）、`player:getBuffs()` / `player:hasBuff(名字)`（查询与将来的全量同步用）。
- **Buff 自己管自己的资源与订阅**：一律走 `buff:bindGC(...)`（`Zone:disable()` / `game:on(...)` / `Phase:addLimit(...)` 这些撤销函数直接喂进去，随移除自动撤销）、`buff:remove()`（幂等：撤销全部资源、注销全部订阅、从宿主摘掉）。
- **生命周期由内容写**（内核不预设时长、不提供「时长」参数）：【青釭剑】的状态自己订阅「这个目标那次生效的收尾」（拿载荷里的那次使用比对）删自己，**兜底**则由那张牌把状态挂给那次使用（`useCard:bindGC(buff)` —— 使用收场连带删掉）。
- **与创建者的生命期解耦**：buff 的资源 / 订阅记在 buff 上，**不随创建它的处理器、也不随那张牌消失** —— 「剑被拿走、使用者死亡，窗口照旧」靠的就是这条。

## Capabilities

### New Capabilities

无 —— 探索期的决策记录，不写规格增量（`.openspec.yaml` 设 `skip_specs: true`）。

### Modified Capabilities

无（同上）。

## Impact

- 新增：`server/core/buff.lua`（类 + 门面 `moe.buff`）
- 修改：`server/core/player.lua`（`buffs` 表 + 三个入口）、`server/core/init.lua`（装载）、注解（`Player` 字段 / `Buff` 类）
- 用例：新增 `server/test/core/buff.lua`（挂 / 查 / 同名并存 / `remove` 幂等 / `attach` 撤销 / `on` 注销）
- 文档：`architecture.md`（对象清单加 `Buff`）、`progress.md`
- 下游：**第一个消费者是【青釭剑】**（`add-qinggang-sword`）

## Non-goals

- 挂到**牌 / 区**上（先只玩家；用到再加）。
- **层数合并**（同名的多个实例并存；「叠加」由资源自己的计数承担 —— 子区禁用本来就是计数）。
- 可视化 / 协议接线（本轮只把数据放对；全量同步将来读 `getBuffs()`）。
