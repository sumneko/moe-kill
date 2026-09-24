# AGENTS.md — 项目入口（AI 助手必读）

本文件是本仓库 AI 助手的统一入口（厂商中立，任何 AI 客户端均可读取）：新会话请先阅读本文件，再按 OpenSpec 工作流开展需求规划与实现。

本项目的规格与技能以通用格式落盘，不依赖任何特定客户端：规格位于 `openspec/`，技能位于 `.agents/skills/`（通用 Agent Skills 格式）。

## 项目简介

- 名称：`moe-kill`（三国杀，身份场）
- 状态：基础设施搭建阶段（技术栈已定；具体规则口径待确认，见 `sanguosha-rules` 技能）
- 技术栈：后端单进程 Lua 5.5（运行时 `actboy168/bee.lua`，构建 luamake，调试 `actboy168.lua-debug`）；前端 TypeScript/Web，暂不实现
- 架构：前后端通过 JSON-RPC 通讯，协议为通用规范（一个后端可对接多种前端）；**所有游戏逻辑在后端**，前端只播放表现、采集输入；重连走专门方法全量同步状态
- 验收硬约束：无前端时也能通过导出接口跑完整对局测试
- 参考基准：基础设施与代码风格照搬 `LuaLS/lua-language-server` 的 `4.0.0` 分支；工具库来自 `sumneko/utility`
- 文档与工件语言：简体中文（见 `openspec/config.yaml` 的 `context` 字段）

## 目录结构

| 路径 | 说明 |
| ---- | ---- |
| `openspec/specs/` | 探索期写下的规格快照（**已冻结，不随实现更新**；见「工作流」） |
| `openspec/changes/` | 进行中的变更（`proposal` / `design` / `tasks`；探索期不写 specs） |
| `openspec/changes/archive/` | 已归档变更（保留历史） |
| `openspec/config.yaml` | OpenSpec 项目配置（语言、工件规则、操作指引） |
| `.agents/skills/openspec-*/` | 厂商中立技能（通用 Agent Skills 格式，任何客户端可加载；由 OpenSpec 生成，勿手改） |
| `.agents/skills/moe-kill-dev/` | **项目技能：工程约定**（架构、协议分层、代码风格、构建与调试），开发前先读；接手进度看它的 `references/progress.md` |
| `.agents/skills/sanguosha-rules/` | **项目技能：三国杀规则口径**（身份场、阶段、结算时序、时机系统） |
| `.agents/skills/powershell-safe-invocation/`、`.agents/sync-manifest.json` | 来自通用能力库，见「通用能力」章节 |
| `.github/` | GitHub 平台目录（当前为空，预留 CI 工作流 / issue 模板等） |

## 通用能力

本项目引入了来自通用能力库 [sumneko/skill](https://github.com/sumneko/skill) 的跨项目通用技能，来源仓库与版本记录见 `.agents/sync-manifest.json`。

- **不要直接修改** `.agents/skills/` 下由该仓库同步来的技能。需要改进时先把改动回传到源仓库，再从源仓库重新同步；否则项目副本会与真相源分叉，之后的同步会产生冲突。
- 项目专属的定制（项目路径、团队约定）应写在项目自己的文件里，不要混进同步来的技能。
- 项目自有技能（`moe-kill-dev`、`sanguosha-rules`）不登记进 `sync-manifest.json`，也不回传到通用能力库。

## 工作流（OpenSpec / OPSX）

先规划、后实现。遵循"规划边界"：除非用户明确进入实施阶段，否则只创建规划工件，不直接改业务代码。

**探索期的用法：只留决策记录，不写规格**（用户 2026-09-21 定）。理由：此时设计会反复推翻（效果模型三天里换了三轮），而规格（requirements / scenarios）是**最贵、最不抗变**的一层 —— 每次都要人工对账，产出却是对刚写完的代码的复述。**可执行契约由用例承担**（`server/bin/moe-kill.exe --test`）。

- 变更工件 = **`proposal.md` + `design.md` + `tasks.md`**；**不写 `specs/`**：建完变更后在它的 `.openspec.yaml` 里加一行 `skip_specs: true`。实测（2026-09-21）：加了它以后 `openspec status` 把 `specs` 记成 `skipped`、`tasks` 照常可写，`openspec validate --strict` 接受零增量（只给一条 INFO）。
- **`openspec/specs/` 已冻结**：那是探索期留下的历史快照，**不再随实现更新**，也不再当真相源（要读现状看代码 + 用例 + 技能的 `references/`）。等规则口径稳定（武将 / 牌表 / 流程定稿）后再做**一次性回顾性对齐**，而不是每个功能点都追。
- **只有真要长期稳定的对外契约才写规格**：JSON-RPC 协议、时机 / 事件清单、包与装载器的对外约定 —— 这些有外部消费者、改动昂贵。写这类变更时**不设** `skip_specs`，照常写 `specs/` 增量。

| 场景 | 通用调用（技能名，任意客户端） |
| ---- | ---- |
| 提出新变更（proposal / design / tasks；探索期无 specs） | `/openspec-propose` |
| 探索与讨论（无副作用的思考伙伴） | `/openspec-explore` |
| 按 `tasks.md` 实施变更 | `/openspec-apply-change` |
| 更新已有变更的工件 | `/openspec-update-change` |
| （冻结期不用）把 spec 增量同步进 `openspec/specs/` | `/openspec-sync-specs` |
| 归档已完成变更 | `/openspec-archive-change` |

- 技能文件位于 `.agents/skills/openspec-*/SKILL.md`，为通用 Agent Skills 格式；客户端可自动激活，不支持斜杠调用时直接提及技能名即可。
- 终端中等价操作：`openspec new change`、`openspec status`、`openspec instructions`、`openspec validate`、`openspec archive`。
- 本仓库不含任何厂商专属目录；`openspec update` 目前只维护 `agents` 一个目标。

**接入新客户端**：运行 `openspec init --tools <tool-id> --no-copilot-cloud` 可添加指定客户端集成（如 `github-copilot`、`claude`、`cursor`、`codex`；工具 ID 见 `openspec init --help`）。例如为 GitHub Copilot 生成 `/opsx-propose` 等斜杠命令：`openspec init --tools github-copilot`；`.agents/skills/` 与 `openspec/` 规格数据对所有客户端始终可用，无需重复配置。

## 项目约定

- **伪代码 = 展示思路，不是待 review 的代码**（用户 2026-09-24 定）：用户贴一段草稿说「看看这个思路 / 能不能去掉那个函数」时，要做的第一件事是**读懂并分析他的设计思路** —— 这个形状解决了什么问题、与现有机制怎么接、要补哪些能力；**不是**逐行 review 语法与命名、**不是**跑测试证明它跑不通、**不是**解释「为什么这段不能运行」。草稿跑不通是正常状态；命名 / 用词 / 口径这些该由我按规范改好，再把它实现出来。有疑问先问「你这里想表达的是不是 X」，别把草稿当成品挑毛病。

- **不许删除未经讨论的代码**（用户 2026-09-20 定）：**删代码前必须先问**，尤其是**上一轮对话之后用户新写 / 新改的**代码。不许因为「看起来多余」「本次改动用不到」「顺手清理」就删；判断标准是**这段代码有没有被讨论过**，而不是它现在有没有被引用。要删就单独提出来（说明理由与影响面）、等用户确认再动；**列方案 / 选项时也不许把「顺带删除」塞进去当默认** —— 用户选了一个方案 ≠ 同意里面我加的每一项。

- **开发节奏：自底向上、按功能点推进**（用户 2026-09-19 定）：一次只做一个**具体功能点**（如「杀」），把它相关的功能**做完**（需要的内核能力按**最小可用形状**就地补），再进下一个功能点，最后才在上层（规则流程 / 会话 / 协议）串起来。**不预先设计整套对象模型或完整框架**：细节（出牌限制、距离判定、标记语义…）留到实现到那个功能时再定 —— 提前拍的口径多半会返工。因此早期“随口确认”的接口细节**不构成约束**，实现到相关功能时重新定即可。

- 变更目录名使用小写 kebab-case（如 `add-battle-loop`，允许数字前缀如 `100-xxx`）。
- 工件正文使用简体中文；OpenSpec 结构性标题与 `SHALL` / `MUST` 关键词保持英文。
- 归档前先运行 `openspec validate <name>` 校验；实现完成后勾选 `tasks.md` 全部条目，再执行 `openspec archive <name> --yes`。
- `.agents/skills/` 下由 OpenSpec 生成的文件不要手动修改；升级 CLI 后运行 `openspec update` 刷新。
- 重大需求/架构调整先建变更提案，经确认后再写代码。
- **探索期不写规格**（用户 2026-09-21 定）：变更只做**决策记录**（`proposal` / `design` / `tasks`，并在 `.openspec.yaml` 里设 `skip_specs: true`），`openspec/specs/` **冻结、不维护**；理由与细节见「工作流」，契约以用例为准。

- **可叠加的操作必须返回撤销函数**：凡“添加/附加”类操作（加属性修正、加标记、订阅事件…）一律返回一个 **disposer 函数**，调用它即精确撤销这次添加；不要只提供“移除”，也不要让调用方自己回滚。
- **模块不得持模块级可变状态**（热重载要求）：`local` 只放不可变常量与纯函数；必须跨重载存活的状态挂到**跨重载仍是同一份的载体**上 —— 属于某一局的挂局实例（`game` 上的字段，如号源 `game:nextId()`），内核级、跨局的才挂门面表 `moe`（在 `moe-kill.lua` 里建立、不参与重载），后者写成「有则复用」（如 `moe._x = moe._x or 初值`），并用 **`_` 前缀**标明「内核内部状态、不是对外接口」。**不要挂类表**：类表上的字段会被 `Extends` 复制给子类、并在重载时被 `reset` 清掉。重载边界是**加载方式**（`include` 可重载 / `require` 不参与），详见 `moe-kill-dev` 技能的 `references/architecture.md` 第 8 节。
- **命名：代码用英文，中文只留给难翻译的内容名**（用户 2026-09-19 定）：运行时虽然允许中文标识符（构建期补丁），但**字段名 / 局部变量 / 函数名 / 参数名一律英文**；中文只用于技能名、卡牌名、身份名这类内容词，以及作为**数据取值 / 配置键**出现的名字（`'杀'`、`'主公'`、`'游戏-开始'`、`rule:setValue('体力上限', 4)`、`attrs:get('体力')`）；包名与包内文件名也用中文。**回调参数按载荷的具体类型起名，不要叫 `ctx`**（用户 2026-09-23 定）：有类实例就用它的小驼峰类名（`useCard` / `cardEffect` / `askCard` / `damage` / `heal` / `dying` / `draw` / `judge` / `phase` / `player` / `ask` / `effect` / `result`），无实例的载荷用描述性短名（`target` / `check` / `turn` / `event` / `payload`）。详见 `moe-kill-dev` 的 `references/code-style.md` 第 8 节。
- **读取接口：不传参数的别写成 `getXxx()`**（用户 2026-09-23 定）：不需要参数的读取**尽量直接用字段**（`card.suit` / `desk.players`），算出来的也用 **`__getter`** 伪装成同一种读法（`player.acting`）；`getXxx()` 只留给**要传参数**的读取（`player:getAttr('体力')`、`game:getZone('抽牌')`）。存量里无参的 `getXxx()` 不主动清理。详见 `moe-kill-dev` 的 `references/code-style.md` 第 11 节。
- **禁止用 `error` 做跳出**（用户 2026-09-20 定）：`error` 只有一个语义 = **报错**。不要借 `error` 做控制流（「取消这次生效」「提前结束这次结算」…）—— 错误处理器与测试的错误日志计数都会把它当故障。需要中断执行体时用 `task:reject(原因)` + 让出，由 `Task` 收尾把执行体收掉；表达「因为什么结束」也用 `reject`。详见 `moe-kill-dev` 的 `references/code-style.md` 第 10 节。
- **不要过度防御**（用户 2026-09-19 定）：**正常流程下不会出现的情况不写防御**。调用约定与类型契约已经保证的东西（规则实例的 `rule.room`、自己模块内互相调用的参数、自己创建的对象）直接用 —— 我们相信拿到的是我们自己定义的对象，不去管「万一被人篡改」；只有**运行期真的会缺**的（清单里没有内容包 ⇒ 没牌表、人数不在身份配置表里）与**外部输入**（协议 / 前端数据、别人放的包与文件）才检查。详见 `moe-kill-dev` 的 `references/code-style.md` 第 9 节。
- **注释尽量不写；接口留一行中文说明**（用户 2026-09-19 定）：代码里**不写注释**（说不清就先改名 / 拆函数）；但**入口**（函数 / 方法 / 字段 / 模块门面）保留**一行极短的中文说明**，几个字即可（如「获取标题」），贴在类型注解的 `#` 后。**要保留的注释单独占一行、放在它说明的代码之前，不写行尾注释**（用户 2026-09-23 定）。另一处例外：`package/` 里**卡牌 / 技能**这类内容定义文件，**顶部写它的官方描述**（见 `sanguosha-rules` §9.3）。**存量注释待下次顺手清**。详见 `moe-kill-dev` 的 `references/code-style.md` 第 3 节。
- Git 提交信息：**AI 助手编写或修改的代码，提交信息开头加 `【AI】` 前缀**（如 `【AI】feat(core): 对象与牌堆骨架`）；人工提交不加。正文用简体中文 + conventional commits。
- **改完 Lua 代码必须检查问题面板，把 information 及以上等级的问题清到 0**（hint 级不管）；改不动的来问用户，不要留着。一次性改动大量文件后语言服务器可能延迟甚至卡住，用 `lua.startServer` 重启后再检查。
- **平时只改 Lua，跑测试不需要构建**（用户 2026-09-20 定）：`server/bin/moe-kill.exe` 只是个壳，脚本从源码树加载 ⇒ 直接 `server/bin/moe-kill.exe --test` 就行；**只有**动了 C/C++ 或构建/补丁链（`make.lua`、`make/lua-patch/**`、`3rd/bee.lua`）才需要 `luamake -notest`。

## 环境注意（Windows / PowerShell）

- 执行策略已设为 `RemoteSigned`，`npm` / `openspec` 的 `.ps1` shim **可直接使用**（不再需要 `.cmd` 变通）。
- 用 PowerShell 写文件必须显式指定编码（如 `Set-Content -Encoding UTF8`），否则把 UTF-8 源码写成 GBK/UTF-16 会乱码。
- 前置依赖：Node.js ≥ 20.19.0（OpenSpec CLI 要求）。

## 常用命令速查

```bash
openspec list                     # 查看进行中的变更
openspec list --specs             # 查看已有规格
openspec show <name>              # 查看变更/规格详情
openspec status --change <name>   # 查看工件完成度
openspec validate --all           # 全量校验变更与规格
openspec archive <name> --yes     # 归档已完成的变更
openspec update                   # 升级 CLI 后刷新所有客户端集成文件
```
