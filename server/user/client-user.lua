--- 真实玩家的代表：把询问下发给客户端、等客户端回话
---@class ClientUser : User
---@field client Client # 他走的那条连接
---@field cardView CardSync.View
local M = Class 'ClientUser'

Extends('ClientUser', 'User')

--- 他看得见的那份牌（懒建：第一次读的时候按座位建一份）
---@type CardSync.View?
M.cardView = nil

--- 询问没写 `timeLimit` 时用这个（秒）—— 内容侧可在条件 / 选项上写自己的
---@type number
local DEFAULT_TIME_LIMIT = 10

--- 判超时前多给的时间（秒）：一来一回的路程
---@type number
local TIME_LIMIT_SLACK = 1

-- 回包的形状（照 `proto.d.lua` 的 `Proto.Result.<方法名>` 推）：不合形状就当这次「答不出来」

--- 某个询问的回包形状（声明里漏了就当场报出来）
---@param method string
---@return Shape
local function resultShape(method)
    local shape = moe.proto.shape('Proto.Result.' .. method)
    if not shape then
        error('协议声明里没有回包形状「Proto.Result.' .. method .. '」')
    end
    return shape
end

local SELECT_RESULT    = resultShape 'Ask.Select'
local CHOICE_RESULT    = resultShape 'Ask.Choice'
local USE_RESULT       = resultShape 'Ask.Use'
local HERO_RESULT      = resultShape 'Ask.Hero'
local PANEL_RESULT     = resultShape 'Ask.Panel'

---@param self ClientUser
---@return CardSync.View? # 他看得见的那份牌
---@return true # 将结果缓存下来
M.__getter.cardView = function (self)
    return New 'CardSync.View' (self), true
end

--- 发一条通知
---@param method string
---@param params table
function M:notify(method, params)
    self.client:notify(method, params)
end

--- 发一个请求：给了 `host` 就带上取消号（这次请求的寿命跟着它走；不给就是不能取消）；
--- `params.timeLimit` 给了就同时开个计时器（多给 `TIME_LIMIT_SLACK` 秒宽松），到点还没回就按超时收尾
---@param method string
---@param params table
---@param host? GCHost # 这次请求挂在谁身上（它被收掉时叫停这次请求）
---@return Task
function M:request(method, params, host)
    if host then
        params.cancelToken = params.cancelToken or self.game:nextId()
    end
    local request = self.client:request(method, params)
    if host then
        host:bindGC(function ()
            if request.resolved then
                return
            end
            self:cancel(params.cancelToken)
            request:reject { code = -1, message = 'request canceled' }
        end)
    end
    local timeLimit = params.timeLimit
    if timeLimit then
        -- 计时器挂在请求上：请求一有结果（回包到了 / 被叫停）它跟着一起拆
        -- 到点了就把结果强行定成「超时」（`cancel`：不管之前记过什么）
        request:bindGC(moe.timer.wait(timeLimit + TIME_LIMIT_SLACK, function ()
            if request.resolved then
                return
            end
            if params.cancelToken then
                self:cancel(params.cancelToken)
            end
            request:cancel { code = -3, message = 'timeout' }
        end))
    end
    return request
end

--- 一次 `Ask.Select` 的结果：回包里有哪些字段就解析哪些
---@class ClientUser.SelectResult
---@field players? Player[] # 被选中的玩家
---@field cards? Card[] # 被选中的牌

--- 一次 `Ask.Use` 的结果：回包里有哪些字段就解析哪些
---@class ClientUser.UseResult
---@field usedCard? Card # 被使用的那张实体牌
---@field usedViewAs? integer # 用了第几个「视为」（发起方给的列表下标）
---@field usedSkill? integer # 发动了哪个技能（技能号；换了真技能是调用方的事）
---@field players? Player[] # 被选中的目标
---@field cards? Card[] # 这次带的素材牌（视为 / 技能那两条才有）

--- 发一次 `Ask.Choice`（选项由调用者摆好），把回包的索引换回选项字符串
---@async
---@param ask Effect # 这次询问（挂取消号用）
---@param params Proto.Request.Ask.Choice
---@return string?
function M:choice(ask, params)
    local result = self:request('Ask.Choice', params, ask):await()
    if not result or moe.shape.problem(result, CHOICE_RESULT) then
        return nil
    end
    return params.options[result.choice]
end

--- 发一次 `Ask.Select`：`params` 里传了哪些组件就带上哪些，回包里有几个字段就解析几个
--- 带的号认不出来就是这次没答上（给空）
---@async
---@param ask Effect # 这次询问（挂取消号用）
---@param params Proto.Request.Ask.Select
---@return ClientUser.SelectResult?
function M:select(ask, params)
    local result = self:request('Ask.Select', params, ask):await()
    if not result or moe.shape.problem(result, SELECT_RESULT) then
        return nil
    end
    ---@type ClientUser.SelectResult
    local parsed = {}
    if result.player then
        ---@type Player[]?
        local players = self:playerList(result.player)
        if not players then
            return nil
        end
        parsed.players = players
    end
    if result.card then
        ---@type Card[]?
        local cards = self:cardList(result.card)
        if not cards then
            return nil
        end
        parsed.cards = cards
    end
    return parsed
end

--- 发一次 `Ask.Use`：`params` 里传了哪些组件就带上哪些，回包里有几个字段就解析几个（带的号认不出来就是没答上）
---@async
---@param ask Effect # 这次询问（挂取消号用）
---@param params Proto.Request.Ask.Use
---@return ClientUser.UseResult?
function M:use(ask, params)
    local result = self:request('Ask.Use', params, ask):await()
    if not result or moe.shape.problem(result, USE_RESULT) then
        return nil
    end
    ---@type ClientUser.UseResult
    local parsed = {}
    if result.usedCard then
        local usedCard = self.cardView:cardOf(result.usedCard)
        if not usedCard then
            return nil
        end
        parsed.usedCard = usedCard
    end
    if result.usedViewAs then
        parsed.usedViewAs = result.usedViewAs
    end
    if result.usedSkill then
        parsed.usedSkill = result.usedSkill
    end
    if result.targets then
        ---@type Player[]?
        local players = self:playerList(result.targets)
        if not players then
            return nil
        end
        parsed.players = players
    end
    if result.cards then
        ---@type Card[]?
        local cards = self:cardList(result.cards)
        if not cards then
            return nil
        end
        parsed.cards = cards
    end
    return parsed
end

--- 一组角色的协议号
---@param players Player[]
---@return integer[]
function M:playerIds(players)
    ---@type integer[]
    local ids = {}
    for _, player in ipairs(players) do
        ids[#ids + 1] = player.id
    end
    return ids
end

--- 一组牌的协议号（按这份视图发号）
---@param cards Card[]
---@return integer[]
function M:cardIds(cards)
    local view = self.cardView
    ---@type integer[]
    local ids = {}
    for _, card in ipairs(cards) do
        ids[#ids + 1] = view.cardMap[card].id
    end
    return ids
end

--- 答复里的角色号转回真角色（认不到的号给空 —— 客户端发来的乱号当「没答上」）
---@param ids integer[]
---@return Player[]?
function M:playerList(ids)
    local game = self.game
    ---@type Player[]
    local players = {}
    for _, id in ipairs(ids) do
        local player = game:getPlayerById(id)
        if not player then
            return nil
        end
        players[#players + 1] = player
    end
    return players
end

--- 答复里的牌号转回真牌（认不到的号给空）
---@param ids integer[]
---@return Card[]?
function M:cardList(ids)
    local view = self.cardView
    ---@type Card[]
    local cards = {}
    for _, id in ipairs(ids) do
        local card = view:cardOf(id)
        if not card then
            return nil
        end
        cards[#cards + 1] = card
    end
    return cards
end

--- 答复里的武将全名（`包名.定义名`）转回真定义（认不到就给空 —— 名字是自由串，不像号那样「是我们自己发出去的」）
---@param fullNames string[]
---@return HeroDef[]?
function M:heroList(fullNames)
    ---@type HeroDef[]
    local heroes = {}
    for _, fullName in ipairs(fullNames) do
        local hero = self.game:getHero(fullName)
        if not hero then
            return nil
        end
        heroes[#heroes + 1] = hero
    end
    return heroes
end

--- 一组角色的协议形状（`ids` + 个数区间）
---@param players Player[]
---@param min integer
---@param max integer
---@return Proto.Plan.Player
function M:playerPlan(players, min, max)
    return { ids = self:playerIds(players), min = min, max = max }
end

--- 一次「选牌」询问的 `card` 那半（候选按这份视图的号发；选项里没有牌的跳过）
---@param ask AskCard
---@return Proto.Plan.Card
function M:cardPlan(ask)
    local condition = ask.condition
    ---@type Card[]
    local cards = {}
    for _, option in ipairs(ask.options) do
        local card = option.card
        if card then
            cards[#cards + 1] = card
        end
    end
    return { ids = self:cardIds(cards), min = condition.min, max = condition.max }
end

--- 这次响应冲哪次使用去的（牌名 + 使用者 + 目标）；不是响应就给空
---@param useCard? UseCard
---@return Proto.ResponseTo?
function M:responseToParams(useCard)
    if not useCard then
        return nil
    end
    return {
        card    = useCard.card.name,
        player  = useCard.user.id,
        targets = self:playerIds(useCard.targets),
    }
end

--- 一次「选一张牌」的完整实现（候选摆上、回包转回真牌）：`askCard` / `askPlayCard` / `askUseCardToCard` 共用
---@async
---@param ask AskCard
---@return AskCard.Answer?
function M:pickCards(ask)
    local parsed = self:select(ask, {
        reason     = ask.reason,
        cancelable = ask.condition.cancelable,
        card       = self:cardPlan(ask),
        responseTo = self:responseToParams(ask.responseOptions?.responseTo),
        timeLimit  = ask.timeLimit or DEFAULT_TIME_LIMIT,
    })
    if not parsed then
        return nil
    end
    return { card = parsed.cards or {} }
end

--- 要他在若干选项里挑一个（协议：`Ask.Choice`）
---@async
---@param ask AskChoice
---@return string?
function M:askChoice(ask)
    return self:choice(ask, {
        reason     = ask.reason,
        options    = ask.options,
        cancelable = true,
        timeLimit  = DEFAULT_TIME_LIMIT,
    })
end

--- 要若干名角色（协议：`Ask.Select` 的 `player` 那半）
---@async
---@param ask AskPlayer
---@return Player[]?
function M:askPlayer(ask)
    local parsed = self:select(ask, {
        reason    = ask.reason,
        player    = self:playerPlan(ask.options, ask.condition.min, ask.condition.max),
        timeLimit = ask.timeLimit or DEFAULT_TIME_LIMIT,
    })
    return parsed?.players
end

--- 要几张牌（协议：`Ask.Select` 的 `card` 那半）
---@async
---@param ask AskCard
---@return AskCard.Answer?
function M:askCard(ask)
    return self:pickCards(ask)
end

--- 要一次「给出」：牌与目标两半一起发（协议：`Ask.Select` 的两半）
---@async
---@param ask AskCardWithTarget
---@return AskCard.Answer?
function M:askCardWithTarget(ask)
    local targetCond = ask.targetCondition
    local parsed = self:select(ask, {
        reason     = ask.reason,
        cancelable = ask.condition.cancelable,
        card       = self:cardPlan(ask),
        player     = self:playerPlan(targetCond.players, targetCond.min, targetCond.max),
        timeLimit  = ask.timeLimit or DEFAULT_TIME_LIMIT,
    })
    if not parsed then
        return nil
    end
    return { card = parsed.cards or {}, targets = parsed.players or {} }
end

--- 要一张打出的牌（协议上就是一次「选牌」；「打出」的语义在内核 `AskPlayCard` 里）
---@async
---@param ask AskPlayCard
---@return AskCard.Answer?
function M:askPlayCard(ask)
    return self:pickCards(ask)
end

--- 要一次「对一张牌的使用」（目标牌由发起方定，客户端只要选一张牌）
---@async
---@param ask AskUseCardToCard
---@return AskCard.Answer?
function M:askUseCardToCard(ask)
    return self:pickCards(ask)
end

--- 一次技能询问的候选：每个技能带这次能挑的牌与目标（协议里 `Ask.Use` 的 `skill` 那一组）
---@param options AskUseSkill.Option[]
---@return Proto.SkillPlan[]
function M:skillPlans(options)
    ---@type Proto.SkillPlan[]
    local skills = {}
    for _, option in ipairs(options) do
        ---@type Proto.SkillPlan
        local plan = { id = option.skill.id }
        local cards = option.cards
        if cards then
            plan.cards = { ids = self:cardIds(cards.legal), min = cards.min, max = cards.max }
        end
        local targets = option.targets
        if targets then
            plan.targets = self:playerPlan(targets.legal, targets.min, targets.max)
        end
        skills[#skills + 1] = plan
    end
    return skills
end

--- 答复换成「技能族」的形状（没答上就是空）
---@param options AskUseSkill.Option[]
---@param result ClientUser.UseResult
---@return AskUseSkill.Answer?
function M:skillAnswer(options, result)
    local used = result.usedSkill
    if not used then
        return nil
    end
    for _, option in ipairs(options) do
        if option.skill.id == used then
            return {
                skill   = option.skill,
                cards   = result.cards,
                targets = result.players,
            }
        end
    end
end

--- 要一次技能使用：候选技能各带这次能挑的牌与目标（协议：`Ask.Use` 只给 `skill` 那一组）
---@async
---@param ask AskUseSkill
---@return AskUseSkill.Answer?
function M:askUseSkill(ask)
    ---@type Proto.Request.Ask.Use
    local params = {
        reason     = ask.reason,
        cancelable = true,
        skill      = self:skillPlans(ask.options),
        timeLimit  = DEFAULT_TIME_LIMIT,
    }
    local parsed = self:use(ask, params)
    if not parsed then
        return nil
    end
    return self:skillAnswer(ask.options, parsed)
end

--- 要他在若干武将里挑（协议：`Ask.Hero`；候选是一份武将全名，名单缺省 = 不做限制）
---@async
---@param ask AskHero
---@return HeroDef|HeroDef[]?
function M:askHero(ask)
    local condition = ask.condition
    local min       = condition?.min or 1

    ---@type string[]?
    local fullNames = nil
    local options = ask.options
    if options then
        fullNames = {}
        for _, hero in ipairs(options) do
            fullNames[#fullNames + 1] = hero.fullName
        end
    end

    local result = self:request('Ask.Hero', {
        reason    = ask.reason,
        heroes    = fullNames,
        min       = min,
        max       = condition?.max or min,
        timeLimit = ask.timeLimit or DEFAULT_TIME_LIMIT,
    }, ask):await()

    if not result or moe.shape.problem(result, HERO_RESULT) or not result.heroes then
        return nil
    end
    return self:heroList(result.heroes)
end

--- 要他在一块面板上操作（协议：`Ask.Panel`；面板自身的形状早在 `Panel.Create` / `Update` 里给过、挪牌是另一条请求 `Panel.Move`）
---@async
---@param ask AskPanel
---@return AskPanel.Change?
function M:askPanel(ask)
    -- 挂着这次请求的这段时间里，客户端可以带面板号发 `Panel.Move`
    local close = moe.panelSync.open(ask)
    local result = self:request('Ask.Panel', {
        reason     = ask.reason,
        cancelable = ask.cancelable,
        id         = ask.panel.id,
        timeLimit  = ask.timeLimit or DEFAULT_TIME_LIMIT,
    }, ask):await()
    close()

    if not result or moe.shape.problem(result, PANEL_RESULT) then
        return nil
    end
    -- 答复到手就是「操作完了」：内核那个多轮循环留给 AI / 全局路径用
    local cards = self:cardList(result.card or {})
    if not cards then
        return nil
    end
    ---@type AskPanel.Change
    return { done = true, card = cards }
end

--- 一份「视为」声明的协议形状（来源二选一：技能给名字、手上的牌给号；素材条件按它能收的区与张数发）
---@param viewAs ViewAs
---@param plan Game.UsableTargets
---@return Proto.ViewAs
function M:viewAsParams(viewAs, plan)
    ---@type Proto.ViewAs
    local params = { name = viewAs.name }
    local source = viewAs.source
    if source then
        local proto = self.cardView.cardMap[source]
        if proto then
            params.sourceCard = proto.id
        else
            ---@cast source Skill
            params.sourceSkill = source.id
        end
    end
    local condition = viewAs.options?.condition
    if condition then
        local normalized = moe.askCard.normalizeCondition(self.game, viewAs.owner, condition)
        params.card = {
            ids = self:cardIds(moe.askCard.collectCandidates(viewAs.owner, normalized)),
            min = normalized.min,
            max = normalized.max,
        }
    end
    params.target = { ids = self:playerIds(plan.legal), min = plan.min, max = plan.max }
    return params
end

--- 一次用牌询问的候选：实体牌带目标区间，视为带来源、素材条件与目标区间（协议里 `Ask.Use` 的 `card` / `viewAs` 两组）
---@param ask AskUseCard|AskUse
---@return Proto.CardWithPlan[] # `card` 那一组
---@return Proto.ViewAs[] # `viewAs` 那一组
---@return ViewAs[] # 与发出去那份一一对应（回包给的是下标）
function M:cardPlans(ask)
    ---@type Proto.CardWithPlan[]
    local cards = {}
    ---@type Proto.ViewAs[]
    local viewAsList = {}
    ---@type ViewAs[]
    local viewAsOptions = {}
    for _, option in ipairs(ask.options) do
        ---@cast option AskUseCard.Option
        local card = option.card
        if card then
            local plan = option.plan
            cards[#cards + 1] = {
                id  = self.cardView.cardMap[card].id,
                ids = self:playerIds(plan.legal),
                min = plan.min,
                max = plan.max,
            }
        else
            local viewAs = option.viewAs
            if viewAs then
                viewAsList[#viewAsList + 1]       = self:viewAsParams(viewAs, option.plan)
                viewAsOptions[#viewAsOptions + 1] = viewAs
            end
        end
    end
    return cards, viewAsList, viewAsOptions
end

--- 答复换成「用牌族」的形状（视为答复 / 用实体牌答复两种）
---@param viewAsOptions ViewAs[]
---@param parsed ClientUser.UseResult
---@return AskUseCard.Answer?
function M:cardAnswer(viewAsOptions, parsed)
    if parsed.usedViewAs then
        return {
            viewAs    = viewAsOptions[parsed.usedViewAs],
            targets   = parsed.players,
            materials = parsed.cards,
        }
    end
    return { card = parsed.usedCard, targets = parsed.players }
end

--- 要一次「使用」：实体候选带目标区间，视为候选带来源、素材条件与目标区间（协议：`Ask.Use` 给 `card` / `viewAs` 两组）
---@async
---@param ask AskUseCard
---@return AskUseCard.Answer?
function M:askUseCard(ask)
    local cards, viewAsList, viewAsOptions = self:cardPlans(ask)
    local parsed = self:use(ask, {
        reason     = ask.reason,
        cancelable = ask.condition.cancelable,
        card       = cards,
        viewAs     = viewAsList,
        timeLimit  = ask.timeLimit or DEFAULT_TIME_LIMIT,
    })
    if not parsed then
        return nil
    end
    return self:cardAnswer(viewAsOptions, parsed)
end

--- 要一次行动：能用的牌（含视为）与能发动的技能**一起**摆出来（协议：`Ask.Use` 三组都给）
---@async
---@param ask AskUse
---@return AskUseCard.Answer|AskUseSkill.Answer?
function M:askUse(ask)
    local cards, viewAsList, viewAsOptions = self:cardPlans(ask)
    local parsed = self:use(ask, {
        reason     = ask.reason,
        cancelable = ask.condition.cancelable,
        card       = cards,
        viewAs     = viewAsList,
        skill      = self:skillPlans(ask.skills),
        timeLimit  = ask.timeLimit or DEFAULT_TIME_LIMIT,
    })
    if not parsed then
        return nil
    end
    local asSkill = self:skillAnswer(ask.skills, parsed)
    if asSkill then
        return asSkill
    end
    return self:cardAnswer(viewAsOptions, parsed)
end

--- 叫停一次请求：只发一条 `Cancel` 通知（请求本身照旧等回包 —— 有 id 的请求必须回包，
--- 客户端应当以 `Proto.Error.REQUEST_CANCELED` 收尾）；本地的等待也以同一个错误结束
---@param cancelToken integer
function M:cancel(cancelToken)
    self.client:notify('Cancel', { cancelToken = cancelToken })
end

---@param moves Zone.Move[]
function M:moveCards(moves)
    self.cardView:moveCards(moves)
end

---@param moves Zone.Move[]
function M:removeCards(moves)
    self.cardView:removeCards(moves)
end

---@param moves Zone.Move[]
function M:createCards(moves)
    self.cardView:createCards(moves)
end

---@param cards Card[]
function M:updateCards(cards)
    self.cardView:updateCards(cards)
end


return M
