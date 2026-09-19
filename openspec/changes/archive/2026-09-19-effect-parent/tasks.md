# Tasks

## 1. 记下父效果

- [x] 1.1 `server/core/effect.lua`：加 `---@field parent? Effect`；`apply()` 在 `pushEffect(self)` **之前** `self.parent = self.game:getCurrentEffect()`。验证：问题面板 information 及以上为 0

## 2. 用例

- [x] 2.1 `server/test/core/effect.lua` 增补：嵌套时内层的父是外层、外层的父不存在；根效果的父不存在且不报错；`parent` 与栈顶在嵌套期间的对应关系
- [x] 2.2 `server/test/core/damage.lua` 或 `server/test/core/play.lua` 增补：用牌回调里造成的伤害，其父是用牌效果（且能查到使用者与牌）；父效果与 `Damage.from` 不是同一个东西
- [x] 2.3 跑全量 `--test`：0 失败

## 3. 文档同步

- [x] 3.1 `moe-kill-dev/references/architecture.md` 结算栈一节（§12）：补「效果带 `parent`，由 `apply()` 在压栈前从栈顶取出；父是嵌套关系，与伤害来源无关」
- [x] 3.2 `sanguosha-rules/SKILL.md` §7（结算栈）：同一句话；如该节有空位，补一句「父 ≠ 来源」的口径

## 4. 验收与归档

- [x] 4.1 全量测试 0 失败、问题面板 information 及以上为 0、`openspec validate --all --strict` 全通过
- [x] 4.2 勾完任务 → 提交推送 → 归档 → 再提交推送

