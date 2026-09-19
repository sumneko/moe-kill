# Tasks

**交付方式（用户 2026-09-19 定）**：一个功能点做完就与用户对齐一次。建议轮次：① 改名 core + 照搬 attribute → ② `core-random` → ③ `core-zones` → ④ `core-attributes` → ⑤ `core-objects` → ⑥ 文档与验收。

## 1. 改名、门面与目录约定

- [x] 1.1 `server/engine/` → `server/core/`（`git mv`），`---@class Engine` → `---@class Core`
- [x] 1.2 `server/moe-kill.lua`：`moe.engine` → `moe.core`，类型注解同步
- [x] 1.3 项目根 `game/` 与 `make/bootstrap.lua` 的 `game/?.lua` 路径**本批不建**（用户定：后续测到规则集时再落地）；约定写进设计与此处即可
- [x] 1.4 目录改名（用户 2026-09-19 定）：`script/` → `server/`（与将来的 `client/` 对称）、`script/server/` → `server/session/`、`test/server/` → `test/session/`；同步 `make/bootstrap.lua`、`.luarc.json`、`.vscode/launch.json`、技能文档
- [x] 1.5 入口与产物归入 `server/`（用户 2026-09-19 定）：`main.lua` / `test.lua` / `test/` / `bin/` 全部移入；`make.lua` 的 copy 目标改 `server/bin/`、引导脚本上溯两级求根、`ROOT_PATH` 变为 `<根>/server`；`.gitignore` / `.luarc.json` / `.vscode` / 文档同步

## 2. 照搬属性库

- [x] 2.1 从 `sumneko/utility` 取 `attribute.lua` 放 `server/tools/attribute.lua`（**原样不改**）
- [x] 2.2 `moe-kill-dev` 技能的 `tools/` 清单登记该文件来源（LuaLS 4.0.0 无此文件，来自通用能力库上游）

## 3. 随机源（`core-random`）

- [x] 3.1 `server/core/random.lua`：按 seed 构造的可实例化伪随机源（取范围整数 / 取元素 / 打乱序列），不触碰全局 `math.random` 状态
- [x] 3.2 相同 seed 产生相同序列；两个实例互不干扰

## 4. 牌区（`core-zones`）

- [x] 4.1 `server/core/card.lua`：牌实例（唯一标识 + 标签，不含任何牌定义）
- [x] 4.2 `server/core/zone.lua`：牌区基类（放入 / 取出 / 查看 / 计数 / 列举 / 清空；空区取牌等非法操作明确失败）
- [x] 4.3 区域参数：设置 / 读取 / 修改不透明参数，内核不解释含义
- [x] 4.4a 牌区自身的禁用 / 启用（禁用后放入 / 取出 / 清空 / 洗牌明确失败，读取与参数不受限，可恢复）
- [ ] 4.4b 玩家侧牌区的动态添加 / 删除与“默认列举不含被禁用牌区”（随轮次⑤ 的 `Player` 集合一起落地）
- [x] 4.5 有序能力用**子类**表达（基类 `Zone` 不含取顶/洗牌，子类如 `OrderedZone` 提供按顺序取顶 + 消费注入随机源洗牌）；未具备该能力的牌区被要求取顶/洗牌时明确失败（具体子类实例由 game 层创建，内核不预设）

## 5. 属性（`core-attributes`）

- [x] 5.1 `server/core/attribute.lua`：接入照搬的库 —— `Core.AttributeSystem`（`create` / `define(name, spec)` / `createInstance` / `updateEvents`），由调用方声明属性名与上下限后创建实例（`spec = { simple?, min?, max? }`，默认简易属性）
- [x] 5.2 实例按名读写、上下限生效；增减操作同样受约束（下限只在**写入时**钳制：从未写入过的属性读数为 0）
- [x] 5.3 实例间相互独立
- [x] 5.4 变更可观察：订阅某属性变化（`attrs:event(name, cb)` + `system:updateEvents()` 分发）后修改会收到通知；实例创建后新增定义明确失败
- [ ] 5.5（本轮不暴露，待有消费者再定）公式 / 复杂属性（`setFormula` / `setBaseSymbol` / 字符串型 `min`-`max` 引用）与“查询自上次检查以来的变化”（库的 `getTouched`，返回的是变化**前**的取值）

## 6. 对象模型（`core-objects`）

- [ ] 6.1 `server/core/player.lua`：持有属性实例、参与行动标记、不透明标签、一组可增删禁用的牌区
- [ ] 6.2 `server/core/table.lua`：入座、座位序号、按行动顺序遍历（跳过不参与行动的玩家）、相邻座位
- [ ] 6.3 座位距离求值：沿两侧取较小值、最小为 1、修正参与求值且修正后仍最小为 1（求值非缓存）
- [ ] 6.4 `server/core/room.lua`：加入玩家、持有桌面与牌区集合、查询当前局面；**`room:setPlayerAttributeSystem(system)` 设置玩家属性系统**（创建玩家时用该系统造属性实例）；不设人数上限；两个房间互不影响

## 7. 测试（`server/suites/core/`）

- [x] 7.1 新增 `server/suites/core/init.lua` 并挂到测试入口的套件列表
- [x] 7.2 覆盖随机源：同种子同序列、不同种子不同序列、实例间互不干扰
- [ ] 7.3 覆盖牌区：放入 / 取出 / 计数 / 列举 / 清空、空区取牌明确失败、参数设置与修改、动态增删与禁用启用、相同随机源洗出相同顺序、按顺序取牌、无序牌区取顶失败、牌实例标识可区分
- [ ] 7.4 覆盖属性：自定义属性名、上下限约束（含增减越界）、实例独立、变更可观察、实例创建后新增定义失败
- [ ] 7.5 覆盖对象：属性承载数值、参与标记与标签、牌区增删禁用、行动顺序跳过不参与者、座位距离与修正下限、两个房间互不影响
- [ ] 7.6 覆盖"调用方组合接口搭场景"：用手动取牌 + 放入牌区的方式发出一手牌并断言计数 —— 证明内核不提供"发牌"也能搭出场景，且内核中不存在预设区域名/属性名

## 8. 验收与文档

- [ ] 8.1 `luamake -notest` 编译通过；`server/bin/moe-kill.exe --test` 全绿、退出码 0；问题面板 information 及以上归零
- [ ] 8.2 `architecture.md`：分层图补 `core`（内核，与规则无关）与 `game`（规则集，调用内核）；「无头可测」补"内核接口可直接调用、调用方自行组合场景"
- [ ] 8.3 `sanguosha-rules` 技能：把「决策点统一走请求输入 → 挂起 → 恢复」的主语改为 **Room 内部**（后续批次实现），并注明**内核不含任何流程且不预设区域名/属性名**
- [ ] 8.4 `setup-backend-infra/design.md` 里过期的"`script/engine/` 未来放纯规则引擎"一句修正为 `server/core` + `game/` 的新划分（含 `script/` → `server/` 改名）
- [ ] 8.5 清理 `tmp/`、`log/` 中的临时产物
