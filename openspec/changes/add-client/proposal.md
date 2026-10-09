# Proposal

## Why

前后端通讯要落地，但 `server/transport/`（SKILL 目录表里预留的「JSON-RPC 帧与连接层」）一直是空的；`server/session/` 只是「还没有 User 概念时为了跑测试临时加的外壳」（用户 2026-10-09 定：之后去掉）。

**`Client` 就是一个客户端在后端的代理**：一条连接 + 一个 JSON-RPC 端点（双向）—— 出站 `notify` / `request` / `awaitRequest`，入站 `register(method, fn)`（带 id 的是请求、不带的是通知，正是 JSON-RPC 2.0 原样）。将来 `ClientUser` 在它上面把内核的询问翻成协议调用。

**连接（TCP）本批不做**：所以抽一层 `Link`，`Client` 只认识「读一条 / 写一条消息」这件事 —— 于是「连接先不做」不是妥协，而是结构的一部分：测试拿一对内存 Link 把两张 `Client` 对接，就能无头跑完整协议往返（吃住「无前端也能跑完整对局」那条硬约束）。

## What Changes

- 新增 `server/transport/` 三个文件：
  - `jsonrpc.lua` —— **编解码纯函数**（与传输无关）：请求 / 通知 / 成功响应 / 错误响应四种形状 + 标准错误码。
  - `link.lua` —— `Link` 的接口形状（`read` / `write`）+ **内存实现**（一对互相连通的 Link：本地回环 / 测试用）。
  - `client.lua` —— `Client` 类：`create(link)` / `start()`（起读循环）/ `onMessage(text)` / `notify(method, params)` / `request(method, params, callback?)`（返回 `Task`）/ `awaitRequest(method, params)` / `register(method, fn)`（返回 disposer）。
- `Link` 的形状（用户 2026-10-09 定）：`read` 是 `---@async`、**没数据就挂起**，返回 `string?`（断开或出错时是 `nil, 原因`）；`write(text)` 返回 `boolean, string?`。
- `register` 的回调**可以 await**（经网络层的东西本来就不可能同步）；回调抛错 ⇒ 回 `-32603`。
- **本批不做**：TCP 连接与帧格式、超时、`server/proto/` 的方法名常量、`ClientUser` 的接线、删除 `server/session/`。

## Capabilities

### New Capabilities

无。本变更属探索期的**决策记录**，不写规格增量（`.openspec.yaml` 设 `skip_specs: true`）。理由见 `AGENTS.md`「工作流」：探索期只留决策记录，可执行契约由用例承担。

### Modified Capabilities

无。`openspec/specs/` 已冻结，不回头改。

## Impact

- 新增：`server/transport/{jsonrpc,link,client}.lua` + `init.lua`（只做装载）、`server/test/transport/{jsonrpc,link,client}.lua`。
- **不动**：`server/session/`（保留，之后单独删）、`server/user/`、内核。
- 文档：`references/architecture.md`（新增一节：传输层与 Client）、`references/progress.md`（§1 条目 + 基线）、`SKILL.md`（目录表补 `server/transport/`）。
