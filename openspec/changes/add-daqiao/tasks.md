# Tasks

## 1. 内核：拆 canUse + 全量合法目标的读取口

- [x] 1.1 `server/core/game.lua`：抽出局部函数 `checkTargets`（目标那半：数量区间 / 取小 / 子集 / 重复），`canUse` 只剩「合并选项 → 判牌本体 → 判目标 → 问内容侧」
- [x] 1.2 `server/core/game.lua`：新增 `game:getLegalTargets(使用者, 牌, 选项?)` —— 跑牌的 `targets` 条件 + 逐候选问 `'卡牌-目标-能否指定'`；**不合并选项、不判「能不能用」**；没声明目标条件 / 一个都没有 ⇒ 空表

## 2. 内核：官方「转移」

- [x] 2.1 `server/core/effect/use-card.lua`：`UseCard:replaceTarget(换掉谁, 换成谁)` —— 换 `self.targets` 里的元素 + **立刻对新目标补发三份「指定目标后」**；「换掉谁」不在目标列表里就报错

## 3. 类型面：`ignoreDistance` 的声明外移

- [x] 3.1 `server/core/game.lua`：`Game.UseOptions` / `Game.UseOptionsInput` 去掉 `ignoreDistance`（留一句「其余名字由读它的包自己声明」）
- [x] 3.2 `package/@基础/距离.lua`：接管两条声明（它就 `isInRange` 读它）

## 4. 内容：大乔

- [x] 4.1 `package/标准/武将/大乔.lua`（新）：吴 · 女 · 体力上限 3；文件顶部写官方描述 + 注明【国色】待机制
- [x] 4.2 【流离】：`event('卡牌-目标-指定目标后')`（目标自己那份）→ 认【杀】+ 只认「我是目标」→ 候选 = `getLegalTargets(…, 选项带 ignoreDistance)` ∩ 「大乔攻击范围内（算距离）」− 自己 → 候选为空就不问
- [x] 4.3 一次 `askCardWithTarget`（弃一张 + 选一人），没答 = 不发动；发动套 `skill:cast`（弃牌 + `replaceTarget`）

## 5. 用例

- [x] 5.1 `server/test/core/effect/play.lua` +2：换目标 ⇒ 生效跑新目标、旧目标不生效；新目标收到补发的三份「指定目标后」
- [x] 5.2 `server/test/core/can-use.lua` +3：全量合法目标不受这次目标收窄影响（且不问「能否使用」）；按调用方给的选项算；牌没声明目标条件 ⇒ 空表
- [x] 5.3 `server/test/rule/hero-skill.lua` +4：转移并弃一张（含候选断言：不含使用者 / 不含自己）；**能触发流离**（两个大乔链式转移）；不答复就是不发动；攻击范围内没合法目标时连问都不问
- [x] 5.4 反向验证两轮：拆掉补发 ⇒ 红 2（补发那条 + 链式那条）；`getLegalTargets` 丢掉调用方的选项 ⇒ 红 4；改回后全绿

## 6. 文档

- [x] 6.1 `sanguosha-rules`：§9.2 补 `getLegalTargets` 读取口；新增 §9.30 大乔（官方「转移」依据、「流离能触发流离」、两句判据拆读、`ignoreDistance` 声明归属、不做【国色】）
- [x] 6.2 `moe-kill-dev/references/architecture.md`：`game:canUse` 行（拆函数）、新增 `game:getLegalTargets` 行与 `UseCard:replaceTarget` 行、`Game.UseOptions` 行的声明归属、`game:useCard` 行的「换目标会补发三份」
- [x] 6.3 `moe-kill-dev/references/progress.md`：基线 1022、23 将、成本表大乔行、缺口表划掉「改目标」、§1 本批条目

## 7. 收尾

- [x] 7.1 `server/bin/moe-kill.exe --test` 全绿（1022 用例 0 失败）
- [x] 7.2 问题面板 information 及以上 0
- [ ] 7.3 停在待确认状态，等「提交」
