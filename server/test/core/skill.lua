local fs = require 'bee.filesystem'
local lt = require 'test.ltest'

local probeDir = moe.env.ROOT_PATH / 'tmp' / 'skill-probe'

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
    write('探针/技能.lua', source)
    return moe.game.create {
        seats    = 1,
        random   = moe.random.create(1),
        sources  = { probeDir:string() .. '/*' },
        packages = { '探针' },
    }
end

local PROBE = [[
Skill '奸雄'
    : tags { '锁定技' }
    : auto(true)

Skill '制衡'
]]

lt.test('技能定义：声明与读回', function ()
    useProbe()
    local game  = newGame(PROBE)
    local skill = assert(game:getSkill('奸雄'), '该有定义')

    lt.assertEquals('裸名', '奸雄', skill.name)
    lt.assertEquals('包名', '探针', skill.package)
    lt.assertEquals('完整名', '探针.奸雄', skill.fullName)
    lt.assertEquals('来源是声明它的文件', '探针/技能.lua', skill.source)
end)

lt.test('技能定义：不写自动同意就是关（每次问）', function ()
    useProbe()
    local game   = newGame(PROBE)
    local player = moe.player.create(game, { attributes = game:getAttributeSystem():createInstance() })

    lt.assertEquals('显式写的', true, player:addSkill('奸雄').auto)
    lt.assertEquals('不写就是关', false, player:addSkill('制衡').auto)
end)

lt.test('技能：自动同意开着就不问，关着问一次', function ()
    useProbe()
    local game   = newGame("Skill '甲' : auto(true)\nSkill '乙'")
    local player = moe.player.create(game, { attributes = game:getAttributeSystem():createInstance() })

    ---@type string[]
    local asked = {}
    local answer = '发动'
    game:on('决策-询问', function (ask)
        ---@cast ask AskChoice
        asked[#asked + 1] = ask.reason
        return answer
    end)

    local jia = player:addSkill('甲')
    lt.assertEquals('开关跟着定义走', true, jia.auto)
    lt.assertEquals('开着：直接放行', true, jia:confirm())
    lt.assertEquals('一次都没问', 0, #asked)

    local yi = player:addSkill('乙')
    lt.assertEquals('不写就是关', false, yi.auto)
    lt.assertEquals('关着 + 答发动 ⇒ 要发动', true, yi:confirm())
    lt.assertEquals('问的是技能名', '乙', table.concat(asked, ','))

    answer = '不发动'
    lt.assertEquals('关着 + 答不发动 ⇒ 不发动', false, yi:confirm())
    lt.assertEquals('又问了一次', '乙,乙', table.concat(asked, ','))

    jia.auto = false
    lt.assertEquals('切回手动：也会问', false, jia:confirm())
    lt.assertEquals('这次问的是甲', '乙,乙,甲', table.concat(asked, ','))
end)

lt.test('技能：tryCast 先问一句再发动，不同意就不发动', function ()
    useProbe()
    local game   = newGame("Skill '甲' : auto(true)\nSkill '乙'")
    local player = moe.player.create(game, { attributes = game:getAttributeSystem():createInstance() })

    local answer = '发动'
    game:on('决策-询问', function ()
        return answer
    end)

    local jia = player:addSkill('甲')
    ---@type integer
    local ran = 0
    local cast = jia:tryCast(function ()
        ran = ran + 1
    end)
    lt.assertEquals('自动同意⇒直接发动', 1, ran)
    lt.assertEquals('给回那次发动', jia, assert(cast).source)

    local yi = player:addSkill('乙')
    answer = '不发动'
    ran = 0
    local refused = yi:tryCast(function ()
        ran = ran + 1
    end)
    lt.assertEquals('问了但没同意⇒不发动', 0, ran)
    lt.assertEquals('没发动就没给实例', nil, refused)
end)

lt.test('技能定义：标签', function ()
    useProbe()
    local game = newGame(PROBE)

    local jianxiong = assert(game:getSkill('奸雄'))
    lt.assertEquals('声明过的标签有', true, jianxiong:hasTag('锁定技'))
    lt.assertEquals('没声明的标签没有', false, jianxiong:hasTag('主公技'))
    lt.assertEquals('标签快照', '锁定技', table.concat(jianxiong:getTags(), ','))

    local zhiheng = assert(game:getSkill('制衡'))
    lt.assertEquals('没写过标签就是空', 0, #zhiheng:getTags())
    lt.assertEquals('没写过就都没有', false, zhiheng:hasTag('锁定技'))
end)

lt.test('技能定义：标签可以多次调，取并集', function ()
    useProbe()
    local game = newGame("Skill '护驾'\n    : tags '主公技'\n    : tags { '锁定技', '限定技' }")

    local hudao = assert(game:getSkill('护驾'))
    lt.assertEquals('三次都算上', true,
        hudao:hasTag('主公技') and hudao:hasTag('锁定技') and hudao:hasTag('限定技'))
    lt.assertEquals('一共三个', 3, #hudao:getTags())
end)

lt.test('技能定义：觉醒技视为附带锁定技与限定技', function ()
    useProbe()
    local game = newGame("Skill '觉醒'\n    : tags '觉醒技'")

    local skill = assert(game:getSkill('觉醒'))
    lt.assertEquals('自己算有', true, skill:hasTag('觉醒技'))
    lt.assertEquals('也算锁定技', true, skill:hasTag('锁定技'))
    lt.assertEquals('也算限定技', true, skill:hasTag('限定技'))
    lt.assertEquals('不牵连别的', false, skill:hasTag('主公技'))
    lt.assertEquals('快照仍是声明过的那个', 1, #skill:getTags())
end)

lt.test('技能定义：同一个包里重复声明报错', function ()
    useProbe()
    lt.assertError('重复声明', function ()
        newGame("Skill '奸雄'\nSkill '奸雄'")
    end)
end)

lt.test('技能定义：名字里不能有点号', function ()
    useProbe()
    lt.assertError('名字带点号', function ()
        newGame("Skill '魏.奸雄'")
    end)
end)

lt.test('技能定义：加载之外不能声明', function ()
    useProbe()
    local game = newGame(PROBE)

    lt.assertError('加载之外声明', function ()
        game:declareSkill('突袭')
    end)
end)

lt.test('技能定义：清空规则内容后没了', function ()
    useProbe()
    local game = newGame(PROBE)
    lt.assertEquals('清空前有', true, game:getSkill('奸雄') ~= nil)

    game:resetContent()
    lt.assertEquals('清空后没了', nil, game:getSkill('奸雄'))
end)

lt.test('技能定义：裸名与限定名都能查', function ()
    useProbe()
    local game = newGame(PROBE)

    lt.assertEquals('限定名是同一条', game:getSkill('奸雄'), game:getSkill('探针.奸雄'))
    lt.assertEquals('查不到就是空', nil, game:getSkill('没有这个'))
end)

lt.test('技能定义：与牌名、武将名互不冲突', function ()
    useProbe()
    local game = newGame("Card '奸雄'\nHero '奸雄'\nSkill '奸雄'")

    local card  = assert(game:getCard('奸雄'))
    local hero  = assert(game:getHero('奸雄'))
    local skill = assert(game:getSkill('奸雄'))

    lt.assertEquals('三个不同的对象', true, card ~= hero and hero ~= skill and card ~= skill)
end)
lt.test('技能：挂到角色身上就跑一次「被动」', function ()
    useProbe()
    local game = newGame([[
Skill '探针技能'
    : on('被动', function (skill, host)
        host:bindGC(skill.owner:on('测试-时机', function (value)
            skill.owner:setTag('收到', value)
        end))
    end)
]])
    local player = moe.player.create(game, { attributes = game:getAttributeSystem():createInstance() })

    lt.assertEquals('挂之前没有', false, player:hasSkill('探针技能'))

    local skill = player:addSkill('探针技能')
    lt.assertEquals('挂上了', true, player:hasSkill('探针技能'))
    lt.assertEquals('实例认得自己', player, skill.owner)
    lt.assertEquals('快照里有一条', 1, #player:getSkills())

    player:fire('测试-时机', '甲')
    lt.assertEquals('「被动」里订的生效了', '甲', player:getTag('收到'))

    skill:remove()
    lt.assertEquals('摘掉了', false, player:hasSkill('探针技能'))
    player:setTag('收到', nil)
    player:fire('测试-时机', '乙')
    lt.assertEquals('摘掉后订阅也跟着撤了', nil, player:getTag('收到'))
end)

lt.test('技能：停用后不再生效，重新启用又生效', function ()
    useProbe()
    local game = newGame([[
Skill '探针技能'
    : on('被动', function (skill, host)
        host:bindGC(skill.owner:on('测试-时机', function (value)
            skill.owner:setTag('收到', value)
        end))
    end)
]])
    local player = moe.player.create(game, { attributes = game:getAttributeSystem():createInstance() })
    local skill  = player:addSkill('探针技能')

    player:fire('测试-时机', '甲')
    lt.assertEquals('启用时收得到', '甲', player:getTag('收到'))

    skill:disablePassive()
    player:setTag('收到', nil)
    player:fire('测试-时机', '乙')
    lt.assertEquals('停用后收不到', nil, player:getTag('收到'))

    skill:enablePassive()
    player:fire('测试-时机', '丙')
    lt.assertEquals('重新启用又收得到', '丙', player:getTag('收到'))
end)

lt.test('技能：没有这个技能定义就报错', function ()
    useProbe()
    local game   = newGame(PROBE)
    local player = moe.player.create(game, { attributes = game:getAttributeSystem():createInstance() })

    lt.assertError('没有这个技能', function ()
        player:addSkill('没有这个')
    end)
end)
