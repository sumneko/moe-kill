local fs = require 'bee.filesystem'
local lt = require 'test.ltest'

local probeDir = moe.env.ROOT_PATH / 'tmp' / 'buff-probe'

---@param rel string
---@param content string
local function write(rel, content)
    local file = probeDir / rel
    fs.create_directories(file:parent_path())
    local ok, err = moe.util.saveFile(file:string(), content)
    assert(ok, err)
end

---@return fun() # 配 <close> 用
local function useProbe()
    fs.remove_all(probeDir)
    fs.create_directories(probeDir)
    return function ()
        fs.remove_all(probeDir)
    end
end

---@param source string # 探针包里的定义
---@return Game
---@return Player # 1 号位
local function newGame(source)
    write('探针/定义.lua', source)
    local game = moe.game.create {
        seats    = 1,
        random   = moe.random.create(1),
        sources  = { probeDir:string() .. '/*' },
        packages = { '探针' },
    }
    local attributeSystem = game:getAttributeSystem()
    attributeSystem:define('体力', {
        min    = -999999,
        max    = 999999,
        simple = true,
    })
    local player = moe.player.create(game, { attributes = attributeSystem:createInstance() })
    game.desk:sit(1, player)
    player:setAttr('体力', 4)
    return game, player
end

--- 一只会记账的状态：获得时挂一条「禁用自己手牌区」的资源（失去时该由 bindGC 自动撤销）
local RECORD = [[
Buff '记录'
    : on('获得', function (buff)
        game:setValue('获得次数', (game:getValue('获得次数') or 0) + 1)
        game:setValue('获得时载荷', buff.payload)
        buff:bindGC(buff.owner:getZone('手牌'):disable())
    end)
    : on('失去', function (buff)
        game:setValue('失去次数', (game:getValue('失去次数') or 0) + 1)
        game:setValue('失去时的名字', buff.name)
        game:setValue('失去时区还被禁用', buff.owner:getZone('手牌'):isEnabled() == false)
    end)
]]

lt.test('状态：挂上之后就查得到', function ()
    local guard <close> = useProbe()
    local game, player = newGame(RECORD)

    local buff = player:addBuff('记录')

    lt.assertEquals('名字来自定义', '记录', buff.name)
    lt.assertEquals('记着挂在谁身上', player, buff.owner)
    lt.assertEquals('查得到', true, player:hasBuff('记录'))
    lt.assertEquals('快照里有它', buff, player:getBuffs()[1])
    lt.assertEquals('获得时机发了一次', 1, game:getValue('获得次数'))
end)

lt.test('状态：同名可以并存', function ()
    local guard <close> = useProbe()
    local game, player = newGame(RECORD)

    local one = player:addBuff('记录')
    local two = player:addBuff('记录')

    lt.assertEquals('两只不是同一个实例', false, one == two)
    lt.assertEquals('两只都在', 2, #player:getBuffs())
    lt.assertEquals('获得时机各发一次', 2, game:getValue('获得次数'))
end)

lt.test('状态：remove 幂等', function ()
    local guard <close> = useProbe()
    local game, player = newGame(RECORD)
    local buff = player:addBuff('记录')

    buff:remove()
    lt.assertEquals('摘掉了', 0, #player:getBuffs())
    lt.assertEquals('查不到了', false, player:hasBuff('记录'))
    lt.assertEquals('失去时机发了一次', 1, game:getValue('失去次数'))

    buff:remove()
    lt.assertEquals('再摘一次不再发时机', 1, game:getValue('失去次数'))
end)

lt.test('状态：bindGC 挂的资源随失去撤销', function ()
    local guard <close> = useProbe()
    local game, player = newGame(RECORD)
    local hand = player:getZone('手牌')

    local buff = player:addBuff('记录')
    lt.assertEquals('获得时挂的资源生效了', false, hand:isEnabled())

    buff:remove()
    lt.assertEquals('失去时自动撤销', true, hand:isEnabled())
end)

lt.test('状态：失去时资源还没撤、字段还读得到', function ()
    local guard <close> = useProbe()
    local game, player = newGame(RECORD)
    local buff = player:addBuff('记录')
    buff:remove()

    lt.assertEquals('发失去时实例上还读得到名字', '记录', game:getValue('失去时的名字'))
    lt.assertEquals('发失去时资源还没撤', true, game:getValue('失去时区还被禁用'))
end)

lt.test('状态：getBuffs 是快照', function ()
    local guard <close> = useProbe()
    local game, player = newGame(RECORD)

    local buff = player:addBuff('记录')
    local snapshot = player:getBuffs()
    player:addBuff('记录')

    lt.assertEquals('快照没跟着涨', 1, #snapshot)
    lt.assertEquals('快照里还是原来那只', buff, snapshot[1])
    lt.assertEquals('现场已经有两只', 2, #player:getBuffs())
end)

lt.test('状态：挂上时给的载荷，在获得时机就读得到', function ()
    local guard <close> = useProbe()
    local game, player = newGame(RECORD)

    local mark = {}
    local buff = player:addBuff('记录', mark)

    lt.assertEquals('实例上存着', mark, buff.payload)
    lt.assertEquals('获得时机读得到', mark, game:getValue('获得时载荷'))
end)

lt.test('状态：没给载荷时是空的', function ()
    local guard <close> = useProbe()
    local game, player = newGame(RECORD)

    local buff = player:addBuff('记录')

    lt.assertEquals('没给就是空', nil, buff.payload)
end)

lt.test('状态：没有对应定义就报错', function ()
    local guard <close> = useProbe()
    local game, player = newGame(RECORD)

    lt.assertError('查不到定义', function ()
        player:addBuff('查无此状态')
    end)
end)
