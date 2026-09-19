# Tasks

## 1. 内核机制（`server/core/event.lua`）

- [ ] 1.1 新增 `Core.Event`：按时机名分发（`on(name, cb) -> disposer` / `fire(name, ...)` / `clear()` / 列出已有时机名），底层用 `moe.sevent`（注册顺序即执行顺序、错误隔离沿用 `xpcall(cb, log.error, ...)`）；验证：`--test core.event` 能跑出用例
- [ ] 1.2 挂在 `server/core/init.lua` 的 `moe.core.event`；验证：`moe.core.event.create()` 可用
- [ ] 1.3 边界行为：未注册的时机名 `fire` 是空操作；`disposer` 精确撤销一次注册且重复撤销安全；`clear()` 清空全部注册；验证：对应用例通过

## 2. 规则门面

- [ ] 2.1 `moe.rule` 持有一个事件实例，`load` 开始时重置（与规则表同生命周期）；验证：清空重载后旧注册不再触发的用例通过
- [ ] 2.2 `rule:on(名字, 回调)` 只在加载过程中可用（加载之外调用报错）、按注册顺序执行、返回 disposer；验证：三个用例都通过
- [ ] 2.3 `rule:fire(名字, 上下文)` 在加载期与加载后都可用，按名触发并传上下文；验证：触发与传上下文的用例通过

## 3. 测试

- [ ] 3.1 新增 `server/test/core/event.lua`（机制：按名分发、注册顺序、disposer、clear、未注册空操作、回调报错不打断其余、上下文透传）并挂到套件列表；验证：`--test core.event` 全绿
- [ ] 3.2 新增 `server/test/rule/event.lua`（规则集侧：加载期注册能被触发、按注册顺序执行、加载之外注册报错、清空重载后旧注册清空、后注册覆盖先注册写的状态）并挂到套件列表；验证：`--test rule.event` 全绿
- [ ] 3.3 组合场景用例：两个包先后注册同一时机，后注册者写下的值生效（模拟"国战覆盖身份场的设置"）；验证：该用例通过

## 4. 文档

- [ ] 4.1 `moe-kill-dev/references/architecture.md`：新增「时机与事件」一节（机制在内核 / 实例由规则门面持有与注入的依赖方向、注册顺序即执行顺序、覆盖靠顺序、随清空重载清空、时机名不预设、`fire` 的使用约定）
- [ ] 4.2 `moe-kill-dev/SKILL.md` 目录表补 `server/core/event.lua`；`references/architecture.md` 的 references 索引行同步
- [ ] 4.3 `sanguosha-rules`：规则集侧写法补 `rule:on('游戏开始', ...)` 示例与"内容包不主动 fire"的约定；§8 时机系统指向落地的机制（时机名集中定义的建议保留为规则层约定）

## 5. 验收

- [ ] 5.1 `luamake -notest` 通过；全量 `--test` 全绿退出码 0；`--test core.event` 与 `--test rule.event` 全绿；问题面板 information 及以上为 0
- [ ] 5.2 确认本批未引入"改事件载荷/取消事件"这类机制（改状态一律走接口）
- [ ] 5.3 确认时机名没有被预设或枚举（内核与加载器不认识任何具体时机名）
