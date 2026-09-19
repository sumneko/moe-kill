# Tasks

## 1. 内核：桌子（`server/core/desk.lua`）

- [x] 1.1 `Core.Desk`：`create(座位数)`、`sit(座位号, 玩家)`、`getPlayer(座位号)`、`getPlayers()`、`getIndex(玩家)`；座位数量不设上限；验证：`--test core.desk` 能跑出用例
- [x] 1.2 行动顺序：`getNext(player)` 按**座位号递增**推进，跳过空座位与 `isActing() == false` 的玩家；验证：顺序、跳空位、跳不参与行动者三个用例通过
- [x] 1.3 `getDistance(from, to)`：沿两个方向取较小值、最小 1、每次当场求值；验证：三个用例通过
- [x] 1.4 挂在 `moe.core.desk`；验证：门面可用

## 2. 内核：玩家（`server/core/player.lua`）

- [x] 2.1 `Core.Player`：持属性实例、`getAttributes()`；验证：`--test core.player` 能跑出用例
- [x] 2.2 牌区：`addZone(名字) -> disposer`（撤销即移除）、`getZones()`；验证：可增删的用例通过
- [x] 2.3 标签：`setTag/getTag/removeTag`（原样存取，不解释）；验证：该用例通过
- [x] 2.4 参与行动标记：`setActing(bool)` / `isActing()`；验证：该用例通过（与桌子的行动顺序联动）
- [x] 2.5 挂在 `moe.core.player`；验证：门面可用

## 3. 门面（`server/rule/init.lua`）

- [x] 3.1 规则数值：`rule:setValue(名字, 值)` / `rule:setValues { ... }` / `rule:getValue(名字)` / `rule:getValues()`；全局一张表、后者覆盖前者、随清空重载清空、未设置读 nil；验证：三个用例通过
- [x] 3.2 注入面加入内核门面 `core`（标准库白名单不变，仍然不给 `require` / `io` / `os`）；验证：规则集里能调 `core.*` 的用例通过 + 既有"拿不到 require"用例继续通过
- [x] 3.3 时机名统一改成 `分类-动作` 风格（`'游戏开始'` → `'游戏-开始'`）：改既有测试与文档里的名字，并确认注册/触发/覆盖语义不变；验证：`--test rule.event` 全绿
- [x] 3.4 事件参数 meta：新增 `server/rule/env-meta.lua`（`---@meta`，不参与运行），声明注入的全局 `rule` / `core`、`Rule.EventCtx.<事件名>` 与 `rule:on` / `rule:fire` 的重载签名；验证：问题面板不报 `duplicate-doc-field`，且规则集里 `ctx.xxx` 能按事件名收窄出类型（拿一个探针文件确认）

## 4. 规则包

- [x] 4.1 `package/基础/配置.lua`：用 `rule:setValues` 落默认值（体力上限 4、主公体力上限加成 1 等）；验证：读取到默认值的用例通过
- [x] 4.2 `package/基础/体力.lua`：定义 `体力` / `体力上限` 两个属性；验证：属性可用的用例通过
- [x] 4.3 `package/基础/牌堆.lua`：注册「游戏-开始」按牌表建牌实例 → 放入有序牌区 → 用注入的随机源洗牌；牌表缺失时报错（不写牌堆）；验证：三个用例通过
- [x] 4.4 `package/身份场/配置.lua`：4~8 人的身份配置（主公 1 / 忠臣 / 反贼 / 内奸）放进规则数值；验证：查询与覆盖的用例通过
- [x] 4.5 `package/身份场/开局.lua`：注册「游戏-开始」分配身份（随机、可用固定 seed 复现）→ 写进玩家标签 → 主公坐 1 号位 → 主公体力上限 +1（走改上限接口）；验证：三个用例通过
- [x] 4.6 `package/标准/牌表.lua`：标准版牌表（每种牌的张数）写进规则数值；花色点数留到需要判定 / 拼点时再加（按需最小形状）；验证：总张数与构成用例通过
- [ ] 4.7 **牌表逐条核对**：张数按标准版列一遍，交给用户过目（数据错了只改这一处）；验证：核对记录写进本任务说明。**核对记录（待用户过目）**：基本牌 53（杀 30 / 闪 15 / 桃 8）；锦囊 31（过河拆桥 6 / 顺手牵羊 5 / 无中生有 4 / 无懈可击 4 / 决斗 3 / 南蛮入侵 3 / 五谷丰登 2 / 借刀杀人 2 / 万箭齐发 1 / 桃园结义 1）；装备 18（武器 9：诸葛连弩 2 / 青釭剑 1 / 雌雄双股剑 1 / 青龙偃月刀 1 / 丈八蛇矛 1 / 贯石斧 1 / 方天画戟 1 / 麒麟弓 1；防具 3：八卦阵 2 / 仁王盾 1；+1 马 3：绝影 1 / 的卢 1 / 爪黄飞电 1；−1 马 3：赤兔 1 / 大宛 1 / 紫骍 1）；**合计 102 张**。列成 `rule:setValue('牌表', { { 名 = '杀', 张数 = 30 }, ... })`

## 5. 装配与测试

- [x] 5.1 `server/test/rule/setup.lua`：8 人完整开局（建属性系统 / Desk / 玩家 / 牌区 → `rule:fire('游戏-开始', ctx)`）断言：每人有身份、体力 = 上限、主公上限比别人多 1、首行动者是主公、牌堆张数等于牌表总张数；验证：该用例通过
- [x] 5.2 复现性：同一 seed 两次开局得到相同的身份分配与牌堆顺序；验证：该用例通过
- [x] 5.3 套件挂载与回归：`--test core.desk`、`--test core.player`、`--test rule.base`、`--test rule.identity`、`--test rule.setup` 全绿，且既有套件不回归（含 `--test rule.event` 改名后的回归）；验证：全绿

## 6. 文档

- [x] 6.0 `architecture.md` 第 10 节补「时机命名风格（`分类-动作`）」与「事件参数 meta（`server/rule/event-meta.lua`，事件名去连字符即类型名）」；`sanguosha-rules` §8 同步
- [x] 6.1 `architecture.md`：第 9 节补「执行环境注入面（`rule` + `core`）」，第 9 节的覆盖 / 并存对照表补「规则数值：后者覆盖前者」一行；分层图补 `package/基础`、`package/身份场`、`package/标准`
- [x] 6.2 `moe-kill-dev/SKILL.md` 目录表：`server/core/` 补桌子与玩家；`package/` 行补三个包的名字
- [x] 6.3 `sanguosha-rules`：§1 身份配置与 §5 距离的口径对齐实现（主公 +1 走改上限、身份写标签、距离由桌子求值）；规则集侧写法补 `rule:setValue` 与 `core.*` 的用法示例
- [x] 6.4 `infrastructure.md`：命令速查补新套件名

## 7. 验收

- [x] 7.1 `luamake -notest` 通过；全量 `--test` 全绿退出码 0；问题面板 information 及以上为 0
- [x] 7.2 确认内核里**没有任何游戏流程**（不出现身份 / 回合 / 摸牌 / 胜负等概念，也不出现牌名与属性名）
- [x] 7.3 确认距离是**求值**而非缓存字段（距离只由座位号与座位总数决定，实现里没有存下来的 distance 字段）
