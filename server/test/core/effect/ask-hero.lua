local fs = require 'bee.filesystem'
local lt = require 'test.ltest'

local probeDir = moe.env.ROOT_PATH / 'tmp' / 'ask-hero-probe'

local HEROES = [[
Hero '甲'
Hero '乙'
Hero '丙'
]]

---@return Game
---@return Player # 被问者
local function newGame()
    fs.remove_all(probeDir)
    fs.create_directories(probeDir)
    local file = probeDir / '探针' / '武将.lua'
    fs.create_directories(file:parent_path())
    local ok, err = moe.util.saveFile(file:string(), HEROES)
    assert(ok, err)

    local game = moe.game.create {
        seats    = 2,
        random   = moe.random.create(1),
        sources  = { probeDir:string() .. '/*' },
        packages = { '探针' },
    }
    local attributeSystem = game:getAttributeSystem()
    attributeSystem:define('体力', {
        min    = -999999,
        max    = 999999,
        simple = true,
    })
    local player = moe.player.create(game, { attributes = attributeSystem:createInstance() })
    game.desk:sit(1, player)
    return game, player
end

lt.test('询问：一次往返（候选名单摆在询问上）', function ()
    local game, player = newGame()
    local first  = assert(game:getHero('甲'))
    local second = assert(game:getHero('乙'))
    local third  = assert(game:getHero('丙'))

    ---@type AskHero?
    local asked = nil
    game:on('武将-询问', function (askHero)
        asked = askHero
        return third
    end)

    local ask = game:askHero(player, '选将', { hero = { first, second, third } })

    lt.assertEquals('种类标识', 'askHero', ask.kind)
    lt.assertEquals('被问者', player, ask.to)
    lt.assertEquals('缘由', '选将', ask.reason)
    local fromAnswerer = assert(asked, '应答方没被问到')
    lt.assertEquals('应答方拿到的就是这一条询问', ask, fromAnswerer)
    lt.assertEquals('候选名单挂在询问上', third, assert(fromAnswerer.options)[3])
    lt.assertEquals('答复成为结果', third, ask.hero)
    lt.assertEquals('首选也是它', third, assert(ask.heroes)[1])
end)

lt.test('询问：答复不在候选里 ⇒ 拒收', function ()
    local game, player = newGame()
    local first  = assert(game:getHero('甲'))
    local second = assert(game:getHero('乙'))
    local third  = assert(game:getHero('丙'))

    game:on('武将-询问', function ()
        return third
    end)

    local ask = game:askHero(player, '选将', { hero = { first, second } })

    lt.assertEquals('原因', '答复的目标不在可选项里', ask.err)
    lt.assertEquals('没有答复', nil, ask.hero)
end)

lt.test('询问：答复重复 ⇒ 拒收', function ()
    local game, player = newGame()
    local first  = assert(game:getHero('甲'))

    game:on('武将-询问', function ()
        return { first, first }
    end)

    local ask = game:askHero(player, '选将', { hero = { first }, min = 2, max = 2 })

    lt.assertEquals('原因', '答复的目标重复了', ask.err)
end)

lt.test('询问：个数区间（一次挑两名）', function ()
    local game, player = newGame()
    local first  = assert(game:getHero('甲'))
    local second = assert(game:getHero('乙'))

    ---@type integer
    local replies = 0
    game:on('武将-询问', function ()
        replies = replies + 1
        if replies == 1 then
            return first
        end
        return { first, second }
    end)

    local few = game:askHero(player, '选将', { hero = { first, second }, min = 2, max = 2 })
    lt.assertEquals('只给一名 ⇒ 拒收', '至少要指定 2 个目标', few.err)

    local ok = game:askHero(player, '选将', { hero = { first, second }, min = 2, max = 2 })
    lt.assertEquals('给了两名 ⇒ 成立', true, ok.success)
    lt.assertEquals('两名都在', 2, #ok.heroes)
end)

lt.test('询问：不给条件 = 不做限制', function ()
    local game, player = newGame()
    local third  = assert(game:getHero('丙'))

    game:on('武将-询问', function (askHero)
        lt.assertEquals('没有候选名单', nil, askHero.options)
        return third
    end)

    local ask = game:askHero(player, '测试')

    lt.assertEquals('成立了', true, ask.success)
    lt.assertEquals('答复照收', third, ask.hero)
end)

lt.test('询问：min 为 0 ⇒ 没人表态也算成立', function ()
    local game, player = newGame()
    local first  = assert(game:getHero('甲'))

    local ask = game:askHero(player, '选将', { hero = { first }, min = 0 })

    lt.assertEquals('成立了', true, ask.success)
    lt.assertEquals('没有答复', 0, #ask.heroes)
end)

lt.test('询问：没人表态 ⇒ 取消', function ()
    local game, player = newGame()
    local first  = assert(game:getHero('甲'))

    local ask = game:askHero(player, '选将', { hero = { first } })

    lt.assertEquals('没成立', false, ask.success)
    lt.assertEquals('原因', '取消', ask.err)
end)
