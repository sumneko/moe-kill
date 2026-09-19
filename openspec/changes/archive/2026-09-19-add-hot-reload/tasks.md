# Tasks

## 1. 接入热重载实现

- [x] 1.1 新增 `server/tools/reload.lua`：照搬 `y3-editor/y3-lualib` 的 `tools/reload.lua`，把 `y3.util.*` 改成 `moe.util.*`，类型注解改为本工程风格；验证：`luamake -notest` 编译通过、问题面板 information 及以上为 0
- [x] 1.2 让 `onBeforeReload` / `onAfterReload` 返回撤销函数（上游返回空）；验证：`--test core.reload` 的「回调可撤销」用例通过
- [x] 1.3 `server/moe-kill.lua` 挂载 `moe.reload = require 'tools.reload'`（不额外注入全局名），并核对全局 `require` 覆盖后原有加载行为不变；验证：`--test` 全绿、退出码 0
- [x] 1.4 同步 `server/tools/class.lua` 上游一行修复：`class:__newindex` 首行补 `config:init()`；验证：该处与 `D:\Github\utility\class.lua` 一致，且全量用例仍全绿
- [x] 1.5 `.luarc.json` 增加 `runtime.special`：`{ "include": "require" }`（按用户要求已落）；验证：2.1 改用 `include` 后内核文件不出现 `undefined-global`，且 `include 'core.card'` 能跳转到模块定义
- [x] 1.6 按用户要求把日志前移（“优先加载日志”）：`moe.env` 与 `log` 实例移到 `server/moe-kill.lua`（`enable*` 之后、加载内核之前），`server/master.lua` 只留线程名与启动日志；随之去掉 1.1 为旧顺序加的兜底、直接 `xpcall(f, log.error, ...)`；验证：`--test` 全绿，且内核加载期用 `log` 不报 `nil`

## 2. 内核门面与跨重载存活状态

- [x] 2.1 `server/core/init.lua` 改为门面表 + 工厂函数形状（`moe.core = moe.core or {}`），各内核模块改用 `include` 加载以登记为可重载；验证：`--test core` 全绿，且重载后 `moe.core.card` 仍是同一张表
- [x] 2.2 `server/core/card.lua` 的标识计数器从模块级 `local` 改为挂类表的「有则复用」写法；验证：`core-zones` 规格的「重载后标识不重复」用例通过
- [x] 2.3 逐个核对 `server/core/*.lua`，确认除不可变常量与纯函数外没有模块级可变状态；验证：逐个文件说明核对结论（无则记“无”）

## 3. 重载范围（加载方式即边界）

- [x] 3.1 内核模块改用 `include` 加载（登记）、`tools/` 保持 `require`，且**不引入**任何名单 / 过滤配置；验证：`reload()` 无参调用只重跑内核模块，`tools.*` 不被重跑
- [x] 3.2 确认新增一个内核模块只靠「用 `include` 加载」即自动进入重载范围（无需改配置）；验证：`hot-reload` 规格的「加一个新内核模块即可被重载」用例通过

## 4. 测试

- [x] 4.1 新增 `server/test/core/reload.lua` 并在 `server/test/core/init.lua` 注册；验证：`--test core.reload` 能跑出用例且全绿
- [x] 4.2 假模块用例（`package.preload`）：登记过的模块被重新执行、未登记的不受影响、加载报错返回明确失败；验证：对应 3 个用例通过
- [x] 4.3 回调用例：前后顺序与「是否重载」告知、撤销函数生效、单个回调报错不中断其余、重载期间可识别；验证：对应 4 个用例通过
- [x] 4.4 自注销用例：一个可重载模块注册带副作用的重载后回调，连续重载三次后副作用不累积；验证：该用例通过
- [x] 4.5 老实例用例：重载后同一实例调用到新方法体，且自有字段、类型标识与有效性不变；验证：对应 2 个用例通过
- [x] 4.6 端到端用例：在 `server/tmp/` 真写一个模块文件、临时补 `package.path`，改内容后重载并断言新行为；验证：该用例通过（用例结束时清掉临时文件）
- [x] 4.7 全量回归：`--test` 全绿、退出码 0，内核用例（`--test core`）全绿
- [x] 4.8 关键用例只断言自己的探针（探针幂等），不依赖其它已登记模块；验证：单独跑 `--test core.reload` 与在全量里跑，结果一致
- [x] 4.9 覆盖 `recycle`（立即执行 + 每次重载后重跑 + 重载前回收登记过的旧对象）；验证：该用例通过

## 5. 文档

- [x] 5.1 `.agents/skills/moe-kill-dev/references/architecture.md`：补热重载位置与边界（`include` 用于可重载模块、`tools/` 走 `require`；**加载方式即重载边界**，不带名单/过滤配置）
- [x] 5.2 `.agents/skills/moe-kill-dev/references/code-style.md`：补「内核模块不得持模块级可变状态」与存活状态寄放写法（`__` 前缀 + 有则复用），并说明合并语义的两条限制（删除不生效、老实例不重跑 `__init`）
- [x] 5.3 `AGENTS.md` 的「项目约定」补一行：新增内核/规则模块时，必须跨重载存活的数据挂类表或门面表，不得放模块级可变量
- [x] 5.4 `.agents/skills/sanguosha-rules/SKILL.md`：注明规则层将来可重载（一句话，不展开）
- [x] 5.5 `architecture.md` 第 8 节补「撤销与自动注销的分工」（用户 2026-09-19 补充）：自动注销是默认（可重载模块里跟着模块走的注册不写 disposer）；disposer 只留给「注册在不可重载模块里」与「自动注销盖不到、必须重建的资源」；验证：`code-style.md` 同步该口径、design.md 记入 D10

## 6. 验收

- [x] 6.1 `luamake -notest` 编译通过；`server/bin/moe-kill.exe --test` 全绿退出码 0、`--test core` 全绿；问题面板 information 及以上为 0
- [x] 6.2 核对一次重载的日志出现成对的 `reload start` / `reload finish`，且重载结果列出了被重新执行的模块名
- [x] 6.3 确认本轮交付只含接口（没有文件监视、没有协议入口、`--develop` 行为不变）；验证：`git status` 中没有监视/协议相关新增文件
- [x] 6.4 配置收尾（按用户要求已落）：`.luarc.json` 加 `runtime.special`；从 `.vscode/settings.json` 去掉与 `.luarc.json` 重复的 `Lua.runtime.version`；`Lua.misc.parameters` 保留在 VS Code 设置（启动参数，挪走不生效）
