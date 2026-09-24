local fs = require 'bee.filesystem'
local lt = require 'test.ltest'

local probeDir = moe.env.ROOT_PATH / 'tmp' / 'use-card-to-card-probe'

fs.remove_all(probeDir)
fs.create_directories(probeDir)
do
    local file = probeDir / '探针' / '牌.lua'
    fs.create_directories(file:parent_path())
    local ok, err = moe.util.saveFile(file:string(), [[
Card '抵消牌'
    : on('对卡牌生效', function (cardEffectToCard)
        cardEffectToCard.user:setTag('抵消掉了', cardEffectToCard.target)
    end)
Card '受检牌'
    : on('对卡牌生效', function () end)
Card '没声明牌'
]])
    assert(ok, err)
end

---@param count integer
---@return Game
---@return Player[] # 按座位号升序
local function newGame(count)
    local random = moe.random.create(1)
    local game   = moe.game.create {
        seats    = count,
        random   = random,
        sources  = { './package/*', probeDir:string() .. '/*' },
        packages = { '探针' },
    }
    local desk = game.desk
    local attributeSystem = game:getAttributeSystem()
    attributeSystem:define('体力', {
        min    = -999999,
        max    = 999999,
        simple = true,
    })
    ---@type Player[]
    local players = {}
    for i = 1, count do
        local player = moe.player.create(game, { attributes = attributeSystem:createInstance() })
        desk:sit(i, player)
        player:setAttr('体力', 4)
        players[i] = player
    end
    game.turnPlayer = players[1]
    return game, players
end

lt.test('对牌使用：用一张牌，目标是一张牌', function ()
    local game, players = newGame(2)
    local user = players[1]
    local hand = assert(user:getZone('手牌'))
    local card = game:createCard('抵消牌')
    hand:put(card)
    local target = game:createCard('没声明牌')

    local useCard = game:useCardToCard(user, card, target)

    lt.assertEquals('种类标识', 'useCardToCard', useCard.kind)
    lt.assertEquals('目标牌就是给的那张', target, user:getTag('抵消掉了'))
    lt.assertEquals('牌已经离开手牌', 0, hand:count())
    lt.assertEquals('用掉的牌进弃牌堆', true, moe.util.arrayHas(game:getZone('弃牌'):list(), card))
end)

lt.test('对牌使用：钩子拿得到这次用牌', function ()
    local game, players = newGame(2)
    local user = players[1]
    local hand = assert(user:getZone('手牌'))
    local card = game:createCard('抵消牌')
    hand:put(card)
    local target = game:createCard('没声明牌')

    ---@type Card?
    local seenTarget = nil
    ---@type Card?
    local checkedTarget = nil
    ---@type UseCardToCard?
    local seenUseCard = nil
    game:on('卡牌-能否使用', function (check)
        checkedTarget = check.target
    end)
    game:on('卡牌-结算后', function (effect)
        if effect.kind == 'useCardToCard' then
            ---@cast effect UseCardToCard
            seenTarget  = effect.targetCard
            seenUseCard = effect
        end
    end)

    game:useCardToCard(user, card, target)

    lt.assertEquals('校验时告诉内容侧目标牌', target, checkedTarget)
    lt.assertEquals('结算后拿得到目标牌', target, seenTarget)
    lt.assertEquals('结算后拿到这次用牌', true, seenUseCard ~= nil)
    lt.assertEquals('这次使用记下了它产生的那次生效', 'cardEffectToCard', assert(seenUseCard).cardEffectToCard.kind)
end)

lt.test('对牌使用：没声明「对卡牌生效」就用不了', function ()
    local game, players = newGame(2)
    local user = players[1]
    local hand = assert(user:getZone('手牌'))
    local card = game:createCard('没声明牌')
    hand:put(card)

    local ok, reason = game:canUseToCard(user, card)
    lt.assertEquals('不成立', false, ok)
    lt.assertEquals('原因', '「探针.没声明牌」没有声明「对卡牌生效」，不能对牌使用', reason)

    lt.assertFailed('用也用不出去', game:useCardToCard(user, card, game:createCard('没声明牌')))
    lt.assertEquals('牌留在手上', 1, hand:count())
end)

lt.test('对牌使用：不在手上的牌不成立', function ()
    local game, players = newGame(2)
    local user = players[1]
    local card = game:createCard('抵消牌')

    local ok, reason = game:canUseToCard(user, card, game:createCard('没声明牌'))
    lt.assertEquals('不成立', false, ok)
    lt.assertEquals('原因', '使用者手上没有这张牌', reason)
end)

lt.test('对牌使用：内容侧的否决带着目标牌', function ()
    local game, players = newGame(2)
    local user = players[1]
    local hand = assert(user:getZone('手牌'))
    local card = game:createCard('受检牌')
    hand:put(card)

    ---@type Card?
    local checkedTarget = nil
    game:on('卡牌-能否使用', function (check)
        if check.card == card then
            checkedTarget = check.target
            return '这张牌不能对这个目标用'
        end
    end)

    local target = game:createCard('没声明牌')
    local ok, reason = game:canUseToCard(user, card, target)
    lt.assertEquals('否决时拿得到目标牌', target, checkedTarget)
    lt.assertEquals('不成立', false, ok)
    lt.assertEquals('原因来自内容侧', '这张牌不能对这个目标用', reason)
end)

lt.test('对牌使用：自己的阶段里用一次就记一次账', function ()
    local game, players = newGame(2)
    local user = players[1]
    local hand = assert(user:getZone('手牌'))
    local card = game:createCard('抵消牌')
    hand:put(card)
    local phase <close> = game:enterPhase(user, '出牌')

    game:useCardToCard(user, card, game:createCard('没声明牌'))

    lt.assertEquals('记在出牌阶段上', 1, phase:getUseCount('抵消牌'))
end)
