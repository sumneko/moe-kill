# Tasks

## 1. 内核：`Panel`

- [x] 1.1 `server/core/panel.lua`（新）：`Panel : GCHost`（`moe.panel.create`）—— 行 / `rows` / `cards` / `disableCard` / `isDisabled` / `addMark` / `marks` / `visible` / `isVisibleTo`
- [x] 1.2 `row(cards, title?)` 可链式追加；行内有序、行序号 1 起（协议里就用序号）；另给 `findCell` / `contains` / `takeOut` / `appendCell`（询问与内容侧搬动用）
- [x] 1.3 把 `createPanel` 装成内容侧全局（`loader/init.lua` 的注入项）+ `env-meta` 的类型面

## 2. 内核：`AskPanel`

- [x] 2.1 `server/core/effect/ask-panel.lua`（新）：`AskPanel : Effect`（`kind = 'askPanel'`）
- [x] 2.2 `settle()`：循环 fire `'面板-询问'`，每次只收**变化值**（`moves` / `card`）或 `done`；上限 1000 次
- [x] 2.3 校验：变化里的每张牌都在面板上、没被禁用、`row` 存在、面板允许 `moveable`；挑选的牌同样要在面板上、没被禁用、不超 `max` ⇒ **先全验、再全应用**（有一条不合法就整条作废）
- [x] 2.4 `done` 时按 `min` 校验选中张数（`min` 默认 0）⇒ 定结果 `{ rows = 各行, card = 选中那张（如有）, cards = 选中的牌 }`
- [x] 2.5 `server/core/game.lua`：`game:askPanel(被问者, 缘由, 面板)`
- [x] 2.6 `env-meta`：`'面板-询问'` / `'面板-答复'` 的订阅面与载荷类型；`effect/init.lua` 加 include

## 3. 内容：观星（换掉占位分配）

- [x] 3.1 `package/标准/武将/诸葛亮.lua`：`createPanel('观星', owner, { moveable = true, min = 0 })` 两行（牌堆顶 / 牌堆底）
- [x] 3.2 `game:askPanel` ⇒ `deck:placeTop(result.rows[1])` / `deck:placeBottom(result.rows[2])`；没答上就按面板当前形状放回；删掉 `arrange` 占位
- [x] 3.3 用例：原来那条改成「没人摆 ⇒ 照原顺序放回牌堆顶」；新增两条 —— 「把牌摆到「牌堆底」那一行」与「答复中途被拒收 ⇒ 已经摆好的照摆」（同时钉住 `placeBottom` 与「照面板形状放回」）

## 4. 内容：五谷丰登（面板版 + 兜底）—— ⏳ 待做

- [ ] 4.1 `'使用'`：亮出的牌建一块面板（`min = 1, max = 1, cancelable = false`）挂到这次使用上（`bindGC` + `setTag`）
- [ ] 4.2 `'生效'`：`game:askPanel(target, '五谷丰登', panel).card`；`disableCard` + `addMark('${hero:{name}}')` + `moveCard` 到手牌
- [ ] 4.3 **兜底**：没答 ⇒ 替他拿**第一张没被禁用的**（`panel:cards()` + `isDisabled` 扫过去）
- [ ] 4.4 用例：三人各拿一张、拿走的不能再被拿、`addMark` 记的是拿走者、**没答那条（兜底拿到第一张可用的）**、剩余进弃牌堆

## 5. 协议（`specs/` 增量）

- [x] 5.1 `specs/card-panel/spec.md`：面板的形状（行 / 顺序 / 禁用 / 标记 / 牌面可见性 / 布局与张数人人可见）
- [x] 5.2 同文件：一次询问的往返（变化 → 校验 → 状态更新 → `done` 定结果）+ 校验失败的处理（整条作废）+ 取消与「一个都不选」

## 6. 收尾

- [x] 6.1 `server/bin/moe-kill.exe --test` 全绿（**1063 → 1081**）
- [x] 6.2 问题面板 information 及以上 0
- [x] 6.3 反向验证：注释掉观星的 `placeBottom` ⇒ 1 红；观星改成「全放顶」（不照面板形状）⇒ 2 红（上批那条已知缺口也一并钉住了）；⏳ 待做：变化校验 / `min` 确定校验 / 五谷兜底
- [x] 6.4 `openspec validate --all --strict`（36/36；本变更有 specs，不再 skip）
- [x] 6.5 停在待确认状态，等「提交」

## 7. 文档 —— ⏳ 待做

- [ ] 7.1 `architecture.md`：`Panel` / `askPanel` 行、`'面板-询问'` 时机、`createPanel` 全局
- [ ] 7.2 `sanguosha-rules`：§9.33 观星改成面板版；五谷丰登的口径（「获得」= 必须 + 兜底）
- [ ] 7.3 `progress.md`：基线 + 本批条目
