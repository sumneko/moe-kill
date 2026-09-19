local fs = require 'bee.filesystem'
local lt = require 'test.ltest'

local probeDir = moe.env.ROOT_PATH / 'tmp' / 'rule-probe'

---@type Game
local game

---@param sources? string[]
---@return Game
local function newGame(sources)
    return moe.game.create {
        desk    = moe.desk.create(4),
        random  = moe.random.create(1),
        sources = sources or { probeDir:string() .. '/*' },
    }
end

---@param items? string[] # 省略时复用局上记的清单
---@return string[] # 这一次实际执行过的文件
local function load(items)
    return moe.loader.install(game, { packages = items })
end

---@return unknown
local function prepare()
    fs.remove_all(probeDir)
    fs.create_directories(probeDir)
    game = newGame()
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
---@return CardDef
local function card(name)
    return assert(game:getCard(name), '规则条目不存在：' .. name)
end

lt.test('规则集：按清单顺序加载并展开目录', function ()
    local guard <close> = prepare()
    write('a.lua', 'Card("甲")')
    write('b.lua', 'Card("乙")')
    write('包/一.lua', 'Card("丙")')
    write('包/二.lua', 'Card("丁")')

    local loaded = load(list('a', 'b', '包'))

    lt.assertEquals('加载了三个项（目录展开成两个文件）', 4, #loaded)
    lt.assertEquals('清单顺序保持在前', 'a', loaded[1]:match '([^/\\]+)%.lua$')
    lt.assertEquals('第二个文件次序不变', 'b', loaded[2]:match '([^/\\]+)%.lua$')
    lt.assertEquals('目录里的文件都被加载', true, game:getCard('丙') ~= nil)
    lt.assertEquals('目录里的第二个文件也被加载', true, game:getCard('丁') ~= nil)
    lt.assertEquals('清单里的文件也被加载', true, game:getCard('甲') ~= nil)
end)

lt.test('规则集：不通过模块加载器', function ()
    local guard <close> = prepare()
    write('a.lua', 'Card("甲")')

    local reloadCount = #moe.reload.includedNames
    local loaded = load(list('a'))

    lt.assertEquals('确实加载了', 1, #loaded)
    lt.assertEquals('没有进入可重载登记集合', reloadCount, #moe.reload.includedNames)
    lt.assertEquals('没有进入模块缓存', nil, package.loaded[loaded[1]])
end)

lt.test('规则集：同一文件只执行一次', function ()
    local guard <close> = prepare()
    write('a.lua', 'Card("甲"):on("跑", function () end)')

    load(list('a', 'a'))

    lt.assertEquals('只执行了一次', 1, #card('甲'):getHandlers('跑'))
end)

lt.test('规则集：依赖先于本文件其余代码执行', function ()
    local guard <close> = prepare()
    write('依赖.lua', 'Card("依赖")')
    write('主.lua', 'Depends { "./依赖" }\n'
        .. 'local dep = game:getCard("依赖")\n'
        .. 'Card("主"):on("检查", function () return dep ~= nil end)')

    local loaded = load(list('主'))

    lt.assertEquals('两个文件都被执行', 2, #loaded)
    lt.assertEquals('依赖先完成', '依赖', loaded[1]:match '([^/\\]+)%.lua$')
    lt.assertEquals('依赖在本文件后续代码之前已就绪', true, card('主'):getHandlers('检查')[1]())
end)

lt.test('规则集：目录依赖会展开', function ()
    local guard <close> = prepare()
    write('包/一.lua', 'Card("甲")')
    write('包/二.lua', 'Card("乙")')
    write('主.lua', 'Depends { "./包" }')

    load(list('主'))

    lt.assertEquals('目录下的第一个文件被加载', true, game:getCard('甲') ~= nil)
    lt.assertEquals('目录下的第二个文件被加载', true, game:getCard('乙') ~= nil)
end)

lt.test('规则集：循环依赖不死循环', function ()
    local guard <close> = prepare()
    write('a.lua', 'Depends { "./b" }\nCard("甲")')
    write('b.lua', 'Depends { "./a" }\nCard("乙")')

    local loaded = load(list('a'))

    lt.assertEquals('两个文件各执行一次', 2, #loaded)
    lt.assertEquals('第一个文件走完', true, game:getCard('甲') ~= nil)
    lt.assertEquals('第二个文件走完', true, game:getCard('乙') ~= nil)
end)

lt.test('规则集：依赖的依赖也先满足', function ()
    local guard <close> = prepare()
    write('底层.lua', 'Card("底层")')
    write('中层.lua', 'Depends { "./底层" }\nCard("中层")')
    write('顶层.lua', 'Depends { "./中层" }')

    load(list('顶层'))

    lt.assertEquals('底层被加载', true, game:getCard('底层') ~= nil)
    lt.assertEquals('中层被加载', true, game:getCard('中层') ~= nil)
end)

lt.test('规则集：链式登记并可按名字查询', function ()
    local guard <close> = prepare()
    write('a.lua', 'Card("杀")\n'
        .. ':on("选目标", function () end)\n'
        .. ':on("使用", function () end)\n'
        .. ':on("使用", function () end)')

    load(list('a'))

    local slash = card('杀')
    lt.assertEquals('可以按名字查到', true, slash ~= nil)
    lt.assertEquals('同名得到同一条定义', slash, game:getCard('杀'))
    lt.assertEquals('同名的不同回调分别登记', 1, #slash:getHandlers('选目标'))
    lt.assertEquals('同名回调按次累积', 2, #slash:getHandlers('使用'))
    lt.assertEquals('未登记的事件取到空集合', 0, #slash:getHandlers('不存在'))
end)

lt.test('规则集：清空重载后旧内容不再可见', function ()
    local guard <close> = prepare()
    write('a.lua', 'Card("甲")')
    load(list('a'))
    lt.assertEquals('首次加载有甲', true, game:getCard('甲') ~= nil)

    write('a.lua', 'Card("乙")')
    local loaded = load(list('a'))

    lt.assertEquals('重载执行了文件', 1, #loaded)
    lt.assertEquals('旧条目已清空', nil, game:getCard('甲'))
    lt.assertEquals('新条目已登记', true, game:getCard('乙') ~= nil)
end)

lt.test('规则集：省略清单时沿用上一次', function ()
    local guard <close> = prepare()
    write('a.lua', 'Card("甲")')

    load(list('a'))
    local loaded = load()

    lt.assertEquals('沿用了上次清单', 1, #loaded)
    lt.assertEquals('内容被重新登记', true, game:getCard('甲') ~= nil)
end)

lt.test('规则集：同名时文件优先于目录', function ()
    local guard <close> = prepare()
    write('包.lua', 'Card("文件")')
    write('包/一.lua', 'Card("目录")')

    load(list('包'))

    lt.assertEquals('加载的是文件', true, game:getCard('文件') ~= nil)
    lt.assertEquals('目录没有被展开', nil, game:getCard('目录'))
end)

lt.test('规则集：清单增删即生效', function ()
    local guard <close> = prepare()
    write('a.lua', 'Card("甲")')
    write('b.lua', 'Card("乙")')

    load(list('a'))
    lt.assertEquals('清单里没有乙', nil, game:getCard('乙'))

    load(list('a', 'b'))
    lt.assertEquals('把新文件加进清单即生效', true, game:getCard('乙') ~= nil)

    load(list('a'))
    lt.assertEquals('从清单移除即失效', nil, game:getCard('乙'))
end)

lt.test('规则集：文件执行报错时明确失败', function ()
    local guard <close> = prepare()
    write('好的.lua', 'Card("甲")')
    write('坏的.lua', 'error("规则集故意报错")')

    local err = lt.assertError('加载以错误结束', function ()
        load(list('好的', '坏的'))
    end) or ''

    lt.assertEquals('失败信息指出出错的文件', true, err:find('坏的', 1, true) ~= nil)
    lt.assertError('此后依赖声明不再被接受', function ()
        Depends { '好的' }
    end)
end)

lt.test('规则集：文件解析失败时明确失败', function ()
    local guard <close> = prepare()
    write('语法错.lua', 'local = 1')

    local err = lt.assertError('加载以错误结束', function ()
        load(list('语法错'))
    end) or ''

    lt.assertEquals('失败信息指出出错的文件', true, err:find('语法错', 1, true) ~= nil)
end)

lt.test('规则集：引用了不存在的项时明确失败', function ()
    local guard <close> = prepare()

    lt.assertError('清单项不存在时报错', function ()
        load(list('根本没有这个文件'))
    end)
    lt.assertError('依赖项不存在时报错', function ()
        write('主.lua', 'Depends { "./也没有这个依赖" }')
        load(list('主'))
    end)
end)

lt.test('规则集：文件里不需要 require，也拿不到 require', function ()
    local guard <close> = prepare()
    write('a.lua', 'Card("甲")')
    write('b.lua', 'require("bee.filesystem")')

    load(list('a'))
    lt.assertEquals('不使用 require 也能加载', true, game:getCard('甲') ~= nil)

    lt.assertError('拿不到 require', function ()
        load(list('b'))
    end)
end)

lt.test('规则集：拿不到内核门面，但能从 game 上建属性系统', function ()
    local guard <close> = prepare()
    write('a.lua', 'local x = core.card.create("杀")')

    lt.assertError('拿不到 core', function ()
        load(list('a'))
    end)

    write('c.lua', 'local x = moe.util.map')
    lt.assertError('拿不到 moe', function ()
        load(list('c'))
    end)

    write('b.lua', 'local system = game:getAttributeSystem()\n'
        .. 'system:define("体力上限", { min = 0 })\n'
        .. 'local attrs = system:createInstance()\n'
        .. 'attrs:set("体力上限", 3)\n'
        .. 'Card("测"):on("跑", function () return attrs:get("体力上限") end)')

    load(list('b'))

    lt.assertEquals('属性系统可用', 3, card('测'):getHandlers('跑')[1]())
end)

lt.test('规则集：能用注入的工具集筛列表', function ()
    local guard <close> = prepare()
    write('a.lua', 'Card("甲"):on("跑", function ()\n'
        .. '    local list = { 1, 2, 3, 4 }\n'
        .. '    local picked = util.filter(list, function (value) return value % 2 == 0 end)\n'
        .. '    assert(util.contains(picked, 4))\n'
        .. '    return table.concat(util.map(picked, tostring), ",")\n'
        .. 'end)')

    load(list('a'))

    lt.assertEquals('筛出偶数再变换', '2,4', card('甲'):getHandlers('跑')[1]())
end)

lt.test('规则集：工具集里只有纯函数', function ()
    local guard <close> = prepare()
    write('a.lua', 'Card("甲"):on("跑", function ()\n'
        .. '    local ready = util.filter ~= nil and util.map ~= nil and util.contains ~= nil\n'
        .. '    local clean = util.loadFile == nil and util.saveFile == nil and util.defer == nil\n'
        .. '    return ready and clean\n'
        .. 'end)')

    load(list('a'))

    lt.assertEquals('滤波 / 变换 / 包含可用，IO 与定时类的拿不到', true, card('甲'):getHandlers('跑')[1]())
end)

lt.test('规则集：文件可以用中文标识符书写', function ()
    local guard <close> = prepare()
    write('杀.lua', 'local 杀 = Card "杀"\n'
        .. 'local 伤害 = 1\n'
        .. 'local function 造成伤害(目标)\n'
        .. '    return 目标 .. 伤害\n'
        .. 'end\n'
        .. '杀:on("使用", 造成伤害)')

    load(list('杀'))

    local slash = card('杀')
    lt.assertEquals('中文标识符定义的表被登记', true, slash ~= nil)
    lt.assertEquals('中文标识符写的函数可调用', '甲1', slash:getHandlers('使用')[1]('甲'))
end)

lt.test('规则集：Depends 只能在加载时使用', function ()
    local guard <close> = prepare()
    lt.assertError('加载之外调用依赖声明报错', function ()
        Depends { '无所谓' }
    end)
end)

lt.test('规则集：依赖支持相对路径', function ()
    local guard <close> = prepare()
    write('卡牌/杀.lua', 'Card("杀")')
    write('主.lua', 'Depends { "./卡牌/杀" }')

    local loaded = load(list('主'))

    lt.assertEquals('相对依赖先执行', '卡牌/杀.lua', loaded[1]:match 'pk/(.*)$')
    lt.assertEquals('相对依赖被登记', true, game:getCard('杀') ~= nil)
end)

lt.test('规则集：相对路径可以跨包', function ()
    local guard <close> = prepare()
    write('基础规则/身份场.lua', 'Card("身份场")')
    write('军争/卡牌/火杀.lua', 'Depends { "../../基础规则/身份场" }\nCard("火杀")')

    load(list('军争/卡牌/火杀'))

    lt.assertEquals('跨包依赖被加载', true, game:getCard('身份场') ~= nil)
    lt.assertEquals('声明依赖的文件也被加载', true, game:getCard('火杀') ~= nil)
end)

lt.test('规则集：同一文件的不同写法只执行一次', function ()
    local guard <close> = prepare()
    write('卡牌/杀.lua', 'Card("杀"):on("跑", function () end)')
    write('主.lua', 'Depends { "./卡牌/../卡牌/杀" }\n'
        .. 'Depends { "pk/卡牌/杀" }')

    local loaded = load(list('主'))

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
    end)

    write('卡牌/杀.lua', 'Card("前")')
    local ok, err = moe.util.saveFile((other / 'pk' / '卡牌' / '杀.lua'):string(), 'Card("后")')
    assert(ok, err)
    game = newGame { probeDir:string() .. '/*', other:string() .. '/*' }

    local loaded = load(list('卡牌/杀'))

    lt.assertEquals('只执行了生效版本', 1, #loaded)
    lt.assertEquals('生效的是后一个来源', true, game:getCard('后') ~= nil)
    lt.assertEquals('前一个来源的同路径文件没执行', nil, game:getCard('前'))
end)

---@param rel string
---@param content string
local function writeDefault(rel, content)
    local file = probeDir / '@默认' / rel
    fs.create_directories(file:parent_path())
    local ok, err = moe.util.saveFile(file:string(), content)
    assert(ok, err)
end

lt.test('规则集：@ 包默认加载、不在清单里、排在最前', function ()
    local guard <close> = prepare()
    write('乙/二.lua', 'Card("乙二")')
    writeDefault('一.lua', 'Card("默认一")')

    local loaded = load(list('乙'))

    lt.assertEquals('清单只写了乙，默认包也执行了', 2, #loaded)
    lt.assertEquals('默认包排在最前，逻辑路径不带 @', '默认/一.lua', loaded[1])
    lt.assertEquals('清单项在后', 'pk/乙/二.lua', loaded[2])
    lt.assertEquals('元信息里的包名也不带 @', true, game:getPackageMeta('默认') ~= nil)
    lt.assertEquals('能按不带 @ 的限定名取到条目', '默认.默认一', card('默认.默认一').fullName)
end)

lt.test('规则集：显式写进清单的默认包也只执行一遍', function ()
    local guard <close> = prepare()
    write('乙/二.lua', 'Card("乙二")')
    writeDefault('一.lua', 'Card("默认一")')

    local loaded = load { '默认', 'pk/乙' }

    lt.assertEquals('默认包只执行一次', 2, #loaded)
    lt.assertEquals('顺序仍是默认包在前', '默认/一.lua', loaded[1])
end)

lt.test('规则集：包内出现 @ 前缀时明确报错', function ()
    local guard <close> = prepare()
    write('甲/@配置.lua', 'Card("甲")')

    lt.assertError('@ 只能出现在包目录名开头', function ()
        load(list('甲'))
    end)
end)

lt.test('规则集：两个局互不影响', function ()
    local guard <close> = prepare()
    write('a.lua', 'Card("甲")')
    write('b.lua', 'game:setValue("数值", 1)\nCard("乙")')

    local source = { probeDir:string() .. '/*' }
    local first  = newGame(source)
    local second = newGame(source)

    moe.loader.install(first, { packages = list('a') })
    moe.loader.install(second, { packages = list('b') })

    lt.assertEquals('第一份只有甲', true, first:getCard('甲') ~= nil and first:getCard('乙') == nil)
    lt.assertEquals('第二份只有乙', true, second:getCard('乙') ~= nil and second:getCard('甲') == nil)
    lt.assertEquals('第一份没有第二份的规则数值', nil, first:getValue('数值'))
    lt.assertEquals('第二份有自己的规则数值', 1, second:getValue('数值'))

    moe.loader.install(first, { packages = list('b') })

    lt.assertEquals('第一份清空重载后拿到乙', true, first:getCard('乙') ~= nil)
    lt.assertEquals('第二份照旧', true, second:getCard('乙') ~= nil)
    lt.assertEquals('第二份的规则数值也没被动过', 1, second:getValue('数值'))
end)
