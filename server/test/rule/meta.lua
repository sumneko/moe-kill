local fs = require 'bee.filesystem'
local lt = require 'test.ltest'

local probeDir = moe.env.ROOT_PATH / 'tmp' / 'meta-probe'

---@type Moe.Rule
local rule

---@return unknown
local function prepare()
    fs.remove_all(probeDir)
    fs.create_directories(probeDir)
    rule = moe.rule.create { sources = { probeDir:string() .. '/*' } }
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

lt.test('互斥：没被加载时不报错', function ()
    local guard <close> = prepare()
    write('甲/开始.lua', 'rule.depends { "!乙" }\nrule.card("甲牌")')

    local loaded = rule:load(list('甲'))

    lt.assertEquals('加载正常完成', 1, #loaded)
    lt.assertEquals('条目照常登记', true, rule:getCard('甲牌') ~= nil)
end)

lt.test('互斥：被加载时报错并指出两方', function ()
    local guard <close> = prepare()
    write('甲/开始.lua', 'rule.depends { "!乙" }')
    write('乙/牌.lua', 'rule.card("乙牌")')

    local err = lt.assertError('互斥冲突报错', function ()
        rule:load(list('甲', '乙'))
    end) or ''

    lt.assertEquals('错误指出声明者', true, err:find('甲/开始.lua', 1, true) ~= nil)
    lt.assertEquals('错误指出被排斥的项', true, err:find('乙', 1, true) ~= nil)
end)

lt.test('互斥：清单顺序反过来也拦得住', function ()
    local guard <close> = prepare()
    write('甲/开始.lua', 'rule.depends { "!乙" }')
    write('乙/牌.lua', 'rule.card("乙牌")')

    lt.assertError('互斥方在后也报错', function ()
        rule:load(list('乙', '甲'))
    end)
end)

lt.test('互斥：项支持相对路径', function ()
    local guard <close> = prepare()
    write('甲/开始.lua', 'rule.depends { "!../乙" }')
    write('乙/牌.lua', 'rule.card("乙牌")')

    lt.assertError('相对路径互斥也报错', function ()
        rule:load(list('甲', '乙'))
    end)
end)

lt.test('互斥：前缀相同但不同包不误判', function ()
    local guard <close> = prepare()
    write('甲/开始.lua', 'rule.depends { "!乙" }\nrule.card("甲牌")')
    write('乙外传/牌.lua', 'rule.card("外传牌")')

    rule:load(list('甲', '乙外传'))

    lt.assertEquals('两个包都登记成功', true, rule:getCard('甲牌') ~= nil and rule:getCard('外传牌') ~= nil)
end)

lt.test('互斥：冲突时本轮没有任何文件被执行', function ()
    local guard <close> = prepare()
    write('甲/牌.lua', 'rule.card("旧牌")')
    rule:load(list('甲'))
    lt.assertEquals('先有一轮成功的加载', true, rule:getCard('旧牌') ~= nil)

    write('甲/牌.lua', 'rule.depends { "!乙" }\nrule.card("新牌")')
    write('乙/牌.lua', 'rule.card("被排斥的牌")')

    lt.assertError('互斥冲突报错', function ()
        rule:load(list('甲', '乙'))
    end)

    lt.assertEquals('本轮声明方没执行', nil, rule:getCard('新牌'))
    lt.assertEquals('本轮被排斥方也没执行', nil, rule:getCard('被排斥的牌'))
    lt.assertEquals('上一轮的内容没被破坏（校验期失败不执行任何文件）', true, rule:getCard('旧牌') ~= nil)
end)

lt.test('同包重复条目：执行前就报错并指出两处来源', function ()
    local guard <close> = prepare()
    write('甲/一.lua', 'rule.card("重复的牌")')
    write('甲/二.lua', 'rule.card("重复的牌")')

    local err = lt.assertError('重复条目报错', function ()
        rule:load(list('甲'))
    end) or ''

    lt.assertEquals('错误指出第一处来源', true, err:find('甲/一.lua', 1, true) ~= nil)
    lt.assertEquals('错误指出第二处来源', true, err:find('甲/二.lua', 1, true) ~= nil)
    lt.assertEquals('执行前就报错，本轮没有文件被执行', nil, rule:getCard('重复的牌'))
end)

lt.test('元信息：依赖、条目、文件与来源都可查', function ()
    local guard <close> = prepare()
    write('甲/开始.lua', 'rule.depends { "./牌" }\nrule.card("甲牌")')
    write('甲/牌.lua', 'rule.card("乙牌")')

    rule:load(list('甲'))

    local meta = assert(rule:getPackageMeta('甲'), '没有拿到包元信息')
    lt.assertEquals('包名', '甲', meta.name)
    lt.assertEquals('依赖项（相对路径已解析）', '甲/牌', table.concat(meta.depends, ','))
    lt.assertEquals('没有互斥项', 0, #meta.excludes)
    lt.assertEquals('条目清单按声明顺序', '甲牌,乙牌', table.concat(meta.entries, ','))
    lt.assertEquals('两个文件都在', 2, #meta.files)
    lt.assertEquals('第一个文件是声明依赖的那个', '甲/开始.lua', meta.files[1].logical)
    lt.assertEquals('文件带来源物理路径', true, (meta.files[1].source or ''):find('甲', 1, true) ~= nil)
    lt.assertEquals('试跑成功标记', true, meta.files[1].ok)
    lt.assertEquals('查不到的包返回不存在', nil, rule:getPackageMeta('没有这个包'))
    lt.assertEquals('可以一次取全部元信息', true, rule:getMetas()['甲'] ~= nil)
end)

lt.test('元信息：返回的是只读快照', function ()
    local guard <close> = prepare()
    write('甲/牌.lua', 'rule.card("甲牌")')

    rule:load(list('甲'))

    local meta = assert(rule:getPackageMeta('甲'), '没有拿到包元信息')
    meta.entries[1] = '被改掉了'
    meta.files[1].logical = '被改掉了'

    local again = assert(rule:getPackageMeta('甲'), '没有拿到包元信息')
    lt.assertEquals('条目没被外部改动影响', '甲牌', again.entries[1])
    lt.assertEquals('文件也没被外部改动影响', '甲/牌.lua', again.files[1].logical)
end)

lt.test('预解析：试跑失败只记警告，加载照常完成', function ()
    local guard <close> = prepare()
    write('甲/一.lua', 'rule.card("甲牌")')
    write('甲/二.lua', 'assert(rule:getCard("甲牌") ~= nil, "还没到时候")')

    local loaded = rule:load(list('甲'))

    lt.assertEquals('两个文件都执行了', 2, #loaded)
    lt.assertEquals('条目照常登记', true, rule:getCard('甲牌') ~= nil)
    local meta = assert(rule:getPackageMeta('甲'), '没有拿到包元信息')
    lt.assertEquals('第一个文件试跑成功', true, meta.files[1].ok)
    lt.assertEquals('第二个文件试跑失败', false, meta.files[2].ok)
    lt.assertEquals('试跑失败的文件没有条目被记下', 0, #meta.files[2].entries)
end)

lt.test('预解析：跨文件依赖在元信息里完整', function ()
    local guard <close> = prepare()
    write('甲/主.lua', 'rule.depends { "./深层/牌" }')
    write('甲/深层/牌.lua', 'rule.card("深牌")')

    rule:load(list('甲'))

    local meta = assert(rule:getPackageMeta('甲'), '没有拿到包元信息')
    lt.assertEquals('依赖项被解析成逻辑路径', '甲/深层/牌', meta.depends[1])
    lt.assertEquals('依赖指向的文件也在文件清单里', 2, #meta.files)
    lt.assertEquals('依赖文件的条目也被记下', '深牌', meta.entries[1])
end)

lt.test('互斥：指向不存在的包时也不报错', function ()
    local guard <close> = prepare()
    write('甲/牌.lua', 'rule.depends { "!没有这个包" }\nrule.card("甲牌")')

    rule:load(list('甲'))

    lt.assertEquals('加载正常完成', true, rule:getCard('甲牌') ~= nil)
end)

lt.test('预解析：结束后 nil 的元表恢复原状', function ()
    local guard <close> = prepare()
    write('甲/牌.lua', 'rule.card("甲牌")')

    rule:load(list('甲'))

    lt.assertEquals('试跑窗口外 nil 没有元表', nil, debug.getmetatable(nil))
end)
