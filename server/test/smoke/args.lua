local lt   = require 'test.ltest'
local args = require 'args'

lt.test('命令行参数：三种形式与键名归一化', function ()
    local parsed = args.parse {
        '--test',
        'smoke.args',
        '--loglevel=trace',
        '--develop',
        '--dbg-port',
        '11419',
    }
    lt.assertEquals('--key value 形式', 'smoke.args', parsed.TEST)
    lt.assertEquals('--key=value 形式', 'trace', parsed.LOGLEVEL)
    lt.assertEquals('裸开关', true, parsed.DEVELOP)
    lt.assertEquals('键名连字符转下划线', 11419, parsed.DBG_PORT)
end)

lt.test('命令行参数：未识别参数被保留且不报错', function ()
    ---@type table<string, Args.Value>
    local parsed = args.parse { '--unknown-thing=1' }
    lt.assertEquals('保留未识别参数', 1, parsed.UNKNOWN_THING)
end)

lt.test('命令行参数：调试地址与端口有默认值', function ()
    local parsed = args.current { '--develop' }
    lt.assertEquals('默认地址', '127.0.0.1', parsed.DBGADDRESS)
    lt.assertEquals('默认端口', 11418, parsed.DBGPORT)
end)

lt.test('命令行参数：布尔字面量', function ()
    local parsed = args.parse { '--develop=true', '--dbgwait=false' }
    lt.assertEquals('true 字面量', true, parsed.DEVELOP)
    lt.assertEquals('false 字面量', false, parsed.DBGWAIT)
end)
