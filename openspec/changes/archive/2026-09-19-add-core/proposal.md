# Proposal

## Why

用户已确定实施顺序与分界线：**先做内核（core）并单元测试，规则集与 session 都排在后面**；并且明确要求「**目前的实现应该和游戏流程规则完全无关**」。

内核的定位因此是**通用对象与容器**：

- 内核**不认识**任何游戏概念：不存在"手牌区 / 装备区 / 判定区 / 体力"这种写死的名字。
  - **牌区**是通用容器：放入 / 取出 / 计数 / 列表 + **区域参数**（如可见性，可调接口改），并支持**动态添加 / 删除 / 禁用**。手牌区、装备区、判定区、抽牌堆、弃牌堆、处理区**都是它的实例**（牌堆与区域合并成同一套抽象）。
  - **属性**是通用数值：接入 `sumneko/utility` 的 `attribute` 库（定义 / 实例 / 上下限 / 公式 / 变更事件），**属性名与公式由调用方（将来的规则集）定义**，内核不预设。
- 规则类的数值与时序（起手牌数、身份配置、谁先手、阶段顺序、主公 +1 血）**全部不进内核**。
- **内核的每一项能力都要导出成可以直接调用的接口**；测试直接调接口，将来 session / Room 只是这些接口的调用者。
- 测试里的"发牌""开局"由**测试自己组合接口**完成（连续取牌 + 放入牌区即发牌），内核不提供这类高层动作。
- 内核命名统一为 **core**（原 `engine` 改名：`server/core/`、`moe.core`）。

## What Changes

- **改名**：`script/` → `server/`（与将来的 `client/` 对称）、`server/server/`（会话外壳）→ `server/session/`、`test/server/` → `test/session/`；`engine/` → `core/`；`moe.engine` → `moe.core`（门面 `moe.server` 不变）。
- **规则集目录（本批只记录约定，不创建）**：项目根 `game/`（与 `server/` 平级），按中文包组织（如 `game/基础规则/`、`game/卡牌包/标准/`）；目录本体、`package.path` 与加载方式**测试到那部分时再落地**，本批只把约定写进设计与技能文档，**不实现任何规则**。
- **牌区（统一容器）**：通用牌区 + 参数 + 动态增删禁用；抽牌堆多一项"按顺序取顶 + 洗牌（消费注入的随机源）"的能力；牌实例只承载唯一标识与标签，牌的定义属配置。
- **属性**：照搬 `sumneko/utility` 的 `attribute.lua` 到 `tools/`（照搬区），并在内核里接入为通用属性（玩家持有属性实例；属性名 / 公式 / 上下限由调用方定义）。
- **对象模型**：玩家（属性实例 + 参与标记 + 不透明标签 + 一组牌区）、桌子（座位、行动顺序、座位距离求值）、房间（装配根，持有桌面与牌区；不设人数上限）；房间之间互不影响。
- **随机源**：可实例化、可注入，不使用全局 `math.random` 状态。

**明确不做**：开局装配（身份 / 起手牌数 / 发牌 / 先手）、回合阶段推进、牌的效果与结算、技能、决策者接口（内核没有流程，没有消费者）、规则集内容、会话 / 协议 / 网络 / 前端、身份信息隔离。

## Capabilities

### New Capabilities

- `core-zones`: 通用牌区（统一容器 + 区域参数 + 动态增删禁用 + 抽牌堆的有序取牌与可复现洗牌 + 牌实例标识）
- `core-attributes`: 通用属性（属性定义与实例、上下限约束、属性名与公式由调用方定义、实例间独立）
- `core-objects`: 玩家 / 桌子 / 房间（属性实例、参与标记、标签、牌区集合、座位、行动顺序、座位距离、房间隔离）
- `core-random`: 可实例化、可注入的伪随机源（确定性与实例间互不干扰）

### Modified Capabilities

（无。`openspec/specs/` 现有 `headless-server` 与 `async-io`，本批不修改它们。）

## Impact

- **新增**：`server/core/`（内核）、`server/test/core/`（单元测试）、`server/tools/attribute.lua`（照搬）。
- **改名（本轮已完成）**：`script/` → `server/`；`server/session/`（原 `script/server/`）；`server/test/`（原 `test/`）；`server/engine/` → `server/core/`；`moe.engine` → `moe.core`；入口与产物入 `server/`（`server/main.lua`、`server/test.lua`、`server/bin/`、`server/log/`、`server/tmp/`）。
- **延后**：`game/` 目录本体、`make/bootstrap.lua` 里的 `game/?.lua` 路径、规则集加载方式 —— 等后续批次测到规则集时再落地（本批只写约定）。
- **文档**：`moe-kill-dev` 技能的分层图、目录职责表与 `tools/` 改动清单（新增照搬的 `attribute.lua`）；`setup-backend-infra/design.md` 里"`script/engine/` 未来放纯规则引擎"一句已过期，一并修正。
- **不改**：`server/session/`（Session 保留不动）、`server/async-io.lua`、协议层、前端。
- **后续顺序提醒**：规则集（开局装配 / 阶段流程 / 牌的效果 / 技能）与"内核与会话串起来"都在后面的批次；**卡牌开搞前先与用户预研**。
