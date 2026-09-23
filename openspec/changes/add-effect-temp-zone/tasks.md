# Tasks

## 1. 内核：`Effect` 搬家

- [x] 1.1 新建 `server/core/effect/effect.lua`：内容 = 现在的 `effect/init.lua`（基类、`apply` / `await` / `reject` / `remove` / 标签袋）
- [x] 1.2 `server/core/effect/init.lua` 改成只做装载：先 `include 'core.effect.effect'`，再按序 `include` 各子文件
- [x] 1.3 `server/core/init.lua` 里 10 行 `core.effect.*` 缩成 1 行 `include 'core.effect'`；9 个子文件的 `require 'core.effect'` 改成 `require 'core.effect.effect'`
- [x] 1.4 验证：`server/bin/moe-kill.exe --test` 462 用例 0 失败；问题面板 information 及以上为 0

## 2. 内核：临时处理区与收尾时机

- [x] 2.1 `Effect` 加 `---@field tempZone? Zone`（一行中文说明）+ `getTempZone()`：第一次调用时 `moe.zone.create()`（不走 `game:createZone`）
- [x] 2.2 `Effect:apply()` 里挂收尾：`task:onResolved` / `task:onRejected` → `game:fire('效果-收尾', self)`（两个都挂，取消 / 超时走 `reject` 也能收）
- [x] 2.3 `server/core/loader/env-meta.lua` 声明 `'效果-收尾'` 的 `on` / `fire` 重载（ctx = `Effect`）
- [x] 2.4 用例（`server/test/core/effect/init.lua`）：懒建（没用过就是空）/ 收尾只触发一次 / 不成立（`reject`）也收尾 / 取消也收尾 / 子效果结完之后才收尾 / 临时区不在公共区表里
- [x] 2.5 验证：`--test core.effect` 全绿；问题面板 0

## 3. 内容侧：收尾订阅与五谷丰登迁移

- [x] 3.1 新增 `package/@基础/收尾.lua`：订阅 `'效果-收尾'`，临时区里还有牌就 `game:moveCard(剩余, '弃牌')`
- [x] 3.2 `package/标准/卡牌/五谷丰登.lua`：亮出的牌 `moveCard` 进 `ctx:getTempZone()`；`'生效'` 从 `ctx.parent.tempZone:list()` 里问牌；删掉 `'结算后'` 钩子与 `table.without`
- [x] 3.3 验证：`--test rule.trick` 五谷丰登 4 条用例全绿；`--test rule` 全绿

## 4. 文档与总验证

- [x] 4.1 更新 `.agents/skills/moe-kill-dev/references/architecture.md`（`Effect` 行加临时区与收尾时机、时机表、`effect/` 目录说明、无头测试清单）与 `references/progress.md`
- [x] 4.2 更新 `.agents/skills/sanguosha-rules/SKILL.md`（§9.10 五谷丰登的写法改成临时区版本）
- [x] 4.3 验证：`server/bin/moe-kill.exe --test` 0 失败；问题面板 information 及以上 0；`openspec validate add-effect-temp-zone --strict` 通过

## 5. 批二：判定 / 使用 / 打出也进临时区，废弃 `处理` 公共区

- [x] 5.1 `package/@基础/牌堆.lua`：不再建 `处理` 公共区
- [x] 5.2 `package/@基础/使用.lua`：用过的牌进 `ctx:getTempZone()`，`'卡牌-结算后'` 订阅删掉（收尾统一送弃牌）
- [x] 5.3 `package/@基础/打出.lua`：打出的牌进**发起那次结算**的临时区（`ctx.parent`；没有父结算就直接送 `弃牌`），`'卡牌-答复后'` 订阅删掉
- [x] 5.4 `package/@基础/判定.lua`：翻出的判定牌进 `judge:getTempZone()`、`'判定-后'` 整段删掉；内核 `Judge:replace` 把新牌也挪进同一块临时区
- [x] 5.5 用例：删掉 5 处「处理只是路过 / 处理也建好了」断言（牌的去向已由「进弃牌」覆盖）；腾空牌堆的两处改用例自建区
- [x] 5.6 验证：`--test` 468 用例 0 失败；问题面板 information 及以上 0
