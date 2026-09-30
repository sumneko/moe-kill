local fs = require 'bee.filesystem'
local lt = require 'test.ltest'

local probeDir = moe.env.ROOT_PATH / 'tmp' / 'cast-probe'

---@return unknown # 配 <close> 用
local function useProbe()
    fs.remove_all(probeDir)
    fs.create_directories(probeDir)
    return moe.util.defer(function ()
        fs.remove_all(probeDir)
    end)
end

---@param content string # 探针包里的定义
---@return Game
local function newGame(content)
    local file = probeDir / '探针' / '技能.lua'
    fs.create_directories(file:parent_path())
    local ok, err = moe.util.saveFile(file:string(), content)
    assert(ok, err)
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

---@async
lt.test('发动：里面起的结算挂在它下面（归因）', function ()
    local leave <close> = useProbe()
    local game   = newGame("Card '护甲'\nSkill '甲'")
    local player = newPlayer(game)
    local skill  = player:addSkill('甲')
    local zone   = game:createZone('暂存')
    local card   = game:createCard('护甲')

    ---@type MoveCard?
    local move = nil
    local cast = skill:cast(function ()
        moe.await.sleep(0)
        move = game:moveCard(card, zone)
    end)

    lt.assertEquals('发动的是它自己', skill, cast.source)
    lt.assertEquals('发动者', player, cast.from)
    lt.assertEquals('里面那次挪牌挂在它下面', cast, assert(move).parent)
    lt.assertEquals('挪牌照常生效', zone, card:getZone())
end)

---@async
lt.test('发动：有父效果时不进记牌器', function ()
    local leave <close> = useProbe()
    local game   = newGame("Skill '甲'")
    local player = newPlayer(game)
    local skill  = player:addSkill('甲')

    ---@type Cast?
    local inner = nil
    local outer = skill:cast(function ()
        inner = skill:cast(function () end)
    end)

    lt.assertEquals('外层在平地上起 ⇒ 是根、记了一条', 1, #game:getEffects())
    lt.assertEquals('记的就是它', outer, game:getEffects()[1])
    lt.assertEquals('内层的父是外层', outer, assert(inner).parent)
end)

---@async
lt.test('发动：装备 —— source 是那张牌、发动者是持牌的人', function ()
    local leave <close> = useProbe()
    local game   = newGame("Card '护甲'\nSkill '甲'")
    local player = newPlayer(game)
    local card   = game:createCard('护甲')
    assert(player:getZone('手牌')):accept(card)

    local cast = card:cast(function () end)

    lt.assertEquals('source 是那张牌', card, cast.source)
    lt.assertEquals('发动者是持牌的人', player, cast.from)
end)
