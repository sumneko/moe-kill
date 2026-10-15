--- 协议类型的前端产物（`client/src/proto.d.ts`）：翻译口径 + 跟磁盘上那份对得上

local lt = require 'test.ltest'

lt.test('proto 类型：类型写法解得成节点', function ()
    local node = moe.proto.parseType 'Proto.Card[]?'
    lt.assertEquals('外层是可选', 'optional', node.kind)
    lt.assertEquals('里层是数组', 'list', node.inner.kind)
    lt.assertEquals('再里层是类名', 'Proto.Card', node.inner.inner.name)

    local struct = moe.proto.parseType '{ zone: string, cards: Proto.Card[] }[]'
    lt.assertEquals('内联结构套数组', 'list', struct.kind)
    lt.assertEquals('结构里两个字段', 2, #struct.inner.fields)
    lt.assertEquals('第二个字段是可选的', false, struct.inner.fields[2].optional)

    lt.assertError('写错当场炸', function ()
        moe.proto.parseType 'Proto.Card $'
    end)
end)

lt.test('proto 类型：翻出来的 TS 那几条口径', function ()
    local text = moe.protoType.text()

    lt.assertNotEquals('命名空间按点摊开', nil, text:find('export namespace Proto {', 1, true))
    lt.assertNotEquals('字面量联合原样留着', nil, text:find("suit?: '黑桃' | '红桃' | '梅花' | '方块';", 1, true))
    lt.assertNotEquals('可选字段带问号', nil, text:find('face?: Proto.CardFace;', 1, true))
    lt.assertNotEquals('数组', nil, text:find('cards: Proto.Card[];', 1, true))
    lt.assertNotEquals('内联结构', nil, text:find('show?: { zone: string; cards: Proto.Card[] }[];', 1, true))
    lt.assertNotEquals('继承', nil, text:find('export interface Select extends Proto.Cancelable, Proto.Timelimit {', 1, true))
    lt.assertNotEquals('数字字面量', nil, text:find('code: -32600;', 1, true))
    lt.assertNotEquals('叶子类型', nil, text:find('seats: number;', 1, true))
    lt.assertNotEquals('没字段也没下层的类当自由表', nil, text:find('export type Custom = Record<string, unknown>;', 1, true))
end)

lt.test('proto 类型：磁盘上那份跟现翻出来的一致', function ()
    local path = moe.protoType.path()
    local onDisk = moe.fsu.loadFile(path)
    lt.assertNotEquals('产物读得到（跑一下 server/bin/moe-kill.exe --gen-proto）', nil, onDisk)
    lt.assertEquals('一模一样（换行符不论）', moe.protoType.text(), (assert(onDisk):gsub('\r\n', '\n')))
end)
