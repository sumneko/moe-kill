--- 卡牌下行同步：每个连接一份「这个客户端看见的牌」的账
---
--- 视图 id **不进内核**：由每个连接自己的号源发；看不见内容的区里的牌只有 id（匿名代号）。
--- 新牌进账时，看不见牌面的那些会把号与同区另一张匿名牌对调 —— 客户端那边只是多了一个新号，
--- 服务端内部这张新牌背上的却是旧号，之后移除 / 移动报出去的号都认不出是哪张。

---@class CardSync.API
moe.cardSync = {}

--- 每个连接一份视图（键是连接：连接被回收时自动清）
---@type table<Client, CardSync.View>
moe.cardSync.views = moe.cardSync.views or setmetatable({}, { __mode = 'k' })

--- 每个局攒着的脏牌
---@type table<Game, table<Card, true>>
moe.cardSync.dirty = moe.cardSync.dirty or setmetatable({}, { __mode = 'k' })

--- 每个局「哪些真牌在哪个协议区域」（跟连接无关，一份共用 —— 挑同区匿名牌用）—— 懒创建
---@type table<Game, table<string, Card[]>>
moe.cardSync.zones = moe.cardSync.zones or setmetatable({}, { __mode = 'k' })

--- 每张牌最近一次进区时那次搬动的可见性（组装要用）
---@type table<Card, Visibility>
moe.cardSync.lastVisible = moe.cardSync.lastVisible or setmetatable({}, { __mode = 'k' })

--- 每张牌最近一次离开的区（进区时配对发移动通知用）
---@type table<Card, Zone>
moe.cardSync.lastLeave = moe.cardSync.lastLeave or setmetatable({}, { __mode = 'k' })

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

--- 协议区域的键（把「同一个区」的牌分到一组用）
---@param zone Proto.Zone?
---@return string
local function zoneKey(zone)
    if not zone then
        return ''
    end
    return '{}#{}' % { zone.name or '', zone.player or 0 }
end

--- 这个连接在某个区里看不见牌面的那些牌（`card` 自己也算一个 —— 抽到自己就等于不换）
---@param view CardSync.View
---@param card Card
---@param zone Zone
---@return Card[]
local function hiddenIn(view, card, zone)
    ---@type Card[]
    local hidden = { card }
    local areas  = moe.cardSync.zones[view.player.game]
    local cards  = areas?[zoneKey(toZone(zone))]
    if cards then
        for i = 1, #cards do
            local other    = cards[i]
            local snapshot = view.cards[other]
            if other ~= card and snapshot and snapshot.template == nil then
                hidden[#hidden + 1] = other
            end
        end
    end
    return hidden
end

--- 记下这张牌进了哪个协议区域（懒创建那个区的列表）
---@param game Game
---@param card Card
---@param zone Zone
local function addToZone(game, card, zone)
    local areas = moe.cardSync.zones[game]
    if not areas then
        areas = {}
        moe.cardSync.zones[game] = areas
    end
    local key   = zoneKey(toZone(zone))
    local cards = areas[key]
    if not cards then
        cards = {}
        areas[key] = cards
    end
    cards[#cards + 1] = card
end

--- 记下这张牌离开了哪个协议区域
---@param game Game
---@param card Card
---@param zone Zone
local function removeFromZone(game, card, zone)
    local cards = moe.cardSync.zones[game]?[zoneKey(toZone(zone))]
    if not cards then
        return
    end
    for i = 1, #cards do
        if cards[i] == card then
            table.remove(cards, i)
            return
        end
    end
end

--- 这一局所有牌区（局上的公共区 + 各玩家的区）
---@param game Game
---@return Zone[]
local function allZones(game)
    local zones = game:getZones()
    for _, player in ipairs(game.desk.players) do
        for _, zone in ipairs(player:getZones()) do
            zones[#zones + 1] = zone
        end
    end
    return zones
end

--- 一个连接的那份账（视图 id 是这个连接自己的号：每张新牌进来发一个，离区就作废）
---@class CardSync.View : Class.Base
---@field player Player # 这个连接是谁
---@field cards table<Card, Proto.Card> # 这个客户端当前看到的每张牌（背面牌也在里面，只是没有牌面）
---@field private idCounter integer # 视图 id 的号源（每个连接一套）
local M = Class 'CardSync.View'

---@param player Player
function M:__init(player)
    self.player    = player
    self.cards     = {}
    self.idCounter = 0
end

--- 发一个视图号
---@return integer
function M:nextId()
    self.idCounter = self.idCounter + 1
    return self.idCounter
end

--- 按这个视角组装一张牌（看不见内容就只给 id 与区域）
---@param card Card
---@param id integer
---@return Proto.Card
function M:toCard(card, id)
    local zone   = card:getZone()
    ---@type Proto.Card
    local result = { id = id, zone = toZone(zone) }
    if zone and contentVisible(zone, moe.cardSync.lastVisible[card], self.player) then
        local own = card.ownFace
        result.template = { name = own.name, suit = own.suit, point = own.point }
        local modifier = card.modifier
        if modifier then
            result.modifier = { name = modifier.name, suit = modifier.suit, point = modifier.point }
        end
    end
    return result
end

--- 这个连接多了一张新牌：发号、记账；看不见牌面的还要与同区一张匿名牌把号对调
---@param card Card
---@return Proto.Card # 要发给这个客户端的快照
function M:create(card)
    local snapshot = self:toCard(card, self:nextId())
    self.cards[card] = snapshot
    local zone = card:getZone()
    if zone and snapshot.template == nil then
        local other = self.player.game.random:pick(hiddenIn(self, card, zone))
        if other ~= card then
            self.cards[card], self.cards[other] = self.cards[other], snapshot
        end
    end
    return snapshot
end

--- 同一区里牌面变了没有：变了就原地换一份快照（号不变）
---@param card Card
---@return Proto.Card? # 变了才给（没变就不用发）
function M:update(card)
    local old   = self.cards[card]
    local fresh = self:toCard(card, old.id)
    if sameCard(old, fresh) then
        return nil
    end
    self.cards[card] = fresh
    return fresh
end

--- 这个连接看不到这张牌了：从账里划掉
---@param card Card
function M:remove(card)
    self.cards[card] = nil
end

--- 丢掉现在这份账（全量重发前用）
function M:reset()
    self.cards = {}
end

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
        view = New 'CardSync.View' (player)
        moe.cardSync.views[client] = view
    end
    return view
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
            local old = view.cards[card]
            if not old then
                creates[#creates + 1] = view:create(card)
            elseif sameZone(old.zone, toZone(card:getZone())) then
                local fresh = view:update(card)
                if fresh then
                    updates[#updates + 1] = fresh
                end
            else
                removes[#removes + 1] = old.id
                view:remove(card)
                creates[#creates + 1] = view:create(card)
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
    ---@type function[]
    local undos = {
        game:on('卡牌-进入区域', function (card, zone, visible)
            local from = moe.cardSync.lastLeave[card]
            moe.cardSync.lastLeave[card] = nil
            moe.cardSync.lastVisible[card] = visible
            addToZone(game, card, zone)
            if from then
                notifyMove(card, from, zone)
            end
            markDirty(game, card)
        end),
        game:on('卡牌-离开区域', function (card, zone)
            moe.cardSync.lastLeave[card] = zone
            removeFromZone(game, card, zone)
            markDirty(game, card)
        end),
        game:on('卡牌-变化', function (card)
            markDirty(game, card)
        end),
    }
    return function ()
        for _, undo in ipairs(undos) do
            undo()
        end
    end
end

--- 把这一局所有牌区里的牌全量发一遍（开局 / 重连用）
---@param game Game
function moe.cardSync.syncAll(game)
    moe.cardSync.dirty[game] = nil
    -- 区域状态是所有连接共用的一份：先照内核的现状重建一遍
    moe.cardSync.zones[game] = {}
    local zones = allZones(game)
    for _, zone in ipairs(zones) do
        for _, card in ipairs(zone:list()) do
            addToZone(game, card, zone)
        end
    end
    broadcast(game, function (view)
        view:reset()
        ---@type Proto.Card[]
        local cards = {}
        for _, zone in ipairs(zones) do
            for _, card in ipairs(zone:list()) do
                moe.cardSync.lastVisible[card] = nil
                cards[#cards + 1] = view:create(card)
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
