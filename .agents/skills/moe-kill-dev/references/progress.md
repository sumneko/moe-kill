# 当前进度与下一步

> **这份文件是给"换台电脑接着做"用的状态快照**（2026-09-22 记录）。真相源永远是**代码 + 用例 + 其它 references**；本文件只写三件事：做到哪了、下一步做什么、什么还没定。
> 验收口径：`server/bin/moe-kill.exe --test` ⇒ **419 用例 0 失败**；问题面板 information 及以上 **0**。

## 1 已经跑通的一条链

```
moe.game.create（建局 + 装包）→ '游戏-开始'（建牌堆 / 定义属性 / 分身份）
  → game:runFlow()（回合流程：准备→判定→摸牌→出牌→弃牌→结束）
  → 出牌阶段：game:askCard(player, '出牌', { targets = {} })（内核按条件筛出手牌里能用的牌 + 各自可用目标；用满次数的牌也不进选项）
  → game:useCard（canUse 二次校验（含次数）→ 记一次账 → 取出牌 → 逐目标 CardEffect 生效）
  → 伤害 / 回复（内核只发时机，扣血 / 回血写在 @基础）
  → 濒死求桃（早于 '伤害-后'）→ 死亡 → 奖惩（先）→ 身份场胜负判定（后）→ game:endGame 收掉流程
```

**内容包现状**（`package/`）

| 包 | 文件 |
| --- | --- |
| `@基础` | 配置 / 体力 / 攻击范围 / 牌堆 / 使用 / 打出 / 抽牌 / 伤害 / 回复 / 濒死 / 回合 / 基本牌（模板）/ `meta.lua` |
| `身份场` | 配置 / 开局 / 奖惩 / 胜负 / `meta.lua` |
| `标准` | 牌表（102 张**草稿**，待核对）/ 卡牌：杀 / 闪 / 桃 / `meta.lua` |
| `@tools` | `table.lua` —— 给**内容侧**标准库加 `filter` / `map` / `contains` |

**内核现状**（`server/core/`）

- 对象：`Card` / `Zone` / `OrderedZone` / `Attributes` / `Random` / `Desk` / `Player` / `Game` / `Event` / `Phase`
- 效果族（`core/effect/`）：`Effect` + `use-card`（含 `CardEffect`）/ `ask` / `ask-card` / `move-card` / `damage` / `heal` / `draw` / `dying`；**嵌套上限 `Effect.MAX_DEPTH = 150`**（安全阀：超了那一层以「取消」收尾 + `warn`，不算失败；实测再深进程会直接没）
- 局上的入口：`game:canUse`（**用牌校验**：内建条目 + `'卡牌-能否使用'` 内容侧条目）/ `useCard` / `askCard` / `ask` / `moveCard` / `damage` / `heal` / `draw` / `createCard` / `createZone` / `enterDying` / `endGame` / `runFlow` / `registerFlow`
- **定义上的三件套**（2026-09-22）：`CardDef:kind(名字)` / `isKind` / `getKinds`（分类，内核只记录；取值省略「牌」字）、`CardDef:zone(区名)` / `getZone`（**必须从哪个牌区用**，`canUse` 的内建条目；不声明 = 任一牌区都行）、`CardDef:extends(名字)`（把基类的钩子与字段**抄**过来，基类的钩子跑前面、抄完脱钩、支持限定名）；公共模板在 `package/@基础/基本牌.lua`（`kind '基本'` + `zone '手牌'`），【杀】用 `: extends '基本牌'`
- **号是局内发的**（2026-09-22）：`game:nextId()` —— 每次都递增、重装规则内容不重置、**牌与将来的技能共用同一串号**；牌实例自己不再取号（`Card:__init(label, id)` / `moe.card.create(label, id)` 的号都由调用方给），另一局从 1 重新开始
- **阶段是内核一等对象**（2026-09-22）：`game:enterPhase(玩家, 阶段名)` 返回可 `<close>` 的 `Phase` 实例（`game.phase` = 当前阶段；可嵌套、离开要按嵌套顺序）；阶段事件改**由内核触发**，ctx = 阶段实例（**BREAKING**：`ctx.phase` → `ctx.name`）；实例上有**标签袋**与**两本账**：`addUseCount / getUseCount`（已用次数）、`addLimit / getLimitDelta`（上限增减）
- **按次数的限制整套在内核**（2026-09-22）：限额写在**内容定义**上（`Card '杀' : limit('出牌', 1)`，没声明就是 1000 = 事实上不限）；`game:canUse` 多一条**内建条目**（阶段属于使用者时 `已用 < 限额 + 增减`，不通过就**不问内容侧**），`useCard` 校验通过后**内核自己记一次**（只在自己的阶段里记）—— 两种口径：`phase:addUseCount(名字, -1)`（此牌不计次数）、`phase:addLimit(名字, n)`（可以多用一次 / +1000 相当于不限）；**原来的 `@基础/使用限制.lua` 已删**（用户 2026-09-22 同意）
- **濒死当场结、带着那次伤害**（2026-09-22）：检查点在规则侧（`@基础/伤害.lua` 扣完血判 ≤0）⇒ `game:enterDying(受害者, 这次伤害)` **当场结算**（不再记账、不再等效果收尾、也不再能撤销）；时机 **`'濒死'` → `'濒死-进入'`（BREAKING）**，新增 **`'濒死-离开'`**（结完还活着才发）；**时序：濒死（含判死 / 奖惩 / 胜负）早于 `'伤害-后'`**；凶手记在死者的 `'凶手'` 标签上；`Draw` 对已阵亡的角色直接完成；`game.dyingPending` / `game:flushDying()` 与属性监听那套已删
- **事件的快速返回**（2026-09-22）：时机回调**明确返回非 nil 值就停下、跳过之后的事件**，`game:fire` 把它交回调用方（落在 `tools/simple-event.lua`，记账在 `infrastructure.md`）；规则侧因此约定**疑问式事件名（能否…）= 期望返回值的事件**
- **询问带合法选项**（2026-09-22）：`game:askCard(被问者, 缘由, 条件?)` —— 条件是 `AskCard.Condition`（`name?` 牌名 + `targets?` 目标窗口）；**内核在询问前遍历被问者的牌区、按条件算出 `ask.options`**（条件里给了 `targets` 就跑 `canUse`，于是内容侧的 `'卡牌-能否使用'` 条目一并生效；`targets = {}` 空表 = 只要求「至少有一个合法目标」；省略 `targets` = 不要求目标、不跑 `canUse`）；**答复必须落在选项里**（不在就拒收：`.err` = 原因、`.card` 不存在）；不给条件 = 不做限制。业务层三处调用点都是一行（`'出牌'` / `'打出'` / 求桃）
- 时机 21 个 —— 清单见 `references/architecture.md` 第 10 节与 `server/core/loader/env-meta.lua`

## 2 下一步：待用户挑（**尚未开工**）

上一批「死亡奖惩」已做完（含内核的濒死改造：当场结算 + 两个时机 + `Draw` 拦死者；见 `openspec/changes/archive/` 里的 `2026-09-22-add-death-reward`）。下面这些是用户已表态、还没开工的方向，**按一个功能点一批推进**（用户 2026-09-19 定），下一批做哪个由用户定：

| 候选 | 现状 / 前置 |
| --- | --- |
| **判定机制** | `game:judge`（翻牌 → 改判时机 → 结果入弃牌）—— 「抽牌 / 弃置 / 获得 / 判定」四个常用动作里**唯一没做**的 |
| **即时锦囊 + 无懈可击** | 缺的是"无懈的嵌套询问窗口"；现在能挂同一套 `canUse` 校验 |
| **装备与距离修正** | `desk:getDistance` 已就位，缺修正来源（±1 马、武器改攻击范围）与装备区 |
| **武将技能** | 前置是武将系统（选将 / 技能注册） |
| **会话 / 协议** | 前端接线 —— 按用户节奏放最后；届时要写 JSON-RPC 规格（不设 `skip_specs`） |
| **询问家族** | `timeout` + `askSkill`，timeout 与答复做 race；`Ask` 只剩弃牌阶段在用 |

## 3 用户已表态、还没做的方向

- **询问家族**：将来加 `timeout` 与 `askSkill`，**timeout 与答复做 race**。`Ask`（通用决策询问，答复是 `any`）现在只剩弃牌阶段在用，用户认为它"意义不明" —— 等那批到位再谈去留（**不要擅自删**）。
- **回合时限**：真游戏靠它兜住"玩家不答"与"误选"，还没实现。用户给的形状：

  ```lua
  local countDown <close> = player:countDown(30)
  while countDown:leftTime() > 0 do
      local ask = ...
      if ask.card then
          local useCard = game:useCard()
          if not useCard.err then countDown:reset() end
      end
  end
  ```

  并指出**忙等解决不了问题** —— 得在节点上让出（`moe.await.sleep(...)`），否则事件循环根本不跑、定时器永不触发（连测试的 5 秒看门狗都抓不住）。
  归属：**内核**（时间 + 让出能力），`30` 这个数字是**规则数值**。
- **扁平调度（把"resume 套 resume"拉平）**（用户 2026-09-22 备忘，**暂不实施**）：最外层一个**调度器循环**取"下一个协程"来 resume；Task 被 await 时不内联唤醒，而是把要恢复的协程**登记进队列** + `yield` 回调度器 ⇒ C 栈深度与逻辑深度脱钩（现在嵌套到 ~225 层会把进程直接搞死，见 `architecture.md` §12）。参考 `sumneko/utility/recursive.lua`（那库是给**普通递归**用的，要 256 层切片；**我们已全是 Task，会简单很多**）。**对外无感**（`await` 本来就是"返回时任务已结完"，所以 `game:damage(...)` 后立刻断言、`ask.result` 立刻可读都照旧）；代价在实现层：动照搬件 `tools/{task,await}.lua` + `Effect` 的驱动 + 调度器接线（最自然是事件循环兼任），每次唤醒多过一遍调度循环。

（判定机制 / 即时锦囊 + 无懈可击 / 装备与距离 / 武将技能 / 会话与协议 —— 已上提到 §2 的候选表。）

## 4 工程状态提醒

- **本地提交可能还没推**：换机器前先推；schannel 会握手失败，用 `git -c http.sslBackend=openssl push`。
- `openspec/specs/` **已冻结、不维护**（探索期口径见根目录 `AGENTS.md`）；进行中的变更看 `openspec/changes/`。
- 两个见过的环境坑：
  1. **聊天编辑会话会把旧 URI 的文件回写到磁盘**（归档 / 改名之后）⇒ 检查 `git status` 里的 `??`；`openspec list` 里可能多出一个假的「No tasks」变更（删掉那个只剩 `.openspec.yaml` 的目录即可）。
  2. 用编辑工具往 `openspec new change` 生成的 `.openspec.yaml` 里追加 `skip_specs: true` 会**吃掉换行**（变成 `created: …skip_specs: true`）⇒ 追加后读回来确认。
