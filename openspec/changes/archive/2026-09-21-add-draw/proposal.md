# Proposal

## Why

「抽 X 牌」这种会被多处复用的动作，现在**只有 `@基础/回合.lua` 里的局部函数 `draw` 用得到**（摸牌阶段），别的包根本调不到 —— 内容包之间没有共享函数的通道（注入面只有 `game` / `Card` / `Depends` / `util`，规则数值不许存函数，全局表拿不到）。将来【无中生有】、武将技能（【遗计】）都要摸牌，不能各写一遍。

答案其实已经在手边：**内核给效果与入口、规则给语义** —— 与伤害 / 回复 / 濒死完全同形（内核不认识区名，所以取牌与洗回只能写在内容侧）。

## What Changes

- **内核新增 `Draw` 效果**（`server/core/draw.lua`，`kind` = `draw`，字段 `player` / `count`）：`settle()` 只触发一次 **`'摸牌'`** 时机 —— 内核**不碰任何牌区**（区名是内容侧约定）。
- **内核新增入口 `game:draw(player, count)`**：与 `game:damage` / `game:heal` 同形（`apply()` + `await()`，返回效果实例，可进效果链、失败读 `.err`）。
- **规则侧新增 `package/@基础/抽牌.lua`**：订阅 `'摸牌'`，实现「从 `抽牌` 依次取顶 → 不够时把 `弃牌` 洗回 → 整批 `game:moveCard` 进该玩家的 `手牌`」（从 `回合.lua` 搬过来的 `recycleDiscard` 也在这里）。
- **`package/@基础/回合.lua` 瘦身**：删掉局部 `draw` / `recycleDiscard`，摸牌阶段改成 `game:draw(player, DRAW_COUNT)`。
- **把「常用动作的形状」写成通用约定**（`moe-kill-dev` 与 `sanguosha-rules`）：内核**一个效果 + 一个便利入口**、语义写在 `@基础` 的同名文件里；**不为"替换动作"预先造注册表**（现在覆盖靠"改状态 + 注册顺序"，真要替换时再谈）。
- 用例：`core/draw`（内核侧）+ `rule/draw`（规则侧：真摸 / 洗回 / 都空就摸不到）。

**明确不做**：通用动作注册表（`game:registerAction`）、"获得牌 / 弃置 / 判定"这些同族动作（按功能点就地补）、`Draw` 的前后时机（用户定：只给 `'摸牌'`，将来真要用再加）。

## Capabilities

### New Capabilities

- （无）

### Modified Capabilities

- （无）

> 探索期不写规格（`.openspec.yaml` 设 `skip_specs: true`）：契约由用例承担 —— `--test core.draw` / `rule.draw`，以及既有的 `--test rule.turn`（摸牌阶段那两条）。

## Impact

- 新增：`server/core/draw.lua`、`package/@基础/抽牌.lua`、`server/test/core/draw.lua`、`server/test/rule/draw.lua`
- 改动：`server/core/game.lua`（`game:draw`）、`server/core/init.lua`、`server/core/loader/env-meta.lua`（`'摸牌'` 时机）、`package/@基础/回合.lua`（摸牌阶段改用入口）、`server/test.lua`
- 文档：`architecture.md` §12、`sanguosha-rules`（抽牌写法 + 通用约定）、`moe-kill-dev`（通用约定）、`infrastructure.md` 命令速查
- 行为不变：摸牌阶段的摸 2 张与洗回弃牌语义**原样搬走**（用例 `rule.turn` 那两条应当继续通过）
