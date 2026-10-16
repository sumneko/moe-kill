local lt = require 'test.ltest'

--- 内容侧那份工具文件（直接加载 —— 它是纯 Lua，只用标准库）
local function loadUtil()
    local path = (moe.env.ROOT_PATH:parent_path() / 'package' / '@tools' / 'util.lua'):string()
    local chunk = assert(loadfile(path))
    chunk()
    ---@diagnostic disable-next-line: unknown-cast-variable
    ---@cast util table
    return util
end

lt.test('内容侧 util.locale：没有参数就是裸文本', function ()
    local util = loadUtil()
    lt.assertEquals('原样给回', '请使用一张牌', util.locale('请使用一张牌'))
    lt.assertEquals('空参数表也算没有', '请使用一张牌', util.locale('请使用一张牌', {}))
end)

lt.test('内容侧 util.locale：给参数就拼成「模板@参数表」', function ()
    local util = loadUtil()
    lt.assertEquals('数字保持数字', '${locale:弃置 {num} 张牌}@{"num":2}',
        util.locale('弃置 {num} 张牌', { num = 2 }))
    -- 键的顺序由 `pairs` 定，不保证 —— 只断言两个键都在
    local both = util.locale('{a} 与 {b}', { a = '甲', b = '乙' })
    lt.assertEquals('带上两个键', true,
        both:sub(1, #'${locale:{a} 与 {b}}@') == '${locale:{a} 与 {b}}@'
        and both:find('"a":"甲"', 1, true) ~= nil
        and both:find('"b":"乙"', 1, true) ~= nil)
end)

lt.test('内容侧 util.locale：表与转义', function ()
    local util = loadUtil()
    lt.assertEquals('数组', '${locale:{list}}@{"list":["甲","乙"]}',
        util.locale('{list}', { list = { '甲', '乙' } }))
    lt.assertEquals('嵌套表 + 引号转义', '${locale:{who}}@{"who":{"name":"x\\"y"}}',
        util.locale('{who}', { who = { name = 'x"y' } }))
    lt.assertEquals('换行也转义', '${locale:{t}}@{"t":"a\\nb"}',
        util.locale('{t}', { t = 'a\nb' }))
end)
