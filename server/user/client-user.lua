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

--- 要若干名角色：问客户端（候选摆进参数，再把回包的 id 转回 `Player`；答不出来就是空）
---@async
---@param ask AskPlayer
---@return Player[]?
function M:askPlayer(ask)
    local game = self.game
    ---@type integer[]
    local ids = {}
    for _, player in ipairs(ask.options) do
        ids[#ids + 1] = player.id
    end

    ---@type Proto.Request.Ask.Select
    local params = {
        reason = ask.reason,
        player = {
            ids = ids,
            min = ask.condition.min,
            max = ask.condition.max,
        },
    }
    local result = self:request('Ask.Select', params, ask):await()
    if not result then
        return nil
    end
    ---@type Player[]
    local answer = {}
    for _, id in ipairs(result.player or {}) do
        answer[#answer + 1] = assert(game:getPlayerById(id), '答复里的玩家不在这一局里')
    end
    return answer
end

--- 要几张牌：问客户端（候选摆进参数，再把回包的 id 转回 `Card`；答不出来就是空）
---@async
---@param ask AskCard
---@return AskCard.Answer?
function M:askCard(ask)
    local condition = ask.condition
    local view = self.cardView
    ---@type integer[]
    local ids = {}
    for _, option in ipairs(ask.options) do
        local card = option.card
        if card then
            ids[#ids + 1] = view.cardMap[card].id
        end
    end

    ---@type Proto.Request.Ask.Select
    local params = {
        reason     = ask.reason,
        cancelable = condition.cancelable,
        card       = {
            ids = ids,
            min = condition.min,
            max = condition.max,
        },
    }
    local result = self:request('Ask.Select', params, ask):await()
    if not result then
        return nil
    end
    ---@type Card[]
    local cards = {}
    for _, id in ipairs(result.card or {}) do
        cards[#cards + 1] = assert(view:cardOf(id), '答复里的牌不在这一局里')
    end
    return { card = cards }
end

--- 要一次「给出」：牌与目标两半一起发（答不出来就是空）
---@async
---@param ask AskCardWithTarget
---@return AskCard.Answer?
function M:askCardWithTarget(ask)
    local game       = self.game
    local cardCond   = ask.condition
    local targetCond = ask.targetCondition

    local view = self.cardView
    ---@type integer[]
    local cardIds = {}
    for _, option in ipairs(ask.options) do
        local card = option.card
        if card then
            cardIds[#cardIds + 1] = view.cardMap[card].id
        end
    end
    ---@type integer[]
    local playerIds = {}
    for _, player in ipairs(targetCond.players) do
        playerIds[#playerIds + 1] = player.id
    end

    ---@type Proto.Request.Ask.Select
    local params = {
        reason     = ask.reason,
        cancelable = cardCond.cancelable,
        card       = {
            ids = cardIds,
            min = cardCond.min,
            max = cardCond.max,
        },
        player     = {
            ids = playerIds,
            min = targetCond.min,
            max = targetCond.max,
        },
    }
    local result = self:request('Ask.Select', params, ask):await()
    if not result then
        return nil
    end
    local answer = result
    ---@type Card[]
    local cards = {}
    for _, id in ipairs(answer.card or {}) do
        cards[#cards + 1] = assert(view:cardOf(id), '答复里的牌不在这一局里')
    end
    ---@type Player[]
    local targets = {}
    for _, id in ipairs(answer.player or {}) do
        targets[#targets + 1] = assert(game:getPlayerById(id), '答复里的玩家不在这一局里')
    end
    return { card = cards, targets = targets }
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
