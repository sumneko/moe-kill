# Proposal

## Why

武将牌面已经落地（`HeroDef`），但 `: skills { '奸雄', '护驾' }` 里的**技能名至今没有任何落点** —— 技能自身的定义（名字 / 发动方式 / 标签）没有对象可挂。这是技能系统的第一层：先把「技能是什么」定义出来，后面的挂载、生效、主公技过滤才有东西可引用。

同时借这批把一条口径钉死（底本 `Chapter1/Section2` + `Chapter2/Section5`）：**「是不是锁定技」与「要不要强制发动」无关**，锁定技只是标签（目前唯一作用是「不被克制」）；强制与否看描述里有没有「可」字。⇒ **发动方式与标签必须是两个正交维度**。

## What Changes

- 内核新增 **`SkillDef`**（`server/core/skill.lua`），形状照 `HeroDef`：`name` / `package` / `fullName` / `source` + **发动方式 `kind`** + **标签集合**。
  - **发动方式**：`'主动' | '被动' | '自动'`，**不写就是「主动」**（用户口径：这个值**只影响「按钮能不能点」**，与结算是强制还是可选无关）。
  - **标签**：`: tags { '锁定技', '主公技' }`（可多次调、取并集）+ 读法 `skill:hasTag(名字)` / `skill:getTags()`；**「觉醒技」视为附带锁定技与限定技**（底本 Chapter2/Section5 明说）。
- **环境函数 `Skill '奸雄'`** + 查询 `game:declareSkill` / `getSkill`（按包存、裸名解析三条、同包重名报错、随 `resetContent` 清）—— 与牌 / 状态 / 武将**同形**；**技能名与牌名、武将名是三个独立命名空间**（同包同名不冲突）。
- **技能定义不存描述文本**：官方描述照卡牌那样写在文件顶部 `--`（`code-style.md` §3 例外二）。

## Capabilities

无。本变更属探索期的**决策记录**，不写规格增量（`.openspec.yaml` 设 `skip_specs: true`）。可执行契约由用例承担，见 `AGENTS.md`「工作流」。

## Impact

- 内核：新增 `server/core/skill.lua`；`game.lua` 加 `skills` / `skillPackages` 与两个入口；`core/init.lua` 装载；加载器两处注入 `Skill` + `env-meta.lua` 声明。
- 内容侧：**本批一行不动**（标准包的武将技能等生效机制那批再写 —— 那时的技能文本要另找来源校对）。
- 测试：新增 `server/test/core/skill.lua`（并在 `server/test/core/init.lua` 注册）。
- 文档：`references/architecture.md`（内容定义入口表）、`progress.md`、`sanguosha-rules`（新增技能定义一节）。
