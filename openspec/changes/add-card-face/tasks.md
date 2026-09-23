# Tasks

## 1. 内核：`Card` 带上牌面

- [x] 1.1 `server/core/card.lua`：加两个**公开字段** `suit?`（花色）/ `point?`（点数）（各配一行中文说明），`Card:__init(label, id, suit, point)` 与 `moe.card.create(label, id, suit, point)` 一路传下去；**不另给 getter**（字段直接读；将来真有派生读法再用 `__getter`）；验证：`--test core.card` 全绿
- [x] 1.2 `server/core/game.lua`：`game:createCard(name, suit, point)` 追加两个可选参数（注释里说明「花色 / 点数由内容侧给，内核不解释」）；验证：`--test core.game` 全绿、既有调用点一行不改

## 2. 内容侧：牌表逐张 + 建牌带牌面

- [x] 2.1 `package/标准/牌表.lua`：改成**逐张**（`{ name = '杀', suit = '黑桃', point = 7 }`），**张数构成不变**（杀 30 / 闪 15 / 桃 8 / 无懈可击 4 / 各锦囊与装备照旧，共 102 张），顶部保留「草稿：张数与牌面待按官方标准版核对」的说明；验证：`--test rule.base` 的张数构成用例全绿
- [x] 2.2 `package/@基础/牌堆.lua`：建牌循环改成逐条 `game:createCard(entry.name, entry.suit, entry.point)`（不再按 `count` 重复）；验证：`--test rule.base` / `--test rule.setup` / `--test rule.turn` 全绿

## 3. 用例

- [x] 3.1 `server/test/core/card.lua`：那条「内核不预设名称 / 花色 / 点数 / 效果」按**新契约**改写 —— 没传牌面时表里就是 `id,label` 两类字段（`suit` / `point` 不存在）、传了则多这两个键且**直接读字段**读得到；仍然没有 `'名称'` / `'效果'` 这类字段（内核不解释牌面）；验证：`--test core.card` 全绿
- [x] 3.2 `server/test/core/game.lua`：`game:createCard('杀', '黑桃', 7)` 带得上牌面（顺便钉住「不传就为空」这条 Optional 行为的落点）；验证：`--test core.game` 全绿
- [x] 3.3 `server/test/rule/base.lua` / `setup.lua` / `turn.lua`：三处 `totalCards` 帮助函数从「按 `entry.count` 求和」改成「数表长（`#cardTable`）」；`base.lua` 另加一条**牌表自检**：每张都有花色（四种之一）与点数（1..13 的整数），且总张数 102；验证：`--test rule.base` / `--test rule.setup` / `--test rule.turn` 全绿

## 4. 文档与验收

- [x] 4.1 `.agents/skills/sanguosha-rules/SKILL.md`：新增「牌面」小节（花色四种 / 点数 1..13 / 颜色是派生 / 牌面由内容侧给、内核只存不解释 / 判定与拼点怎么读 / 牌表数据待核对），并在 §4 或 §9 里链过去
- [x] 4.2 `moe-kill-dev/references/architecture.md`：§12 的 `Card` 行（两个字段直接读，**没有 getter**）与 `game:createCard(名字, 花色, 点数)` 行；顺手把「内核不预设牌名 / 花色 / 点数」的旧措辞改成「内核不解释牌名与牌面，只搬运内容给的取值」
- [x] 4.3 `moe-kill-dev/references/progress.md`：内核现状（`Card` 带牌面）、内容包现状（牌表逐张）、用例数、§2 候选表划掉「牌面」
- [x] 4.4 验收：`server/bin/moe-kill.exe --test` 全量 0 失败、问题面板 information 及以上 0；提交（`【AI】` 前缀）
