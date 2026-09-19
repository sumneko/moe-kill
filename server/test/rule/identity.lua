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

---@param player Core.Player
---@return any
local function identity(player)
    return player:getTag('身份')
end

lt.test('身份场：8 人局的配置', function ()
    local guard <close> = support.load { '身份场' }

    local config = assert(moe.rule:getValue('身份配置')[8], '没有 8 人局配置')
    ---@type table<string, integer>
    local counts = {}
    for _, entry in ipairs(config) do
        counts[entry.identity] = entry.count
    end

    lt.assertEquals('1 主公', 1, counts['主公'])
    lt.assertEquals('2 忠臣', 2, counts['忠臣'])
    lt.assertEquals('4 反贼', 4, counts['反贼'])
    lt.assertEquals('1 内奸', 1, counts['内奸'])
end)

lt.test('身份场：配置可以被后续包覆盖', function ()
    local guard <close> = support.load { '身份场' }

    local probe <close> = useProbe()
    write('我的规则/配置.lua', 'rule:setValue("身份配置", { [4] = { { identity = "全部主公", count = 4 } } })')
    moe.rule.setRoots { './package/*', probeDir:string() .. '/*' }
    moe.rule.load { '身份场', '我的规则' }

    local config = assert(moe.rule:getValue('身份配置')[4], '没有 4 人局配置')
    lt.assertEquals('被覆盖了', '全部主公', config[1].identity)
end)

lt.test('身份场：人数不在配置里时不分配身份', function ()
    local guard <close> = support.load { '基础', '身份场', '标准' }

    local game = support.start(3)

    for i = 1, 3 do
        lt.assertEquals('第 {} 个玩家拿不到身份（回调报错被时机机制记录）' % { i }, nil, identity(game.players[i]))
    end
end)

lt.test('身份场：身份被写进标签', function ()
    local guard <close> = support.load { '基础', '身份场', '标准' }

    local game = support.start(8)

    ---@type table<string, integer>
    local counts = {}
    for i = 1, 8 do
        local value = identity(game.players[i])
        lt.assertEquals('第 {} 个玩家有身份' % { i }, 'string', type(value))
        counts[value] = (counts[value] or 0) + 1
    end

    lt.assertEquals('恰好一位主公', 1, counts['主公'])
    lt.assertEquals('两位忠臣', 2, counts['忠臣'])
    lt.assertEquals('四位反贼', 4, counts['反贼'])
    lt.assertEquals('一位内奸', 1, counts['内奸'])
end)

lt.test('身份场：主公坐 1 号位且体力上限多 1', function ()
    local guard <close> = support.load { '基础', '身份场', '标准' }

    local game = support.start(8)
    local lord = game.players[1]

    lt.assertEquals('1 号位是主公', '主公', identity(lord))
    lt.assertEquals('主公上限是默认值 + 1', 5, lord:getAttributes():get('体力上限'))
    lt.assertEquals('主公体力也补到上限', 5, lord:getAttributes():get('体力'))
    lt.assertEquals('其他人上限不加', 4, game.players[2]:getAttributes():get('体力上限'))
end)

lt.test('身份场：首回合从主公开始', function ()
    local guard <close> = support.load { '基础', '身份场', '标准' }

    local game = support.start(8)

    lt.assertEquals('最后一个座位之后回到主公', game.players[1], game.desk:getNext(game.players[8]))
end)
