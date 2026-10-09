# Tasks

## 1. JSON-RPC 编解码

- [x] 1.1 `server/transport/jsonrpc.lua`：错误码常量 + `decode` / `encodeCall`（不给 `id` 就是通知）/ `encodeResult` / `encodeError`
- [x] 1.2 用例 `test.transport.jsonrpc`：四种形状往返 / 脏数据 / 错误码
- [x] 1.3 帧原语（`HEADER_SIZE` = 4 / `encodeFrame` / `decodeFrameLength`）—— **住 `client.lua` 的局部**（用户 2026-10-09：长度头不是 jsonrpc 的一部分）

## 2. Link

- [x] 2.1 `server/transport/link.lua`：`Link` 类型 + 内存实现 `pair()`（一对互联；关掉一端会让另一端读空）
- [x] 2.2 用例 `test.transport.link`：写进去读得到 / 关掉一端另一端读到 `nil` 与原因 / 写失败

## 3. Client

- [x] 3.1 `Client:create(link)` + `start()`（读循环任务）+ `onMessage(text)`
- [x] 3.2 `notify` / `request`（返回 `Task`，callback 可选）/ `awaitRequest`
- [x] 3.3 **模块级**的 `moe.client.register(method, fun(client, params))`（返回 disposer；带 id 当请求、不带当通知；同一个 method 重复注册报错）
- [x] 3.4 断开的收摊（`read` 给空 ⇒ 标记关闭 + pending 全部以「连接已断开」收尾）
- [x] 3.5 用例 `test.transport.client`：两张 Client 对接（通知 / 请求往返 / 错误响应 / 未知方法 / 未知 id / 异步 register / disposer / 断开）
- [x] 3.6 发送套长度头、读循环按帧长读（`read(4)` + `read(长度)`，不自己维护缓冲；用例含「粘在一起的帧也各解一条」与「头和正文分两批到」）

## 4. 文档与验收

- [x] 4.1 `references/architecture.md` 新增一节（传输层与 Client）
- [x] 4.2 `references/progress.md` §1 条目 + 基线
- [x] 4.3 `SKILL.md` 目录表补 `server/transport/`
- [x] 4.4 `server/bin/moe-kill.exe --test` 全绿（1143 用例 0 失败）、问题面板 information 及以上为 0
