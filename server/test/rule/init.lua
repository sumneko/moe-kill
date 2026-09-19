local fs = require 'bee.filesystem'
local lt = require 'test.ltest'

local probeDir = moe.env.ROOT_PATH / 'tmp' / 'rule-probe'

moe.rule.setRoots { probeDir:string() .. '/*' }

---@return unknown
local function prepare()
    fs.remove_all(probeDir)
    fs.create_directories(probeDir)
    return moe.util.defer(function ()
        fs.remove_all(probeDir)
    end)
end

---@param rel string
---@param content string
local function write(rel, content)
    local file = probeDir / 'pk' / rel
    fs.create_directories(file:parent_path())
    local ok, err = moe.util.saveFile(file:string(), content)
    assert(ok, err)
end

---@param ... string
---@return string[]
local function list(...)
    ---@type string[]
    local items = { ... }
    for i, item in ipairs(items) do
        items[i] = 'pk/' .. item
    end
    return items
end

---@param name string
---@return Rule.Card
local function card(name)
    return assert(moe.rule.getCard(name), '规则条目不存在：' .. name)
end

lt.test('规则集：按清单顺序加载并展开目录', function ()
    local guard <close> = prepare()
    write('a.lua', 'rule.card("甲")')
    write('b.lua', 'rule.card("乙")')
    write('包/一.lua', 'rule.card("丙")')
    write('包/二.lua', 'rule.card("丁")')

    local loaded = moe.rule.load(list('a', 'b', '包'))

    lt.assertEquals('加载了三个项（目录展开成两个文件）', 4, #loaded)
    lt.assertEquals('清单顺序保持在前', 'a', loaded[1]:match '([^/\\]+)%.lua$')
    lt.assertEquals('第二个文件次序不变', 'b', loaded[2]:match '([^/\\]+)%.lua$')
    lt.assertEquals('目录里的文件都被加载', true, moe.rule.getCard('丙') ~= nil)
    lt.assertEquals('目录里的第二个文件也被加载', true, moe.rule.getCard('丁') ~= nil)
    lt.assertEquals('清单里的文件也被加载', true, moe.rule.getCard('甲') ~= nil)
end)

lt.test('规则集：不通过模块加载器', function ()
    local guard <close> = prepare()
    write('a.lua', 'rule.card("甲")')

    local reloadCount = #moe.reload.includedNames
    local loaded = moe.rule.load(list('a'))

    lt.assertEquals('确实加载了', 1, #loaded)
    lt.assertEquals('没有进入可重载登记集合', reloadCount, #moe.reload.includedNames)
    lt.assertEquals('没有进入模块缓存', nil, package.loaded[loaded[1]])
end)

lt.test('规则集：同一文件只执行一次', function ()
    local guard <close> = prepare()
    write('a.lua', 'rule.card("甲"):on("跑", function () end)')

    moe.rule.load(list('a', 'a'))

    lt.assertEquals('只执行了一次', 1, #card('甲'):getHandlers('跑'))
end)

lt.test('规则集：依赖先于本文件其余代码执行', function ()
    local guard <close> = prepare()
    write('依赖.lua', 'rule.card("依赖")')
    write('主.lua', 'rule.depends { "./依赖" }\n'
        .. 'local 依赖 = rule.getCard("依赖")\n'
        .. 'rule.card("主"):on("检查", function () return 依赖 ~= nil end)')

    local loaded = moe.rule.load(list('主'))

    lt.assertEquals('两个文件都被执行', 2, #loaded)
    lt.assertEquals('依赖先完成', '依赖', loaded[1]:match '([^/\\]+)%.lua$')
    lt.assertEquals('依赖在本文件后续代码之前已就绪', true, card('主'):getHandlers('检查')[1]())
end)

lt.test('规则集：目录依赖会展开', function ()
    local guard <close> = prepare()
    write('包/一.lua', 'rule.card("甲")')
    write('包/二.lua', 'rule.card("乙")')
    write('主.lua', 'rule.depends { "./包" }')

    moe.rule.load(list('主'))

    lt.assertEquals('目录下的第一个文件被加载', true, moe.rule.getCard('甲') ~= nil)
    lt.assertEquals('目录下的第二个文件被加载', true, moe.rule.getCard('乙') ~= nil)
end)

lt.test('规则集：循环依赖不死循环', function ()
    local guard <close> = prepare()
    write('a.lua', 'rule.depends { "./b" }\nrule.card("甲")')
    write('b.lua', 'rule.depends { "./a" }\nrule.card("乙")')

    local loaded = moe.rule.load(list('a'))

    lt.assertEquals('两个文件各执行一次', 2, #loaded)
    lt.assertEquals('第一个文件走完', true, moe.rule.getCard('甲') ~= nil)
    lt.assertEquals('第二个文件走完', true, moe.rule.getCard('乙') ~= nil)
end)

lt.test('规则集：依赖的依赖也先满足', function ()
    local guard <close> = prepare()
    write('底层.lua', 'rule.card("底层")')
    write('中层.lua', 'rule.depends { "./底层" }\nrule.card("中层")')
    write('顶层.lua', 'rule.depends { "./中层" }')

    moe.rule.load(list('顶层'))

    lt.assertEquals('底层被加载', true, moe.rule.getCard('底层') ~= nil)
    lt.assertEquals('中层被加载', true, moe.rule.getCard('中层') ~= nil)
end)

lt.test('规则集：链式登记并可按名字查询', function ()
    local guard <close> = prepare()
    write('a.lua', 'rule.card("杀")\n'
        .. ':on("选目标", function () end)\n'
        .. ':on("使用", function () end)\n'
        .. ':on("使用", function () end)')

    moe.rule.load(list('a'))

    local 杀 = card('杀')
    lt.assertEquals('可以按名字查到', true, 杀 ~= nil)
    lt.assertEquals('同名得到同一条定义', 杀, moe.rule.card('杀'))
    lt.assertEquals('同名的不同回调分别登记', 1, #杀:getHandlers('选目标'))
    lt.assertEquals('同名回调按次累积', 2, #杀:getHandlers('使用'))
    lt.assertEquals('未登记的事件取到空集合', 0, #杀:getHandlers('不存在'))
end)

lt.test('规则集：清空重载后旧内容不再可见', function ()
    local guard <close> = prepare()
    write('a.lua', 'rule.card("甲")')
    moe.rule.load(list('a'))
    lt.assertEquals('首次加载有甲', true, moe.rule.getCard('甲') ~= nil)

    write('a.lua', 'rule.card("乙")')
    local loaded = moe.rule.load(list('a'))

    lt.assertEquals('重载执行了文件', 1, #loaded)
    lt.assertEquals('旧条目已清空', nil, moe.rule.getCard('甲'))
    lt.assertEquals('新条目已登记', true, moe.rule.getCard('乙') ~= nil)
end)

lt.test('规则集：省略清单时沿用上一次', function ()
    local guard <close> = prepare()
    write('a.lua', 'rule.card("甲")')

    moe.rule.load(list('a'))
    local loaded = moe.rule.load()

    lt.assertEquals('沿用了上次清单', 1, #loaded)
    lt.assertEquals('内容被重新登记', true, moe.rule.getCard('甲') ~= nil)
end)

lt.test('规则集：同名时文件优先于目录', function ()
    local guard <close> = prepare()
    write('包.lua', 'rule.card("文件")')
    write('包/一.lua', 'rule.card("目录")')

    moe.rule.load(list('包'))

    lt.assertEquals('加载的是文件', true, moe.rule.getCard('文件') ~= nil)
    lt.assertEquals('目录没有被展开', nil, moe.rule.getCard('目录'))
end)

lt.test('规则集：清单增删即生效', function ()
    local guard <close> = prepare()
    write('a.lua', 'rule.card("甲")')
    write('b.lua', 'rule.card("乙")')

    moe.rule.load(list('a'))
    lt.assertEquals('清单里没有乙', nil, moe.rule.getCard('乙'))

    moe.rule.load(list('a', 'b'))
    lt.assertEquals('把新文件加进清单即生效', true, moe.rule.getCard('乙') ~= nil)

    moe.rule.load(list('a'))
    lt.assertEquals('从清单移除即失效', nil, moe.rule.getCard('乙'))
end)

lt.test('规则集：文件执行报错时明确失败', function ()
    local guard <close> = prepare()
    write('好的.lua', 'rule.card("甲")')
    write('坏的.lua', 'error("规则集故意报错")')

    local err = lt.assertError('加载以错误结束', function ()
        moe.rule.load(list('好的', '坏的'))
    end) or ''

    lt.assertEquals('失败信息指出出错的文件', true, err:find('坏的', 1, true) ~= nil)
    lt.assertError('此后依赖声明不再被接受', function ()
        moe.rule.depends { '好的' }
    end)
end)

lt.test('规则集：文件解析失败时明确失败', function ()
    local guard <close> = prepare()
    write('语法错.lua', 'local = 1')

    local err = lt.assertError('加载以错误结束', function ()
        moe.rule.load(list('语法错'))
    end) or ''

    lt.assertEquals('失败信息指出出错的文件', true, err:find('语法错', 1, true) ~= nil)
end)

lt.test('规则集：引用了不存在的项时明确失败', function ()
    local guard <close> = prepare()

    lt.assertError('清单项不存在时报错', function ()
        moe.rule.load(list('根本没有这个文件'))
    end)
    lt.assertError('依赖项不存在时报错', function ()
        write('主.lua', 'rule.depends { "./也没有这个依赖" }')
        moe.rule.load(list('主'))
    end)
end)

lt.test('规则集：文件里不需要 require，也拿不到 require', function ()
    local guard <close> = prepare()
    write('a.lua', 'rule.card("甲")')
    write('b.lua', 'require("bee.filesystem")')

    moe.rule.load(list('a'))
    lt.assertEquals('不使用 require 也能加载', true, moe.rule.getCard('甲') ~= nil)

    lt.assertError('拿不到 require', function ()
        moe.rule.load(list('b'))
    end)
end)

lt.test('规则集：文件可以用中文标识符书写', function ()
    local guard <close> = prepare()
    write('杀.lua', 'local 杀 = rule.card "杀"\n'
        .. 'local 伤害 = 1\n'
        .. 'local function 造成伤害(目标)\n'
        .. '    return 目标 .. 伤害\n'
        .. 'end\n'
        .. '杀:on("使用", 造成伤害)')

    moe.rule.load(list('杀'))

    local 杀 = card('杀')
    lt.assertEquals('中文标识符定义的表被登记', true, 杀 ~= nil)
    lt.assertEquals('中文标识符写的函数可调用', '甲1', 杀:getHandlers('使用')[1]('甲'))
end)

lt.test('规则集：rule.depends 只能在加载时使用', function ()
    lt.assertError('加载之外调用依赖声明报错', function ()
        moe.rule.depends { '无所谓' }
    end)
end)

lt.test('规则集：依赖支持相对路径', function ()
    local guard <close> = prepare()
    write('卡牌/杀.lua', 'rule.card("杀")')
    write('主.lua', 'rule.depends { "./卡牌/杀" }')

    local loaded = moe.rule.load(list('主'))

    lt.assertEquals('相对依赖先执行', '卡牌/杀.lua', loaded[1]:match 'pk/(.*)$')
    lt.assertEquals('相对依赖被登记', true, moe.rule.getCard('杀') ~= nil)
end)

lt.test('规则集：相对路径可以跨包', function ()
    local guard <close> = prepare()
    write('基础规则/身份场.lua', 'rule.card("身份场")')
    write('军争/卡牌/火杀.lua', 'rule.depends { "../../基础规则/身份场" }\nrule.card("火杀")')

    moe.rule.load(list('军争/卡牌/火杀'))

    lt.assertEquals('跨包依赖被加载', true, moe.rule.getCard('身份场') ~= nil)
    lt.assertEquals('声明依赖的文件也被加载', true, moe.rule.getCard('火杀') ~= nil)
end)

lt.test('规则集：同一文件的不同写法只执行一次', function ()
    local guard <close> = prepare()
    write('卡牌/杀.lua', 'rule.card("杀"):on("跑", function () end)')
    write('主.lua', 'rule.depends { "./卡牌/../卡牌/杀" }\n'
        .. 'rule.depends { "pk/卡牌/杀" }')

    local loaded = moe.rule.load(list('主'))

    lt.assertEquals('只执行了一次', 1, #card('杀'):getHandlers('跑'))
    lt.assertEquals('只记录两条（依赖与主文件）', 2, #loaded)
end)

lt.test('规则集：跨来源时只执行生效版本', function ()
    local guard <close> = prepare()
    local other = moe.env.ROOT_PATH / 'tmp' / 'rule-probe-other'
    fs.remove_all(other)
    fs.create_directories(other / 'pk' / '卡牌')
    local restore <close> = moe.util.defer(function ()
        fs.remove_all(other)
        moe.rule.setRoots { probeDir:string() .. '/*' }
    end)

    write('卡牌/杀.lua', 'rule.card("前")')
    local ok, err = moe.util.saveFile((other / 'pk' / '卡牌' / '杀.lua'):string(), 'rule.card("后")')
    assert(ok, err)
    moe.rule.setRoots { probeDir:string() .. '/*', other:string() .. '/*' }

    local loaded = moe.rule.load(list('卡牌/杀'))

    lt.assertEquals('只执行了生效版本', 1, #loaded)
    lt.assertEquals('生效的是后一个来源', true, moe.rule.getCard('后') ~= nil)
    lt.assertEquals('前一个来源的同路径文件没执行', nil, moe.rule.getCard('前'))
end)
