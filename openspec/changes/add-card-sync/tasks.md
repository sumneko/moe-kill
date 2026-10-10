# Tasks

## 1. 连接侧的卡牌视图

- [x] 1.1 `server/transport/card-sync.lua` 骨架：门面 `moe.cardSync`；**每个连接**一份视图（`id → Proto.Card`）+ 视图 id 的号源 + 连接自带的随机源；在 `server/transport/init.lua` 里装载，视图随连接释放（弱键表）。验证：用例「全量灌入」里两个连接各收一条
- [x] 1.2 进出的 id 规则：进区分配新 id；从可见区移除用真实那张的 id；从**不可见区**移除时，从「该连接看到的、这个区里没有牌面的那些牌」中**随机挑一个** id。验证：用例「看不见的牌只有 id 与区域」
- [x] 1.3 内核侧：**`Card.id` 保留**（当调试号）；**不新增内核通道** —— 进 / 离区在局上再发一份（`'卡牌-进入区域'` / `'卡牌-离开区域'`），牌自己变了新增局上时机 **`'卡牌-变化'`**（2026-10-10 用户定：重开游戏会重建 `Game`，同一局不重装，所以不必让订阅跨 `resetContent` 存活）。验证：全量用例绿、面板 0

## 2. 组装（协议 zone / 一张牌 / 按视角）

- [x] 2.1 协议 zone 的组装：玩家 id + 区名；没有归属的区不带玩家；临时区（无名无主）一律表示成同一个空区域。验证：用例「无名区（临时区）之间互移不发移动、也不换 id」
- [x] 2.2 组装一张牌的 `Proto.Card`：`zone` + `template`（**牌自己那份面**，`card.ownFace`）+ `modifier`（**所有「转化」叠出来的那一份**，`card.modifier`，没挂就不带）。验证：用例「挂上转化只动 modifier / 没转化就不带 modifier」
- [x] 2.3 按收件人裁剪：区级可见性叠加这一次搬动的可见性，任一不可见就不给 `template`。验证：用例「看不见的牌只有 id 与区域」「自己的手牌看得见」

## 3. 置脏与 flush

- [x] 3.1 局上记脏卡表 + **第一次标脏只登记一次** flush（`moe.await.wake`，与 `player.custom` 同一套）。验证：用例「一笔调度里连改两次只发一次」
- [x] 3.2 flush 的比较与三分类：与该连接视图里那份逐字段比 —— 一致不发 / 有变化且协议 zone 相同 ⇒ `Card.Update` / 换区 ⇒ 换新 id + `Card.Remove` + `Card.Create`（移除在前、创建在后；空的不发）。验证：用例「牌进区发创建、离区发移除」「换区会换新 id」「区域没变就原地更新」
- [x] 3.3 视图的更新时机与内容：每次组装后把新那份存回该连接的视图。验证：用例「加了转化又撤销，等于没变，不发通知」

## 4. 移动的预通知

- [x] 4.1 离开时记住来源区、进入时配对比较；协议 zone 不同就**当场**发 `Card.Move`（带 `from` / `to` 与搬之前的视图 id）。验证：用例「搬牌当场发移动通知」（断言不等调度就已发出）
- [x] 4.2 无名区之间互移：不发 `Card.Move`、也不换视图 id。验证：用例

## 5. 出口与开局全量

- [x] 5.1 `User` 加四条卡牌出口（`cardCreate` / `cardUpdate` / `cardRemove` / `cardMove`，基类空实现）；`ClientUser` 覆写成四条 `notify`。验证：`test.transport.card-sync` 全绿（走的就是这四条）
- [x] 5.2 `moe.cardSync.syncAll(game)`：把这一局全部牌区里的牌灌一遍（含抽牌堆，按视角裁剪）。验证：用例「全量灌入把各区的牌都发一遍」。（**「开局自动调」留给外壳**，本批只提供入口）

## 6. 端到端与收尾

- [x] 6.1 用例 `test.transport.card-sync` 10 条，覆盖全量 / 背面裁剪 / 进区 / 离区 / 换区换 id / 原地更新 / 无变化不发 / 移动预通知 / 无名区互移 / 一笔调度合并。验证：`--test transport.card-sync` 10 通过
- [x] 6.2 全量验收：`server/bin/moe-kill.exe --test` ⇒ **1176 用例 0 失败**；问题面板 information 及以上 0
- [x] 6.3 文档：`references/architecture.md` 新增第 16 节（视图在连接侧、四类通知、判定口径、匿名 id），`references/progress.md` 条目 + 基线，`SKILL.md` 目录表补 `server/transport/card-sync.lua`。验证：三个文件已更新
