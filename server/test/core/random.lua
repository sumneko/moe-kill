local lt = require 'test.ltest'

---@param seed integer
---@param count integer
---@return string
local function sequence(seed, count)
    local generator = moe.random.create(seed)
    local values    = {}
    for i = 1, count do
        values[i] = generator:nextInt(1, 1000000)
    end
    return table.concat(values, ',')
end

---@param count integer
---@return string
local function ordered(count)
    local values = {}
    for i = 1, count do
        values[i] = i
    end
    return table.concat(values, ',')
end

---@param seed integer
---@param count integer
---@return string
local function shuffled(seed, count)
    local generator = moe.random.create(seed)
    local values    = {}
    for i = 1, count do
        values[i] = i
    end
    return table.concat(generator:shuffle(values), ',')
end

lt.test('随机源：同种子同序列、异种子异序列', function ()
    lt.assertEquals('同种子同序列', sequence(20260919, 32), sequence(20260919, 32))
    lt.assertNotEquals('异种子异序列', sequence(20260919, 32), sequence(20260920, 32))
    lt.assertNotEquals('起始种子同样不同', sequence(1, 32), sequence(2, 32))
end)

lt.test('随机源：实例之间互不干扰', function ()
    local first  = moe.random.create(7)
    local second = moe.random.create(7)

    for i = 1, 50 do
        first:nextInt(1, 1000)
    end

    local firstValues  = {}
    local secondValues = {}
    for i = 1, 32 do
        firstValues[i]  = first:nextInt(1, 1000000)
        secondValues[i] = second:nextInt(1, 1000000)
    end

    lt.assertNotEquals('被消耗的实例序列已前移', sequence(7, 32), table.concat(firstValues, ','))
    lt.assertEquals('另一实例与单独使用一致', sequence(7, 32), table.concat(secondValues, ','))
end)

lt.test('随机源：取范围整数落在闭区间内', function ()
    local generator = moe.random.create(2026)
    local counts    = {}

    for i = 1, 3000 do
        local value = generator:nextInt(3, 5)
        lt.assertEquals('取值不小于下界', true, value >= 3)
        lt.assertEquals('取值不大于上界', true, value <= 5)
        counts[value] = (counts[value] or 0) + 1
    end

    lt.assertEquals('下界可及', true, (counts[3] or 0) > 0)
    lt.assertEquals('中间值可及', true, (counts[4] or 0) > 0)
    lt.assertEquals('上界可及', true, (counts[5] or 0) > 0)
    lt.assertEquals('单点区间取值', 9, generator:nextInt(9, 9))
end)

lt.test('随机源：取元素来自给定序列', function ()
    local generator = moe.random.create(20260919)
    local list      = { '甲', '乙', '丙', '丁' }
    local seen      = {}

    for i = 1, 200 do
        seen[generator:pick(list)] = true
    end

    lt.assertEquals('甲被取到', true, seen['甲'] == true)
    lt.assertEquals('乙被取到', true, seen['乙'] == true)
    lt.assertEquals('丙被取到', true, seen['丙'] == true)
    lt.assertEquals('丁被取到', true, seen['丁'] == true)
end)

lt.test('随机源：打乱保留元素且改变顺序', function ()
    local generator = moe.random.create(20260919)
    local list      = {}

    for i = 1, 108 do
        list[i] = i
    end

    local result = generator:shuffle(list)
    local total  = 0
    local marks  = {}
    local kinds  = 0
    for i = 1, #list do
        total = total + list[i]
        if not marks[list[i]] then
            marks[list[i]] = true
            kinds = kinds + 1
        end
    end

    lt.assertEquals('原地打乱并返回原表', list, result)
    lt.assertEquals('元素数量不变', 108, #list)
    lt.assertEquals('元素总和不变', 108 * 109 / 2, total)
    lt.assertEquals('元素互异', 108, kinds)
    lt.assertNotEquals('顺序已改变', ordered(108), table.concat(list, ','))
end)

lt.test('随机源：同种子打乱同序、异种子异序', function ()
    lt.assertEquals('同种子同序', shuffled(42, 108), shuffled(42, 108))
    lt.assertNotEquals('异种子异序', shuffled(42, 108), shuffled(43, 108))
end)

lt.test('随机源：不触碰全局随机状态', function ()
    math.randomseed(20260919)
    local before = math.random(1, 1000000)

    math.randomseed(20260919)
    local generator = moe.random.create(20260919)
    generator:nextInt(1, 100)
    generator:shuffle({ 1, 2, 3, 4, 5 })
    local after = math.random(1, 1000000)

    lt.assertEquals('全局序列未被消耗', before, after)
end)

lt.test('随机源：非法请求明确失败', function ()
    local generator = moe.random.create(1)

    lt.assertError('下界大于上界', function ()
        generator:nextInt(5, 4)
    end)
    lt.assertError('范围端点非整数', function ()
        generator:nextInt(1.5, 4)
    end)
    lt.assertError('从空序列取元素', function ()
        generator:pick({})
    end)
    lt.assertError('种子非整数', function ()
        moe.random.create(1.5)
    end)
end)
