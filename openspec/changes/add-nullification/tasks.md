# Tasks

## 1. 内核：「对一张牌使用」这一支（方案 B）

- [x] 1.1 `server/core/effect/use-card-to-card.lua`（新）：`UseCardToCard`（一次使用、目标是牌，`kind = 'useCardToCard'`；沿用 `'结算前'` / `'结算后'` / 记一次使用 / 收尾送弃牌）、`CardEffectToCard`（对那张牌的一次生效，`kind = 'cardEffectToCard'`，跑定义项的 `'对卡牌生效'` 钩子，载荷 `(cardEffectToCard, useCard)`）
- [x] 1.2 `server/core/effect/ask-use-card-to-card.lua`（新）：`AskUseCardToCard`（`extends AskCard`）+ `Condition` / `Option` 都带 `target Card`；候选 = 逐张跑 `canUseToCard(被问者, 牌, 目标牌)`，答复只给牌
- [x] 1.3 `server/core/effect/init.lua` 装载两个新文件
- [x] 1.4 `server/core/game.lua`：抽出共用的「牌本身能不能用」校验（名字 / 定义 / 在不在手里 / 使用区域是否声明过 / 次数），`canUse` 改用；新增 `canUseToCard(user, card, targetCard?)`（合法性 = 定义声明过 `'对卡牌生效'`，并触发 `'卡牌-能否使用'` 带 `target`）、`game:useCardToCard`、`game:askUseCardToCard`
- [x] 1.5 `server/core/loader/env-meta.lua`：注册钩子 `on(self, '对卡牌生效', handler)`；`'结算前'` / `'结算后'` / `'卡牌-结算前'` / `'卡牌-结算后'` 的载荷放宽成 `UseCard|UseCardToCard`（on 与 fire 都改）；`'卡牌-能否使用'` 补 `---@field target? Card`；三个 ask 载荷联合类型补 `AskUseCardToCard`

## 2. 内容：【无懈可击】

- [x] 2.1 `package/标准/卡牌/无懈可击.lua`（新）：顶部写官方描述（使用时机 / 使用目标 / 作用效果）；`Card '无懈可击' : extends '锦囊牌' : on('对卡牌生效', function () end)` —— 声明壳（真正抵消由下面的窗口落地，因为内核的取消只能由被取消的效果自己的执行体发起）
- [x] 2.2 同文件顶层写窗口：`game:on('效果-即将生效', …)` **只认 `cardEffect` 与 `cardEffectToCard` 两种 `kind`**（+ `isKind('锦囊')`），不认 `useCard` / `useCardToCard`；`nullified(card)` 用 `game.desk:actionOrder(game.desk.alivePlayers)` 走一圈、`game:askUseCardToCard(player, card.name, { name = '无懈可击', target = card })` 问、问到就用 `game:useCardToCard` 真用出去（那张无懈自己也会走一遍窗口 ⇒ 嵌套由事件产生）；净结果是被抵消就 `effect:remove()`；判决直接读那次使用的 `childs` 里 `cardEffectToCard` 的 `.err`（空 = 它生效了 = 上层被抵消），不另设标记
- [x] 2.3 牌表里那 4 张【无懈可击】已存在，不动

## 3. 用例

- [x] 3.1 `server/test/rule/trick.lua`：既有的 5 个应答脚本加护栏 —— 遇到无懈询问（`ask.kind == 'askUseCardToCard'`）直接跳过，避免询问次数 / 顺序变化误伤；加 `isNullifyAsk` / `pendingEffect`（读 `ask.parent`）两个辅助
- [x] 3.2 同上：**没人响应** ⇒ 一圈询问照发（`'1,2,3'`）且锦囊照常结算
- [x] 3.3 同上：**一层抵消** ⇒ 该目标不生效，打出的【无懈可击】与原锦囊都进了弃牌堆
- [x] 3.4 同上：**两层互相抵消** ⇒ 第二张【无懈可击】把第一张抵消掉，原锦囊照常生效；并沿效果树断言**中层那次「对牌生效」被真的取消**（`err == canceled`），它不是只把最外层取消掉
- [x] 3.5 同上：**多目标只抵消一个**（靠 `ask.parent` 认出这次问的是哪个目标的生效）
- [x] 3.6 同上：**非锦囊不触发**（【杀】结算里没有无懈询问，缘由为 `'杀'`）
- [x] 3.7 同上：**它主动用不出去**（出牌阶段候选里只有别的锦囊；`canUse(user, card, {})` 报「没有声明『获取目标』，现在用不了」）
- [x] 3.8 同上：**答复不在选项里** ⇒ 按没用处理、不报错、锦囊照常生效、牌还在手上
- [x] 3.9 同上：**一张没生效的无懈封不住这一圈**（四个人：第一个抵锦囊、第二个把那张无懈抵掉、第三个接着抵锦囊 ⇒ 锦囊不生效、三张无懈都进弃牌堆）
- [x] 3.10 跑 `server/bin/moe-kill.exe --test` 全量 0 失败（基线 533 → 552）；问题面板 information 及以上 0 条
- [x] 3.11 新增两个内核套件（与既有「每个效果类一套」的惯例对齐）：`server/test/core/effect/use-card-to-card.lua`（对牌使用：目标是一张牌 / 钩子拿得到这次用牌 / 没声明就用不了 / 不在手上不成立 / 内容侧否决带 `target` / 记在出牌阶段上）与 `ask-use-card-to-card.lua`（候选逐张跑校验且选项带目标牌 / 答复多给目标就拒收 / 答复不在选项里就拒收且牌不动 / 没人应答 / 缘由与被问者带到应答方）；在 `server/test.lua` 里登记

## 4. 文档

- [x] 4.1 `.agents/skills/sanguosha-rules/SKILL.md` §9.10：补【无懈可击】的口径（官方原文：使用时机 / 使用目标 / 作用效果；「抵消」= 对该目标不生效）+ 我们的落点（「对一张牌使用」这一支 + `'效果-即将生效'` + `remove()`，逐目标、分层循环、每层一圈）；标注【闪】目前仍在【杀】自己的 `'生效'` 里，两者位置不同
- [x] 4.2 `.agents/skills/moe-kill-dev/references/architecture.md` §12：在 `'效果-即将生效'` 那行写明它**就是官方的「生效前」**；补「对一张牌使用」这一支的类与入口（`UseCardToCard` / `CardEffectToCard` / `AskUseCardToCard` / `canUseToCard` / `useCardToCard` / `askUseCardToCard` / `'对卡牌生效'`）；测试清单补 `--test rule.trick` 与两个新内核套件
- [x] 4.3 `.agents/skills/moe-kill-dev/references/code-style.md` 命名表补 `cardEffectToCard` / `useCardToCard`
- [x] 4.4 `.agents/skills/moe-kill-dev/references/progress.md`：记本批（新增 / 改动文件、验收基线 551、§2 候选表把「剩余普通锦囊」标成已做完）

## 5. 收尾

- [x] 5.1 `openspec validate add-nullification` 通过（本批带 `core-play` 规格增量，**不设** `skip_specs`）
- [ ] 5.2 提交（`【AI】` 前缀）；问过用户后再 archive（archive 会把增量同步进 `openspec/specs/core-play/spec.md`）
