---@meta

-- 本文件只声明注入环境的类型：环境对象本身、内容定义入口、以及 game 上的**事件**（按名收窄 on/fire 的上下文）。
-- Game 上其余入口（askCard / moveCard / drawCards …）的声明在 `server/core/game.lua`，别往这里抄一份。
-- 内核建好的四个基础牌区（局上 `抽牌` / `弃牌`，玩家身上 `手牌` / `判定`）是**对内容侧的约定**：包可以直接取（`game:getZone('弃牌')`），但不得重建同名区；声明见 `game.lua` / `player.lua` 里 getZone 的重载。

---@type Game
game = nil

---@type fun(name: string): CardDef
Card = nil

---@type fun(name: string): BuffDef
Buff = nil

---@type fun(name: string): HeroDef
Hero = nil

---@type fun(name: string): SkillDef
Skill = nil

--- 建一块牌面（把一批牌摊成若干行，可以在上面摆 / 挑）
---@type fun(name: string, visible?: Visibility, options?: Panel.Options): Panel
createPanel = nil

---@type fun(items: string[])
Depends = nil

--- 内容侧共享的规则数据袋：装载器每轮装载给一张新的空表（内核不认识里面的东西 —— 字段由内容侧自己声明，如 `@基础/meta.lua` 里的 `equipZones`）
---@class Loader.Rule
---@type Loader.Rule
rule = nil

--- 牌的钩子是**固定**的：名字由内核约定、与启用的包无关，清单以本文件为准（不留 string 兜底，拼错在编辑期就报）
---@class CardDef
---@field on fun(self: CardDef, event: '卡牌-进入区域', handler: fun(card: Card, zone: Zone, visible?: Visibility): any): CardDef # 这张牌进入某个牌区之后跑（只有有归属者的区会发；`visible` = 这次搬动对谁可见，不给 = 源区可见 or 目标区可见）
---@field on fun(self: CardDef, event: '卡牌-离开区域', handler: fun(card: Card, zone: Zone, visible?: Visibility): any): CardDef # 这张牌离开某个牌区时跑（发的时候它已经不在那个区里）
---@field on fun(self: CardDef, event: '使用', handler: fun(useCard: UseCard|UseCardToCard)): CardDef # 使用结算开始时跑一次（逐目标之前；声明了 skipEffect 的牌就到这）
---@field on fun(self: CardDef, event: '生效', handler: fun(cardEffect: CardEffect, useCard: UseCard?)): CardDef # 一次生效（使用期逐目标 / 判定阶段每张一次）
---@field on fun(self: CardDef, event: '被动', handler: fun(card: Card, zone: Zone, host: GCHost)): CardDef # 被动启用时跑一次：要挂什么就 `host:bindGC(…)`（停用时内核释放容器）
--- **订阅时机**用 `event`（订**这张牌的主人**头上那份）/ `globalEvent`（订局上那份）：只做订阅与生命周期 —— **要不要发动（`card:cast(…)`）由回调自己写**（与 `'被动'` 里手写 `owner:on(…)` 等价）；时机名开放 ⇒ 这里只列内核常用几条、其余走 `fun(card: Card, ...: any)` 兜底，内容侧时机的重载住 `package/@基础/meta.lua`
---@field event fun(self: CardDef, name: '卡牌-来源-结算前', handler: fun(card: Card, useCard: UseCard|UseCardToCard): any): CardDef # 主人使用的牌开始结算（订主人那份）
---@field event fun(self: CardDef, name: '卡牌-进入区域', handler: fun(card: Card, zone: Zone, visible?: Visibility): any): CardDef # 主人名下的区里有牌进来（牌自己那份由 `on('卡牌-进入区域')` 收；公共区没有主人、不发）
---@field event fun(self: CardDef, name: '卡牌-离开区域', handler: fun(card: Card, zone: Zone, visible?: Visibility): any): CardDef # 主人名下的区里有牌离开（同上）
---@field event fun(self: CardDef, name: '卡牌-来源-使用选项', handler: fun(card: Card, check: Game.Event.卡牌使用选项): (Game.UseOptionsInput?)): CardDef # 主人这次使用的选项（**收集式**：返回值会被 `fire` 收走；跑在 `game:collect` 里 ⇒ 别在里面 await）
---@field event fun(self: CardDef, name: '卡牌-来源-指定目标后', handler: fun(card: Card, useCard: UseCard, target: Player): any): CardDef
---@field event fun(self: CardDef, name: '卡牌-目标-指定目标后', handler: fun(card: Card, useCard: UseCard, target: Player): any): CardDef # 主人自己被指定为目标后（逐目标；全局那份之外、对目标再发一份）
---@field event fun(self: CardDef, name: '卡牌-目标-能否指定', handler: fun(card: Card, plan: CardDef.TargetPlan): any): CardDef # 别人要用牌指定主人时问一句（返回非空 = 不能指定他）
---@field event fun(self: CardDef, name: '效果-来源-被响应', handler: fun(card: Card, ask: AskPlayCard): any): CardDef # 主人发起的那次生效被响应了（算不算抵消由内容侧自己按缘由 / 牌名判）；要驳回就用 `ask:cancel(原因)`（不会返回）
---@field event fun(self: CardDef, name: '效果-来源-能否生效', handler: fun(card: Card, effect: Effect): any): CardDef # 询问要不要阻止这一次生效（第二段：问来源，`effect.from`）；返回非 nil 即阻止
---@field event fun(self: CardDef, name: '效果-目标-能否生效', handler: fun(card: Card, effect: Effect): any): CardDef # 被问的是不是主人自己（`effect.to`）；回调返回字符串就是否决原因
---@field event fun(self: CardDef, name: '阶段-开始', handler: fun(card: Card, phase: Phase): any): CardDef
---@field event fun(self: CardDef, name: '阶段-生效', handler: fun(card: Card, phase: Phase): any): CardDef
---@field event fun(self: CardDef, name: '阶段-结束', handler: fun(card: Card, phase: Phase): any): CardDef
---@field event fun(self: CardDef, name: '效果-收尾', handler: fun(card: Card, effect: Effect): any): CardDef
---@field event fun(self: CardDef, name: string, handler: fun(card: Card, ...: any): any): CardDef
---@field globalEvent fun(self: CardDef, name: '游戏-开始', handler: fun(card: Card, event: Game.Event.游戏开始): any): CardDef
---@field globalEvent fun(self: CardDef, name: '卡牌-结算前', handler: fun(card: Card, useCard: UseCard|UseCardToCard): any): CardDef
---@field globalEvent fun(self: CardDef, name: '卡牌-结算后', handler: fun(card: Card, useCard: UseCard|UseCardToCard): any): CardDef
---@field globalEvent fun(self: CardDef, name: '卡牌-使用选项', handler: fun(card: Card, check: Game.Event.卡牌使用选项): (Game.UseOptionsInput?)): CardDef # **收集式**（跑在 `game:collect` 里 ⇒ 别在里面 await）
---@field globalEvent fun(self: CardDef, name: '卡牌-指定目标后', handler: fun(card: Card, useCard: UseCard, target: Player): any): CardDef # 逐目标发（全局那份）
---@field globalEvent fun(self: CardDef, name: '卡牌-能否使用', handler: fun(card: Card, check: Game.Event.卡牌能否使用): any): CardDef
---@field globalEvent fun(self: CardDef, name: '效果-能否生效', handler: fun(card: Card, effect: Effect): any): CardDef # 询问要不要阻止这一次生效（第一段：问全局）；返回非 nil 即阻止
---@field globalEvent fun(self: CardDef, name: '效果-被响应', handler: fun(card: Card, ask: AskPlayCard): any): CardDef
---@field globalEvent fun(self: CardDef, name: '效果-收尾', handler: fun(card: Card, effect: Effect): any): CardDef
---@field globalEvent fun(self: CardDef, name: '玩家-死亡', handler: fun(card: Card, player: Player): any): CardDef
---@field globalEvent fun(self: CardDef, name: '回合-开始', handler: fun(card: Card, turn: Game.Event.Turn): any): CardDef
---@field globalEvent fun(self: CardDef, name: '回合-结束', handler: fun(card: Card, turn: Game.Event.Turn): any): CardDef
---@field globalEvent fun(self: CardDef, name: '阶段-开始', handler: fun(card: Card, phase: Phase): any): CardDef
---@field globalEvent fun(self: CardDef, name: '阶段-生效', handler: fun(card: Card, phase: Phase): any): CardDef
---@field globalEvent fun(self: CardDef, name: '阶段-结束', handler: fun(card: Card, phase: Phase): any): CardDef
---@field globalEvent fun(self: CardDef, name: '游戏-结束', handler: fun(card: Card, result: Game.Result): any): CardDef
---@field globalEvent fun(self: CardDef, name: string, handler: fun(card: Card, ...: any): any): CardDef

--- 状态的时机是**固定**的：名字由内核约定、与启用的包无关（清单以本文件为准，不留 string 兜底）
---@class BuffDef
---@field on fun(self: BuffDef, event: '获得', handler: fun(buff: Buff)): BuffDef # 挂到某人身上之后跑一次（在这里挂资源 / 订阅：`buff:bindGC(...)`）
---@field on fun(self: BuffDef, event: '失去', handler: fun(buff: Buff)): BuffDef # 失去时跑一次（资源已经挂在 bindGC 上，这里只在「真的需要知道」时才用）

--- 技能的**钩子**是固定集合：名字由内核约定、与启用的包无关（所以不留 string 兜底，拼错在编辑期就报）
--- **订阅时机**用 `event`（订技能主人头上那份）/ `globalEvent`（订局上那份）：只做订阅与生命周期 —— **要不要发动（`skill:tryCast`）由回调自己写**（与 `'被动'` 里手写 `owner:on(…)` 等价，省的是那两层壳）；时机名开放 ⇒ 这里只列内核常用几条、其余走 `fun(skill: Skill, ...: any)` 兜底，内容侧时机（伤害 / 治疗 / 判定）的重载住 `package/@基础/meta.lua`
---@class SkillDef
---@field on fun(self: SkillDef, event: '被动', handler: fun(skill: Skill, host: GCHost)): SkillDef # 技能挂上时跑一次（要挂什么就 `host:bindGC(…)`；停用时内核释放容器）
---@field on fun(self: SkillDef, event: '使用', handler: fun(cast: SkillCast)): SkillDef # 主动发动时跑（`cast` = 这次发动：`cast.source` 技能 / `cast.from` 发动者 / `cast.use` 带的牌与目标）
---@field event fun(self: SkillDef, name: '卡牌-来源-结算前', handler: fun(skill: Skill, useCard: UseCard|UseCardToCard): any): SkillDef # 自己使用的牌开始结算（订自己那份）
---@field event fun(self: SkillDef, name: '卡牌-来源-使用选项', handler: fun(skill: Skill, check: Game.Event.卡牌使用选项): (Game.UseOptionsInput?)): SkillDef # 自己这次使用的选项（**收集式**：回调返回值会被 `fire` 收走；它跑在 `game:collect` 里 ⇒ 别在里面 await）
---@field event fun(self: SkillDef, name: '卡牌-进入区域', handler: fun(skill: Skill, card: Card, zone: Zone, visible?: Visibility): any): SkillDef # 主人名下的区里有牌进来（公共区没有主人、不发）
---@field event fun(self: SkillDef, name: '卡牌-离开区域', handler: fun(skill: Skill, card: Card, zone: Zone, visible?: Visibility): any): SkillDef # 主人名下的区里有牌离开（【枭姬】用它）
---@field event fun(self: SkillDef, name: '阶段-开始', handler: fun(skill: Skill, phase: Phase): any): SkillDef
---@field event fun(self: SkillDef, name: '阶段-生效', handler: fun(skill: Skill, phase: Phase): any): SkillDef
---@field event fun(self: SkillDef, name: '阶段-结束', handler: fun(skill: Skill, phase: Phase): any): SkillDef
---@field event fun(self: SkillDef, name: '效果-收尾', handler: fun(skill: Skill, effect: Effect): any): SkillDef
---@field event fun(self: SkillDef, name: '卡牌-来源-指定目标后', handler: fun(skill: Skill, useCard: UseCard, target: Player): any): SkillDef
---@field event fun(self: SkillDef, name: '卡牌-目标-指定目标后', handler: fun(skill: Skill, useCard: UseCard, target: Player): any): SkillDef # 主人自己被指定为目标后（逐目标；全局那份之外、对目标再发一份；【流离】用它）
---@field event fun(self: SkillDef, name: '效果-来源-能否生效', handler: fun(skill: Skill, effect: Effect): any): SkillDef # 询问要不要阻止这一次生效（第二段：问来源，`effect.from`）；返回非 nil 即阻止
---@field event fun(self: SkillDef, name: '效果-目标-能否生效', handler: fun(skill: Skill, effect: Effect): any): SkillDef
---@field event fun(self: SkillDef, name: '卡牌-目标-能否指定', handler: fun(skill: Skill, plan: CardDef.TargetPlan): any): SkillDef # 别人要用牌指定目标时问自己一句（返回非空 = 不能指定我，返回值就是原因；【谦逊】用它）
---@field event fun(self: SkillDef, name: string, handler: fun(skill: Skill, ...: any): any): SkillDef
---@field globalEvent fun(self: SkillDef, name: '游戏-开始', handler: fun(skill: Skill, event: Game.Event.游戏开始): any): SkillDef
---@field globalEvent fun(self: SkillDef, name: '卡牌-结算前', handler: fun(skill: Skill, useCard: UseCard|UseCardToCard): any): SkillDef
---@field globalEvent fun(self: SkillDef, name: '卡牌-结算后', handler: fun(skill: Skill, useCard: UseCard|UseCardToCard): any): SkillDef
---@field globalEvent fun(self: SkillDef, name: '卡牌-使用选项', handler: fun(skill: Skill, check: Game.Event.卡牌使用选项): (Game.UseOptionsInput?)): SkillDef # **收集式**（跑在 `game:collect` 里 ⇒ 别在里面 await）
---@field globalEvent fun(self: SkillDef, name: '卡牌-指定目标后', handler: fun(skill: Skill, useCard: UseCard, target: Player): any): SkillDef # 逐目标发（全局那份）
---@field globalEvent fun(self: SkillDef, name: '卡牌-能否使用', handler: fun(skill: Skill, check: Game.Event.卡牌能否使用): any): SkillDef
---@field globalEvent fun(self: SkillDef, name: '效果-能否生效', handler: fun(skill: Skill, effect: Effect): any): SkillDef # 询问要不要阻止这一次生效（第一段：问全局）；返回非 nil 即阻止
---@field globalEvent fun(self: SkillDef, name: '效果-被响应', handler: fun(skill: Skill, ask: AskPlayCard): any): SkillDef
---@field globalEvent fun(self: SkillDef, name: '效果-收尾', handler: fun(skill: Skill, effect: Effect): any): SkillDef
---@field globalEvent fun(self: SkillDef, name: '玩家-死亡', handler: fun(skill: Skill, player: Player): any): SkillDef
---@field globalEvent fun(self: SkillDef, name: '回合-开始', handler: fun(skill: Skill, turn: Game.Event.Turn): any): SkillDef
---@field globalEvent fun(self: SkillDef, name: '回合-结束', handler: fun(skill: Skill, turn: Game.Event.Turn): any): SkillDef
---@field globalEvent fun(self: SkillDef, name: '阶段-开始', handler: fun(skill: Skill, phase: Phase): any): SkillDef
---@field globalEvent fun(self: SkillDef, name: '阶段-生效', handler: fun(skill: Skill, phase: Phase): any): SkillDef
---@field globalEvent fun(self: SkillDef, name: '阶段-结束', handler: fun(skill: Skill, phase: Phase): any): SkillDef
---@field globalEvent fun(self: SkillDef, name: '游戏-结束', handler: fun(skill: Skill, result: Game.Result): any): SkillDef
---@field globalEvent fun(self: SkillDef, name: string, handler: fun(skill: Skill, ...: any): any): SkillDef

--- 开局**准备**（比「游戏-开始」更早的一步：发身份 / 选将都发生在它里面）—— 同样没有事件参数，触发时给空表
---@class Game.Event.游戏准备

--- 目前没有事件参数：触发时给空表，环境对象从 game 取
---@class Game.Event.游戏开始

--- 回合级时机：谁是回合角色
---@class Game.Event.Turn
---@field player Player # 回合角色

--- 这张牌此刻能不能用：返回非 nil 值即否决（返回值就是原因）
---@class Game.Event.卡牌能否使用
---@field user Player # 使用者
---@field card Card # 要用的牌
---@field targets? Player[] # 要校验的角色目标（省略 = 只判「此刻能不能用」）
---@field target? Card # 要校验的牌目标（对牌使用这一支才有）

--- 这次使用的选项：每个订阅者返回一份 `Game.UseOptionsInput`（没有贡献就不返回）
---@class Game.Event.卡牌使用选项
---@field user Player # 使用者
---@field card Card # 要用的牌

---@class Game
---@field rule Loader.Rule # 这一轮装载的规则数据袋（与内容侧那个全局 `rule` 是同一张表）
---@field setValue fun(self: Game, name: string, value: any) # 记一条临时数据（内核不解释名字；规则数值请写进 `rule`）
---@field setValues fun(self: Game, values: table<string, any>)
---@field getValue fun(self: Game, name: string): any
---@field getValues fun(self: Game): table<string, any>
---@field on fun(self: Game, name: '游戏-准备', callback: fun(event: Game.Event.游戏准备): any): function # 开局准备（比「游戏-开始」更早的一步：发身份 / 选将）—— **由装配侧 fire**，内核不代劳
---@field fire fun(self: Game, name: '游戏-准备', event: Game.Event.游戏准备): any
---@field on fun(self: Game, name: '游戏-开始', callback: fun(event: Game.Event.游戏开始): any): function
---@field fire fun(self: Game, name: '游戏-开始', event: Game.Event.游戏开始): any
---@field on fun(self: Game, name: '效果-能否生效', callback: fun(effect: Effect): any): function # 询问要不要阻止这一次生效（第一段：问全局）：返回非 nil 即阻止（返回值就是原因）
---@field fire fun(self: Game, name: '效果-能否生效', effect: Effect): any # 返回值就是那条阻止的原因
---@field on fun(self: Game, name: '效果-收尾', callback: fun(effect: Effect): any): function # 每次结算结完都发一次（载荷 = 效果自己）
---@field fire fun(self: Game, name: '效果-收尾', effect: Effect): any
---@field on fun(self: Game, name: '效果-被响应', callback: fun(ask: AskPlayCard): any): function # 一次生效被响应了（要驳回就在回调里 `ask:cancel(原因)` —— 调用后不会返回；本时机不读返回值）
---@field fire fun(self: Game, name: '效果-被响应', ask: AskPlayCard): any
---@field on fun(self: Game, name: '卡牌-询问', callback: fun(askCard: AskCard|AskCardWithTarget|AskUseCard|AskUseCardToCard|AskPlayCard): any): function # 问应答方要答复：**第一个给出答复的胜出（后面的订阅者不再调）**；返回空 = 不表态
---@field fire fun(self: Game, name: '卡牌-询问', askCard: AskCard|AskCardWithTarget|AskUseCard|AskUseCardToCard|AskPlayCard): any # 返回值就是答复（`AskCard.Answer`；没人表态给空）
---@field on fun(self: Game, name: '卡牌-答复', callback: fun(askCard: AskCard|AskCardWithTarget|AskUseCard|AskUseCardToCard|AskPlayCard): any): function
---@field fire fun(self: Game, name: '卡牌-答复', askCard: AskCard|AskCardWithTarget|AskUseCard|AskUseCardToCard|AskPlayCard): any
---@field on fun(self: Game, name: '卡牌-答复后', callback: fun(askCard: AskCard|AskCardWithTarget|AskUseCard|AskUseCardToCard|AskPlayCard): any): function
---@field fire fun(self: Game, name: '卡牌-答复后', askCard: AskCard|AskCardWithTarget|AskUseCard|AskUseCardToCard|AskPlayCard): any
---@field on fun(self: Game, name: '卡牌-能否使用', callback: fun(check: Game.Event.卡牌能否使用): any): function
---@field fire fun(self: Game, name: '卡牌-能否使用', check: Game.Event.卡牌能否使用): any # 返回值就是那条否决原因
---@field on fun(self: Game, name: '卡牌-使用选项', callback: fun(check: Game.Event.卡牌使用选项): (Game.UseOptionsInput?)): function # 这次使用选项的全局那份（使用者身上还有一份）
---@field collect fun(self: Game, name: '卡牌-使用选项', check: Game.Event.卡牌使用选项): Game.UseOptionsInput[] # 收集每个来源贡献的选项片段（这就是上面那条的收集式叫法）
---@field collect fun(self: Game, name: string, ...: any): any[] # 动态时机名走这条（收集所有回调的第一个返回值）
---@field on fun(self: Game, name: '卡牌-变化', callback: fun(card: Card): any): function # 一张牌自己变了（牌名 / 花色 / 点数这类，没换区）
---@field fire fun(self: Game, name: '卡牌-变化', card: Card): any
---@field on fun(self: Game, name: '卡牌-进入区域', callback: fun(card: Card, zone: Zone, visible?: Visibility): any): function # 任何一张牌进了某个区（牌定义那份与区主人那份之外、再在局上发一份）
---@field fire fun(self: Game, name: '卡牌-进入区域', card: Card, zone: Zone, visible?: Visibility): any
---@field on fun(self: Game, name: '卡牌-离开区域', callback: fun(card: Card, zone: Zone, visible?: Visibility): any): function # 任何一张牌离开了某个区（同上）
---@field fire fun(self: Game, name: '卡牌-离开区域', card: Card, zone: Zone, visible?: Visibility): any
---@field on fun(self: Game, name: '卡牌-结算前', callback: fun(useCard: UseCard|UseCardToCard): any): function
---@field fire fun(self: Game, name: '卡牌-结算前', useCard: UseCard|UseCardToCard): any
---@field on fun(self: Game, name: '卡牌-结算后', callback: fun(useCard: UseCard|UseCardToCard): any): function
---@field fire fun(self: Game, name: '卡牌-结算后', useCard: UseCard|UseCardToCard): any
---@field on fun(self: Game, name: '卡牌-指定目标后', callback: fun(useCard: UseCard, target: Player): any): function # 逐目标发（全局那份）
---@field fire fun(self: Game, name: '卡牌-指定目标后', useCard: UseCard, target: Player): any
---@field on fun(self: Game, name: '玩家-死亡', callback: fun(player: Player): any): function
---@field fire fun(self: Game, name: '玩家-死亡', player: Player): any
---@field on fun(self: Game, name: '回合-开始', callback: fun(turn: Game.Event.Turn): any): function
---@field fire fun(self: Game, name: '回合-开始', turn: Game.Event.Turn): any
---@field on fun(self: Game, name: '回合-结束', callback: fun(turn: Game.Event.Turn): any): function
---@field fire fun(self: Game, name: '回合-结束', turn: Game.Event.Turn): any
---@field on fun(self: Game, name: '阶段-开始', callback: fun(phase: Phase): any): function
---@field fire fun(self: Game, name: '阶段-开始', phase: Phase): any
---@field on fun(self: Game, name: '阶段-生效', callback: fun(phase: Phase): any): function
---@field fire fun(self: Game, name: '阶段-生效', phase: Phase): any
---@field on fun(self: Game, name: '阶段-结束', callback: fun(phase: Phase): any): function
---@field fire fun(self: Game, name: '阶段-结束', phase: Phase): any
---@field on fun(self: Game, name: '决策-询问', callback: fun(ask: Ask|AskPlayer|AskChoice): any): function # 问应答方要答复：**第一个给出答复的胜出（后面的订阅者不再调）**；返回空 = 不表态
---@field fire fun(self: Game, name: '决策-询问', ask: Ask|AskPlayer|AskChoice): any # 返回值就是答复（`Ask` / `AskChoice` 是任意值、`AskPlayer` 是一名或几名角色；没人表态给空）
---@field on fun(self: Game, name: '决策-答复', callback: fun(ask: Ask|AskPlayer|AskChoice): any): function
---@field fire fun(self: Game, name: '决策-答复', ask: Ask|AskPlayer|AskChoice): any
---@field on fun(self: Game, name: '面板-询问', callback: fun(askPanel: AskPanel): any): function # 问应答方要一次回复（**开着**的询问：应答方回变化值，直到它点「确定」）；**第一个给出回复的胜出（后面的订阅者不再调）**；返回空 = 不表态
---@field fire fun(self: Game, name: '面板-询问', askPanel: AskPanel): any # 返回值就是一次回复（`AskPanel.Change`；没人表态给空）
---@field on fun(self: Game, name: '面板-答复', callback: fun(askPanel: AskPanel): any): function # 收到了一次回复（变化已经验证并生效；面板的当前形状照它读）
---@field fire fun(self: Game, name: '面板-答复', askPanel: AskPanel): any
---@field on fun(self: Game, name: '武将-询问', callback: fun(askHero: AskHero): any): function # 问应答方要一名或几名武将（**第一个给出答复的胜出（后面的订阅者不再调）**）；返回空 = 不表态
---@field fire fun(self: Game, name: '武将-询问', askHero: AskHero): any # 返回值就是答复（`HeroDef|HeroDef[]`；没人表态给空）
---@field on fun(self: Game, name: '武将-答复', callback: fun(askHero: AskHero): any): function
---@field fire fun(self: Game, name: '武将-答复', askHero: AskHero): any
---@field on fun(self: Game, name: '技能-询问', callback: fun(ask: AskUseSkill): any): function # 问应答方要发动哪个技能：**第一个给出答复的胜出（后面的订阅者不再调）**；返回空 = 不表态
---@field fire fun(self: Game, name: '技能-询问', ask: AskUseSkill): any # 返回值就是答复（`{ skill = …, cards = …, targets = … }`；没人表态给空）
---@field on fun(self: Game, name: '游戏-结束', callback: fun(result: Game.Result): any): function
---@field fire fun(self: Game, name: '游戏-结束', result: Game.Result): any
---@field on fun(self: Game, name: string, callback: fun(payload: any): any): function
---@field fire fun(self: Game, name: string, ...: any): any # 第一个回调明确给出的返回值（快速返回）

--- 玩家自己的时机表（与 Game 同形）：技能挂在它身上，只在自己被问到的那一段醒来
---@class Player
---@field on fun(self: Player, name: '卡牌-进入区域', callback: fun(card: Card, zone: Zone, visible?: Visibility): any): function # 自己名下的区里有牌进来（牌自己那份之外、对区的主人再发一份；公共区没有主人、不发）
---@field fire fun(self: Player, name: '卡牌-进入区域', card: Card, zone: Zone, visible?: Visibility): any
---@field on fun(self: Player, name: '卡牌-离开区域', callback: fun(card: Card, zone: Zone, visible?: Visibility): any): function # 自己名下的区里有牌离开（同上；【枭姬】挂这里）
---@field fire fun(self: Player, name: '卡牌-离开区域', card: Card, zone: Zone, visible?: Visibility): any
---@field on fun(self: Player, name: '阶段-开始', callback: fun(phase: Phase): any): function # 自己这个玩家的阶段开始（全局那份之外、对当事人再发一份）
---@field fire fun(self: Player, name: '阶段-开始', phase: Phase): any
---@field on fun(self: Player, name: '阶段-生效', callback: fun(phase: Phase): any): function # 自己这个玩家的阶段生效（全局那份之外、对当事人再发一份）
---@field fire fun(self: Player, name: '阶段-生效', phase: Phase): any
---@field on fun(self: Player, name: '阶段-结束', callback: fun(phase: Phase): any): function # 自己这个玩家的阶段结束（全局那份之外、对当事人再发一份）
---@field fire fun(self: Player, name: '阶段-结束', phase: Phase): any
---@field on fun(self: Player, name: '效果-来源-能否生效', callback: fun(effect: Effect): any): function # 询问要不要阻止这一次生效（第二段：问来源）：返回非 nil 即阻止（返回值就是原因）
---@field fire fun(self: Player, name: '效果-来源-能否生效', effect: Effect): any # 返回值就是那条阻止的原因
---@field on fun(self: Player, name: '效果-目标-能否生效', callback: fun(effect: Effect): any): function # 询问要不要阻止这一次生效（第三段：问目标）：返回非 nil 即阻止（返回值就是原因）
---@field fire fun(self: Player, name: '效果-目标-能否生效', effect: Effect): any # 返回值就是那条阻止的原因
---@field on fun(self: Player, name: '卡牌-目标-能否指定', callback: fun(plan: CardDef.TargetPlan): any): function # 别人要用牌指定目标时问一句：返回非 nil 即不能指定我（返回值就是原因）
---@field fire fun(self: Player, name: '卡牌-目标-能否指定', plan: CardDef.TargetPlan): any # 返回值就是那条原因
---@field on fun(self: Player, name: '效果-收尾', callback: fun(effect: Effect): any): function # 冲自己来的效果结完时再发一份（全局那份之外、对当事人再发一份）
---@field fire fun(self: Player, name: '效果-收尾', effect: Effect): any
---@field on fun(self: Player, name: '卡牌-来源-结算前', callback: fun(useCard: UseCard|UseCardToCard): any): function # 自己使用的牌开始结算时再发一份（全局那份叫「卡牌-结算前」、对使用者再发一份带方向词）
---@field fire fun(self: Player, name: '卡牌-来源-结算前', useCard: UseCard|UseCardToCard): any
---@field on fun(self: Player, name: '卡牌-来源-使用选项', callback: fun(check: Game.Event.卡牌使用选项): (Game.UseOptionsInput?)): function # 自己使用的牌的选项（全局那份之外、对使用者再发一份）
---@field collect fun(self: Player, name: '卡牌-来源-使用选项', check: Game.Event.卡牌使用选项): Game.UseOptionsInput[] # 收集使用者自己那几个来源贡献的选项片段
---@field collect fun(self: Player, name: string, ...: any): any[] # 动态时机名走这条（收集所有回调的第一个返回值）
---@field on fun(self: Player, name: '卡牌-来源-指定目标后', callback: fun(useCard: UseCard, target: Player): any): function # 自己使用的牌指定目标后（逐目标；全局那份之外、对使用者再发一份）
---@field fire fun(self: Player, name: '卡牌-来源-指定目标后', useCard: UseCard, target: Player): any
---@field on fun(self: Player, name: '卡牌-目标-指定目标后', callback: fun(useCard: UseCard, target: Player): any): function # 自己被指定为目标后（逐目标；全局那份之外、对目标再发一份）
---@field fire fun(self: Player, name: '卡牌-目标-指定目标后', useCard: UseCard, target: Player): any
---@field on fun(self: Player, name: '效果-来源-被响应', callback: fun(ask: AskPlayCard): any): function # 自己发起的那次生效被响应了（全局那份之外、对来源再发一份）；要驳回就用 `ask:cancel(原因)`（不会返回）
---@field fire fun(self: Player, name: '效果-来源-被响应', ask: AskPlayCard): any
---@field on fun(self: Player, name: string, callback: fun(payload: any): any): function
---@field fire fun(self: Player, name: string, ...: any): any # 第一个回调明确给出的返回值（快速返回）
