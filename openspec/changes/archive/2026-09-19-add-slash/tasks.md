# Tasks

## 1. 内核：伤害机制

- [x] 1.1 `server/core/game.lua` 增加 `damage(from, to, amount)`：先 `fire('伤害-前', ctx)` → 目标的 `体力` 减去点数 → 再 `fire('伤害-后', ctx)`，`ctx = { from, to, amount }`；不做濒死 / 死亡（体力可为负）。验证：`--test core.damage` 用例通过
- [x] 1.2 新增 `server/test/core/damage.lua`（套件 `core.damage`）：体力下降、可降到负数且无死亡、两个时机的先后（前：体力未变；后：已变）、上下文含来源 / 目标 / 点数、无订阅者是空操作；`server/test.lua` 注册。验证：`--test core.damage` 全绿
- [x] 1.3 `server/core/loader/env-meta.lua` 补 `'伤害-前'` / `'伤害-后'` 的上下文类型与 `game:on` / `game:fire` 重载。验证：问题面板 information 及以上为 0

## 2. 内核：使用机制

- [x] 2.1 `server/core/game.lua` 增加 `play(user, card, targets)`：在使用者名下牌区里定位并取出该牌 → 按牌的标签名查内容定义（查不到报错，牌不动）→ 调内容的 `'目标合法'` 回调（返回 `false` ⇒ 失败且牌不动）→ 按声明顺序调 `'使用'` 回调 → `fire('卡牌-结算后', { user, card, targets })`。验证：`--test core.play` 用例通过
- [x] 2.2 新增 `server/test/core/play.lua`（套件 `core.play`）：正常使用（探针牌的效果被执行）、牌不在使用者手上、牌没有内容定义、目标不合法时失败且牌留在原处、`'使用'` 回调按声明顺序执行、收尾时机被触发且能拿到牌；`server/test.lua` 注册。验证：`--test core.play` 全绿
- [x] 2.3 `server/core/loader/env-meta.lua` 补 `'卡牌-结算后'` 的上下文类型。验证：问题面板 information 及以上为 0

## 3. 规则包

- [x] 3.1 新增 `package/@基础/攻击范围.lua`：顶层 `define('攻击范围', { min = 0, max = 999999, simple = true })`，「游戏-开始」给每个玩家写 1。验证：`--test rule.slash` 中断言开局后 `攻击范围` 为 1
- [x] 3.2 `package/@基础/牌堆.lua`：「游戏-开始」建局上的 `弃牌堆`、给每个玩家建 `手牌`；订阅 `'卡牌-结算后'` 把用掉的牌放进 `弃牌堆`。验证：`--test rule.slash` 中断言用了的牌出现在 `弃牌堆`
- [x] 3.3 新增 `package/标准/卡牌/杀.lua`：`Card '杀'` 声明 `'目标合法'`（目标在攻击范围内：`game:getDesk():getDistance(user, target) <= 攻击范围`）与 `'使用'`（对目标 `game:damage(user, target, 1)`）。验证：`--test rule.slash` 中断言目标掉 1 点体力
- [x] 3.4 新增 `server/test/rule/slash.lua`（套件 `rule.slash`）：用 `support.start` 建局 → 从 `抽牌堆` 取一张「杀」进使用者手牌 → `game:play` → 断言目标体力 -1、牌进 `弃牌堆`；再断言射程外的目标被拒绝（牌仍在手上）；`server/test.lua` 注册。验证：`--test rule.slash` 全绿

## 4. 验收与文档

- [x] 4.1 全量 `server\bin\moe-kill.exe --test` 0 失败；问题面板 information 及以上为 0；`openspec validate --all --strict` 全通过
- [x] 4.2 文档同步：`moe-kill-dev` 的 `architecture.md`（补「使用与伤害」的机制与时机名）、`sanguosha-rules/SKILL.md`（§6 / §7 补「杀」的已实现口径、§9.1 示例补这张牌）、`moe-kill-dev/SKILL.md` 目录表（新增的包文件如涉及）；`AGENTS.md` 如有过期表述一并修
