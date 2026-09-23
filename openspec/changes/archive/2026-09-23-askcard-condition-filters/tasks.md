# Tasks

## 1. 内核：`AskCard.Condition` 重做

- [x] 1.1 `server/core/effect/ask-card.lua` 的类型：`Condition` 改成 `name?` / `zone?` / `card?` / `target?`（都是「单值或其一的数组」）；`Option` / `Answer` 收回到 `card?` / `targets?`；撤掉 `__getter.zone`；验证：`--test core.effect.ask-card` 全绿
- [x] 1.2 `collectOptions` 重写：候选 = `zone` 里的牌 ∪ `card` 那批（都没给 ⇒ 被问者名下所有牌区）；`zone` 名字按「被问者 → 局上」解析（新增本地 `resolveZone`）；`optionOf` 只做筛选（`name` 其一、`target` 交集非空、必要时跑 `canUse`）；验证：同上
- [x] 1.3 使用语义：`reason == '使用'`（或给了 `target`）⇒ 逐张跑 `game:canUse`，用不了的不进选项、选项带各自的可用目标（给了 `target` 时取**交集**）；`answerProblem` 回到只判定"牌 + 目标"；验证：同上

## 2. 内核用例（`server/test/core/effect/ask-card.lua`）

- [x] 2.1 条件：`zone` 过滤（给区名与给区对象各一条）、`card` 一批、两者并集、`name` 数组（其一）、`target` 交集（选项 targets = 交集；名单外的目标被拒）
- [x] 2.2 使用语义：`reason = '使用'` ⇒ 只收能用的牌（没 `'获取目标'` 的牌 / 次数用满的牌不进选项）、选项带可用目标；其它缘由不跑 `canUse`
- [x] 2.3 撤掉区域用例（「候选可以是一批区域」「答复的区域不在候选项里就拒收」「牌与区域可以同时是候选」）与 `targets = {}` 那条改名成「`target = {}` 没有候选」

## 3. 内容侧调用点

- [x] 3.1 `package/@基础/回合.lua`：`PLAY_PHASE_CONDITION = { zone = '手牌' }` + `game:askCard(player, '使用', …)`；验证：`--test rule.turn` 全绿
- [x] 3.2 `package/@基础/濒死.lua`：`{ name = '桃', target = player }`；验证：`--test rule.dying` 全绿
- [x] 3.3 `package/标准/卡牌/{过河拆桥,顺手牵羊}.lua`：条件改成 `{ zone = 目标身上有牌的区 }`，答复直接 `ask.card`（不再分「牌候选 / 区候选」、不再 `random:pick`）；验证：`--test rule.trick` 全绿
- [x] 3.4 `package/标准/卡牌/五谷丰登.lua`：`{ card = 剩余 }`；验证：同上
- [x] 3.5 其余调用点（杀 / 闪 / 万箭齐发 / 南蛮入侵 / 决斗 的 `{ name = '闪' }` / `{ name = '杀' }`）写法不变，确认仍然可用

## 4. 规则侧用例

- [x] 4.1 `server/test/rule/support.lua`：应答脚本回到 `Card[]`（撤掉联合类型与 `---@cast`）
- [x] 4.2 `server/test/rule/turn.lua`：出牌阶段的应答改认 `reason == '使用'`
- [x] 4.3 `server/test/rule/trick.lua`：过河拆桥（手牌也能直接被挑中 ⇒ 断言"挑中的那张进了弃牌"）、顺手牵羊（明区挑牌 / 手牌直接挑、距离与合法目标）、五谷丰登沿用
- [x] 4.4 `server/test/rule/{slash,dying}.lua`：条件形状跟着改（`targets` → `target`），行为断言不变

## 5. 文档与验收

- [x] 5.1 `.agents/skills/moe-kill-dev/references/architecture.md`：§12 的 `askCard` 行与「询问与应答方」按新语义重写（四个字段 + 使用语义走缘由 + 撤销 `zone` 候选）；牌区可见性那条改成「协议层的输入」
- [x] 5.2 `.agents/skills/sanguosha-rules/SKILL.md`：§6 / §7 / §9.10 的写法示例（出牌阶段 `'使用'`、两张牌逐张候选）；`.agents/skills/moe-kill-dev/references/progress.md` 同步
- [x] 5.3 验收：`server/bin/moe-kill.exe --test` 全量 0 失败、问题面板 information 及以上 0；提交（`【AI】` 前缀）并归档变更
