# Tasks

## 1. 门面拍平与命名

- [x] 1.1 `server/core/init.lua`：各模块挂到 `moe.*`（`moe.card` / `moe.zone` / `moe.orderedZone` / `moe.random` / `moe.attribute` / `moe.event` / `moe.desk` / `moe.player` / `moe.room` / `moe.rule`），去掉 `moe.core`；验证：`moe.core == nil`
- [x] 1.2 类型前缀改名：`Core.*` → `Moe.*`（`server/core/*.lua` 的 `---@class` / `Class '...'` / 注解），`Rule.*` → `Moe.Rule.*`
- [x] 1.3 `server/moe-kill.lua` 不再挂 `moe.core`；`server/test.lua` 与 `server/test/**` 的 `moe.core.X` 改成 `moe.X`
- [x] 1.4 验证：`--test core` 全绿、问题面板 information 及以上为 0

## 2. 规则加载器实例化

- [x] 2.1 目录搬迁：`server/rule/{init,vfs,preparse,env-meta}.lua` → `server/core/rule/*`（模块名 `core.rule*`），`server/rule/` 删除
- [x] 2.2 `server/core/rule/init.lua` 改成 `Moe.Rule` 类：状态（规则表 / 包顺序 / 包元信息 / 规则数值 / 时机 / 属性系统 / 来源 / 上次清单 / 加载上下文）全部落在**实例**上，`create { sources?, packages? }` 给了清单即立刻加载
- [x] 2.3 入口形状：`rule.card` / `rule.depends` 在实例上绑成**点号**可调；`load` / `getCard` / `setValue` / `setValues` / `getValue` / `getValues` / `on` / `fire` / `getAttributeSystem` / `getPackageMeta` / `getMetas` / `setRoots` / `getRoots` 改成实例方法（内部用 `self`）
- [x] 2.4 热重载：`core.rule` 系列走 `includeCore`（与其它内核模块一致）；`env-meta.lua` 只被语言服务器读，不进集合
- [x] 2.5 `env-meta.lua`：`rule` 的类型指向**规则实例**（类声明留在实现处，不在 meta 里重复声明）；`Rule.EventCtx.游戏开始` → `Moe.Rule.EventCtx.游戏开始`
- [x] 2.6 验证：`--test rule` / `--test rule.vfs` / `--test rule.meta` 等规则侧套件全绿

## 3. 房间自建规则

- [x] 3.1 `server/core/room.lua`：`create { desk, random, sources?, packages? }` 内部建规则实例并加载（不给清单则只装默认加载的包），提供 `getRule()`；`Moe.Room.CreateOptions` 补两个可选字段
- [x] 3.2 验证：`--test core.room` 补「建场地时装好规则」「两个场地的规则互不影响」两条用例并通过

## 4. 测试适配

- [x] 4.1 `server/test/rule/support.lua`：辅助改成「建场地（带清单）→ 返回场地与规则实例」，`start` 从 `room:getRule()` 取属性系统
- [x] 4.2 `server/test/rule/*`：全局单例改成按用例建实例（`rule` 是局部变量）
- [x] 4.3 规则包（`package/**`）确认**无需改动**（只看见注入的 `rule` 与 `ctx.room`）
- [x] 4.4 全量回归；验证：`--test` 全绿、退出码 0

## 5. 文档同步

- [x] 5.1 `architecture.md`：第 1 节分层（去掉 `moe.core`，规则加载器归内核模块组）、第 8 节热重载范围、第 9 节规则集加载（实例语义 + `create` 形状）、第 10 节时机（实例持有）、第 11 节预解析（实例级 stub）
- [x] 5.2 `moe-kill-dev/SKILL.md` 目录表与引用行；`code-style.md`（门面/命名相关条目）
- [x] 5.3 `infrastructure.md` 的目录布局与命令速查（测试过滤名有无变化）
- [x] 5.4 `sanguosha-rules/SKILL.md`（§9 规则集侧写法、§1 体力与属性系统归属）；`AGENTS.md` 里提到 `moe.core` / `server/rule/` 的地方

## 6. 验收

- [x] 6.1 构建（`luamake -notest`）+ 全量测试 0 失败 + 问题面板 information 及以上为 0
- [x] 6.2 `openspec validate --all --strict` 全通过
