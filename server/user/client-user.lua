--- 真实玩家的代表：把询问下发给客户端、等客户端回话
---@class ClientUser : User
---@field client Client # 他走的那条连接
---@field cardView CardSync.View
local M = Class 'ClientUser'

Extends('ClientUser', 'User')

--- 他看得见的那份牌（懒建：第一次读的时候按座位建一份）
---@type CardSync.View?
M.cardView = nil

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

--- 发一个请求：给了 `host` 就带上取消号（这次请求的寿命跟着它走；不给就是不能取消）
---@param method string
---@param params table
---@param host? GCHost # 这次请求挂在谁身上（它被收掉时叫停这次请求）
---@return Task
function M:request(method, params, host)
    if not host then
        return self.client:request(method, params)
    end
    params.cancelToken = params.cancelToken or self.game:nextId()
    local request = self.client:request(method, params)
    host:bindGC(function ()
        if request.resolved then
            return
        end
        self:cancel(params.cancelToken)
        request:reject { code = -1, message = 'request canceled' }
    end)
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
---@field players? Player[] # 被选中的目标
---@field cards? Card[] # 这次使用带的素材牌（视为那条才有）

--- 发一次 `Ask.Choice`（选项由调用者摆好），把回包的索引换回选项字符串
---@async
---@param ask Effect # 这次询问（挂取消号用）
---@param params Proto.Request.Ask.Choice
---@return string?
function M:choice(ask, params)
    local result = self:request('Ask.Choice', params, ask):await()
    if not result then
        return nil
    end
    return params.options[result.choice]
end

--- 发一次 `Ask.Select`：`params` 里传了哪些组件就带上哪些，回包里有几个字段就解析几个
---@async
---@param ask Effect # 这次询问（挂取消号用）
---@param params Proto.Request.Ask.Select
---@return ClientUser.SelectResult?
function M:select(ask, params)
    local result = self:request('Ask.Select', params, ask):await()
    if not result then
        return nil
    end
    local game   = self.game
    local view   = self.cardView
    local answer = result
    ---@type ClientUser.SelectResult
    local parsed = {}
    if answer.player then
        ---@type Player[]
        local players = {}
        for _, id in ipairs(answer.player) do
            players[#players + 1] = assert(game:getPlayerById(id), '答复里的玩家不在这一局里')
        end
        parsed.players = players
    end
    if answer.card then
        ---@type Card[]
        local cards = {}
        for _, id in ipairs(answer.card) do
            cards[#cards + 1] = assert(view:cardOf(id), '答复里的牌不在这一局里')
        end
        parsed.cards = cards
    end
    return parsed
end

--- 发一次 `Ask.Use`：`params` 里传了哪些组件就带上哪些，回包里有几个字段就解析几个
---@async
---@param ask Effect # 这次询问（挂取消号用）
---@param params Proto.Request.Ask.Use
---@return ClientUser.UseResult?
function M:use(ask, params)
    local result = self:request('Ask.Use', params, ask):await()
    if not result then
        return nil
    end
    local game   = self.game
    local view   = self.cardView
    local answer = result
    ---@type ClientUser.UseResult
    local parsed = {}
    if answer.usedCard then
        parsed.usedCard = assert(view:cardOf(answer.usedCard), '答复里的牌不在这一局里')
    end
    if answer.usedViewAs then
        parsed.usedViewAs = answer.usedViewAs
    end
    if answer.targets then
        ---@type Player[]
        local players = {}
        for _, id in ipairs(answer.targets) do
            players[#players + 1] = assert(game:getPlayerById(id), '答复里的玩家不在这一局里')
        end
        parsed.players = players
    end
    if answer.cards then
        ---@type Card[]
        local cards = {}
        for _, id in ipairs(answer.cards) do
            cards[#cards + 1] = assert(view:cardOf(id), '答复里的牌不在这一局里')
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
    local view      = self.cardView
    ---@type integer[]
    local ids = {}
    for _, option in ipairs(ask.options) do
        local card = option.card
        if card then
            ids[#ids + 1] = view.cardMap[card].id
        end
    end
    return { ids = ids, min = condition.min, max = condition.max }
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
    })
end

--- 要若干名角色（协议：`Ask.Select` 的 `player` 那半）
---@async
---@param ask AskPlayer
---@return Player[]?
function M:askPlayer(ask)
    local parsed = self:select(ask, {
        reason = ask.reason,
        player = self:playerPlan(ask.options, ask.condition.min, ask.condition.max),
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
        ---@type integer[]
        local ids = {}
        for _, card in ipairs(moe.askCard.collectCandidates(viewAs.owner, normalized)) do
            ids[#ids + 1] = self.cardView.cardMap[card].id
        end
        params.card = { ids = ids, min = normalized.min, max = normalized.max }
    end
    params.target = { ids = self:playerIds(plan.legal), min = plan.min, max = plan.max }
    return params
end

--- 要一次「使用」：实体候选带目标区间，视为候选带来源、素材条件与目标区间（协议：`Ask.Use`）
---@async
---@param ask AskUseCard
---@return AskUseCard.Answer?
function M:askUseCard(ask)
    ---@type Proto.CardWithPlan[]
    local cards = {}
    ---@type Proto.ViewAs[]
    local viewAsList = {}
    ---@type ViewAs[] # 发出去的视为列表 ⇄ 真声明（回包给的是下标）
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
    local parsed = self:use(ask, {
        reason     = ask.reason,
        cancelable = ask.condition.cancelable,
        card       = cards,
        viewAs     = viewAsList,
    })
    if not parsed then
        return nil
    end
    if parsed.usedViewAs then
        return {
            viewAs    = viewAsOptions[parsed.usedViewAs],
            targets   = parsed.players,
            materials = parsed.cards,
        }
    end
    return { card = parsed.usedCard, targets = parsed.players }
end

--- 叫停一次请求（客户端收到后不再回话，只按「请求被取消」回个包）
---@param cancelToken integer
function M:cancel(cancelToken)
    self.client:notify('Cancel', { cancelToken = cancelToken })
end

---@param moves Zone.Move[]
function M:moveCards(moves)
    self.cardView:moveCards(moves)
end

---@param cards Card[]
function M:updateCards(cards)
    self.cardView:updateCards(cards)
end


return M
