-- 给客户端播动画的节拍（服务器让出时间，客户端才有机会把这一段播出来）

--- 每种动作等多久（数字照前端的动画时长定：飞一张牌 1 秒、手牌挪位 0.26 秒）
local BEAT = {
    turnBegin   = 0.2,
    moveCard    = 1,
    playCard    = 1,
    damage      = 0.4,
    heal        = 0.3,
    judge       = 0.3,
    -- 判定结果：客户端先亮牌 1 秒、再打勾 / 叉停 1.8 秒，演完才收尾
    judgeResult = 3,
    death       = 0.5,
    panelChange = 0.3,
}

game:on('回合-开始', function ()
    game:animSleep(BEAT.turnBegin)
end)

--- 一次搬动（摸牌 / 弃牌 / 装备 / 判定区 / 洗回）一起等一次，不按张数算
--- 「时」= 表现通知已经发出去了、落位通知还没发：在这里让出，客户端才有时间播完这一段
game:on('卡牌-批量移动时', function (moves)
    if #moves > 0 then
        game:animSleep(BEAT.moveCard)
    end
end)

--- 打出与使用都是「把牌亮到桌上」：三种询问都算
game:on('卡牌-答复', function (askCard)
    local kind = askCard.kind
    if kind == 'askPlayCard' or kind == 'askUseCard' or kind == 'askUseCardToCard' then
        game:animSleep(BEAT.playCard)
    end
end)

game:on('伤害-结束', function ()
    game:animSleep(BEAT.damage)
end)

game:on('治疗-结束', function ()
    game:animSleep(BEAT.heal)
end)

game:on('判定-后', function ()
    game:animSleep(BEAT.judge)
end)

--- 判定出了结果：客户端要先亮判定牌、再打勾 / 叉 —— 等它演完，这个效果才收尾（牌才进弃牌堆）
--- 注意：这里**不能**直接订阅「判定-结果」——那个事件订阅顺序在同步层之前，会让广播排到等完以后。
--- 所以给个节拍函数，由判定自己在 fire 完之后调。
rule.judgeResultBeat = function ()
    game:animSleep(BEAT.judgeResult)
end

game:on('玩家-死亡', function ()
    game:animSleep(BEAT.death)
end)

game:on('面板-变化', function ()
    game:animSleep(BEAT.panelChange)
end)
