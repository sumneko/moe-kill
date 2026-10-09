# Design

## Context

- 现成的基础设施：`moe.json`（`tools/json.lua` 的 `encode` / `decode`）、`moe.task`（「一次请求 = 一个任务」是既有形状）、`moe.await`（`yield` 让出直到 resume）、`moe.asyncIO`（socket 事件源注册 —— 连接批要用）。
- `server/session/` 是待删的临时外壳；`server/transport/` 与 `server/proto/` 是架构里预留的位置（`architecture.md` §1 与 `moe-kill-dev` 的目录表）。
- 协议设计原则（`architecture.md` §3）已经定了：方法名 `域.动作`、后端权威、需要玩家输入时后端发**反向请求**、重连走专门方法 —— 本批只做承载它们的**机制**，不做具体方法。

## Goals / Non-Goals

**Goals**

- 一个**不依赖 socket** 的双向 JSON-RPC 端点（`Client`）：出站请求 / 通知，入站注册方法。
- **无头可测**：两张 `Client` 用一对内存 `Link` 对接就能跑完整往返。
- 连接、帧格式、超时都不是这个端点的事（各归各层）。

**Non-Goals**

- TCP 连接与帧格式（`Content-Length` 或换行分隔）。
- 请求超时（用户 2026-10-09 定：**不做**）。
- `server/proto/` 的方法名常量表（方法名由调用方给字符串）。
- `ClientUser` 的接线（它现在还是空壳）。
- 删除 `server/session/`（本批一行不动）。

## Decisions

### D1. 三层切分

| 文件 | 职责 | 认识的边界 |
| --- | --- | --- |
| `jsonrpc.lua` | 编解码**纯函数** | 只认识「表 ↔ 字符串」 |
| `link.lua` | 传输（`read` / `write`） | 只认识「一条消息 = 一个字符串」 |
| `client.lua` | 端点（方法表 / id / pending / 读循环） | 只认识 `Link` 的两个方法 |

`jsonrpc.lua` 不碰 IO、不碰 Client 状态 ⇒ 可以单测往返与错误分支（对应 `architecture.md` §6 的第 3 条：协议契约测试不必真开 socket）。

门面：`moe.client`（`create`）/ `moe.link`（`pair`）/ `moe.jsonrpc`（纯函数），`init.lua` 只做装载。

### D2. `Link` 的形状（用户 2026-10-09 定）

```lua
---@class Link
---@field read async fun(self: Link): string?, string? # 读下一条消息：没数据就挂起；断开或出错时给 `nil` + 原因
---@field write fun(self: Link, text: string): boolean, string? # 发一条消息：失败给 `false` + 原因
```

- **帧不在这层**：`read(n)` 读 `n` 个字节（不够挂起）、`read()` 把能读的全读走（完全没有数据才挂起）—— 它只管字节；**帧由 `jsonrpc` 给原语、由 `Client` 切与套**（见 D2b）。
- 本批的**内存实现**：`moe.link.pair()` 造一对互相连通的 Link（A 写的 B 读到，反之亦然）；**关掉一端 ⇒ 另一端 `read` 给 `nil, 原因`**（这是「断开」的唯一信号）。
- 实现里读不到数据就 `moe.await.yield` 让出（恢复绑在调用它的协程上 —— 这是「应答方可以让出」的同一套机制）。

### D2b. 帧格式：4 字节长度头 + 正文（用户 2026-10-09 定）

- 头 = `string.pack('>I4', #text)`（大端 32 位无符号，**长度不含头本身**）；正文 = JSON-RPC 那串。
- 原语（`HEADER_SIZE` / `encodeFrame` / `decodeFrameLength`）住 `client.lua` 的局部 —— **帧不是 JSON-RPC 的一部分**（用户 2026-10-09 定：长度头是传输约定，`jsonrpc.lua` 只管「表 ↔ 字符串」）。
- **`Client` 不维护缓冲**（用户 2026-10-09：buffer 由 link 维护）：读循环就是「`read(4)` 取头 → 解长度 → `read(长度)` 取正文 → `onMessage`」—— 凑够一帧由 `Link` 挂着等，半包 / 粘包在 `link:read(n)` 里消化；`Client:send` 发送前套头。

### D3. 读循环归 `Client`

`Client:start()` 起一个任务跑：

```lua
while true do
    local head = self.link:read(4)                          -- 长度头（不足就由 link 挂着等）
    if not head then break end
    local text = self.link:read(decodeFrameLength(head))    -- 正文
    if not text then break end
    self:onMessage(text)
end
-- 收摊：标记关闭 + 把 pending 全部以「连接已断开」收尾
```

`Client:onMessage(text)` 也对外可见（想自己驱动读的调用方可以直接喂）。

### D4. `request` 返回 `Task`（callback 可选）

- `request(method, params, callback?)`：发出去 + 记 pending ⇒ 返回 `Task`；收到响应时 `resolve(result)` / `reject(错误对象)`；`callback` 给了就同时挂上去（成功 / 失败两边都调）。
- `awaitRequest(method, params)` = `request(...):await()`（`---@async`，等不到就是失败）。
- **写失败**（`write` 给 `false`）⇒ 该请求立刻以那个原因 reject。
- `notify(method, params)` 返回 `write` 的 `boolean, string?`（没人为通知的失败兜底）。

### D5. `register` 与入站分派

- 一张方法表；**带 id 的当请求**（回调返回值 = `result`，抛错 ⇒ `-32603` + 错误消息）、**不带 id 的当通知**（返回值忽略，抛错只记日志 —— 通知没地方回错）。
- 回调**可以 await**（`---@async`）。
- `register` 返回 **disposer**（可叠加操作的约定）。
- **同一个 method 重复注册 ⇒ 报错**（一个 method 只能有一个处理器；与内核 `addZone` 撞名的口径一致）。
- 未知 method 的请求 ⇒ `-32601`；未知 id 的响应 ⇒ 一条 `warn`、丢掉。

### D6. 错误形状

JSON-RPC 2.0 标准：`{ code = number, message = string, data? = any }`；常量放 `jsonrpc.lua`：`PARSE_ERROR = -32700` / `INVALID_REQUEST = -32600` / `METHOD_NOT_FOUND = -32601` / `INVALID_PARAMS = -32602` / `INTERNAL_ERROR = -32603`。

- 解析失败（脏数据）⇒ 回 `-32700`（id 为 null）。
- 内部错误**不带堆栈**（协议不外泄内部细节；堆栈在日志里）。

### D7. 内存 `Link` 不是测试后门

它是**真实可用**的「本地回环」（同一进程内两张 `Client` 对接）：无头测试用它，将来的本地单机模式也能用它。

### D8. 本批不做

TCP / 帧格式 / 超时 / `proto/` 方法名常量 / `ClientUser` 接线 / 删 `server/session/`。

## Risks / Trade-offs

- **`read` 挂起 = 需要一个常驻协程**：读循环是 Client 起的一个任务 ⇒ 断开时要能收敛（`read` 给 `nil` 就退出，见 D3）。
- **协议细节延后**：帧格式与超时不在本批 ⇒ 真连 TCP 时还要定一次（那时第一个真需求是「连上 / 断开 / 半包」）。
- **没有方法名常量表**：方法名现在是散字符串 ⇒ 等有真方法（协议批）时再建 `proto/`，那一条早就写在 `architecture.md` §3。

## Migration Plan

- 现有代码零改动（新目录、新用例；`session/` 不动）。
- 新用例：`test.transport.jsonrpc`（四种形状往返 / 脏数据 / 错误）、`test.transport.link`（写读 / 关掉一端读空 / 写失败）、`test.transport.client`（两张 Client 对接：通知 / 请求往返 / 错误响应 / 未知方法 / 未知 id / 异步 register / disposer / 断开）。
- 后续批次：连接层（TCP + 帧格式）、`ClientUser` 接线、`proto/` 方法名、删 `session/`。

## Open Questions

无 —— 用户 2026-10-09 已定：落点 `transport` / `request` 返回 `Task` / `register` 可 await / 不做超时 / `Link` 只 `read` + `write`、且 `read` 是「没数据就挂起」的异步方法。
