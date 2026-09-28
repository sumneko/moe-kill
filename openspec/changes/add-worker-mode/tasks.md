# Tasks

> **本变更只记录决策，不进入实施**（用户 2026-09-28 定）。下面的批次写出实施形状与验证方式；**实施时机：等 `package/标准` 的工作全部做完之后**。
>
> 已知的顺带影响：worker 落地前，「包直接修改基类」是**全局**语义（类表在进程内一份）；worker 落地后每个 VM 一份类表，这条自然变成按局语义。

## 1. per-VM 加固（单 VM 下行为不变）

- [x] 1.1 自唤醒通道名改成 `名字 .. '#' .. thread.id`（**已随 `replace-async-io-with-poll` 落地**：该模块换成 `server/loop-waiter.lua`，通道名就写在那里），验证：`server/bin/moe-kill.exe --test` 全量 0 失败
- [ ] 1.2 日志落地按 VM 分文件（`log` 路径 / `moe.env.LOG_FILE` 带 VM 标识），验证：同进程两个 VM 同时写，各自文件内容不交错、无残缺行
- [ ] 1.3 把「VM 初始化」从 `server/bin/main.lua` 抽成可复用的一段（`package.path` + 根目录推导 + 参数解析），验证：现有 `server/main.lua` 与新的 worker 入口都靠它起来，`--test` 全量 0 失败
- [ ] 1.4 新增「双 worker 冒烟」用例：同一进程起两个独立 VM、两个都开到能开局，验证：用例通过，且两条路径互不干扰（各自通道、各自日志）

## 2. worker 身份 + 单局模式

- [ ] 2.1 收出 worker 侧入口（内核 + 内容包 + 会话外壳 + 事件循环驱动视作「跑一局的那一坨」），验证：单局模式能跑完一整局（脚本化应答驱动到分出胜负）
- [ ] 2.2 开发与测试切到 worker 入口，验证：`server/bin/moe-kill.exe --test` 全量 0 失败、问题面板 information 及以上 0
- [ ] 2.3 跨 VM 消息接线：worker 与宿主之间用协议三种形状（请求 / 反向请求 / 通知），验证：跨 VM 用例覆盖三种形状各至少一条
- [ ] 2.4 退出与关停按设计顺序落地（请退出 → `asyncfd:cancel` → `channel.destroy`），验证：用例断言 worker 正常退出、通道已注销、宿主收到结束消息
- [ ] 2.5 错误按局上报（不依赖 `errlog()` 的进程级队列），验证：用例断言某局报错只影响该局，且宿主收到的错误带得上该局标识
- [ ] 2.6 加「宿主无关」用例：同一份 worker 逻辑内联跑与线程跑结果一致，验证：两种跑法下断言相同
- [ ] 2.7 更新文档：`references/architecture.md` 新增「worker / master 与单局模式」一节、`references/infrastructure.md` 补线程与通道一节、`AGENTS.md` 目录职责表反映新分层，验证：三处文档与代码现状一致

## 3. 去掉「卸载 / 重装」（用户 2026-09-28 定）

- [ ] 3.1 删掉 `game:resetContent()` 与 `server/core/loader/init.lua` 里对它的调用与「清空局上的内容」那段，验证：`server/bin/moe-kill.exe --test` 全量 0 失败
- [ ] 3.2 删掉依赖重装的用例（`server/test/core/game.lua`、`server/test/core/phase.lua`、`server/test/rule/flow.lua`、`server/test/rule/init.lua` 里的相关条目），验证：`--test` 全量 0 失败、问题面板 information 及以上 0
- [ ] 3.3 包清单变成 VM 启动参数：`moe.game.create { packages = … }` 是唯一入口（master 传 / 单局模式交互选 / 测试用参数），去掉 `loader.install` 的「省略即复用上一次清单与来源」语义，验证：单局模式能按显式清单开局
- [ ] 3.4 文档改写：`references/architecture.md` §9.8「重装语义」整节 + §9.1 / §9.3 / §9.6 / §8.4 / 第 10 节里提「重装」的句子、`references/progress.md`、`AGENTS.md`，验证：逐条对照代码确认文档与现状一致

## 4. master（范围备忘）

- [ ] 4.1 另开一个变更写 master 的 proposal（lobby、会话表归属、重连全量状态经 master 转发），验证：`openspec validate --strict` 通过，且本变更不变为「已实施」
