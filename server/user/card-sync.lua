--- 卡牌下行同步：每个 ClientUser 一份「他看得见的那份牌」的账 + 按局的收发
---
--- 视图 id **不进内核**：由视图自己的号源发；看不见内容的区里的牌只有 id（匿名代号）。
--- 新牌进账时，看不见牌面的那些会把号与同区另一张匿名牌对调 —— 客户端那边只是多了一个新号，
--- 服务端内部这张新牌背上的却是旧号，之后移除 / 移动报出去的号都认不出是哪张。

---@class CardSync.API
moe.cardSync = {}

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
---@class CardSync.View
---@field cardMap table<Card, Proto.Card> # 这个客户端当前看到的每张牌（背面牌也在里面，只是没有牌面）
---@field cardZones table<string, Card[]> # 按协议区域分组的牌列表
---@field private idCounter integer # 视图 id 的号源（每份视图一套）
local V = Class 'CardSync.View'

--- 协议区域的键（把「同一个区」的牌分到一组用）
---@param zone Proto.Zone?
---@return string
local function keyOfPZone(zone)
    if not zone then
        return ''
    end
    return '{}#{}' % { zone.name or '', zone.player or 0 }
end

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
        local pzoneKey = keyOfPZone(pcard.zone)
        table.insert(self.cardZones[pzoneKey], card)
        self.cardMap[card] = pcard
    end
end

--- 发一个视图号
---@return integer
function V:nextId()
    self.idCounter = self.idCounter + 1
    return self.idCounter
end

---@param card Card
---@return boolean
function V:isCardVisible(card)
    local pcard = self.cardMap[card]
    return pcard?.face?.name ~= nil
end

--- 协议里的区域：既没有名字也没有归属的（临时区）一律是同一个空区域
---@param zone? Zone
---@return Proto.Zone
function V:toPZone(zone)
    return {
        player = zone?.owner?.id,
        name   = zone?.name,
    }
end

---@param card Card
function V:hidden(card)
    if self:isCardVisible(card) then
        return
    end
    local pzone = self:toPZone(card:getZone())
    local cards = self.cardZones[keyOfPZone(pzone)]
    ---@type Card[]
    local hidden = moe.util.arrayFilter(cards, function (c)
        return not self:isCardVisible(c)
    end)

    if #hidden == 0 then
        return
    end

    local target = self.random:pick(hidden)
    if target == card then
        return
    end

    local a = self.cardMap[card]
    local b = self.cardMap[target]
    a.id, b.id = b.id, a.id
end

---@param moves Zone.Move[]
function V:moveCards(moves)
    local pmoves = moe.util.map(moves, function (move)
        local visible
        if move.visible then
            visible = moe.visibility.isVisibleTo(move.visible, self.user.player)
        else
            visible = move.from?:isVisibleTo(self.user.player)
                   or move.to:isVisibleTo(self.user.player)
        end
        local pcard = self.cardMap[move.card]
        ---@type Proto.CardMove
        return {
            id   = visible and pcard?.id   or nil,
            face = visible and pcard?.face or nil,
            from = self:toPZone(move.from),
            to   = self:toPZone(move.to),
        }
    end)
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

---@param cards Card[]
function V:updateCards(cards)
    ---@type Proto.Card[]
    local updates = {}
    ---@type integer[]
    local removes = {}
    ---@type Proto.Card[]
    local creates = {}
    for _, card in ipairs(cards) do
        ---@type Proto.Card?
        local pcard = self.cardMap[card]
        local oldPZone = pcard?.zone
        local newPZone = self:toPZone(card:getZone())
        local oldPZoneKey = keyOfPZone(oldPZone)
        local newPZoneKey = keyOfPZone(newPZone)

        if oldPZoneKey == newPZoneKey then
            local newPCard = self:toPCard(card)
            if not moe.util.equal(pcard, newPCard) then
                self.cardMap[card] = newPCard
                updates[#updates+1] = newPCard
            end
        else
            moe.util.arrayRemove(self.cardZones[oldPZoneKey], card)
            table.insert(self.cardZones[newPZoneKey], card)

            if pcard then
                removes[#removes+1] = pcard.id
            end

            pcard = self:toPCard(card)
            pcard.id = self:nextId()
            self.cardMap[card] = pcard
            self:hidden(card)
            creates[#creates+1] = pcard
        end
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
