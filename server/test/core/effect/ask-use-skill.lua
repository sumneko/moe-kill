local fs = require 'bee.filesystem'
local lt = require 'test.ltest'

local probeDir = moe.env.ROOT_PATH / 'tmp' / 'ask-use-skill-probe'

fs.remove_all(probeDir)
fs.create_directories(probeDir)
do
    local file = probeDir / '探针' / '技能.lua'
    fs.create_directories(file:parent_path())
    local ok, err = moe.util.saveFile(file:string(), [[
Skill '制衡'
    : on('使用', function (skill, cast)
        cast:setTag('跑过', skill.name)
    end)
Skill '奸雄'
]])
    assert(ok, err)
end

---@return Game
local function newGame()
    return moe.game.create {
        seats    = 1,
        random   = moe.random.create(1),
        sources  = { probeDir:string() .. '/*' },
        packages = { '探针' },
    }
end

---@param game Game
---@return Player
local function newPlayer(game)
    return moe.player.create(game, { attributes = game:getAttributeSystem():createInstance() })
end

lt.test('要一次技能使用：候选只看有主动发动钩子的技能', function ()
    local game   = newGame()
    local player = newPlayer(game)
    player:addSkill('制衡')
    player:addSkill('奸雄')
    game:on('技能-询问', function (ask)
        return nil
    end)

    local ask = game:askUseSkill(player, '出牌')

    lt.assertEquals('种类标识', 'askUseSkill', ask.kind)
    lt.assertEquals('缘由原样带着', '出牌', ask.reason)
    lt.assertEquals('只列出有钩子的那个', 1, #ask.options)
    lt.assertEquals('就是它', '制衡', ask.options[1].name)
end)

lt.test('要一次技能使用：答了就发动，归因在技能名下', function ()
    local game   = newGame()
    local player = newPlayer(game)
    player:addSkill('制衡')
    game:on('技能-询问', function (ask)
        return ask.options[1]
    end)

    local ask = game:askUseSkill(player, '出牌')

    lt.assertEquals('答复读得到', '制衡', assert(ask.skill).name)
    local cast = assert(ask.cast, '入口应该发动它')
    lt.assertEquals('就是一次发动', 'cast', cast.kind)
    lt.assertEquals('归因到技能名下', '制衡', cast.source?.name)
    lt.assertEquals('发动者是他', player, cast.from)
    lt.assertEquals('钩子跑过了', '制衡', cast:getTag('跑过'))
    lt.assertEquals('再调一次不会发动第二遍', cast, ask:use())
end)

lt.test('要一次技能使用：答复不是他身上的技能就拒收', function ()
    local game   = newGame()
    local player = newPlayer(game)
    player:addSkill('制衡')
    local other = newPlayer(game)
    other:addSkill('制衡')
    game:on('技能-询问', function (ask)
        return other:getSkills()[1]
    end)

    local ask = game:askUseSkill(player, '出牌')

    lt.assertEquals('没拿到答复', nil, ask.skill)
    lt.assertEquals('原因', '答复不是可以发动的技能', ask.err)
    lt.assertEquals('也没发动', nil, ask.cast)
end)

lt.test('要一次技能使用：没人应答就没有答复，也不算失败', function ()
    local game   = newGame()
    local player = newPlayer(game)
    player:addSkill('制衡')
    lt.clearErrors()

    local ask = game:askUseSkill(player, '出牌')

    lt.assertEquals('没有答复', nil, ask.skill)
    lt.assertEquals('不算失败', nil, ask.err)
    lt.assertEquals('也没发动', nil, ask.cast)
    lt.assertEquals('没有记下错误', 0, #lt.errors)
end)

lt.test('只到 apply：不等它、也不替你发动出去', function ()
    local game   = newGame()
    local player = newPlayer(game)
    player:addSkill('制衡')
    game:on('技能-询问', function (ask)
        return ask.options[1]
    end)

    local ask = game:startAskUseSkill(player, '出牌')
    lt.assertEquals('刚起完：候选都还没算', 0, #ask.options)

    ask:await()
    lt.assertEquals('等它才结：答复到手', '制衡', assert(ask.skill).name)
    lt.assertEquals('不等你点头就不发动', nil, ask.cast)

    ask:use()
    lt.assertEquals('发动了才有那次发动', '制衡', assert(ask.cast).source?.name)
end)
