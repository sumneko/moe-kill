local fs      = require 'bee.filesystem'
local lt      = require 'test.ltest'
local support = require 'test.rule.support'

local probeDir = moe.env.ROOT_PATH / 'tmp' / 'identity-probe'

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

---@param 玩家 Core.Player
---@return any
local function 身份(玩家)
    return 玩家:getTag('身份')
end

lt.test('身份场：8 人局的配置', function ()
    local guard <close> = support.load { '身份场' }

    local 配置 = assert(moe.rule:getValue('身份配置')[8], '没有 8 人局配置')
    ---@type table<string, integer>
    local 计数 = {}
    for _, 项 in ipairs(配置) do
        计数[项.身份] = 项.人数
    end

    lt.assertEquals('1 主公', 1, 计数['主公'])
    lt.assertEquals('2 忠臣', 2, 计数['忠臣'])
    lt.assertEquals('4 反贼', 4, 计数['反贼'])
    lt.assertEquals('1 内奸', 1, 计数['内奸'])
end)

lt.test('身份场：配置可以被后续包覆盖', function ()
    local guard <close> = support.load { '身份场' }

    local probe <close> = useProbe()
    write('我的规则/配置.lua', 'rule:setValue("身份配置", { [4] = { { 身份 = "全部主公", 人数 = 4 } } })')
    moe.rule.setRoots { './package/*', probeDir:string() .. '/*' }
    moe.rule.load { '身份场', '我的规则' }

    local 配置 = assert(moe.rule:getValue('身份配置')[4], '没有 4 人局配置')
    lt.assertEquals('被覆盖了', '全部主公', 配置[1].身份)
end)

lt.test('身份场：人数不在配置里时不分配身份', function ()
    local guard <close> = support.load { '基础', '身份场', '标准' }

    local 局 = support.start(3)

    for i = 1, 3 do
        lt.assertEquals('第 {} 个玩家拿不到身份（回调报错被时机机制记录）' % { i }, nil, 身份(局.玩家[i]))
    end
end)

lt.test('身份场：身份被写进标签', function ()
    local guard <close> = support.load { '基础', '身份场', '标准' }

    local 局 = support.start(8)

    ---@type table<string, integer>
    local 计数 = {}
    for i = 1, 8 do
        local 值 = 身份(局.玩家[i])
        lt.assertEquals('第 {} 个玩家有身份' % { i }, 'string', type(值))
        计数[值] = (计数[值] or 0) + 1
    end

    lt.assertEquals('恰好一位主公', 1, 计数['主公'])
    lt.assertEquals('两位忠臣', 2, 计数['忠臣'])
    lt.assertEquals('四位反贼', 4, 计数['反贼'])
    lt.assertEquals('一位内奸', 1, 计数['内奸'])
end)

lt.test('身份场：主公坐 1 号位且体力上限多 1', function ()
    local guard <close> = support.load { '基础', '身份场', '标准' }

    local 局   = support.start(8)
    local 主公 = 局.玩家[1]

    lt.assertEquals('1 号位是主公', '主公', 身份(主公))
    lt.assertEquals('主公上限是默认值 + 1', 5, 主公:getAttributes():get('体力上限'))
    lt.assertEquals('主公体力也补到上限', 5, 主公:getAttributes():get('体力'))
    lt.assertEquals('其他人上限不加', 4, 局.玩家[2]:getAttributes():get('体力上限'))
end)

lt.test('身份场：首回合从主公开始', function ()
    local guard <close> = support.load { '基础', '身份场', '标准' }

    local 局 = support.start(8)

    lt.assertEquals('最后一个座位之后回到主公', 局.玩家[1], 局.desk:getNext(局.玩家[8]))
end)
