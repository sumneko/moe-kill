--- 卡牌下行同步：每个 ClientUser 一份「他看得见的那份牌」的账 + 按局的收发
---
--- 视图 id **不进内核**：由视图自己的号源发；看不见内容的区里的牌只有 id（匿名代号）。
--- 一批牌进账后，把该区「看不见面」的牌的号整体洗一遍 —— 客户端那边只是多了几个新号，
--- 服务端内部这些号落在谁背上却是随机的，之后移除 / 移动报出去的号都认不出是哪张。

---@class CardSync.API
moe.cardSync = {}

--- 客户端接入了：把这一局的卡牌账带起来（重复调无害）
---@param user User
---@return CardSync.View?
function moe.cardSync.attach(user)
    return user.cardView
end

---@class Game: Class.Base
---@field package cardSync Game.CardSync # 这一局的卡牌下行账本
local Game = Class 'Game'

---@param self Game
---@return Game.CardSync
---@return true
Game.__getter.cardSync = function (self)
    return New 'Game.CardSync' (self), true
end

--- 按局的账本挂在局上：`package` 可见性只给本文件看（内核不认识协议，就不写进 game.lua 了）
---@class Game.CardSync
---@field dirtyCards? table<Card, true> # 还没下发的脏卡（下一笔调度统一发）
---@field viewSeq integer # 视图随机源的种子号源（每份视图发一段：换号挑牌用，不碰局里的随机源）
local S = Class 'Game.CardSync'

---@param game Game
function S:__init(game)
    self.viewSeq   = 0
    self.game      = game

    self:watchEvent()
end

---@param callback fun(user: User)
function S:eachUser(callback)
    for _, player in ipairs(self.game.desk.players) do
        if player.user then
            callback(player.user)
        end
    end
end

---@param card Card
function S:markDirty(card)
    if self.dirtyCards then
        self.dirtyCards[card] = true
        return
    end
    self.dirtyCards = { [card] = true }

    moe.await.wake(function ()
        local dirtyCards = self.dirtyCards
        if not dirtyCards then
            return
        end
        self.dirtyCards = nil

        local cards = moe.util.keysOf(dirtyCards)
        table.sort(cards, function (a, b)
            return a.id < b.id
        end)

        self:eachUser(function (user)
            user:updateCards(cards)
        end)
    end)
end

---@private
function S:watchEvent()
    self.game:on('卡牌-批量移动', function (moves)
        self:eachUser(function (user)
            user:moveCards(moves)
        end)

        for _, move in ipairs(moves) do
            self:markDirty(move.card)
        end
    end)

    self.game:on('卡牌-变化', function (card)
        self:markDirty(card)
    end)
end

--- 一份账（视图 id 是这份账自己的号：每张新牌进来发一个，离区就作废 —— 懒建在 `user.cardView` 上）
---@class CardSync.View : Class.Base
---@field cardMap table<Card, Proto.Card> # 这个客户端当前看到的每张牌（背面牌也在里面，只是没有牌面）
---@field cardZones table<string, Card[]> # 按协议区域分组的牌列表
---@field private idCounter integer # 视图 id 的号源（每份视图一套）
local V = Class 'CardSync.View'

---@param user User
function V:__init(user)
    self.user      = user
    self.cardMap   = {}
    self.cardZones = moe.util.multiTable(2)
    self.idCounter = 0

    local game = user.game
    game.cardSync.viewSeq = game.cardSync.viewSeq + 1
    self.random    = moe.random.create(game.cardSync.viewSeq)

    self:fillCardZones()
end

---@private
function V:fillCardZones()
    local allCards = self.random:shuffle(moe.util.copy(self.user.game.allCards))
    for _, card in ipairs(allCards) do
        local pcard = self:toPCard(card)
        pcard.id = self:nextId()
        table.insert(self.cardZones[assert(pcard.zone)], card)
        self.cardMap[card] = pcard
    end
end

--- 发一个视图号
---@return integer
function V:nextId()
    self.idCounter = self.idCounter + 1
    return self.idCounter
end

--- 协议号转回真牌（这份账里的号；认不到就是空）
---@param id integer
---@return Card?
function V:cardOf(id)
    for card, pcard in pairs(self.cardMap) do
        if pcard.id == id then
            return card
        end
    end
end

---@param card Card
---@return boolean
function V:isCardVisible(card)
    local pcard = self.cardMap[card]
    return pcard?.face?.name ~= nil
end

--- 协议里的区域：拼成一个字符串「名字#玩家号」（玩家号 0 = 无主）
--- 客户端自己拆；同名同主就是同一个区 —— 账本也拿它当索引
---@param zone? Zone
---@return string
function V:toPZone(zone)
    return '{}#{}' % { zone?.name or '', zone?.owner?.id or 0 }
end

--- 把一个区里所有「看不见面」的牌的号整体洗一遍 —— 新牌进账时叫一次，让号与牌的对应关系翻乱
--- 一批牌只洗一次（号码池子就是这一区现存的暗牌号）；整区洗比「两两对调」更彻底，代价是 O(这一区牌数)
---@param key string
function V:shuffleHidden(key)
    local cards = self.cardZones[key]
    if not cards then
        return
    end
    ---@type Proto.Card[]
    local hidden = {}
    ---@type integer[]
    local ids    = {}
    for _, card in ipairs(cards) do
        if not self:isCardVisible(card) then
            local pcard = assert(self.cardMap[card])
            hidden[#hidden + 1] = pcard
            ids[#ids + 1]       = pcard.id
        end
    end
    if #hidden < 2 then
        return
    end
    self.random:shuffle(ids)
    for i, pcard in ipairs(hidden) do
        pcard.id = ids[i]
    end
end

---@param moves Zone.Move[]
function V:moveCards(moves)
    ---@type Proto.CardMove[]
    local pmoves = {}
    for _, move in ipairs(moves) do
        local from = self:toPZone(move.from)
        local to   = self:toPZone(move.to)
        if from ~= to then
            local visible
            if move.visible then
                visible = moe.visibility.isVisibleTo(move.visible, self.user.player)
            else
                visible = move.from?:isVisibleTo(self.user.player)
                       or move.to:isVisibleTo(self.user.player)
            end
            local pcard = self.cardMap[move.card]
            pmoves[#pmoves+1] = {
                id   = visible and pcard?.id   or nil,
                face = visible and pcard?.face or nil,
                from = from,
                to   = to,
            }
        end
    end
    if #pmoves == 0 then
        return
    end
    self.user:notify('Card.Move', {
        moves = pmoves,
    })
end

---@param card Card
---@return Proto.Card
function V:toPCard(card)
    local pcard = self.cardMap[card]
    local visible = card:isVisible(self.user.player)
    return {
        id       = pcard?.id,
        face     = visible and self:toPCardFace(card.ownFace)  or nil,
        modifier = visible and self:toPCardFace(card.modifier) or nil,
        zone     = self:toPZone(card:getZone()),
    }
end

---@param face? Card.Modifier | Card.Face
---@return Proto.CardFace?
function V:toPCardFace(face)
    if not face then
        return nil
    end
    return {
        name  = face.name,
        suit  = face.suit,
        point = face.point,
    }
end

--- 这份账现在的全量快照（每次读实时拼一份，按号排；接了 `Proto.SnapShot.cards`）
---@type Proto.Card[]
V.snapshot = nil

---@param self CardSync.View
---@return Proto.Card[]
V.__getter.snapshot = function (self)
    ---@type Proto.Card[]
    local cards = {}
    for _, list in pairs(self.cardZones) do
        for _, card in ipairs(list) do
            cards[#cards+1] = self.cardMap[card]
        end
    end
    table.sort(cards, function (a, b)
        return a.id < b.id
    end)
    return cards
end

---@param cards Card[]
function V:updateCards(cards)
    ---@type Proto.Card[]
    local updates = {}
    ---@type integer[]
    local removes = {}
    ---@type Proto.Card[]
    local creates = {}
    ---@type table<string, true> # 这一批里被动过号的区（末尾各洗一次，不逐张扫）
    local shuffled = {}
    for _, card in ipairs(cards) do
        ---@type Proto.Card?
        local pcard = self.cardMap[card]
        local oldPZone = pcard?.zone or ''
        local newPZone = self:toPZone(card:getZone())

        if oldPZone == newPZone then
            local newPCard = self:toPCard(card)
            if not moe.util.equal(pcard, newPCard) then
                self.cardMap[card] = newPCard
                updates[#updates+1] = newPCard
            end
        else
            moe.util.arrayRemove(self.cardZones[oldPZone], card)
            table.insert(self.cardZones[newPZone], card)

            if pcard then
                removes[#removes+1] = pcard.id
            end

            pcard = self:toPCard(card)
            pcard.id = self:nextId()
            self.cardMap[card] = pcard
            shuffled[newPZone] = true
            creates[#creates+1] = pcard
        end
    end

    for key in pairs(shuffled) do
        self:shuffleHidden(key)
    end

    if #updates > 0 then
        self.user:notify('Card.Update', {
            cards = updates,
        })
    end
    if #removes > 0 then
        self.user:notify('Card.Remove', {
            ids = removes,
        })
    end
    if #creates > 0 then
        self.user:notify('Card.Create', {
            cards = creates,
        })
    end
end
