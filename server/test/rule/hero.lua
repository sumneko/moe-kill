local fs      = require 'bee.filesystem'
local lt      = require 'test.ltest'
local support = require 'test.rule.support'

local probeDir = moe.env.ROOT_PATH / 'tmp' / 'hero-setup-probe'

---@param rel string
---@param content string
local function write(rel, content)
    local file = probeDir / rel
    fs.create_directories(file:parent_path())
    local ok, err = moe.util.saveFile(file:string(), content)
    assert(ok, err)
end

---@return fun() # 配 <close> 用
local function useProbe()
    fs.remove_all(probeDir)
    fs.create_directories(probeDir)
    return function ()
        fs.remove_all(probeDir)
    end
end

lt.test('武将装配：装上之后读到牌面数据与体力', function ()
    local run    = support.start { count = 2, packages = { '标准' } }
    local player = run.players[1]
    local hero   = assert(run.game:getHero('曹操'))

    player:setHero(hero)

    lt.assertEquals('装的是这张武将', hero, player.hero)
    lt.assertEquals('势力跟着来', '魏', player.kingdom)
    lt.assertEquals('性别跟着来', '男', player.sex)
    lt.assertEquals('体力上限用武将的（覆写了默认值）', 4, player:getAttr('体力上限'))
    lt.assertEquals('体力是初始值', 4, player:getAttr('体力'))
end)

lt.test('武将装配：装上就把他的技能挂上', function ()
    local run    = support.start { count = 2, packages = { '标准' } }
    local player = run.players[1]

    player:setHero(assert(run.game:getHero('曹操')))

    lt.assertEquals('有【奸雄】', true, player:hasSkill('奸雄'))
    lt.assertEquals('没装身份场 ⇒ 主公技不挂', false, player:hasSkill('护驾'))
end)

lt.test('武将牌面：势力与性别的声明与读法', function ()
    useProbe()
    write('探针/武将.lua', [[
Hero '甲'
    : kingdom '魏'
    : sex '男'

Hero '乙'
    : kingdom '蜀'
    : kingdom '吴'

Hero '丙'
]])

    local run = support.start {
        count    = 2,
        sources  = { './package/*', probeDir:string() .. '/*' },
        packages = { '标准', '探针' },
    }

    local hero = assert(run.game:getHero('甲'))
    lt.assertEquals('势力', '魏', hero:getKingdom())
    lt.assertEquals('性别', '男', hero:getSex())

    lt.assertEquals('重复调以后写的为准', '吴', assert(run.game:getHero('乙')):getKingdom())

    local blank = assert(run.game:getHero('丙'))
    lt.assertEquals('没声明的势力是空', nil, blank:getKingdom())
    lt.assertEquals('没声明的性别是空', nil, blank:getSex())
end)

lt.test('武将牌面：体力的声明与读法', function ()
    useProbe()
    write('探针/武将.lua', [[
Hero '只给上限'
    : hp(4)

Hero '给了初始值'
    : hp(3, 1)

Hero '重复调'
    : hp(3)
    : hp(5)
]])

    local run = support.start {
        count    = 2,
        sources  = { './package/*', probeDir:string() .. '/*' },
        packages = { '标准', '探针' },
    }

    local maxHp, hp = assert(run.game:getHero('只给上限')):getHp()
    lt.assertEquals('上限 4', 4, maxHp)
    lt.assertEquals('不给初始体力值就取上限', 4, hp)

    maxHp, hp = assert(run.game:getHero('给了初始值')):getHp()
    lt.assertEquals('上限 3', 3, maxHp)
    lt.assertEquals('初始 1', 1, hp)

    maxHp, hp = assert(run.game:getHero('重复调')):getHp()
    lt.assertEquals('重复调以后写的为准', 5, maxHp)
    lt.assertEquals('初始体力值跟着新上限', 5, hp)
end)

lt.test('武将装配：初始体力值可以不为上限', function ()
    useProbe()
    write('探针/武将.lua', "Hero '残血'\n    : hp(3, 1)")

    local run = support.start {
        count    = 2,
        sources  = { './package/*', probeDir:string() .. '/*' },
        packages = { '标准', '探针' },
    }
    local player = run.players[1]
    player:setHero(assert(run.game:getHero('残血')))

    lt.assertEquals('上限 3', 3, player:getAttr('体力上限'))
    lt.assertEquals('体力 1', 1, player:getAttr('体力'))
end)

lt.test('武将装配：先选将再开局，默认体力不覆盖', function ()
    local run = support.start {
        count       = 2,
        packages    = { '标准' },
        beforeStart = function (game, players)
            players[1]:setHero(assert(game:getHero('曹操')))
        end,
    }

    lt.assertEquals('上限还是武将的', 4, run.players[1]:getAttr('体力上限'))
    lt.assertEquals('体力也是武将的', 4, run.players[1]:getAttr('体力'))
    lt.assertEquals('没选将的那个用默认值', 5, run.players[2]:getAttr('体力上限'))
end)

lt.test('武将装配：主公加成叠在武将之上', function ()
    local run = support.start {
        count       = 4,
        packages    = { '标准', '身份场' },
        beforeStart = function (game, players)
            local hero = assert(game:getHero('曹操'))
            for _, player in ipairs(players) do
                player:setHero(hero)
            end
        end,
    }

    local lord = run.players[1]
    lt.assertEquals('1 号位是主公', '主公', lord.identity)
    lt.assertEquals('上限 = 武将 4 + 主公加成 1', 5, lord:getAttr('体力上限'))
    lt.assertEquals('体力也跟上', 5, lord:getAttr('体力'))
    lt.assertEquals('别人还是武将的 4', 4, run.players[2]:getAttr('体力上限'))
end)

lt.test('武将装配：没选将就还是默认体力', function ()
    local run    = support.start { count = 2, packages = { '标准' } }
    local player = run.players[1]

    lt.assertEquals('上限是默认值', 5, player:getAttr('体力上限'))
    lt.assertEquals('体力也是', 5, player:getAttr('体力'))
    lt.assertEquals('没有武将', nil, player.hero)
    lt.assertEquals('没有势力', nil, player.kingdom)
end)

lt.test('武将装配：武将没写体力就用默认值', function ()
    useProbe()
    write('探针/武将.lua', "Hero '没写体力'\n    : kingdom '群'")

    local run = support.start {
        count    = 2,
        sources  = { './package/*', probeDir:string() .. '/*' },
        packages = { '标准', '探针' },
    }
    local player = run.players[1]
    local hero   = assert(run.game:getHero('没写体力'))
    player:setHero(hero)

    local maxHp, hp = hero:getHp()
    lt.assertEquals('读法也兜成默认体力', 5, maxHp)
    lt.assertEquals('初始体力值同上限', 5, hp)

    lt.assertEquals('上限兜底成默认体力', 5, player:getAttr('体力上限'))
    lt.assertEquals('体力也是', 5, player:getAttr('体力'))
    lt.assertEquals('其余字段照旧', '群', player.kingdom)
end)
