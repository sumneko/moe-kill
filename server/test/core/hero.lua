local fs = require 'bee.filesystem'
local lt = require 'test.ltest'

local probeDir = moe.env.ROOT_PATH / 'tmp' / 'hero-probe'

---@param rel string
---@param content string
local function write(rel, content)
    local file = probeDir / rel
    fs.create_directories(file:parent_path())
    local ok, err = moe.util.saveFile(file:string(), content)
    assert(ok, err)
end

---@return unknown # 配 <close> 用
local function useProbe()
    fs.remove_all(probeDir)
    fs.create_directories(probeDir)
    return moe.util.defer(function ()
        fs.remove_all(probeDir)
    end)
end

---@param source string # 探针包里的定义
---@return Game
local function newGame(source)
    write('探针/武将.lua', source)
    return moe.game.create {
        seats    = 1,
        random   = moe.random.create(1),
        sources  = { probeDir:string() .. '/*' },
        packages = { '探针' },
    }
end

local PROBE = [[
Hero '甲'
    : skills { '技能一', '技能二' }
    : value('珠联璧合', '乙')
]]

local KIND_PROBE = [[
Hero '甲'
    : addKind('君主')
    : addKind('君主')
    : addKind('测试')

Hero '乙'
    : addKind('测试')
    : kind('君主')

Hero '丙'
]]

lt.test('武将定义：声明与读回', function ()
    useProbe()
    local game = newGame(PROBE)
    local hero = assert(game:getHero('甲'), '该有定义')

    lt.assertEquals('裸名', '甲', hero.name)
    lt.assertEquals('包名', '探针', hero.package)
    lt.assertEquals('完整名', '探针.甲', hero.fullName)

    local skills = hero:getSkills()
    lt.assertEquals('两个技能', 2, #skills)
    lt.assertEquals('按声明顺序', '技能一,技能二', table.concat(skills, ','))
    lt.assertEquals('自带数据读得到', '乙', hero:getValue('珠联璧合'))
end)

lt.test('武将定义：分类（addKind 只追加、不重复）', function ()
    useProbe()
    local game = newGame(KIND_PROBE)
    local hero = assert(game:getHero('甲'))

    lt.assertEquals('两个分类，按声明顺序', '君主,测试', table.concat(hero:getKinds(), ','))
    lt.assertEquals('是君主', true, hero:isKind('君主'))
    lt.assertEquals('没打过的不是', false, hero:isKind('别的'))
end)

lt.test('武将定义：kind 一次定下（会把已经打过的分类换掉）', function ()
    useProbe()
    local game = newGame(KIND_PROBE)
    local hero = assert(game:getHero('乙'))

    lt.assertEquals('只剩后写的那一个', '君主', table.concat(hero:getKinds(), ','))
end)

lt.test('武将定义：没打分类就是空', function ()
    useProbe()
    local game = newGame(KIND_PROBE)
    local hero = assert(game:getHero('丙'))

    lt.assertEquals('分类为空', 0, #hero:getKinds())
    lt.assertEquals('不是任何分类', false, hero:isKind('君主'))
end)

lt.test('武将定义：没声明的字段就是空', function ()
    useProbe()
    local game = newGame("Hero '丙'")
    local hero = assert(game:getHero('丙'))

    lt.assertEquals('技能表是空表', 0, #hero:getSkills())
    lt.assertEquals('没声明过的数据是空', nil, hero:getValue('珠联璧合'))
end)

lt.test('武将定义：重复调以后写的为准', function ()
    useProbe()
    local game = newGame("Hero '甲'\n    : skills { '一' }\n    : skills { '二', '三' }")
    local hero = assert(game:getHero('甲'))

    lt.assertEquals('后写的技能', '二,三', table.concat(hero:getSkills(), ','))
end)

lt.test('武将定义：拿到的技能名是快照', function ()
    useProbe()
    local game = newGame(PROBE)
    local hero = assert(game:getHero('甲'))

    local skills = hero:getSkills()
    skills[1] = '改过的'
    lt.assertEquals('改快照不影响定义', '技能一', hero:getSkills()[1])
end)

lt.test('武将定义：裸名与限定名都能查', function ()
    useProbe()
    local game = newGame(PROBE)
    local hero = assert(game:getHero('甲'))

    lt.assertEquals('限定名是同一条', hero, game:getHero('探针.甲'))
    lt.assertEquals('查不到就是空', nil, game:getHero('没有这个'))
end)

lt.test('武将定义：同一个包里重复声明报错', function ()
    useProbe()
    lt.assertError('重复声明', function ()
        newGame("Hero '甲'\nHero '甲'")
    end)
end)

lt.test('武将定义：名字里不能有点号', function ()
    useProbe()
    lt.assertError('名字带点号', function ()
        newGame("Hero '甲.乙'")
    end)
end)

lt.test('武将定义：加载之外不能声明', function ()
    useProbe()
    local game = newGame(PROBE)

    lt.assertError('加载之外声明', function ()
        game:declareHero('丁')
    end)
end)

lt.test('武将定义：清空规则内容后没了', function ()
    useProbe()
    local game = newGame(PROBE)
    lt.assertEquals('清空前有', true, game:getHero('甲') ~= nil)

    game:resetContent()
    lt.assertEquals('清空后没了', nil, game:getHero('甲'))
end)

lt.test('武将定义：标准包里的武将是定义好的', function ()
    local game = moe.game.create {
        seats    = 1,
        random   = moe.random.create(1),
        sources  = { './package/*' },
        packages = { '标准' },
    }

    local caocao = assert(game:getHero('曹操'))
    local maxHp  = caocao:getHp()
    lt.assertEquals('曹操是魏势力', '魏', caocao:getKingdom())
    lt.assertEquals('曹操是男性', '男', caocao:getSex())
    lt.assertEquals('曹操体力上限 4', 4, maxHp)
    lt.assertEquals('曹操的技能', '奸雄,护驾', table.concat(caocao:getSkills(), ','))

    local liubei = assert(game:getHero('刘备'))
    lt.assertEquals('刘备是蜀势力', '蜀', liubei:getKingdom())
    lt.assertEquals('刘备的技能', '仁德,激将', table.concat(liubei:getSkills(), ','))
end)
