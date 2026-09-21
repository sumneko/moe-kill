## 1 内核：AskCard 的答复形状
- [x] 1.1 AskCard.Answer = { card Card, targets? Player|Player[] }（server/core/effect/ask-card.lua）
- [x] 1.2 M:answer(value) 收答复表；nil = 没答上；重复应答改判 self.task.resolved（照旧只记一条 info）
- [x] 1.3 card / targets 改成 getter 转存（self.result?.card / ?.targets），删掉 settle 里的赋值
- [x] 1.4 第三个参数 question -> condition（匹配条件；内核不解释），CreateOptions 与 __init 同步
- [x] 1.5 server/core/game.lua 的 M:askCard(to, reason, condition)：参数名、注解与返回说明

## 2 内核：useCard 接受联合类型
- [x] 2.1 M:useCard 的 targets 声明成 Player|Player[]，入口归一到 Player[]（用 Type 判单个；空表仍按没指定目标报错）
- [x] 2.2 UseCard 自己的字段 / CreateOptions 保持 Player[]
- [x] 2.3 用例：core.effect.play 加「目标给单个或一张列表都行」

## 3 内容：出牌阶段改用 askCard
- [x] 3.1 package/@基础/回合.lua 的 playPhase：askCard(player, 出牌, {}) -> ask.card 为空就结束阶段 -> useCard(player, card, ask.targets or {})；删掉 hand:list() 候选载荷
- [x] 3.2 package/标准/卡牌/杀.lua：askCard(...).result -> .card
- [x] 3.3 package/@基础/濒死.lua：askCard(...).result -> .card

## 4 用例
- [x] 4.1 core.effect.ask-card：答复改成 { card = ... }；读结果改 .card；ask.question 断言改 ask.condition
- [x] 4.2 同文件新增「答复带目标」（单个与列表都测）
- [x] 4.3 rule.support 的 scripted：ask:answer { card = answers[index] }
- [x] 4.4 rule.turn：出牌阶段的应答挪到 卡牌-询问（只认 reason == 出牌，保持先让出一次再答复）；弃牌阶段独立成 discard 选项
- [x] 4.5 rule.slash、rule.dying：答复形状与 .card 读法
- [x] 4.6 --test 全绿（360 用例 0 失败）+ 问题面板 information 及以上 0

## 5 文档
- [x] 5.1 architecture.md §12：askCard 行（答复形状 / condition / .card .targets）、useCard 行的目标类型、询问与应答方段、答复之后段、杀.lua 示例
- [x] 5.2 sanguosha-rules §3（出牌阶段改 askCard）/ §6 / §7 / §9.2 / §9.4
- [x] 5.3 architecture.md 里 Ask 那条：只剩弃牌阶段（出牌已迁走）

## 6 归档
- [x] 6.1 openspec validate askcard-answer-targets
- [x] 6.2 openspec archive askcard-answer-targets --yes
- [x] 6.3 提交（【AI】前缀）
