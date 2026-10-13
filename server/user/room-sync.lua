--- 房间下行：谁进来了、还差几个人（开局之前的那点状态）

---@class RoomSync.API
moe.roomSync = {}

--- 广播一次房间状态（给已经入座的每个人一份）
---@param game Game
function moe.roomSync.broadcast(game)
    ---@type Proto.Player.Base[]
    local players = {}
    for _, player in ipairs(game.desk.players) do
        players[#players + 1] = moe.playerSync.toBase(player)
    end
    ---@type Proto.Notify.Room.Update
    local data = {
        seats   = game.desk:getCount(),
        players = players,
    }
    for _, player in ipairs(game.desk.players) do
        local user = player.user
        if user then
            ---@cast user ClientUser
            user:notify('Room.Update', data)
        end
    end
end

return moe.roomSync
