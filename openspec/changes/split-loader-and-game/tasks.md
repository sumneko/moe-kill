# Tasks

## 1. 内核拆分

- [x] 1.1 搬迁：`server/core/rule/*` → `server/core/loader/*`（`vfs.lua` / `preparse.lua` / `env-meta.lua` 改类型名 `Moe.Rule.*` → `Moe.Loader.*`）；`server/core/room.lua` → `server/core/game.lua`
- [x] 1.2 `server/core/loader/init.lua`：只留装载逻辑（vfs 建树 → 试跑 → 校验 → `game:resetContent()` → 执行），入口 `moe.loader.install(game, { sources?, packages? })`（返回执行过的文件列表；不传参数时复用局上记的来源与清单）
- [x] 1.3 `server/core/game.lua`：`Moe.Game` 类 = 桌子 / 随机源 / 公共牌区 + 规则内容状态；提供 `create` / `resetContent` / `declareCard` / `getCard` / `setValue(s)` / `getValue(s)` / `on` / `fire` / `getAttributeSystem` / `createZone` / `getZone` / `getZones` / `createCard` / `getPackageMeta` / `getMetas`；`moe.game.create { desk, random, sources?, packages? }` 内部调装载器
- [x] 1.4 `server/core/init.lua`：挂 `moe.loader` / `moe.game`（去掉 `moe.rule` / `moe.room`）
- [x] 1.5 验证：`--test core` 全绿

## 2. 注入环境

- [x] 2.1 环境 = `game` + `Card` + `Depends` + 标准库白名单；`Card` / `Depends` 是装载器构造的闭包（捕获局与本次上下文），加载结束后再调报「只能在加载规则集时声明」
- [x] 2.2 预解析的 stub 环境同步（`Card` / `Depends` 记条目 / 依赖，不写真实状态）
- [x] 2.3 `server/core/loader/env-meta.lua`：声明注入的 `game`（`Moe.Game`）/ `Card` / `Depends` 与各时机的 `ctx` 类型（`Moe.Game.EventCtx.游戏开始`）
- [x] 2.4 验证：`--test rule` 系列全绿

## 3. 规则包与测试

- [x] 3.1 规则包改写法：`game:setValue(s)` / `game:on` / `game:getAttributeSystem` / `game:getValue`；`rule.card` → `Card`、`rule.depends` → `Depends`、`rule.room` → `game`（六个包文件）
- [x] 3.2 测试改名（脚本 token 替换 + 逐文件 review）：`server/test/rule/**`（建局代替建规则实例、`prepare()` 建局、探针字符串）、`server/test/core/*`、`server/test.lua` 套件名（`core.room` → `core.game`）
- [x] 3.3 `server/test/core/game.lua`（原 `room.lua`）与 `server/test/rule/support.lua` 手改（`support.start` 建局 + 触发 `{ }`）
- [x] 3.4 顺手规范化 26 处类型侧可选注解（`number?` → `? number`；`server/tools/` 不动）
- [x] 3.5 全量回归：`--test` 0 失败

## 4. 文档

- [x] 4.1 `architecture.md`：第 1 节分层图（`game` / `loader`）、第 8 节热重载范围、第 9 节（规则集加载 → 装载器 + 局）、第 10 节（时机实例由局持有、env 说明）、第 11 节（预解析）
- [x] 4.2 `moe-kill-dev/SKILL.md` 目录表与引用；`infrastructure.md` 的套件名与目录布局；`code-style.md`（如还有 `rule` 写法）
- [x] 4.3 `sanguosha-rules/SKILL.md`（§8 落定机制、§9 结构性约束、§9.1 示例改成 `game` + `Card` / `Depends`）；`AGENTS.md` 里提到 `moe.rule` / `server/rule/` 的地方

## 5. 验收与归档

- [x] 5.1 全量测试 0 失败、问题面板 information 及以上为 0、`openspec validate --all --strict` 全通过
- [x] 5.2 勾完任务 → 提交推送 → **归档**（归档后如新能力有 `Purpose` 占位就补上）→ 再提交推送
