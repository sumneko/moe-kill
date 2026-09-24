# Tasks

## 1. 内核：无目标的使用

- [x] 1.1 `server/core/game.lua`：`CardDef` 加定义项 `noTarget()` 与读取 `getNoTarget()`（与 `zone` / `kind` 同形；`extends` 抄字段时一并带上）；验证：新增用例「声明了就不需要目标，没声明照旧 fail-closed」通过
- [x] 1.2 `server/core/game.lua`：`canUse` 的目标判据分叉 —— 声明了 `noTarget()` ⇒ 跳过「`'获取目标'` 给出非空列表 / 目标非空 / 是合法目标的子集」，但**调用方给了目标就是不成立**（明确失败，不静默忽略）；验证：新增用例「无目标牌给目标 ⇒ 不成立并给出原因」通过
- [x] 1.3 `server/core/game.lua`：`useCard` 零目标时照旧走完整链条（`'卡牌-结算前'` → 牌自己的 `'结算前'` → 逐目标循环空转 → 牌自己的 `'结算后'` → `'卡牌-结算后'` → 收尾）；验证：新增用例「零目标也跑完两个时机与收尾」通过
- [x] 1.4 `server/core/effect/ask-use-card.lua`：无目标牌的选项不带 `targets`（`AskUseCard.Option.targets` 从「恒非空」改成可空）、答复不需要给目标；有目标的牌照旧必须给且必须落在可用目标里；验证：`--test core.effect.ask-use-card` 通过且新增用例覆盖无目标选项

## 2. 内核：定义项、牌上的随区容器、属性修正、槽位区

- [x] 2.1 `server/core/game.lua`：`CardDef:value(名字, 值)` / `getValue(名字)`（内核只存不解释；`extends` 深拷贝一份数据）；验证：新增用例「数据读得回来 / 重写覆盖 / 基类数据被抄过来且抄完脱钩」通过
- [x] 2.2 `server/core/card.lua`：加私有字段 `zoneGCHost`（懒建）与 `Card:bindZoneGC(撤销函数)`；`Card:bindZone` 在**区真的变了**（`self.zone ~= zone`）时 `Delete` 容器并置空；**不继承 `GCHost`、不改 `server/tools/gc.lua`**；验证：新增用例「挂上去的回调在牌离开区时被调一次 / 没挂过的牌零成本（容器懒建）/ 同区内部调序不算离开区」通过
- [x] 2.3 `server/core/attribute.lua`：`Attributes:addModifier(名字, 增量)` 返回撤销函数（撤销即精确减掉这次加的量）；验证：新增用例「加两条修正、撤销其中一条只减掉它自己」通过
- [x] 2.4 `server/core/loader/env-meta.lua` 与 `references/architecture.md`：把 `noTarget` / `value` / `getValue` 三个定义项、`Card` 的 `zoneGCHost` / `bindZoneGC`（离开区即撤销）、`addModifier`、`setSlots` / `getSlots`、`SlotZone` 与「`AskUseCard.Option.targets` 可空」「`getZone('装备')` 返回 `SlotZone`」写进类型契约；验证：问题面板 0 问题、`--test` 通过
- [x] 2.5 `server/core/game.lua`：`game:setSlots(区名, 槽位名表)` / `game:getSlots(区名)`（加载期声明、与规则数值同层：随重装清空；内核只存不解释）；验证：新增用例（声明后读得回来 / 同一个区名重复声明以后写的为准 / 没声明过读到「不存在」）通过
- [x] 2.6 `server/core/slot-zone.lua`（新模块 + `moe.slotZone.create(局, 槽位名表)` 门面，与 `moe.orderedZone` 同形）：`slots`（声明了哪些槽位）、`getSlot(槽位名)`（**懒校验**：记的牌已不在本区就地失效并返回「不存在」）、`putInto(槽位名, 牌)`（牌不必先在本区 —— 在别的区就 `move`、没归属就 `put`；**同槽已有牌 ⇒ 内核把它同步送进那个局的 `弃牌`**，走 `self.game:getZone('弃牌')` 与 `MoveCard` 无关；槽位名不在声明里、替换时又没给局就报错）；验证：`--test core.zone` 新增用例（放进空槽 / 同槽替换且旧牌进了弃牌 / 一个槽始终只有一张 / 牌被别的路径取走后 `getSlot` 读不到 / 未声明的槽位名报错 / 建区时没给局时只能放进空槽）通过
- [x] 2.7 `server/core/player.lua`：`装备` 区建成 `SlotZone`（带局上声明的名单：`addZone('装备', moe.slotZone.create(self.game:getSlots('装备') or {}))`），`player:getZone('装备')` 的 `@overload` 收窄成 `SlotZone`；验证：`--test core.player` 通过且新增断言「装备区是槽位区、带局上声明的槽位名」通过

## 3. 内容：装备能用

- [x] 3.1 把基类牌挪进 `package/@基础/卡牌/`（`git mv 基本牌.lua 锦囊牌.lua`），并在那里新建 `装备牌.lua`：`Card '装备牌' : kind '装备' : noTarget() : zone '手牌'` + **基类自己的 `'结算后'` 钩子**（遍历 `装备区.slots` 匹配自己的分类 ⇒ `putInto(槽位名, 牌)` → `equip(使用者, 牌)`；**没有「先撤旧牌」这一步** —— 旧牌的修正随它离开区自动撤销）；验证：`--test rule` 全绿（模板移位置不影响路由）且「装备牌在出牌阶段能进 `askUseCard` 选项并落进正确的槽」用例通过
- [x] 3.2 `package/@基础/装备.lua`（新）：① 加载期 `game:setSlots('装备', { '武器', '防具', '进攻马', '防御马' })`；② `equip(玩家, 牌)` —— 按 `value('攻击范围')` / `value('距离修正')` 用 `addModifier` 加修正，并把撤销函数 `card:bindZoneGC(撤销函数)` 挂到牌上（**没有「卸下」**：牌离开装备区就自动撤）；验证：`rule.equip` 的置入 / 替换用例通过
- [x] 3.3 `package/@基础/攻击范围.lua`：**属性与开局赋值都保留**，只补一行说明「修正由 `@基础/装备.lua` 的 `equip` 加、随牌离开区自动撤」；`package/标准/卡牌/杀.lua` 的攻击范围读法**一行不改**；验证：`rule.equip` 的「武器改范围 / 拆走武器后回落」用例 + `--test rule.slash` 通过
- [x] 3.4 `package/@基础/距离.lua`（新）：定义 `进攻修正`（自己到别人，默认 0）/ `防御修正`（别人到自己，默认 0）两个属性 + 求值函数 `distance(from, to)` = `desk:getDistance` + `to:getAttr('防御修正')` + `from:getAttr('进攻修正')`（结算后仍最小 1）；`package/标准/卡牌/杀.lua` 与 `顺手牵羊.lua` 改用它；验证：`rule.equip` 的进攻马 / 防御马用例（含「最小 1」的边界）通过
- [x] 3.5 `package/标准/卡牌/`：新增 8 张武器（诸葛连弩 1 / 雌雄双股剑 2 / 青釭剑 2 / 青龙偃月刀 3 / 丈八蛇矛 3 / 贯石斧 3 / 方天画戟 4 / 麒麟弓 5，分类 `{ '装备', '武器' }`）与 6 张坐骑（进攻马：赤兔 / 大宛 / 紫骍，分类 `{ '装备', '坐骑', '进攻马' }`；防御马：的卢 / 绝影 / 爪黄飞电，分类 `{ '装备', '坐骑', '防御马' }`），每张一个文件、顶部写官方描述；**数据只给数值**（`value('攻击范围', …)` / `value('距离修正', -1 | 1)`，槽位靠分类匹配）；验证：`rule.equip` 里面向牌表逐张断言「进对了槽 + 攻击范围 / 距离修正对」
- [x] 3.6 复核「拆牌 / 奖惩 / 将来任何挪牌路径**都不用改**」：`Zone` 的 `put` / `take` / `move` / `clear` 都经 `card:bindZone` ⇒ 修正自动撤；验证：`rule.equip` 里「【过河拆桥】拆走武器后攻击范围回落且 `getSlot` 读不到」用例通过（**过河拆桥与顺手牵羊的代码一行未改**）

## 4. 内容：【借刀杀人】与奖惩补全

- [x] 4.1 `package/标准/卡牌/借刀杀人.lua`（新）：官方描述 + `'获取目标'`（其他角色、装备区里有武器牌、其攻击范围内还有别的角色）+ `'生效'` 三步（通用 `Ask` 指定角色 ⇒ `askUseCard` 问被借刀者用【杀】 ⇒ 没用出来就交武器）；验证：`rule.trick` 的新用例通过
- [x] 4.2 `package/身份场/奖惩.lua`：主公杀死忠臣 ⇒ 弃手牌**与装备区的牌**（与现有弃手牌同形），并把顶部那行「等装备批次补上」改成已落地的说明；验证：`--test rule.game-over` 的新用例「主公杀忠臣 ⇒ 装备区的牌也进弃牌」通过

## 5. 用例

- [x] 5.1 `server/test/rule/equip.lua`（新套件）：装备牌没有目标也能用 / 置入装备区（进对了槽）/ 同槽替换（旧牌进弃牌、范围与距离都换成新装备的、那个槽里只有新牌）/ 攻击范围随武器变 / 进攻马与防御马各改一边距离且结算后最小 1 / 【过河拆桥】拆走武器后攻击范围回落且 `getSlot` 读不到；验证：`--test rule.equip` 全绿
- [x] 5.2 `server/test/rule/trick.lua`：借刀杀人补四条 —— 用出【杀】（被借刀者打了杀、按杀结算）/ 用不了（没【杀】或目标不在其范围）⇒ 武器交给使用者 / 目标筛选（没有武器牌 / 攻击范围内没有别人 ⇒ 不是合法目标）/ 使用者没指定角色（答复不在候选里）⇒ 按「没指定」处理、武器照交；验证：`--test rule.trick` 全绿
- [x] 5.3 `server/test/rule/game-over.lua`：主公杀忠臣 ⇒ 手牌与装备区的牌都进弃牌（装备区为空时行为不变）；验证：`--test rule.game-over` 全绿
- [x] 5.4 `server/test/core/effect/play.lua` 与 `ask-use-card.lua`：无目标使用的三条（见 1.1~1.4）与数据袋两条（见 2.1）；验证：`--test core.effect.play`、`--test core.effect.ask-use-card` 全绿
- [x] 5.5 `server/test/core/zone.lua` 与 `game.lua`：槽位区与槽位声明的用例（见 2.5 / 2.6）；验证：`--test core.zone`、`--test core.game`、`--test core.player` 全绿
- [x] 5.6 全量回归：`server/bin/moe-kill.exe --test` 0 失败（基线 495，本变更新增若干条）

## 6. 文档

- [x] 6.1 `references/architecture.md` 第 12 节：`canUse` 行补无目标判据、机制表补 `CardDef:noTarget` / `value` / `getValue` 与 `Attributes:addModifier` / `Card:bindZoneGC`（挂在牌上、离开区即撤销）；新增一行写**槽位区与它的槽位声明**（`game:setSlots` / `SlotZone.slots` / `getSlot` / `putInto` 的旧牌去向）；`AskUseCard` 行补「无目标牌的选项不带 targets」；距离与范围的**修正归属**（属性承担、`desk:getDistance` 只给座位距离、修正由内容侧求值函数加上）写进相关口径；验证：与代码一致
- [x] 6.2 `references/progress.md`：§1 记本批（属性「攻击范围」**保留**、修正由 `equip` 加、随牌离开区自动撤；几个新口子：`noTarget` / 数据袋 / 牌上的 `zoneGCHost` / `addModifier` / `SlotZone` / `setSlots`；模板文件挪进 `@基础/卡牌/`）、§2 候选表把「装备与距离修正」拆成「已做（武器 + 坐骑 + 槽位）」与「待做（防具 / 装备技能 / 无懈可击）」、验收基线更新；验证：读一遍无自相矛盾
- [x] 6.3 `sanguosha-rules` 技能：§5 改成「修正已接（内容侧求值函数）」、§9.10 补装备与借刀杀人的口径、§10 补两条待确认（借刀杀人的「范围内没有别人能否使用」、牌表的「青紅剑」）；验证：与实现一致
- [x] 6.4 问题面板 information 及以上清到 0（工作区级检查；不刷新就先跑 `lua.startServer`）

## 7. 收尾

- [x] 7.1 `openspec validate add-equipment --strict` 通过
- [x] 7.2 `tasks.md` 全部勾选后归档：`openspec archive add-equipment --yes`
