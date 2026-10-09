# 设计：观星 / 空城 + 两处内核能力

## D1 内核：有序牌区的「置于区顶 / 区底」

```lua
--- 把一批牌按给定顺序置于区顶（第一张最靠顶）
---@param cards Card[]
function OrderedZone:placeTop(cards)

--- 把一批牌按给定顺序置于区底（第一张更靠上、最后一张最靠底）
---@param cards Card[]
function OrderedZone:placeBottom(cards)
```

- **顺序约定写在方法名上**：`cards[1]` 更靠**顶**（与 `peek(1)` / `draw` 的「1 = 顶」一致）。观星就是把「答复里的第一张」放成新牌堆顶。
- **为什么不只加 `placeTop`**（用户 2026-10-09 选 A）：`placeBottom` 与今天的 `accept`（追加到列表尾 = 区底）语义相同，单列出来**是为了让「顺序约定」只有一处可读**；底本 `Ch1/S2:89` 的「弃牌以随机顺序置于牌堆**底**」也正好用它（见 D2）。
- **为什么不做成效果**（否掉 `game:moveCard(牌, 区, 可见性?, 位置?)`）：位置是**牌区自己的能力**（`draw` / `shuffle` / `accept` 都在牌区上），而且「取顶 / 放回顶」这类操作在底本里是**操作的一部分**（观星 = 观看 + 放回，同一次发动；摸牌 = 取顶 + 挪进手牌），归因由外层的 `skill:cast` 承担就够 —— 不必给内容侧的主入口加参数。
- `Zone:accept` 保持「收牌的唯一入口」不变（它仍然是「进那个区」的通用语义）。

## D2 牌堆不足：本批**不动**（2026-10-09 核对结论）

**结论：现状已与底本一致，不改内核。** 逐行核过：不足回调只在「已经取空」那一刻触发（`#self.cards == 0`），那时顶上原有的牌**早已被取走** ⇒ `moveCard(弃牌 → 牌堆)` 搬进来的是弃牌堆的全部、紧接着的整堆 `shuffle()` 洗的**正是这批** ⇒ 等价于底本 ②「将弃牌堆里的所有牌以随机顺序置于牌堆底」；③（牌堆 = 0 ⇒ 先洗牌）与 ①（都不够 ⇒ 平局）也各自吻合。

**唯一残留 = 执行顺序**：「连弃牌都不够」时底本先判平局、**不取牌**；现状取到取不动再判（已取走的那几张留在结果里）。局面已终局、实际玩不出差别，记进 `architecture.md` 当**已知偏离**（将来真要严格对齐就照下面那份形状改）。

底本原文（备查）：

> 对于操作牌堆里的 X 张牌来说，若牌堆里的牌数小于 X，其依然能执行此操作：① 若（牌堆 + 弃牌）＜ X ⇒ 执行此操作即**游戏以平局结束**；② 若 0 ＜ 牌堆 ＜ X 且（牌堆 + 弃牌）≥ X ⇒ 执行此操作前由系统将弃牌堆里的所有牌**以随机顺序置于牌堆底**；③ 若牌堆 = 0 且 弃牌 ≥ X ⇒ 执行此操作前**先洗牌**。（`Ch2/S8:183` 定义洗牌 = 弃牌全置入牌堆 + 整堆洗混。）

**若将来真要严格对齐 ① 的执行顺序，形状是（本批不做，备查）**：
- `OrderedZone:draw(count)` **取之前**先算一次缺口（`need = count - #cards`），`need > 0` 才叫回调；之后照旧逐张取（这时牌够或游戏已判平局）。
- 回调签名从 `fun(zone)` 改成 `fun(zone, need: integer)`（`need` = 还差几张）—— 现在的回调拿不到 X，所以只能在「已经取空」那一刻补，无法实现 ① 的「先判平局、这次操作不发生」。

```lua
deck:setShortageHandler(function (zone, need)
    if zone:count() + discard:count() < need then
        game:endGame { side = '平局', reason = '牌堆与弃牌堆都没有牌' }   -- ①（文案沿用既有）
        return
    end
    if zone:count() == 0 then
        game:moveCard(discard:list(), zone)   -- ③ 先洗牌
        zone:shuffle()
        return
    end
    local cards = discard:list()              -- ② 弃牌洗混后置于牌堆底
    game.random:shuffle(cards)                -- 用户 2026-10-09 定：走 game.random
    zone:placeBottom(cards)
end)
```

- 真做时的其余注意：随机源用 `game.random`（用户 2026-10-09 定，与 `deck:shuffle()` 共用同一份）；`core/zone.lua` 那条「取空了会调不足回调」的用例要按新签名改。

## D3 内容：观星

```
'阶段-开始'（phase.name == '准备'）
  ⇒ skill:tryCast(function (cast)          -- 「可以」⇒ 先问一句（【洛神】同款）
        local x    = math.min(#game.desk.alivePlayers, 5)
        local seen = deck:draw(x)          -- 顶 X 张（不足照既有不足回调收：要么补上、要么平局）
        local shown = cast:getTempZone()   -- 观看 = 进自己这次发动的临时区
        shown:setVisible(skill.owner)      -- 先把区藏好（只有他看得见，【遗计】同款）
        game:moveCard(seen, shown)         -- 再把牌搬进来（不留「大家都看得见」那一瞬）
        local top, bottom = arrange(seen)  -- ⚠️ 服务器暂定（见下）
        deck:placeTop(top)
        deck:placeBottom(bottom)
     end)
```

- **时机**：`'阶段-开始'` + `phase.name == '准备'`（【洛神】已用这条）。
- **X**：`math.min(#game.desk.alivePlayers, 5)`（「存活角色数且至多为 5」）。
- **观看**：取到自己这次发动的临时区 + `setVisible(owner)`（【遗计】/【五谷丰登】的现成写法）。
- **⚠️ 分配由服务器暂定**（用户 2026-10-09 定：**「排列」询问类先跳过**）：本批用一个显式标注的占位分配 —— **把观看的牌逆序置于牌堆顶**、其余（空）置于牌堆底。选它只因为「任意 + 一眼看得出观星跑过 + 牌一张不多不少」，**不代表任何策略**；等「排列」询问类到位后整段换成玩家的答复（`deck:placeTop(答复的顶堆)` / `deck:placeBottom(答复的底堆)`，形状不必再动）。

## D4 内容：空城

```lua
Skill '空城'
    : tags '锁定技'
    : event('卡牌-目标-能否指定', function (skill, plan)
        if skill.owner:getZone('手牌'):count() > 0 then
            return
        end
        local name = plan.card.name
        if name == '杀' or name == '决斗' then
            return '空城'
        end
    end)
```

- **用技能侧那份 hook**（`SkillDef:event('卡牌-目标-能否指定', fun(skill, plan))`，【谦逊】同款）：`game:getLegalTargets` 逐候选过完牌的 `filter` 后再问候选者自己一句，返回非空即**剔出候选** ⇒ 「不能被选择为目标」正是这个语义。
- **判据是动态的**（每次筛候选现算「此刻有没有手牌」）⇒ 不需要清理 / 撤销。
- **锁定技 ⇒ 没有 `confirm`**：它是「候选阶段自动生效」的状态类效果，不走 `tryCast`。
- **口径注（本批只记不做）**：`useCard:addTarget` 是裸追加、**不过这一关** —— 底本 `Ch2/S5:298`（【求援】把没手牌的诸葛亮「也成为目标」）要求挡得住 ⇒ **加目标要走 `game:getLegalTargets` 筛过的名单**（【流离】就是这么写的）。将来出现绕过它的技能时再谈要不要在内核里补一道。

## D5 被否 / 推迟

- **「排列」询问类**（`AskArrange` 之类）：**推迟**（用户 2026-10-09 定：形状先想一想）。候选形状记在这里备查 —— ① **堆的有序列表**（答复 `{ {顶堆…}, {底堆…} }`，堆数由发起方给；「任意数量放顶」= `#groups[1]`，两堆顺序都能给）；② 一个排列 + 切点（`{ order, cut }`）；③ 一个排列 + 每张的堆号数组。
- **`game:moveCard` 的位置变体**：否，理由见 D1。
- **通用「插入到第 n 位」**：不做 —— 只做「顶 / 底」两个内容侧真的有的语义（将来真需要再按新形状加）。

## D6 落点

| 面 | 文件 | 改什么 |
| --- | --- | --- |
| 内核 | `server/core/ordered-zone.lua` | `placeTop` / `placeBottom`（顺序约定「1 = 顶」） |
| 内容 | `package/标准/武将/诸葛亮.lua`（新） | `Hero '诸葛亮'`（蜀 / 男 / 3）+ `Skill '观星'` + `Skill '空城'` |
| 用例 | `server/test/core/zone.lua` | `placeTop` / `placeBottom` 的顺序、已在区内的牌、空列表 |
| 用例 | `server/test/rule/hero-skill.lua` | 观星（观看 / 放回 / X 的上限 / 不发动）+ 空城（有牌可指定、没牌挡【杀】【决斗】、别的牌不挡、视为的【杀】也挡） |
| 文档 | `moe-kill-dev/references/architecture.md` | `OrderedZone` 的位置能力 + 不足回调签名与口径；`game:getLegalTargets` 行的「加目标」口径注 |
| 文档 | `sanguosha-rules` | §9.x 诸葛亮（观星 / 空城 + 底本引文）；缺口表「置入牌堆顶 / 底」划掉 |
| 文档 | `moe-kill-dev/references/progress.md` | 基线、本批条目 |

## D7 反向验证（实测）

| 拆掉什么 | 结果 |
| --- | --- |
| `placeTop` 退化成 `accept`（置顶变置底） | **4 红**（牌区两条 + 观星两条 —— 它们都钉着顶上的顺序） |
| 观星两行放回（`placeTop` + `placeBottom`）整段注掉 | **2 红**（牌堆少牌 / 临时区没清空） |
| 拆掉空城的 hook | **2 红**（两条挡选目标的用例；「有手牌」「别的牌」那两条照旧绿 ✓） |
| 只注掉 `placeBottom(bottom)` | **0 红** —— 占位的底堆是空的 ⇒ 这条调用本批**测不出来**（记为已知覆盖缺口，等「排列」询问类落地时一并钉） |

## D8 落地时踩到的三处（记下来免得下次再踩）

- **「先藏好区、再搬牌」**（用户 2026-10-09 指出我把顺序写反了）：`getTempZone()` 出来的区默认 `visible = true` ⇒ 先搬牌再 `setVisible` 的话，牌有一瞬落在「大家都看得见」的区里（搬牌是个效果、里面有 `await`）。正确顺序：【遗计】那种写法 —— `getTempZone()` → `setVisible(owner)` → 再搬。用例钉住了它（搬牌生效前那一刻断言 `isVisibleTo(别人) == false`，翻回去就红）。
- **牌区事件不发到局上**：`'卡牌-进入区域'` / `'卡牌-离开区域'` 只发给**牌自己**（按牌定义）与**区的主人**，`game:on(...)` **收不到** ⇒ 想观察「牌进过哪个区」不能订局上那份（用例改成：抓这次 `cast` 的临时区 + 看 `isVisibleTo`）。
- **`canUse` 的两种拒收文案**：候选被清空时是「「标准.杀」现在没有合法目标」，显式传了非法目标才是「「标准.杀」不能以这个角色为目标」—— 2 人局里前者先发生（候选直接空了）。
