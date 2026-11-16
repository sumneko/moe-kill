local lt      = require 'test.ltest'
local support = require 'test.user.support'

---@async
lt.test('调试发牌：列出牌名，并给自己发一张', function ()
    local oldDebug = moe.debug
    moe.debug = true
    local restore <close> = function ()
        moe.debug = oldDebug
    end

    local _, players, fronts = support.newPackageGame()
    local me    = assert(players[1])
    local front = assert(fronts[1])

    local listed, err = front:awaitRequest('Debug.Cards', {})
    lt.assertEquals('列牌名没出错', nil, err)
    ---@cast listed Proto.Result.Debug.Cards
    local names = assert(listed.cards)
    lt.assertEquals('牌表里有【杀】', true, moe.util.arrayHas(names, '杀'))
    lt.assertEquals('牌表里有【闪电】', true, moe.util.arrayHas(names, '闪电'))
    lt.assertEquals('被继承的模板类不进列表', false, moe.util.arrayHas(names, '武器牌'))

    local hand = assert(me:getZone('手牌'))
    local before = hand:count()
    ---@type table<Card, true>
    local seen = {}
    for _, card in ipairs(hand:list()) do
        seen[card] = true
    end

    local _, giveErr = front:awaitRequest('Debug.GiveCard', { name = '闪电' })
    lt.assertEquals('发牌没出错', nil, giveErr)
    lt.assertEquals('手里多了一张', before + 1, hand:count())
    ---@type Card?
    local added = nil
    for _, card in ipairs(hand:list()) do
        if not seen[card] then
            added = card
        end
    end
    lt.assertEquals('发的就是【闪电】', '闪电', assert(added).name)
end)

---@async
lt.test('调试发牌：没有这张牌就报参数不对', function ()
    local oldDebug = moe.debug
    moe.debug = true
    local restore <close> = function ()
        moe.debug = oldDebug
    end

    local _, _, fronts = support.newPackageGame()
    local front = assert(fronts[1])

    local _, err = front:awaitRequest('Debug.GiveCard', { name = '根本没有这张牌' })
    lt.assertEquals('被拒', 'INVALID_PARAMS', assert(err).code == -32602 and 'INVALID_PARAMS' or '别的')
end)

---@async
lt.test('调试发牌：不是调试模式就拒绝', function ()
    local oldDebug = moe.debug
    moe.debug = false
    local restore <close> = function ()
        moe.debug = oldDebug
    end

    local _, _, fronts = support.newPackageGame()
    local front = assert(fronts[1])

    local _, err = front:awaitRequest('Debug.Cards', {})
    lt.assertEquals('被拒', '只有调试模式能这么干', assert(err).message)
end)
