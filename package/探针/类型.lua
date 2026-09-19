rule:on('游戏-开始', function (ctx)
    print(ctx.不存在的字段)
end)

local 动态 = '别的时机'
rule:on(动态, function (ctx)
    print(ctx.随便什么字段)
end)

rule:fire(动态)
