local lt = require 'test.ltest'

--- 把答复写死在身上的 User（测试用）
---@class TestUser : User
---@field answer any
local TestUser = Class 'TestUser'

Extends('TestUser', 'User')

---@param answer any
---@return TestUser
local function userWith(answer)
    local user = New 'TestUser' ()
    user.answer = answer
    return user
end

---@param ask Ask
---@return any
function TestUser:ask(ask)
    return self.answer
end

---@param ask AskPlayer
---@return Player|Player[]?
function TestUser:askPlayer(ask)
    return self.answer
end

---@param ask AskCard
---@return AskCard.Answer?
function TestUser:askCard(ask)
    return self.answer
end

---@param count integer
---@return Game
---@return Player[] # 按座位号升序
local function newGame(count)
    local game = moe.game.create {
        seats   = count,
        random  = moe.random.create(1),
        sources = { lt.cardSource },
    }
    local desk = game.desk
    local attributeSystem = game:getAttributeSystem()
    ---@type Player[]
    local players = {}
    for i = 1, count do
        local player = moe.player.create(game, { attributes = attributeSystem:createInstance() })
        desk:sit(i, player)
        players[i] = player
    end
    return game, players
end

lt.test('玩家：User 可以设置、更换、解绑', function ()
    local _, players = newGame(1)
    local player = assert(players[1])

    lt.assertEquals('初始没有 User', nil, player.user)

    local first = userWith(1)
    player:setUser(first)
    lt.assertEquals('设上读得到', first, player.user)

    local second = userWith(2)
    player:setUser(second)
    lt.assertEquals('换人之后是新的人', second, player.user)

    player:setUser(nil)
    lt.assertEquals('解绑之后没有', nil, player.user)
end)

---@async
lt.test('询问：优先问本人的 User（表态了就不再问全局）', function ()
    local game, players = newGame(1)
    local player = assert(players[1])
    player:setUser(userWith(42))

    local asked = 0
    game:on('决策-询问', function ()
        asked = asked + 1
    end)

    local ask = game:ask(player, '测试', '随便')
    lt.assertEquals('拿到 User 给的答复', 42, ask.reply)
    lt.assertEquals('全局没被问', 0, asked)
end)

---@async
lt.test('询问：User 不表态 ⇒ 回落全局时机', function ()
    local game, players = newGame(1)
    local player = assert(players[1])
    -- 没写回答的 User ⇒ 走基类那几个方法 = 不表态
    player:setUser(New 'TestUser' ())

    game:on('决策-询问', function ()
        return 7
    end)

    lt.assertEquals('全局给了答复', 7, game:ask(player, '测试', '随便').reply)
end)

---@async
lt.test('询问：User 与全局都表态 ⇒ 按 User 的', function ()
    local game, players = newGame(1)
    local player = assert(players[1])
    player:setUser(userWith(42))

    game:on('决策-询问', function ()
        return 7
    end)

    lt.assertEquals('User 先说话', 42, game:ask(player, '测试', '随便').reply)
end)

---@async
lt.test('询问：没有 User 时照旧问全局', function ()
    local game, players = newGame(1)
    local player = assert(players[1])

    game:on('决策-询问', function ()
        return 7
    end)

    lt.assertEquals('全局照旧', 7, game:ask(player, '测试', '随便').reply)
end)

---@async
lt.test('询问：要一张牌那一路也优先问 User（子类覆写的钩子）', function ()
    local game, players = newGame(1)
    local player = assert(players[1])
    local card = game:createCard('杀')
    player:setUser(userWith { card = card })

    local asked = 0
    game:on('卡牌-询问', function ()
        asked = asked + 1
    end)

    local ask = game:askCard(player, '测试')
    lt.assertEquals('拿到 User 给的那张牌', card, ask.card)
    lt.assertEquals('全局没被问', 0, asked)
end)

---@async
lt.test('询问：要一名角色那一路也优先问 User', function ()
    local game, players = newGame(2)
    local player = assert(players[1])
    local other = assert(players[2])
    player:setUser(userWith(other))

    local asked = 0
    game:on('决策-询问', function ()
        asked = asked + 1
    end)

    local ask = game:askPlayer(player, '测试', { players = { other } })
    lt.assertEquals('拿到 User 选的人', other, ask.player)
    lt.assertEquals('全局没被问', 0, asked)
end)
