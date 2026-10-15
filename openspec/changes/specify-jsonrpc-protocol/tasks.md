# Tasks

> 本变更是**补写既成事实的规格**：协议早就跑通，这里只写文档、**不改实现**。所以任务就是「写准 + 核准」。

## 1. 写规格

- [x] 1.1 写 `specs/jsonrpc-protocol/spec.md`（8 条需求：分帧与传输 / 四种消息 / 参数形状校验 / 错误码 / 上行方法清单 / 时限与取消 / 下行通知清单 / WebSocket 握手），并写好 `## Purpose`
- [x] 1.2 逐条对照代码核实 —— 规格里每一句都要能指出落点：
  - 分帧与 `Link`：`server/transport/{link,tcp-link,ws-link}.lua`
  - 四种消息与派发：`server/transport/client.lua`、`server/transport/jsonrpc.lua`
  - 形状校验：`server/tools/shape.lua`、`server/tools/proto.lua` 的 `shape`
  - 错误码：`server/proto.d.lua` 的 `Proto.Error.*`
  - 上行方法与询问答复：`server/room.lua`、`server/user/{snapshot,panel-sync,skill-sync,client-user}.lua`
  - 时限与取消：`server/user/client-user.lua`（`TIME_LIMIT_SLACK`）、`Proto.Notify.Cancel`
  - 通知清单：`server/user/{room-sync,player-sync,card-sync,skill-sync,panel-sync,flow-sync}.lua`
  - 握手：`server/transport/websocket.lua`
- [x] 1.3 `openspec validate specify-jsonrpc-protocol --strict` 通过
- [x] 1.4 在 `moe-kill-dev` 的 `references/architecture.md` 里加一句指针（协议规格在哪、形状以 `proto.d.lua` 为准），避免以后有人只看一边

## 2. 收尾

- [x] 2.1 报告核对结果与规格全文，停在待确认状态（等用户过目 / 归档口令）
