# Tasks

## 1. 内核：有序牌区绑定随机源（`server/core/ordered-zone.lua`）

- [x] 1.1 `create(random?)` / `__init(random)` 记住绑定的随机源；`shuffle(random?)` 省略时用绑定的那个，两者都没有时报错；顺手去掉 `Type(random)` 的运行时判定；验证：`--test core.zone`、`--test core.move`、`--test core.scenario` 全绿
- [x] 1.2 基类 `Core.Zone:shuffle` 的参数改成可选（它本来就只会直接报「不具备有序能力」）；验证：问题面板不再报 `missing-parameter`

## 2. 内核：场地（`server/core/room.lua`）

- [x] 2.1 `Core.Room`：`create { desk, random }`、`getDesk()`、`getRandom()`；验证：`--test core.room` 能跑出用例
- [x] 2.2 按名字建 / 取牌区：`createZone(名字, 有序?)`（同名与非空名校验）、`getZone(名字)`、`getZones()`（按创建顺序）；验证：三个用例通过
- [x] 2.3 建牌：`createCard(名字)`（牌名进不透明标签、每次新实例、名字校验）；验证：该用例通过
- [x] 2.4 有序牌区绑定场地的随机源 ⇒ `shuffle()` 不用传参，同种子同内容洗出同顺序；验证：该用例通过
- [x] 2.5 挂到 `moe.core.room`，`Core` 类补 `room` 字段；验证：门面可用

## 3. 门面与上下文

- [x] 3.1 `server/rule/init.lua` 去掉 `createCard` / `createZone` / `createOrderedZone`（保留 `createAttributeSystem`：属性系统是加载期内容）；验证：`--test rule` 的探针用例改成只验属性系统后全绿
- [x] 3.2 `server/rule/env-meta.lua` 给 `Rule.EventCtx.游戏开始` 加 `---@field room Core.Room`；验证：包代码里 `ctx.room` 有类型（问题面板 0）

## 4. 规则包

- [x] 4.1 `package/@基础/牌堆.lua`：按用户给的形状改 —— `ctx.room:createZone('抽牌堆', true)` → 逐张 `ctx.room:createCard(名字)` 放入 → `deck:shuffle()`；不再写规则数值；验证：`--test rule.base` 全绿（牌堆从场地取）
- [x] 4.2 其余包不动（体力设置与身份分配继续用 `ctx.desk` / `ctx.random`）；验证：`--test rule.identity`、`--test rule.setup` 全绿

## 5. 测试

- [x] 5.1 新增 `server/test/core/room.lua`（持桌子与随机源 / 按名字建取牌区与同名报错 / 有序与无序 / 建牌 / 洗牌省略随机源 / 没绑定时报错），并在 `server/test.lua` 注册；验证：`--test core.room` 全绿
- [x] 5.2 `server/test/rule/support.lua` 建场地并把 `room` 放进 ctx，`Test.RuleSupport` 补 `room` 字段；验证：规则侧套件全绿
- [x] 5.3 `server/test/rule/{base,setup}.lua` 的牌堆断言改从 `game.room:getZone('抽牌堆')` 取；「没有牌表」用例断言场地上没有抽牌堆；验证：这两个套件全绿

## 6. 文档

- [x] 6.1 `architecture.md`：分层图的 `[core]` 补场地、第 9 节书写环境把工厂面收窄成「只有 `createAttributeSystem`」（牌 / 牌区在场地上）、第 10 节的时机上下文补 `room`
- [x] 6.2 `moe-kill-dev/SKILL.md` 目录表：`server/core/` 补场地；`server/rule/` 行的工厂描述同步
- [x] 6.3 `sanguosha-rules` 第 9.1 节：示例改成 `ctx.room:createZone('抽牌堆', true)` + `ctx.room:createCard(名字)`，并写明「公共牌区挂场地、玩家牌区挂玩家」的分工
- [x] 6.4 `infrastructure.md` 命令速查补 `--test core.room`

## 7. 验收

- [x] 7.1 `luamake -notest` 通过；全量 `--test` 全绿退出码 0；问题面板 information 及以上为 0
- [x] 7.2 确认内核里没有游戏流程：`server/core/` 不出现具体牌区名（`抽牌堆` 只出现在规则包与测试里）、不出现回合 / 身份 / 胜负等概念
- [x] 7.3 `openspec validate --all --strict` 全通过
