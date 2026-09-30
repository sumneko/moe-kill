# skill-auto-confirm

## 1 内核

- [x] 1.1 `server/core/skill.lua`：删 `技能类型` 别名 / `kindName` 字段 / `M:kind()` / `M:getKind()`；新增 `M:auto(值)`（默认值存 `---@field package autoFire`，不写 = false）
- [x] 1.2 `server/core/skill.lua`：`Skill` 加公开字段 `auto`（`__init` 里从 `def.autoFire` 初始化）+ 方法 **`S:confirm()`**（`---@async`，`-- 问一次要不要发动：自动同意开着就直接放行，否则问「发动」这一句`）

## 2 内容侧

- [x] 2.1 `package/标准/武将/曹操.lua`：【奸雄】改成 `: auto(true)`，判断换成 `if not skill:confirm() then return end`

## 3 用例

- [x] 3.1 `server/test/core/skill.lua`：探针里的 `: kind '被动'` 换成 `: auto(true)`；「不写发动方式就是「主动」」→「不写自动同意就是关（每次问）」（改成读**实例**的 `auto`）；「发动方式三个取值」→「技能：自动同意开着就不问，关着问一次」（含切开关）
- [x] 3.2 `server/test/rule/skill.lua`：「受到伤害后可以拿到那张牌」→「默认自动同意 ⇒ 不问也拿到那张牌」；「不发动就不拿」→「关掉自动同意后，不发动就不拿」（`skill.auto = false`）；「素材只剩一张在原处」那条的断言改成「自动同意：没问过」

## 4 验收

- [x] 4.1 `server/bin/moe-kill.exe --test` 全绿（**810 用例 0 失败**）
- [x] 4.2 问题面板 information 及以上 0
- [x] 4.3 文档同步：`architecture.md`（`Skill '名字'` 行 + `SkillDef` 行）、`sanguosha-rules` §9.15（代码块 + 两个维度 + 读法 + 【奸雄】）、`progress.md` §1
