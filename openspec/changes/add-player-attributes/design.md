# Design

## D1 属性走自己那一路，不进 `custom`

`custom` 的定位是「内容侧的自由数据」：内核不认识里面的键、也不读它。属性正相反 —— 体力是**内核与规则层都在读**的数据（濒死判定读 `体力`、摸牌阶段读 `摸牌数`），取值由属性系统维护、变化自带 `onChange` 事件。

所以属性单开一路：自己的可见性账本（`Player.attrVisibles`）、自己的脏标记（`'attribute'`）、自己的通知（`Player.UpdateAttribute`）。两路互不影响 —— 属性变化 MUST NOT 顺带发 `custom`，反之亦然。

## D2 fail-closed：没声明过就连本人也不见

沿用 `custom` 在 2026-10-15 改定的口径：**没声明过可见性的属性谁都不下发**（含本人）。

代价是把某个属性摆到界面上必须显式声明一次；换来的是「写进去 ≠ 会下发」这条清晰的边界 —— 内容侧可以放心往属性系统里塞中间量（临时修正、内部计数）而不必担心漏出去。

## D3 报脏靠「首次声明时订上变更事件」

`setAttrVisible` 在该属性**首次**被声明时订一次该属性的 `onChange`（`attrWatches` 记账，重复声明不再订），回调里 `markDirty('attribute')`。

好处：**没声明过的属性变化根本不报脏** —— 与 fail-closed 天然一致，不必在 flush 时逐属性去筛。

另外：**`setAttrVisible` 自己也要报脏**。可见性变了就算「这份数据变了」——否则「把某个属性从私有改成公开」之后，线下不会重发，别人直到这个属性**值再变**才看得到。

## D4 通知一条带一批玩家（用户 2026-10-15 定）

`progress.md` 里当时记的是 `{ id, attributes }`（单个玩家）。实现时按**批量**做：`Proto.Notify.Player.UpdateAttribute = { players: Proto.Player.Attribute[] }`，每项 `{ id, attributes }`。

理由：与既有两条玩家下行（`Player.Update` / `Player.UpdateCustom`）同形 —— 客户端一处循环处理三条，用例断言也一致（`got[1].players[1]`）。

## D5 载荷用数组不用 Record（用户 2026-10-15 定）

`attributes` 是 `Proto.Attribute[]`（`{ name, value }` 的列表），不是 `Record<string, number>`。

好处：**顺序可控**（组装时按名字排序 ⇒ 同一份数据每次发出去逐字节一致，客户端 diff 不抖）；将来给单条属性加字段（上限 / 是否可见…）也不会撑破形状。

## D6 内容侧：体力与体力上限声明公开

`@基础/体力.lua` 里 `setAttrVisible('体力', true)` + `setAttrVisible('体力上限', true)` —— 三国杀里体力是公开信息（数勾玉）。声明必须发生在**属性写值之前**（否则首次写值那次变化订不上事件、不会报脏）。

其余属性（`攻击范围` / `摸牌数` / `进攻修正`…）本批**不声明** —— 它们现在没人显示，等界面要显示了由各自的包声明。
