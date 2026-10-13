local lt = require 'test.ltest'

--- 表里有几项
---@param value table
---@return integer
local function countOf(value)
    local count = 0
    for _ in pairs(value) do
        count = count + 1
    end
    return count
end

lt.test('协议声明：解析类、基类、字段与说明', function ()
    local classes = moe.proto.parse(table.concat({
        '--- 先说一句',
        '---@class A',
        '---@field x integer # 横坐标',
        '---@field y? string',
        '',
        '---@class B: A, C',
        '---@field z boolean[]',
    }, '\n'))

    lt.assertEquals('类数', 2, countOf(classes))
    lt.assertEquals('类说明', '先说一句', classes.A.comment)
    lt.assertEquals('字段数', 2, #classes.A.fields)
    lt.assertEquals('字段名', 'x', classes.A.fields[1].name)
    lt.assertEquals('字段类型原文', 'integer', classes.A.fields[1].type)
    lt.assertEquals('字段说明', '横坐标', classes.A.fields[1].comment)
    lt.assertEquals('必填的字段', false, classes.A.fields[1].optional)
    lt.assertEquals('可选的字段', true, classes.A.fields[2].optional)
    lt.assertEquals('字段名不带问号', 'y', classes.A.fields[2].name)
    lt.assertEquals('基类', 'A', classes.B.bases[1])
    lt.assertEquals('第二个基类', 'C', classes.B.bases[2])
    lt.assertEquals('类型写法原样留着', 'boolean[]', classes.B.fields[1].type)
end)

lt.test('协议声明：继承与类引用都展开', function ()
    local shape = moe.proto.shape 'Proto.Request.Ask.Select'
    lt.assertNotEquals('有这么个类', nil, shape)
    ---@cast shape Shape

    local problem = moe.shape.problem
    lt.assertEquals('照声明对上', nil, problem({ reason = '出牌' }, shape))
    lt.assertEquals('自己声明的字段不能少', '「reason」不能没有', problem({}, shape))
    lt.assertEquals('继承来的字段也认', nil, problem({ reason = '出牌', cancelToken = 7, timeLimit = 10 }, shape))
    lt.assertEquals('继承来的字段也查', '「timeLimit」应该是 number（现在是 string）', problem({ reason = '出牌', timeLimit = '十秒' }, shape))
    lt.assertEquals('引用的类就地展开', nil, problem({ reason = '出牌', player = { ids = { 1 }, min = 1, max = 1 } }, shape))
    lt.assertEquals('引用展开后照样查', '「card.max」不能没有', problem({ reason = '出牌', card = { ids = {}, min = 1 } }, shape))
end)

lt.test('协议声明：叶子、数组、可选', function ()
    local shape = moe.proto.shape 'Proto.Result.Ask.Use'
    ---@cast shape Shape

    local problem = moe.shape.problem
    lt.assertEquals('全可选，空的也认', nil, problem({}, shape))
    lt.assertEquals('对上', nil, problem({ usedCard = 1, targets = { 1, 2 } }, shape))
    lt.assertEquals('类型照声明查', '「usedCard」应该是 integer（现在是 string）', problem({ usedCard = '甲' }, shape))
    lt.assertEquals('数组元素照声明查', '「targets[1]」应该是 integer（现在是 string）', problem({ targets = { '甲' } }, shape))
end)

lt.test('协议声明：内联结构数组', function ()
    local shape = moe.proto.shape 'Proto.Notify.Card.Create'
    ---@cast shape Shape

    local problem = moe.shape.problem
    lt.assertEquals('两半都可选', nil, problem({}, shape))
    lt.assertEquals('正面朝上的部分', nil, problem({ show = { { zone = '牌堆', cards = {} } } }, shape))
    lt.assertEquals('背面朝上的部分是号', nil, problem({ hide = { { zone = '牌堆', cards = { 1, 2 } } } }, shape))
    lt.assertEquals('正面朝上的部分要整张牌', '「show[1].cards[1]」应该是表（现在是 integer）', problem({ show = { { zone = '牌堆', cards = { 1 } } } }, shape))
end)

lt.test('协议声明：字面量联合降级成字符串', function ()
    local shape = moe.proto.shape 'Proto.CardFace'
    ---@cast shape Shape

    local problem = moe.shape.problem
    lt.assertEquals('花色当字符串收', nil, problem({ suit = '黑桃' }, shape))
    lt.assertEquals('别的字符串也收', nil, problem({ suit = '什么' }, shape))
    lt.assertEquals('不是字符串就报', '「suit」应该是 string（现在是 integer）', problem({ suit = 1 }, shape))
end)

lt.test('协议声明：每个类都翻得出形状', function ()
    ---@type string[]
    local failed = {}
    for name in pairs(moe.proto.classes()) do
        local ok, err = pcall(moe.proto.shape, name)
        if not ok then
            failed[#failed + 1] = name .. '（' .. tostring(err) .. '）'
        end
    end
    table.sort(failed)
    lt.assertEquals('翻不出来的类', '', table.concat(failed, '、'))
end)

lt.test('协议声明：上线要校验的形状都有声明', function ()
    for _, method in ipairs { 'Game.Join', 'Game.SnapShot', 'Skill.ChangeAuto', 'Panel.Move' } do
        lt.assertNotEquals('上行参数「' .. method .. '」有声明', nil, moe.proto.shape('Proto.Request.' .. method))
    end
    for _, method in ipairs { 'Ask.Select', 'Ask.Choice', 'Ask.Use', 'Ask.UseSkill', 'Ask.Hero', 'Ask.Panel' } do
        lt.assertNotEquals('回包「' .. method .. '」有声明', nil, moe.proto.shape('Proto.Result.' .. method))
    end
end)

lt.test('协议声明：写错了当场炸', function ()
    lt.assertError('字段前面没有类', function ()
        moe.proto.parse '---@field x integer'
    end)
    lt.assertError('字段写法认不出', function ()
        moe.proto.parse(table.concat({ '---@class A', '---@field x' }, '\n'))
    end)
    lt.assertEquals('没有的类给空', nil, moe.proto.shape 'Proto.不存在的类')
end)
