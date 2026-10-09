# 变更：「取消」收成一种失败

## 需求

**询问没拿到答复 = 「取消」**：`.err` = **`'取消'`**、`.success` 假（`.result` 空）。

**「取消」算不算成立，看这次询问允不允许「不给」**：

- `min` 给 `0` ⇒ 取消是**合法答复**，照常**成立**（`.err` 空、结果为空）；
- 否则 ⇒ 取消**记成失败**；
- `condition.cancelable = false` 的询问（玩家无权拒收）**没人表态**则记**拒收**（`.err` = `'这次询问必须给出答复'`，沿用旧文案）。

**「取消不是故障」这条不变**：只记 `.err`、**不进错误处理器**（生产 `log.error` / 测试 `lt.errors` 都只喂抛出来的 error，见 `design.md` D4）。

## 为什么

- 用户 2026-10-09 提：`AskCard` 的「空答复 = 取消、**不算失败**」这句里，取消本该算失败 —— `Task` 里就专门有个 err 原因是 `CANCELED`，「取消」本来就是经 `err` 表达的。
- 补充口径（用户同日）：**「应当看『取消』是否是合法的。如果 `min = 0`，那么取消视为成功」** —— 所以判据不是「一律失败」，而是**这次询问的下限**。
- **现状是「第三种状态」**：`AskCard` 没人表态时什么都不做 ⇒ 任务由执行体的返回值收尾 ⇒ `.result` / `.err` 都空、`.success` **真**。于是同一件「这次没成立」的事，走「被阻止 / 被驳回」那条路（`.err` 有值）与走「没答上」那条路（`.err` 空）给出相反的 `.success`。
- 实际后果（本批顺手修掉的）：一次**响应**（【杀】要【闪】）没人出【闪】时 `.success` 为真，【杀】读 `.success` 就会把「没人出闪」读成**响应成立** ⇒ 不造成伤害。这正是上一批（【无双】）在 `AskPlayCard:beforeResolve` 里打的那个补丁 —— 现在由基类统一处理，补丁可以删掉。
- 前因：`merge-offset-into-response` 把响应族收进 `AskPlayCard`，`.success` 成了【杀】的正式读法 ⇒ 这个不一致必须先修掉。

## 做什么

1. **内核**：`AskCard:collectAnswer` 的两条「没答上」路径（没人表态 / 空答复）按上述判据记 `.err`；新增 `AskCard:allowNone()` 与模块内的 `isEmptyAnswer(value)`；`AskPlayer` 加同形的 `allowNone()`；`Ask` / `AskChoice` / `AskUseSkill` 的 `settle` 在 `answer == nil` 时 `reject('取消')`。
2. **收编**：`AskPlayCard:settle` 里那句 `reject('没有打出')` 与 `beforeResolve` 的空答复作废**整段删掉**（基类已统一处理），理由词统一成「取消」。
3. **用例**：10 条旧断言（`nil, ask.err` = 「不算失败」）改成 `'取消'`；另加 1 条（`min` 给 0 时没人表态也算成立）、2 条改名点明口径。
4. **文档**：`architecture.md`（`cancelable?` 那行、「询问与应答方」那条、`askPlayCard` / `askPlayer` / `ask` / `askChoice` 四行）与 `progress.md` 同步。

## 不做什么

- **不改「取消不是故障」这条**：声明式的 `reject` / `cancel` 不喂错误处理器（只有 `error` 才是故障）—— 玩家不表态不是 bug，不该进日志。口径两个字说清楚：**`.success` 与「进不进错误处理器」是两根轴**。
- **不给 `Ask` / `AskChoice` / `AskUseSkill` 加 `min`**：它们没有「给几个」的概念（选项 / 答复都是单值），所以它们身上取消一律记失败；将来真需要「允许不选」再显式加字段，不提前开形状。
- **不动 `openspec/specs/`**：那是探索期的历史快照（`core-decision` 写着「没答上 MUST NOT 被当成失败」），按冻结期的口径不追改 —— 且按「不进错误处理器」读与新口径并不冲突，留到将来那次一次性回顾对齐。

## 验收

`server/bin/moe-kill.exe --test` 全绿（**1053 → 1054**）；问题面板 information 及以上 0；【杀】在对方不出【闪】时照常造成伤害、出【闪】时不造成伤害；`min = 0` 的询问（【雌雄双股剑】/【突袭】）取消时 `.err` 仍为空。
