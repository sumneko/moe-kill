local fs = require 'bee.filesystem'
local lt = require 'test.ltest'

local vfs    = require 'core.rule.vfs'
local rootDir = moe.env.ROOT_PATH / 'tmp' / 'vfs-probe'
local base    = moe.env.ROOT_PATH:parent_path()

---@return unknown
local function prepare()
    fs.remove_all(rootDir)
    fs.create_directories(rootDir)
    return moe.util.defer(function ()
        fs.remove_all(rootDir)
    end)
end

---@param rel string
---@param content string
local function write(rel, content)
    local file = rootDir / rel
    fs.create_directories(file:parent_path())
    local ok, err = moe.util.saveFile(file:string(), content)
    assert(ok, err)
end

---@param rel string
---@return string
local function path(rel)
    return (rootDir / rel):string()
end

lt.test('虚拟文件系统：目录本身作为来源', function ()
    local guard <close> = prepare()
    write('单包/卡牌/杀.lua', 'x')
    write('单包/卡牌/b.lua', 'x')
    write('单包/卡牌/a.lua', 'x')
    write('单包/卡牌/说明.txt', 'x')

    local instance = vfs.create({ path('单包') }, base)

    lt.assertEquals('逻辑路径以目录名开头', true, instance:isFile('单包/卡牌/杀.lua'))
    lt.assertEquals('非 lua 文件也在索引里', true, instance:isFile('单包/卡牌/说明.txt'))
    lt.assertEquals('目录被登记', true, instance:isDirectory('单包/卡牌'))
    lt.assertEquals('列出的只有 lua 文件且按路径排序', '单包/卡牌/a.lua\n单包/卡牌/b.lua\n单包/卡牌/杀.lua',
        table.concat(instance:listFiles('单包'), '\n'))
end)

lt.test('虚拟文件系统：容器展开为多个来源', function ()
    local guard <close> = prepare()
    write('某合集/标准/卡牌/杀.lua', 'x')
    write('某合集/一将成名/武将/张飞.lua', 'x')
    write('某合集/.隐藏/卡牌/无.lua', 'x')

    local instance = vfs.create({ path('某合集') .. '/*' }, base)

    lt.assertEquals('第一个子目录成为一个来源', true, instance:isFile('标准/卡牌/杀.lua'))
    lt.assertEquals('第二个子目录也成为一个来源', true, instance:isFile('一将成名/武将/张飞.lua'))
    lt.assertEquals('容器名不进逻辑路径', false, instance:isFile('某合集/标准/卡牌/杀.lua'))
    lt.assertEquals('跳过点开头的目录', false, instance:isFile('.隐藏/卡牌/无.lua'))
end)

lt.test('虚拟文件系统：非法写法报错', function ()
    local guard <close> = prepare()
    write('合集/包/卡牌/杀.lua', 'x')

    for _, pattern in ipairs { path('合集') .. '/*.lua', path('合集') .. '/*/卡牌', '*' } do
        lt.assertError('非法来源报错：' .. pattern, function ()
            vfs.create({ pattern }, base)
        end)
    end
end)

lt.test('虚拟文件系统：来源不存在报错、匹配 0 个允许', function ()
    local guard <close> = prepare()
    fs.create_directories(rootDir / '空')

    lt.assertError('目录本身不存在时报错', function ()
        vfs.create({ path('根本没有这个目录') }, base)
    end)
    lt.assertError('容器不存在时报错', function ()
        vfs.create({ path('根本没有这个目录') .. '/*' }, base)
    end)

    local instance = vfs.create({ path('空') .. '/*' }, base)
    lt.assertEquals('匹配 0 个包不报错', false, instance:exists('空'))
end)

lt.test('虚拟文件系统：后一个来源覆盖同路径文件', function ()
    local guard <close> = prepare()
    write('前/标准/卡牌/杀.lua', '前')
    write('后/标准/卡牌/杀.lua', '后')

    local instance = vfs.create({ path('前') .. '/*', path('后') .. '/*' }, base)

    lt.assertEquals('生效的是后一个来源', (rootDir / '后' / '标准' / '卡牌' / '杀.lua'):string(), instance:resolve('标准/卡牌/杀.lua'))
    lt.assertEquals('只列出一个文件', 1, #instance:listFiles('标准/卡牌'))
end)

lt.test('虚拟文件系统：不同路径取并集、目录内容合并', function ()
    local guard <close> = prepare()
    write('前/标准/卡牌/杀.lua', 'x')
    write('后/标准/卡牌/闪.lua', 'x')
    write('后/标准/卡牌/子/桃.lua', 'x')

    local instance = vfs.create({ path('前') .. '/*', path('后') .. '/*' }, base)

    lt.assertEquals('合并后有三个文件', 3, #instance:listFiles('标准/卡牌'))
    lt.assertEquals('递归列出子目录', '标准/卡牌/子/桃.lua', instance:listFiles('标准/卡牌')[1])
    lt.assertEquals('前一个来源的文件依然在', true, instance:isFile('标准/卡牌/杀.lua'))
    lt.assertEquals('后一个来源的文件也在', true, instance:isFile('标准/卡牌/闪.lua'))
end)

lt.test('虚拟文件系统：不缓存，重新创建即看到变化', function ()
    local guard <close> = prepare()
    write('包/a.lua', 'x')

    local first = vfs.create({ path('包') }, base)
    lt.assertEquals('首次没有新文件', false, first:isFile('包/b.lua'))

    write('包/b.lua', 'x')

    lt.assertEquals('旧实例不自动更新', false, first:isFile('包/b.lua'))
    local second = vfs.create({ path('包') }, base)
    lt.assertEquals('重新合并后看到新文件', true, second:isFile('包/b.lua'))
end)

lt.test('虚拟文件系统：逻辑路径归一化', function ()
    lt.assertEquals('去掉 . 与 ..', '标准/卡牌/杀', vfs.normalize('./标准/./卡牌/../卡牌/杀'))
    lt.assertEquals('分隔符统一', '标准/卡牌', vfs.normalize('标准\\卡牌'))
    lt.assertError('越出规则集根时报错', function ()
        vfs.normalize('../标准')
    end)
end)

lt.test('虚拟文件系统：默认来源', function ()
    lt.assertEquals('默认来源是项目自己的包容器', './package/*', moe.rule.DEFAULT_SOURCES[1])
    lt.assertEquals('默认只有一个来源', 1, #moe.rule.DEFAULT_SOURCES)
end)

lt.test('虚拟文件系统：@ 前缀的目录是默认加载的包', function ()
    local guard <close> = prepare()
    write('@基础/卡牌/杀.lua', 'x')
    write('标准/卡牌/杀.lua', 'x')

    local instance = vfs.create({ path('') .. '*' }, base)

    lt.assertEquals('逻辑名去掉了 @', true, instance:isFile('基础/卡牌/杀.lua'))
    lt.assertEquals('@ 不进逻辑路径', false, instance:isFile('@基础/卡牌/杀.lua'))
    lt.assertEquals('普通包不受影响', true, instance:isFile('标准/卡牌/杀.lua'))
    lt.assertEquals('默认加载的包名单', '基础', table.concat(instance:getDefaultPackages(), ','))
end)

lt.test('虚拟文件系统：容器里的 @ 目录也认', function ()
    local guard <close> = prepare()
    write('合集/@基础/卡牌/杀.lua', 'x')
    write('合集/标准/卡牌/杀.lua', 'x')

    local instance = vfs.create({ path('合集') .. '/*' }, base)

    lt.assertEquals('容器子目录的 @ 同样剔离', '基础', table.concat(instance:getDefaultPackages(), ','))
end)

lt.test('虚拟文件系统：多来源时任一来源带标记即默认加载，且名单排序确定', function ()
    local guard <close> = prepare()
    write('前/基础/卡牌/杀.lua', 'x')
    write('后/@基础/卡牌/闪.lua', 'x')
    write('后/@其它/卡牌/桃.lua', 'x')

    local instance = vfs.create({ path('前') .. '/*', path('后') .. '/*' }, base)

    lt.assertEquals('标记只增不减，且按名字升序', '其它,基础', table.concat(instance:getDefaultPackages(), ','))
    lt.assertEquals('两边的文件合并到同一逻辑包', true, instance:isFile('基础/卡牌/闪.lua'))
end)

lt.test('虚拟文件系统：目录名只有一个 @ 时报错', function ()
    local guard <close> = prepare()
    write('合集2/@/卡牌/杀.lua', 'x')
    fs.create_directories(rootDir / '@')

    lt.assertError('容器里带 @ 的子目录报错', function ()
        vfs.create({ path('合集2') .. '/*' }, base)
    end)
    lt.assertError('目录本身作为来源时同样报错', function ()
        vfs.create({ path('@') }, base)
    end)
end)
