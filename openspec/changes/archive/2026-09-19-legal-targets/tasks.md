# Tasks

## 1. 内核：合法目标列表

- [x] 1.1 `server/core/use-card.lua`：`settle()` 改成 —— 取定义 → 找牌（牌在使用者手上）→ 调 `'获取目标'` 钩子求**交集**得到合法列表 → 拿不到 / 为空 ⇒ 报错（牌不动）→ 校验调用方给的 `targets` 是**非空子集**（否则报错、牌不动）→ 取出牌 → 跑「使用」回调 → 触发 `'卡牌-结算后'`。验证：`--test core.play` 用例通过
- [x] 1.2 `server/core/loader/env-meta.lua`：`CardDef` 的钩子从 `'目标合法'` 改成 `'获取目标'`，处理器返回类型写明 `Player[]`。验证：问题面板 information 及以上为 0

## 2. 规则包与测试

- [x] 2.1 `package/标准/卡牌/杀.lua`：`'获取目标'` 枚举「除使用者以外、且在攻击范围内」的角色，返回列表（不再逐目标返回 `false`）。验证：`--test rule.slash` 全绿
- [x] 2.2 `server/test/rule/slash.lua` 补用例：**不能对自己用**（合法列表里不含使用者自己）
- [x] 2.3 `server/test/core/play.lua`：探针补上 `'获取目标'`；补用例 —— 没声明钩子 ⇒ 不能用；空列表 ⇒ 不能用；目标不在列表 ⇒ 失败且牌不动；给空目标 ⇒ 失败；多个钩子取交集（各收窄一次）。验证：`--test core.play` 全绿
- [x] 2.4 全量 `server\bin\moe-kill.exe --test` 0 失败（262 个用例）；问题面板 information 及以上为 0

## 3. 文档与验收

- [x] 3.1 文档同步：`architecture.md` §9.4（钩子表：名字与返回列表）、§10（钩子清单指向 `env-meta`）、§12（内容侧挂法示例改成枚举列表）；`sanguosha-rules/SKILL.md` §9.2（示例与要点）
- [x] 3.2 `openspec validate --all --strict` 全通过；勾完任务 → 提交推送 → 归档 → 再提交推送
