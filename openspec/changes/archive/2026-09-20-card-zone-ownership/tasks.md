# Tasks

## 1. 内核：牌记自己的归属（`server/core/card.lua`）

- [x] 1.1 牌带一个字段记所在牌区（不在任何牌区里 = 空），对外只读入口 `card:getZone()`；写入入口 `bindZone(牌区或空)` 的说明写明「只有牌区自己用：放进 / 取出时维护」（跨文件写不进私有字段，故走方法）；验证：面板 0、`--test core.move` 的归属用例通过
- [x] 1.2 字段用 `---@field private` 收着，跨文件只经方法与只读入口访问（`---@field package` 在本工程实测也退化成同一文件，别指望它挡得住）

## 2. 内核：牌区维护这本书（`server/core/zone.lua`）

- [x] 2.1 放入 / 取出 / 移动 / 清空四种操作各自把牌的归属改成正确的值；验证：新增的归属用例（放进记得住 / 取出清掉 / 移动跟着走 / 清空全清）
- [x] 2.2 `put` 只接受不在任何牌区里的牌：已有归属时以明确失败结束（错误文本提示换区请用移动），且两边的计数与那张牌的归属都不变；验证：用例「已经在牌区里的牌不能再放进去」（放进别的区、放进同一个区两种情形）
- [x] 2.3 确认这四个操作仍然只动 `cards` 与归属，不产生事件、记录或其它副作用（口径见 `design.md` D6）

## 3. 内核：挪牌入口落地（`server/core/game.lua`）

- [x] 3.1 `game:moveCard(cards, 牌区名)` 由窄接口落成实现：拿到目标区（这一局没有这个名字 ⇒ 明确失败）→ **先把每张牌的源区收齐**（有牌不在任何牌区里 ⇒ 明确失败）→ 再逐个移动，落点为目标区**底部**；验证：`--test core.game` 新增「成批挪牌按给出顺序落进目标区」
- [x] 3.2 两种失败都不改状态（整批校验在改状态之前，天然满足）；验证：用例「挪牌时的两种明确失败都不改状态」断言牌还在原处、归属不变
- [x] 3.3 端到端回归：`package/标准/卡牌/杀.lua` 里「目标打出闪 ⇒ 闪进弃牌堆」这条链转绿（此前因 `moveCard` 未实现而红）

## 4. 用例

- [x] 4.1 `server/test/core/move.lua`：把「移动：内核不记录牌的归属」（薄模型）换成归属用例 —— 放进 / 取出 / 移动 / 清空 + 「已经在牌区里的牌不能再放进去」
- [x] 4.2 `server/test/core/game.lua`：补 `game:moveCard` 的两条用例（成批按顺序落进目标区、两种失败不改状态）
- [x] 4.3 全量回归：`server/bin/moe-kill.exe --test` **300 用例 0 失败**（此前 299+1 红）；不需要构建（只动了 Lua）

## 5. 文档

- [x] 5.1 `moe-kill-dev/references/architecture.md` 第 12 节：接口表补 `game:moveCard` 行、新增「牌记自己的归属」条（含「只记牌区不记下标」与 `put` 拒收），示例去掉「（moveCard 待实现）」、测试清单补 `core.move` / `core.game`
- [x] 5.2 主规格归档后检查 `openspec/specs/core-move/spec.md` 的 Purpose（旧文案写着「内核不记录"牌在哪个牌区"」，需按新口径改掉）

## 6. 验收

- [x] 6.1 `openspec validate card-zone-ownership --strict` 通过、`openspec validate --all --strict` 全通过
- [x] 6.2 全量用例 0 失败；问题面板 0（information 及以上）
- [x] 6.3 归档：`openspec archive card-zone-ownership --yes`，确认主规格 `core-move` 已按 delta 更新（新增两条需求、旧的「内核不记录牌的归属」已移除）
