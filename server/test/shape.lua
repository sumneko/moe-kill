local lt = require 'test.ltest'

lt.test('形状：叶子类型、可选、数组', function ()
    local problem = moe.shape.problem

    lt.assertEquals('整数对上', nil, problem(3, 'integer'))
    lt.assertEquals('小数不是整数', '值应该是 integer（现在是 float）', problem(3.5, 'integer'))
    lt.assertEquals('数字收小数', nil, problem(3.5, 'number'))
    lt.assertEquals('字符串认字符串', nil, problem('甲', 'string'))
    lt.assertEquals('类型不对给原因', '值应该是 integer（现在是 string）', problem('甲', 'integer'))
    lt.assertEquals('可选可以没有', nil, problem(nil, 'integer?'))
    lt.assertEquals('必填不能没有', '值不能没有', problem(nil, 'integer'))
    lt.assertEquals('数组对上', nil, problem({ 1, 2 }, 'integer[]'))
    lt.assertEquals('空表也算数组', nil, problem({}, 'integer[]'))
    lt.assertEquals('数组元素错报位置', '「[2]」应该是 integer（现在是 string）', problem({ 1, '甲' }, 'integer[]'))
    lt.assertEquals('给了单个值不算数组', '值应该是数组（现在是 integer）', problem(1, 'integer[]'))
    lt.assertEquals('可选数组可以没有', nil, problem(nil, 'integer[]?'))
end)

lt.test('形状：结构、嵌套、多余字段', function ()
    local problem = moe.shape.problem
    local plan    = { ids = 'integer[]', min = 'integer', max = 'integer' }
    local request = {
        reason = 'string',
        card   = plan,
        viewAs = moe.shape.array { name = 'string' },
    }

    lt.assertEquals('嵌套对上', nil, problem({
        reason = '出牌',
        card   = { ids = {}, min = 1, max = 1 },
        viewAs = { { name = '杀' } },
    }, request))
    lt.assertEquals('嵌套里缺字段', '「card.max」不能没有', problem({
        reason = '出牌',
        card   = { ids = {}, min = 1 },
        viewAs = {},
    }, request))
    lt.assertEquals('嵌套里类型不对', '「card.ids[1]」应该是 integer（现在是 string）', problem({
        reason = '出牌',
        card   = { ids = { '甲' }, min = 1, max = 1 },
        viewAs = {},
    }, request))
    lt.assertEquals('数组里元素的字段不对', '「viewAs[1].name」应该是 string（现在是 integer）', problem({
        reason = '出牌',
        card   = { ids = {}, min = 1, max = 1 },
        viewAs = { { name = 1 } },
    }, request))
    lt.assertEquals('多了字段也算不合', '「x」多了个字段', problem({
        reason = '出牌',
        card   = { ids = {}, min = 1, max = 1 },
        viewAs = {},
        x      = 1,
    }, request))
    lt.assertEquals('该是表却给了别的', '值应该是表（现在是 integer）', problem(5, request))
    lt.assertEquals('可选结构可以没有', nil, problem({ reason = '出牌' }, {
        reason = 'string',
        card   = moe.shape.optional(plan),
    }))
end)

lt.test('形状：递归结构', function ()
    local problem = moe.shape.problem
    local tree    = { value = 'integer' }
    tree.children = moe.shape.array(tree)

    lt.assertEquals('递归对上', nil, problem({
        value    = 1,
        children = { { value = 2, children = {} } },
    }, tree))
    lt.assertEquals('递归深处也报', '「children[1].children[1].value」应该是 integer（现在是 string）', problem({
        value    = 1,
        children = { { value = 2, children = { { value = '甲', children = {} } } } },
    }, tree))
end)

lt.test('形状：写错 schema 当场炸（那是编程错误）', function ()
    local problem = moe.shape.problem
    lt.assertError('认不出的类型词', function ()
        problem(1, 'integral')
    end)
    lt.assertError('形状不是表也不是字符串', function ()
        ---@type any
        local shape = 5
        problem(1, shape)
    end)
end)
