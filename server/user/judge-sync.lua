--- 判定下行：一次判定有了结果（成 / 败），广播给所有人（判定牌是公开的）

---@class JudgeSync.API
moe.judgeSync = {}

--- 客户端接入了：把这一局的判定账带起来（重复调无害）
---@param user User
---@return Game.JudgeSync
function moe.judgeSync.attach(user)
    return user.game.judgeSync
end

---@class Game: Class.Base
---@field package judgeSync Game.JudgeSync # 这一局的判定结果广播
local Game = Class 'Game'

---@param self Game
---@return Game.JudgeSync
---@return true
Game.__getter.judgeSync = function (self)
    return New 'Game.JudgeSync' (self), true
end

---@class Game.JudgeSync
local S = Class 'Game.JudgeSync'

---@param game Game
function S:__init(game)
    self.game = game

    -- 判定开始：谁在判什么（这一段客户端要等牌飞出来，光一张牌没说明）
    game:on('判定-开始', function (judge)
        ---@type Proto.Notify.Judge.Begin
        local data = {
            player = judge.player.id,
            reason = judge.reason,
        }
        for _, player in ipairs(game.desk.players) do
            player.user?:notify('Judge.Begin', data)
        end
    end)

    -- 内容侧判了成败：判定牌带牌面给出去，谁都能画勾 / 叉
    game:on('判定-结果', function (judge)
        local card = judge.card
        if not card then
            return
        end
        log.debug('判定结果：{} 的「{}」{}' % { judge.player.id, judge.reason or '无缘由', judge.passed and '成' or '败' })
        ---@type Proto.Notify.Judge.Result
        local data = {
            player = judge.player.id,
            reason = judge.reason,
            face   = {
                name  = card.name,
                suit  = card.suit,
                point = card.point,
            },
            passed = judge.passed == true,
        }
        for _, player in ipairs(game.desk.players) do
            player.user?:notify('Judge.Result', data)
        end
    end)
end
