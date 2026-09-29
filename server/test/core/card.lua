local fs = require 'bee.filesystem'
local lt = require 'test.ltest'

local probeDir = moe.env.ROOT_PATH / 'tmp' / 'card-passive-probe'

local probeSource = [[
Card '被动牌'
    : on('被动', function (card, zone)
        game:setValue('应用', (game:getValue('应用') or 0) + 1)
        return function ()
            game:setValue('撤销', (game:getValue('撤销') or 0) + 1)
        end
    end)
Card '记位置'
    : on('被动', function (card, zone)
        game:setValue('记下的牌', card)
        game:setValue('记下的区', zone)
    end)
Card '无撤销'
    : on('被动', function (card, zone)
        game:setValue('无撤销应用', (game:getValue('无撤销应用') or 0) + 1)
    end)
]]

---@return unknown # 配 <close> 用
local function useProbe()
    fs.remove_all(probeDir)
    fs.create_directories(probeDir)
    return moe.util.defer(function ()
        fs.remove_all(probeDir)
    end)
end

---@return Game
local function newGame()
    local file = probeDir / '探针' / '牌.lua'
    fs.create_directories(file:parent_path())
    local ok, err = moe.util.saveFile(file:string(), probeSource)
    assert(ok, err)
    return moe.game.create {
        seats    = 2,
        random   = moe.random.create(1),
        sources  = { probeDir:string() .. '/*' },
        packages = { '探针' },
    }
end

lt.test('牌：标识与牌名都由调用方给出', function ()
    local card = moe.card.create(lt.game(), '杀', 7)

    lt.assertEquals('标识就是给进来的号', 7, card:getId())
    lt.assertEquals('牌名就是给进来的那个值', '杀', card.name)

    local other = moe.card.create(lt.game(), '闪', 8)
    lt.assertEquals('两张牌各自用各自的号', false, card:getId() == other:getId())
end)

lt.test('牌：没给牌名建不出来', function ()
    lt.assertError('空牌名直接报错', function ()
        moe.card.create(lt.game(), '', 9)
    end)
end)

lt.test('牌：内核不解释牌名与牌面，只搬运内容给的取值', function ()
    local card = lt.card('杀')
    local keys = {}

    for key in pairs(card) do
        if type(key) == 'string' and key:sub(1, 2) ~= '__' then
            keys[#keys + 1] = key
        end
    end
    table.sort(keys)
    lt.assertEquals('没给牌面时的字段就是这几样', 'def,game,id,name,passiveSuppress', table.concat(keys, ','))

    ---@type any
    local raw = card
    lt.assertEquals('没有名称字段', nil, raw['名称'])
    lt.assertEquals('没有效果字段', nil, raw['效果'])
end)

lt.test('牌：花色与点数直接读字段', function ()
    local card = moe.card.create(lt.game(), '杀', 7, '黑桃', 9)

    lt.assertEquals('花色就是给进来的那个', '黑桃', card.suit)
    lt.assertEquals('点数就是给进来的那个', 9, card.point)

    local plain = moe.card.create(lt.game(), '闪', 8)
    lt.assertEquals('没给花色就是空', nil, plain.suit)
    lt.assertEquals('没给点数就是空', nil, plain.point)
end)

lt.test('牌：被动出厂不生效，启用时才应用、停用时撤销', function ()
    local guard <close> = useProbe()
    local game = newGame()
    local card = game:createCard('被动牌')
    game:getZone('弃牌'):accept(card)

    lt.assertEquals('没启用过：回调没跑', nil, game:getValue('应用'))

    card:enablePassive()
    lt.assertEquals('启用返回时就已经应用（同步）', 1, game:getValue('应用'))

    card:disablePassive()
    lt.assertEquals('停用后撤销被调了一次', 1, game:getValue('撤销'))

    card:enablePassive()
    lt.assertEquals('再启用会重新应用', 2, game:getValue('应用'))
end)

lt.test('牌：被动压制可叠加，逐层松开才恢复', function ()
    local guard <close> = useProbe()
    local game = newGame()
    local card = game:createCard('被动牌')
    game:getZone('弃牌'):accept(card)

    card:enablePassive()
    card:disablePassive()
    card:disablePassive()
    lt.assertEquals('压了两层：效果已撤', 1, game:getValue('撤销'))

    card:enablePassive()
    lt.assertEquals('松开一层还没到 0：不恢复', 1, game:getValue('应用'))

    card:enablePassive()
    lt.assertEquals('松到 0：重新应用', 2, game:getValue('应用'))
end)

lt.test('牌：重复压制不会重复撤销', function ()
    local guard <close> = useProbe()
    local game = newGame()
    local card = game:createCard('被动牌')
    game:getZone('弃牌'):accept(card)

    card:enablePassive()
    card:disablePassive()
    card:disablePassive()
    card:enablePassive()
    lt.assertEquals('撤销只发生过一次', 1, game:getValue('撤销'))
end)

lt.test('牌：启用与停用各返回一只精确的撤销函数', function ()
    local guard <close> = useProbe()
    local game = newGame()
    local card = game:createCard('被动牌')
    game:getZone('弃牌'):accept(card)

    local undoEnable = card:enablePassive()
    undoEnable()
    lt.assertEquals('撤销这次松开 ⇒ 效果被撤', 1, game:getValue('撤销'))

    local undoDisable = card:disablePassive()
    undoDisable()
    lt.assertEquals('撤销这次压制时没有东西可应用', 1, game:getValue('应用'))

    card:enablePassive()
    lt.assertEquals('再松开才应用', 2, game:getValue('应用'))
end)

lt.test('牌：被动回调拿到牌与它所在的区', function ()
    local guard <close> = useProbe()
    local game = newGame()
    local card = game:createCard('记位置')
    local zone = game:getZone('弃牌')
    zone:accept(card)

    card:enablePassive()
    lt.assertEquals('回调收到的就是这张牌', card, game:getValue('记下的牌'))
    lt.assertEquals('回调收到的是它所在的区', zone, game:getValue('记下的区'))
end)

lt.test('牌：被动回调不返回撤销函数也能启用停用', function ()
    local guard <close> = useProbe()
    local game = newGame()
    local card = game:createCard('无撤销')
    game:getZone('弃牌'):accept(card)

    card:enablePassive()
    card:disablePassive()
    card:enablePassive()
    lt.assertEquals('停用时没有东西可调、也不报错；再启用照常应用', 2, game:getValue('无撤销应用'))
end)
