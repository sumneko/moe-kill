--- user 侧测试的公共夹具：一对真客户端（内存 Link，帧走真协议）+ 两人局 + 发牌
---@class Test.UserSupport
local M = {}

local lt = require 'test.ltest'

--- 全部内容包的来源（`@基础` / `标准` / `身份场`）
M.packageSource = (moe.env.ROOT_PATH:parent_path() / 'package' / '*'):string()

--- 造一对对接好、都起了读循环的客户端
---@return Client # 前端侧
---@return Client # 后端侧
function M.connect()
    local a, b = moe.link.pair()
    local front = moe.client.create(a)
    local back  = moe.client.create(b)
    front:start()
    back:start()
    return front, back
end

--- 让两个座位坐好、每人接一个客户端并接入下行
---@param game Game
---@return Player[]
local function seatAll(game)
    ---@type Player[]
    local players = {}
    for i = 1, 2 do
        local player = moe.player.create(game, { attributes = game:getAttributeSystem():createInstance() })
        local _, back = M.connect()
        game.desk:sit(i, player)
        player:setUser(New 'ClientUser' (game, back))
        assert(player.user):attach()
        players[i] = player
    end
    return players
end

--- 搭一个两人局：每人坐好、都接了客户端并接入下行
---@param sources? string[] # 包来源（省略 = 只装公共牌定义）
---@return Game
---@return Player[]
function M.newGame(sources)
    local game = moe.game.create {
        seats   = 2,
        random  = moe.random.create(1),
        sources = sources or { lt.cardSource },
    }
    return game, seatAll(game)
end

--- 发两张候选牌并搬进他的手牌（他那份卡牌视图账里才有号）
---@async
---@param game Game
---@param player Player
---@return Card
---@return Card
function M.dealCards(game, player)
    local c1 = game:createCard('杀', '黑桃', 7)
    local c2 = game:createCard('闪', '红桃', 2)
    game:moveCard({ c1, c2 }, player:getZone('手牌'))
    moe.await.sleep(0)
    return c1, c2
end

--- 这张牌在那人的客户端视图账里的协议号
---@param player Player
---@param card Card
---@return integer
function M.cardId(player, card)
    local user = assert(player.user)
    ---@cast user ClientUser
    return assert(user.cardView.cardMap[card]).id
end

--- 搭一个装了「标准」包的两人局（要用真牌的业务链用这个）：角色按标准值初始化属性，不然距离算不出来
---@return Game
---@return Player[]
function M.newPackageGame()
    local game = moe.game.create {
        seats    = 2,
        random   = moe.random.create(1),
        sources  = { M.packageSource },
        packages = { '标准' },
    }
    local players = seatAll(game)
    for _, player in ipairs(players) do
        player:setAttr('体力上限', 4)
        player:setAttr('体力', 4)
        player:setAttr('攻击范围', 1)
    end
    return game, players
end

--- 造一张内容包里的真牌并搬进他的牌区（他那份卡牌视图账里才有号）
---@async
---@param game Game
---@param player Player
---@param name string
---@param suit? string
---@param point? integer
---@param zone? string
---@return Card
function M.giveCard(game, player, name, suit, point, zone)
    local card = game:createCard(name, suit, point)
    game:moveCard(card, player:getZone(zone or '手牌'))
    moe.await.sleep(0)
    return card
end

return M
