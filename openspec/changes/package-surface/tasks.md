# Tasks

## 1. 注入工具集

- [ ] 1.1 新增 `server/core/loader/env-util.lua`：`filter(list, predicate)`（自implement，返回满足条件的元素）/ `map(list, transform)`（转调 `moe.util.map`）/ `contains(list, value)`（转调 `moe.util.arrayHas`），全部纯函数。验证：问题面板 information 及以上为 0
- [ ] 1.2 `server/core/loader/init.lua`：把这份工具集作为 `util` 注入执行环境（与 `game` / `Card` / `Depends` 并列）。验证：`--test rule` 里新增的用例能拿到 `util`
- [ ] 1.3 `server/core/loader/env-meta.lua`：声明 `util` 的类型（`Loader.EnvUtil`，`filter` / `map` 用泛型），注释写明"收窄的工具集，不是 `moe.util` 本体"。验证：问题面板 0
- [ ] 1.4 新增用例（`server/test/rule/init.lua` 或就近）：规则集文件里能用 `util` 筛列表；`util` 里没有 IO 类函数；`moe` / `require` / `io` 仍拿不到

## 2. 收敛 game 的读取

- [ ] 2.1 `server/core/game.lua`：删掉 `getDesk` / `getRandom`（公开字段保留）
- [ ] 2.2 改用字段的地方一次改齐：`package/@基础/{体力,牌堆,攻击范围}.lua`、`package/身份场/开局.lua`、`package/标准/卡牌/杀.lua`、`server/test/core/{game,reload}.lua`、文档里的示例。验证：全量 `--test` 0 失败
- [ ] 2.3 `package/标准/卡牌/杀.lua` 的目标筛选改用 `util.filter`（顺手保持"排除使用者自己"）。验证：`--test rule.slash` 全绿

## 3. 文档与验收

- [ ] 3.1 文档同步：`architecture.md` §9.6（注入面：`game` / `Card` / `Depends` / `util` + 白名单）、§9.4 或 §12（示例用 `game.desk` 与 `util.filter`）；`sanguosha-rules/SKILL.md` §9.1（可用工具与"只读 `game.desk` / `game.random`"）
- [ ] 3.2 全量测试 0 失败、问题面板 information 及以上为 0、`openspec validate --all --strict` 全通过
- [ ] 3.3 勾完任务 → 提交推送 → 归档 → 再提交推送
