# 会话交接

新会话请先读 `AGENTS.md`，再读本文件 —— 这里只记「做到哪、下一步、别推翻什么」，细节一律指到工件与技能文档。每次会话收尾由接手者改写本文件（保留有效口径，别堆流水账）。

## 当前状态（2026-09-29 收尾）

- 基线：`server/bin/moe-kill.exe --test` **650 用例 0 失败**；问题面板 information 及以上 0。
- 最近提交：`1e7adb4`（四个后续变更的规划工件 + 会话交接）、`3f4d701`（阶段事件按当事人发 + `Player:currentPhase`）。
- 工作区有**未提交**的改动：`rework-zone-disable` 已实施完毕（内核 + 用例 + 文档 + 变更工件），**等用户「提交」口令**。

## 正在做的一批（按顺序落地）

四个变更的 `proposal.md` / `design.md` / `tasks.md` 里是完整口径，这里只给索引。后一个依赖前面：**1 / 2 互相独立但都改 `zone.lua` 与同一批用例，建议连着做；4 依赖 1 + 2 + 3。**

| 顺序 | 变更 | 一句话 | 状态 |
| ---- | ---- | ---- | ---- |
| 1 | `rework-zone-disable` | 区域禁用 = 逻辑禁用（区里的牌不能用 + 被动被压制）；计数可叠加、`disable()` 返回撤销函数；不再拦搬入搬出 | **已实施，待提交** |
| 2 | `replace-slot-zone-with-equip-zones` | 删掉 `SlotZone` 整套；内容侧在「游戏-开始」建 `武器` / `防具` / `进攻马` / `防御马` 四个普通子区；`equipCard` 承担「一个子区只能有一张」 | 未动工 |
| 3 | `add-buff-system` | 内核 `Buff`：挂在玩家上的有名状态；资源与订阅随移除撤销；生命周期由内容写 | **形状待用户过目** |
| 4 | `add-qinggang-sword` | 【青釭剑】改名 + 效果（压 / 松 / 兜底）+ 效果收尾整理（`'效果-收尾'` 无条件发 + 批量弃牌） | 未动工 |

## 已拍板的口径（别推翻）

- **禁用区域**（用户 2026-09-29）：区里的牌**不能用**、**被动被 `disablePassive` 压住**；**不再拦搬入搬出** —— 「不准置入」是官方规则集里的**封印**，将来按那个名字另做。
- **禁用时区级压制与内容钩子的先后**（2026-09-29 实现时定、已与用户过目；与 `design.md` 初稿的表格相反）：**进区先压再跑钩子、离区先跑钩子再松开** —— 区级那层永远在钩子外侧。理由：被动回调要取 `zone.owner`、`applyPassive` 要 `getZone()`，而 `moveCard` 时牌已绑到新区（弃牌堆）、`clear`/`draw` 时已解绑 ⇒ 反过来会拿新区 / 空区跑被动（当场断言失败）。
- **装备子区**：**内容侧建**（不是内核建）；「装备区」退出内核的基础牌区清单（内核只留 `抽牌` / `弃牌` / `手牌` / `判定`）；「进错子区不启用被动」**内容做**。
- **`SlotZone` 整套删除**（用户批过）。
- **buff 实际做，不用临时闭包方案**（用户 2026-09-29）；挂载点先只 `Player`、同名实例并存、`attach` / `on` / `remove`。
- **青釭剑时机**：压 = `'卡牌-结算前'` 对全目标；松 = 逐目标 `'效果-收尾'`；兜底 = `'卡牌-结算后'`（官方两则裁定见该变更的 `design.md`）。

## 待办 / 悬着的事

- `add-buff-system` 的 buff 形状（`design.md` §1）等用户过目后才动工。
- `add-zhuge-crossbow` 是个**空壳**（目录里只有 `.openspec.yaml`，无工件；诸葛连弩的活已提交）—— 等用户定：删 / 补 / 归档。
- `add-delayed-trick-cards` 显示 Complete，可归档。
- 已知边界（记在 `add-qinggang-sword` 的 non-goals）：官方「窗口内失去防具、其『失去时』技能也不能发动」（【白银狮子】那类裁定）本批做不到 —— 牌离区时区级压制就松了。

## 常用命令

- 全量测试 `server/bin/moe-kill.exe --test`；单套件 `server/bin/moe-kill.exe --test rule.equip`。
- **平时只改 Lua 不需要构建**；动了 C/C++、`make.lua`、`make/lua-patch/**`、`3rd/bee.lua` 才 `luamake -notest`。
- 变更：`openspec list` / `openspec status --change <名字>` / `openspec validate --all`。
- 提交（**用户说「提交」才许**）：`git add -A -- .agents package server openspec AGENTS.md HANDOVER.md`，消息 `-m` 多段、禁用 ASCII 单引号（用「」）。
