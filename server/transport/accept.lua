--- 刚收下的连接接成哪种协议链接：头几个字节是 HTTP 请求就走 WebSocket 握手，否则当裸帧通道

--- 裸帧的开头是 4 字节长度头（大端），撞不出这四个字节
local HTTP_PREFIX = 'GET '

--- 把一条刚收下的 TCP 接成协议链接
---@async
---@param fd bee.socket.fd
---@return Link?
---@return string?
function moe.link.accept(fd)
    local link = moe.link.tcp(fd)
    local head, readErr = link:read(#HTTP_PREFIX)
    if not head then
        link:close(readErr)
        return nil, readErr
    end
    if head == HTTP_PREFIX then
        link:unread(head)
        return moe.link.websocket(link)
    end
    link:unread(head)
    return link
end

return moe.link
