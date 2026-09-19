local fs = require 'bee.filesystem'
local lt = require 'test.ltest'

local probeDir = moe.env.ROOT_PATH / 'tmp' / 'routing-probe'

---@return unknown
local function prepare()
    fs.remove_all(probeDir)
    fs.create_directories(probeDir)
    moe.rule.setRoots { probeDir:string() .. '/*' }
    return moe.util.defer(function ()
        fs.remove_all(probeDir)
    end)
end

---@param rel string
---@param content string
local function write(rel, content)
    local file = probeDir / rel
    fs.create_directories(file:parent_path())
    local ok, err = moe.util.saveFile(file:string(), content)
    assert(ok, err)
end

---@param ... string
---@return string[]
local function list(...)
    return { ... }
end

---@param name string
---@return Rule.Card
local function card(name)
    return assert(moe.rule.getCard(name), '规则条目不存在：' .. name)
end

lt.test('包：定义自动带包前缀并带来源信息', function ()
    local guard <close> = prepare()
    write('标准/卡牌/杀.lua', 'rule.card("杀")')

    moe.rule.load(list('标准'))

    local slash = card('杀')
    lt.assertEquals('裸名', '杀', slash.name)
    lt.assertEquals('包名', '标准', slash.package)
    lt.assertEquals('完整名', '标准.杀', slash.fullName)
    lt.assertEquals('声明它的文件', '标准/卡牌/杀.lua', slash.source)
end)

lt.test('包：包名取自一级目录', function ()
    local guard <close> = prepare()
    write('军争/卡牌/火杀.lua', 'rule.card("火杀")')

    moe.rule.load(list('军争'))

    lt.assertEquals('包名是一级目录而不是卡牌', '军争', card('火杀').package)
    lt.assertEquals('完整名只有两层', '军争.火杀', card('火杀').fullName)
end)

lt.test('包：包外的散落文件报错', function ()
    local guard <close> = prepare()
    write('散落.lua', 'rule.card("甲")')

    lt.assertError('不在包目录里的文件报错', function ()
        moe.rule.load(list('散落'))
    end)
end)

lt.test('包：包目录名里不能含点', function ()
    local guard <close> = prepare()
    write('标准.v1/卡牌/杀.lua', 'rule.card("杀")')

    lt.assertError('包目录名含点报错', function ()
        moe.rule.load(list('标准.v1'))
    end)
end)

lt.test('包：同包重复声明报错', function ()
    local guard <close> = prepare()
    write('标准/卡牌/杀.lua', 'rule.card("杀")')
    write('标准/技能/杀.lua', 'rule.card("杀")')

    local err = lt.assertError('重复声明报错', function ()
        moe.rule.load(list('标准'))
    end) or ''

    lt.assertEquals('报错指出两处来源', true,
        err:find('标准/卡牌/杀.lua', 1, true) ~= nil and err:find('标准/技能/杀.lua', 1, true) ~= nil)
end)

lt.test('包：跨包同名并存', function ()
    local guard <close> = prepare()
    write('标准/卡牌/杀.lua', 'rule.card("杀")')
    write('军争/卡牌/杀.lua', 'rule.card("杀")')

    moe.rule.load(list('标准', '军争'))

    lt.assertEquals('两个包各有一条', true, moe.rule.getCard('标准.杀') ~= nil and moe.rule.getCard('军争.杀') ~= nil)
    lt.assertEquals('两条不是同一个对象', true, moe.rule.getCard('标准.杀') ~= moe.rule.getCard('军争.杀'))
end)

lt.test('包：追加回调走查询入口', function ()
    local guard <close> = prepare()
    write('标准/卡牌/杀.lua', 'rule.card("杀")')
    write('标准/技能/杀的使用.lua', 'rule.depends { "../卡牌/杀" }\n'
        .. 'rule.getCard("杀"):on("使用", function () end)')

    moe.rule.load(list('标准'))

    lt.assertEquals('回调追加到同一条定义上', 1, #card('标准.杀'):getHandlers('使用'))
end)

lt.test('路由：包外裸名走默认路由', function ()
    local guard <close> = prepare()
    write('标准/卡牌/杀.lua', 'rule.card("杀")')
    write('军争/卡牌/杀.lua', 'rule.card("杀")')

    moe.rule.load(list('标准', '军争'))

    lt.assertEquals('取先加载的包', '标准.杀', card('杀').fullName)
    lt.assertEquals('限定名取指定包', '军争.杀', card('军争.杀').fullName)
end)

lt.test('路由：包内裸名优先本包', function ()
    local guard <close> = prepare()
    write('标准/卡牌/杀.lua', 'rule.card("杀")')
    write('军争/卡牌/杀.lua', 'rule.card("杀")\n'
        .. 'local own = rule.getCard("杀")\n'
        .. 'rule.card("检查"):on("跑", function () return own.fullName end)')

    moe.rule.load(list('标准', '军争'))

    lt.assertEquals('包内裸名拿到本包版本', '军争.杀', card('检查'):getHandlers('跑')[1]())
end)

lt.test('路由：本包没有时 fallback', function ()
    local guard <close> = prepare()
    write('标准/卡牌/闪.lua', 'rule.card("闪")')
    write('军争/卡牌/火杀.lua', 'local dodge = rule.getCard("闪")\n'
        .. 'rule.card("检查"):on("跑", function () return dodge and dodge.fullName or "没有取到" end)')

    moe.rule.load(list('标准', '军争'))

    lt.assertEquals('fallback 到默认路由', '标准.闪', card('检查'):getHandlers('跑')[1]())
end)

lt.test('路由：限定名不受包内优先影响', function ()
    local guard <close> = prepare()
    write('标准/卡牌/杀.lua', 'rule.card("杀")')
    write('军争/卡牌/杀.lua', 'rule.card("杀")\n'
        .. 'local fromStandard = rule.getCard("标准.杀")\n'
        .. 'rule.card("检查"):on("跑", function () return fromStandard.fullName end)')

    moe.rule.load(list('标准', '军争'))

    lt.assertEquals('限定名精确取到指定包', '标准.杀', card('检查'):getHandlers('跑')[1]())
end)

lt.test('路由：只有后面的包定义时裸名也可用', function ()
    local guard <close> = prepare()
    write('标准/卡牌/杀.lua', 'rule.card("杀")')
    write('军争/卡牌/火杀.lua', 'rule.card("火杀")')

    moe.rule.load(list('标准', '军争'))

    lt.assertEquals('裸名拿到军争的那条', '军争.火杀', card('火杀').fullName)
end)

lt.test('路由：两种写法是同一个对象', function ()
    local guard <close> = prepare()
    write('标准/卡牌/杀.lua', 'rule.card("杀")')
    write('军争/卡牌/杀.lua', 'rule.card("杀")')

    moe.rule.load(list('标准', '军争'))

    lt.assertEquals('裸名与限定名是同一个对象', true, card('军争.杀') == moe.rule.getCard('军争.杀'))
    lt.assertEquals('包外裸名取的是先加载的包', true, card('杀') == moe.rule.getCard('标准.杀'))
end)

lt.test('路由：未登记的名字查不到', function ()
    local guard <close> = prepare()
    write('标准/卡牌/杀.lua', 'rule.card("杀")')

    moe.rule.load(list('标准'))

    lt.assertEquals('裸名查不到', nil, moe.rule.getCard('闪'))
    lt.assertEquals('限定名查不到', nil, moe.rule.getCard('军争.杀'))
    lt.assertEquals('不存在的包查不到', nil, moe.rule.getCard('没有这个包.杀'))

    ---@type any
    local notString = nil
    lt.assertError('名字必须是字符串', function ()
        moe.rule.getCard(notString)
    end)
end)

lt.test('路由：清单顺序决定裸名解析', function ()
    local guard <close> = prepare()
    write('标准/卡牌/杀.lua', 'rule.card("杀")')
    write('军争/卡牌/杀.lua', 'rule.card("杀")')

    moe.rule.load(list('标准', '军争'))
    lt.assertEquals('先加载的包胜出', '标准.杀', card('杀').fullName)

    moe.rule.load(list('军争', '标准'))
    lt.assertEquals('调换清单顺序后裸名随之改变', '军争.杀', card('杀').fullName)
end)

lt.test('定义入口：只在加载过程中可用', function ()
    local guard <close> = prepare()
    write('标准/卡牌/杀.lua', 'rule.card("杀")')

    moe.rule.load(list('标准'))

    lt.assertError('加载之外声明报错', function ()
        moe.rule.card('闪')
    end)
end)

lt.test('定义入口：名字里不能含点', function ()
    local guard <close> = prepare()
    write('标准/卡牌/杀.lua', 'rule.card("标准.杀")')

    lt.assertError('带分隔符的名字报错', function ()
        moe.rule.load(list('标准'))
    end)
end)
