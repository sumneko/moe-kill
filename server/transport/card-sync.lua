--- 卡牌下行同步：每个连接一份「这个客户端看见的牌」的账
---
--- 视图 id **不进内核**：由每个连接自己的号源发；看不见内容的区里的牌只有 id（匿名代号），
--- 从这种区移除时随机挑一个 id，免得客户端把刚消失的匿名牌与刚出现的明牌配起来。
---@class CardSync.View
---@field player Player # 这个连接是谁
---@field cards table<Card, Proto.Card> # 这个客户端当前看到的每张牌（背面牌也在里面，只是没有牌面）
---@field nextId integer # 视图 id 的号源（每个连接一套）

---@class CardSync.API
moe.cardSync = {}

--- 每个连接一份视图（键是连接：连接被回收时自动清）
---@type table<Client, CardSync.View>
moe.cardSync.views = moe.cardSync.views or setmetatable({}, { __mode = 'k' })

--- 每个局攒着的脏牌
---@type table<Game, table<Card, true>>
moe.cardSync.dirty = moe.cardSync.dirty or setmetatable({}, { __mode = 'k' })

--- 每张牌最近一次进区时那次搬动的可见性（组装要用）
---@type table<Card, Visibility>
moe.cardSync.lastVisible = moe.cardSync.lastVisible or setmetatable({}, { __mode = 'k' })

--- 每张牌最近一次离开的区（进区时配对发移动通知用）
---@type table<Card, Zone>
moe.cardSync.lastLeave = moe.cardSync.lastLeave or setmetatable({}, { __mode = 'k' })

--- 取某个玩家的视图（他没有连接就没有）
---@param player Player
---@return CardSync.View?
local function getView(player)
    local user = player.user
    if not user then
        return nil
    end
    ---@cast user ClientUser
    local client = user.client
    if not client then
        return nil
    end
    local view = moe.cardSync.views[client]
    if not view then
        view = { player = player, cards = {}, nextId = 0 }
        moe.cardSync.views[client] = view
    end
    return view
end

--- 协议里的区域：既没有名字也没有归属的（临时区）一律是同一个空区域
---@param zone? Zone
---@return Proto.Zone
local function toZone(zone)
    local owner = zone and zone.owner
    local name  = zone and zone.name
    if not owner and not name then
        return {}
    end
    ---@type Proto.Zone
    local result = {}
    if owner then
        result.player = owner.id
    end
    if name then
        result.name = name
    end
    return result
end

--- 两份协议区域是不是同一个（「有没有换区」就按它判）
---@param a Proto.Zone?
---@param b Proto.Zone?
---@return boolean
local function sameZone(a, b)
    if not a or not b then
        return false
    end
    return a.name == b.name and a.player == b.player
end

--- 这个玩家看得见这张牌的内容吗（区级可见性叠加这一次搬动的可见性）
---@param zone Zone
---@param visible? Visibility
---@param player Player
---@return boolean
local function contentVisible(zone, visible, player)
    if not zone:isVisibleTo(player) then
        return false
    end
    if not visible then
        return true
    end
    return moe.visibility.isVisibleTo(visible, player)
end

--- 按视角组装一张牌（看不见内容就只给 id 与区域）
---@param view CardSync.View
---@param card Card
---@param id integer
---@return Proto.Card
local function toCard(view, card, id)
    local zone = card:getZone()
    ---@type Proto.Card
    local result = { id = id, zone = toZone(zone) }
    if zone and contentVisible(zone, moe.cardSync.lastVisible[card], view.player) then
        local own = card.ownFace
        result.template = { name = own.name, suit = own.suit, point = own.point }
        local modifier = card.modifier
        if modifier then
            result.modifier = { name = modifier.name, suit = modifier.suit, point = modifier.point }
        end
    end
    return result
end

--- 两份快照是不是完全一样
---@param a Proto.Card
---@param b Proto.Card
---@return boolean
local function sameCard(a, b)
    if a.id ~= b.id or not sameZone(a.zone, b.zone) then
        return false
    end
    local at, bt = a.template, b.template
    if (at == nil) ~= (bt == nil) then
        return false
    end
    if at and bt and (at.name ~= bt.name or at.suit ~= bt.suit or at.point ~= bt.point) then
        return false
    end
    local am, bm = a.modifier, b.modifier
    if (am == nil) ~= (bm == nil) then
        return false
    end
    if am and bm and (am.name ~= bm.name or am.suit ~= bm.suit or am.point ~= bm.point) then
        return false
    end
    return true
end

--- 从视图里随机挑一个「看不见内容」的 id（客户端反正分不清是哪张）
---@param view CardSync.View
---@param zone Zone
---@return Card? # 挑中的那张（视图里的记法）
local function pickHidden(view, zone)
    local key = toZone(zone)
    ---@type Card[]
    local candidates = {}
    for card, snapshot in pairs(view.cards) do
        if snapshot.template == nil and sameZone(snapshot.zone, key) then
            candidates[#candidates + 1] = card
        end
    end
    if #candidates == 0 then
        return nil
    end
    return candidates[math.random(#candidates)]
end

--- 标脏一张牌（第一次标脏给这个局登记一次 flush）
---@param game Game
---@param card Card
local function markDirty(game, card)
    local dirty = moe.cardSync.dirty[game]
    if not dirty then
        dirty = {}
        moe.cardSync.dirty[game] = dirty
        moe.await.wake(function ()
            moe.cardSync.flush(game)
        end)
    end
    dirty[card] = true
end

--- 给每个有连接的玩家发一份（组装用的钩子；发什么由调用方决定）
---@param game Game
---@param build fun(view: CardSync.View): any # 造不出来的那份就不发
---@param send fun(user: User, params: any)
local function broadcast(game, build, send)
    for _, player in ipairs(game.desk.players) do
        local view = getView(player)
        if view then
            local params = build(view)
            local user = player.user
            if params and user then
                send(user, params)
            end
        end
    end
end

--- 搬牌那一刻的通知（当场发，供客户端播动画；协议区域没变就不发）
---@param card Card
---@param from Zone
---@param to Zone
local function notifyMove(card, from, to)
    if sameZone(toZone(from), toZone(to)) then
        return
    end
    broadcast(card.game, function (view)
        local snapshot = view.cards[card]
        if not snapshot then
            return nil
        end
        ---@type Proto.MovingCard
        local moving = { id = snapshot.id }
        if snapshot.template then
            moving.template = snapshot.template
        end
        ---@type Proto.Notify.Card.Move
        return { cards = { moving }, from = toZone(from), to = toZone(to) }
    end, function (user, params)
        user:cardMove(params)
    end)
end

--- 把攒着的脏牌下发（三类通知各自合成一条；分给每个连接时按他的视角算）
---@param game Game
function moe.cardSync.flush(game)
    local dirty = moe.cardSync.dirty[game]
    if not dirty then
        return
    end
    moe.cardSync.dirty[game] = nil
    broadcast(game, function (view)
        ---@type Proto.Card[]
        local creates = {}
        ---@type Proto.Card[]
        local updates = {}
        ---@type integer[]
        local removes = {}
        for card in pairs(dirty) do
            local zone   = card:getZone()
            local old    = view.cards[card]
            if not old then
                view.nextId = view.nextId + 1
                local fresh = toCard(view, card, view.nextId)
                view.cards[card] = fresh
                creates[#creates + 1] = fresh
            else
                local fresh = toCard(view, card, old.id)
                if not sameCard(old, fresh) then
                    if sameZone(old.zone, fresh.zone) then
                        view.cards[card] = fresh
                        updates[#updates + 1] = fresh
                    else
                        removes[#removes + 1] = old.id
                        view.nextId = view.nextId + 1
                        view.cards[card] = toCard(view, card, view.nextId)
                        creates[#creates + 1] = assert(view.cards[card])
                    end
                end
            end
        end
        if #creates + #updates + #removes == 0 then
            return nil
        end
        return { creates = creates, updates = updates, removes = removes }
    end, function (user, batch)
        if #batch.removes > 0 then
            user:cardRemove { ids = batch.removes }
        end
        if #batch.updates > 0 then
            user:cardUpdate { cards = batch.updates }
        end
        if #batch.creates > 0 then
            user:cardCreate { cards = batch.creates }
        end
    end)
end

--- 盯住某个局的进 / 离区（登记一次，之后自动收发）
---@param game Game
---@return fun() # 撤销这次登记
function moe.cardSync.watch(game)
    return game:watch {
        enter = function (card, zone, visible)
            local from = moe.cardSync.lastLeave[card]
            moe.cardSync.lastLeave[card] = nil
            moe.cardSync.lastVisible[card] = visible
            if from then
                notifyMove(card, from, zone)
            end
            markDirty(game, card)
        end,
        leave = function (card, zone)
            moe.cardSync.lastLeave[card] = zone
            markDirty(game, card)
        end,
        change = function (card)
            markDirty(game, card)
        end,
    }
end

--- 把这一局所有牌区里的牌全量发一遍（开局 / 重连用）
---@param game Game
function moe.cardSync.syncAll(game)
    moe.cardSync.dirty[game] = nil
    broadcast(game, function (view)
        ---@type Proto.Card[]
        local cards = {}
        view.cards = {}
        local function collect(zone)
            for _, card in ipairs(zone:list()) do
                moe.cardSync.lastVisible[card] = nil
                view.nextId = view.nextId + 1
                local fresh = toCard(view, card, view.nextId)
                view.cards[card] = fresh
                cards[#cards + 1] = fresh
            end
        end
        for _, zone in ipairs(game:getZones()) do
            collect(zone)
        end
        for _, player in ipairs(game.desk.players) do
            for _, zone in ipairs(player:getZones()) do
                collect(zone)
            end
        end
        if #cards == 0 then
            return nil
        end
        return { cards = cards }
    end, function (user, params)
        user:cardCreate(params)
    end)
end

return moe.cardSync
