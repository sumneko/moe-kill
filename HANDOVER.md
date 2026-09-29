# 会话交接

新会话请先读 `AGENTS.md`，再读本文件 —— 这里只记「做到哪、下一步、别推翻什么」，细节一律指到工件与技能文档。每次会话收尾由接手者改写本文件（保留有效口径，别堆流水账）。

## 当前状态（2026-09-29 收尾）

- 基线：`server/bin/moe-kill.exe --test` **664 用例 0 失败**（用时 ≈ 4 秒）；问题面板 information 及以上 0。
- 最近提交：`4c99771`（收尾时机每次都发 + 两根安全阀）、`5a039d5`（装备区拆成四个普通子区）、`fe60d07`（区域禁用改成逻辑禁用）。
- 工作区有**未提交**的改动（两批 + 归档）：
  - **状态（`Buff`）内核 + 用例 + 文档**（`core/buff.lua`、`core/{game,player,init}.lua`、加载器两处注入与 `env-meta.lua`、`test/core/buff.lua`、`architecture.md` / `progress.md` / 本文件、`add-buff-system` 工件全勾）。
  - **【青釭剑】**（含牌名改名）：`package/标准/卡牌/青釭剑.lua`、`package/标准/牌表.lua`、`server/test/rule/equip.lua`（+5 用例）、`sanguosha-rules` §9.11、`progress.md`、`add-qinggang-sword` 工件全勾。
  - 三个已完成变更的**归档移动**（`archive/2026-09-29-*`）也还没提交。
**都等用户「提交」口令**。

## 正在做的一批（按顺序落地）

四个变更的 `proposal.md` / `design.md` / `tasks.md` 里是完整口径，这里只给索引。后一个依赖前面：**4 依赖 1 + 2 + 3**（1 与 2 都已落地）。

| 顺序 | 变更 | 一句话 | 状态 |
| ---- | ---- | ---- | ---- |
| 1 | `rework-zone-disable` | 区域禁用 = 逻辑禁用（区里的牌不能用 + 被动被压制）；计数可叠加、`disable()` 返回撤销函数；不再拦搬入搬出 | **已提交 `fe60d07` + 已归档**（`archive/2026-09-29-rework-zone-disable`） |
| 2 | `replace-slot-zone-with-equip-zones` | 删掉 `SlotZone` 整套；内容侧在「游戏-开始」建 `武器` / `防具` / `进攻马` / `防御马` 四个普通子区；`equipCard` 承担「一个子区只能有一张」 | **已提交 `5a039d5` + 已归档**（`archive/2026-09-29-replace-slot-zone-with-equip-zones`） |
| 3 | `add-buff-system` | 内核 `Buff`：挂在玩家上的有名状态；资源与订阅随移除撤销；生命周期由内容写 | **已落地（未提交）**；形状由用户定；工件已全勾，可归档 |
| 4 | `add-qinggang-sword` | 【青釭剑】改名 + 效果（压 / 松 / 兜底）—— 原带的「效果收尾整理」**已提前单独落地（2026-09-29）**，不在本变更里 | **已落地（未提交）**；工件已全勾，可归档 |

## 已拍板的口径（别推翻）

- **禁用区域**（用户 2026-09-29）：区里的牌**不能用**、**被动被 `disablePassive` 压住**；**不再拦搬入搬出** —— 「不准置入」是官方规则集里的**封印**，将来按那个名字另做。
- **禁用时区级压制与内容钩子的先后**（2026-09-29 实现时定、已与用户过目；与 `design.md` 初稿的表格相反）：**进区先压再跑钩子、离区先跑钩子再松开** —— 区级那层永远在钩子外侧。理由：被动回调要取 `zone.owner`、`applyPassive` 要 `getZone()`，而 `moveCard` 时牌已绑到新区（弃牌堆）、`clear`/`draw` 时已解绑 ⇒ 反过来会拿新区 / 空区跑被动（当场断言失败）。
- **装备子区**：**内容侧建**（不是内核建）；「装备区」退出内核的基础牌区清单（内核只留 `抽牌` / `弃牌` / `手牌` / `判定`）；「进错子区不启用被动」**内容做**。
- **`SlotZone` 整套删除**（用户批过；2026-09-29 已落地）：区域钩子的载荷回到 `(card, zone)`，`Zone:accept` 只剩一个参数，`moveCardWithSlot` / `MoveCard.slot` 一并删。
- **装备帮助函数的落点**（2026-09-29 实现时定）：装在 `Player` 上（`equipZoneOf` / `equipCard` / `equipCards` 那个 `__getter`），与 `Player:distance` 同一口径 —— 不另开裸全局函数（也免得压 `lowercase-global`）。
- **装备子区的扩展点**（2026-09-29 用户定）：子区名单在共享袋 `rule.equipZones` —— **`rule` 由装载器每轮装载建一张空表并注入**（与 `game` / `Card` / `Depends` / `Class` / `New` 并列；`@基础` 不建它）；别的包加载期往后追加就扩展了子区，不写防御（名称重复就撞名报错、分类对不上就不装）；**可空的取用（`getZone` / `zone.owner`）顺着可空走**（拿不到就不做 / 返回空），不 `assert` 也不 `---@cast`。
- **buff 实际做，不用临时闭包方案**（用户 2026-09-29）；挂载点先只 `Player`、同名实例并存、`remove`。**挂上时可给一份载荷**（`addBuff(名字, 载荷?)` → `buff.payload`，内核只存不解释）；**不读「当前正在结算的效果」那种环境值**（用户 2026-09-30 定：它是栈式、`await` 过就读错，还得内核另立对外承诺）。
- **青釭剑时机**：压 + 兜底都在一处 —— 卡牌在 `owner:on('卡牌-结算前')`（**使用者头上那一份**）对全目标 `useCard:bindGC(target:addBuff('防具无效', useCard))`（**一次做完**，窗口不随剑 / 使用者消失；状态随那次使用被删而删）；松 = 状态自己订 `buff.owner:on('效果-收尾')`（**当事人头上那一份**，只需比 `effect.useCard == 给它的那次使用`）。官方两则裁定见该变更的 `design.md`。
- **「对当事人再发一份」两个时机**（用户 2026-09-30 定，都是照 `'阶段-开始'` 的先例：**全局先发、再对当事人发**，当事人为空就不发）：`'效果-收尾'` → `effect.to`（承受者，「冲我来的效果结完了」）；`'卡牌-结算前'` → `useCard.user`（使用者，「我用的牌开始结算了」）。内容侧想只关心自己那份就订 `player:on(...)`，不用再比字段。
- **`'效果-收尾'` 每次结算结完都发一次**（2026-09-29 用户定「先单独做」，已落地）；默认弃牌改批量 `discard:accept(zone:list())`。**代价：收尾变成可重入** —— 处理器里起的结算（`game:moveCard` / `game:damage`…）也会发收尾 ⇒ **订阅方按载荷过滤，且别在收尾里起新结算**。
- **两根安全阀，判断都在 `bindFinish` 之前**（2026-09-29 用户定，已落地）：`Effect.MAX_DEPTH = 150`（嵌套深度）+ `Effect.MAX_CHILDS = 1000`（一次结算挂的子结算数）；越限那层**不结算也不发收尾** ⇒ 自激链截在 150 层（探针：改前约 276 层爆栈，改后正常返回）。
- **任务模型（2026-09-29 用户逐条定，已落地）**：① `resolve` / `reject` **只记结果**，收口（叫回调 + 叫醒等待者 + 收掉执行体）**只有 `Delete` 会走到**（`Task:__del`）—— 驱动层在执行体末尾 `Delete(self)`；② `cancel` **优先级最高**（结果已定也强行改成「取消」），`setTimeout` / `__close` / `Effect:cancel` 全走它，「已完结就不能再取消」读 **`IsValid(self)`**（不另立字段）；③ **一个任务一条协程**（`executeSync` 立即跑 / `executeAsync` 排一笔调度），只能驱动一次；④ **停住自己的执行体**：`cancel` 里 `Delete` 之后让出一笔调度，`__del` 早先已把「关掉这条协程」**登记到下一笔调度**（`moe.await.wake`）—— **不要**在 `__del` 里让出（会把 `GCHost:__del` 放 GC 绑定那步丢掉），也不靠「不能关当前协程」（实测可以关）；⑤ **唤醒不内联**（`resolveAwaitings` 登记到下一笔调度）+ `Effect:apply` 用 `executeAsync` ⇒ C 栈与逻辑深度脱钩；⑥ **`apply()` 只驱动（排队）**，要「起了就等」写 **`apply():await()`** —— 用例里 `apply()` 之后立刻读结果会读到空值。

## 待办 / 悬着的事

- **下一个功能点由用户定**（见 `progress.md` §2 的候选表）；`add-buff-system` 与 `add-qinggang-sword` 两批均已落地（**未提交**）—— 后者是 Buff 的第一个消费者（区级压制 + `bindGC`）。
- `add-zhuge-crossbow` 是个**空壳**（目录里只有 `.openspec.yaml`，无工件；诸葛连弩的活已提交）—— 等用户定：删 / 补 / 归档。
- 另有 `add-worker-mode`（1/16，另一条线）：玩家时机表的重装退役挂它上面。
- 已归档（本次会话）：`rework-zone-disable` / `replace-slot-zone-with-equip-zones` / `add-delayed-trick-cards` —— 三个归档目录的**移动尚未提交**（`git status` 里是 `??` / `R`）。
- 已知边界（记在 `add-qinggang-sword` 的 non-goals 与 `sanguosha-rules` §9.11）：官方「窗口内失去防具、其『失去时』技能也不能发动」（【白银狮子】那类裁定）本批做不到 —— 牌离区时区级压制就松了。

## 常用命令

- 全量测试 `server/bin/moe-kill.exe --test`；单套件 `server/bin/moe-kill.exe --test rule.equip`。
- **平时只改 Lua 不需要构建**；动了 C/C++、`make.lua`、`make/lua-patch/**`、`3rd/bee.lua` 才 `luamake -notest`。
- 变更：`openspec list` / `openspec status --change <名字>` / `openspec validate --all`。
- 提交（**用户说「提交」才许**）：`git add -A -- .agents package server openspec AGENTS.md HANDOVER.md`，消息 `-m` 多段、禁用 ASCII 单引号（用「」）。
