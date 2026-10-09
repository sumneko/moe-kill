# Tasks

## 1. 内核：有序牌区的位置能力

- [x] 1.1 `server/core/ordered-zone.lua`：加 `placeTop(牌表)` —— 按给定顺序置于区顶（第一张最靠顶）
- [x] 1.2 `server/core/ordered-zone.lua`：加 `placeBottom(牌表)` —— 按给定顺序置于区底
- [x] 1.3 类注释与字段说明补「1 = 顶」的顺序约定（与 `peek` / `draw` 对齐）
- [x] 1.4 顺带：`Zone:toPhysical(cards)`（把「化成实体牌」抽出来，`accept` 与 `placeTop` 共用）+ `takeIn` 多一个 `at`（省略 = 追加，行为等价）

## 2. 内容：诸葛亮（`package/标准/武将/诸葛亮.lua`，新）

- [x] 2.1 `Hero '诸葛亮'`（蜀 / 男 / 3）+ `skills { '观星', '空城' }`
- [x] 2.2 【观星】：`'阶段-开始'` + `phase.name == '准备'` ⇒ `skill:tryCast(...)`
- [x] 2.3 X = `math.min(#game.desk.alivePlayers, 5)`；观看 = 顶 X 张进 `cast:getTempZone()` + `setVisible(owner)`
- [x] 2.4 放回：`deck:placeTop(顶堆)` + `deck:placeBottom(底堆)`；**分配明确标注「服务器暂定」**（逆序置顶），注释里写清「待『排列』询问类」
- [x] 2.5 【空城】：`'卡牌-目标-能否指定'` —— 没有手牌且 `plan.card.name` 是【杀】/【决斗】⇒ 返回 `'空城'`

## 3. 用例

- [x] 3.1 `core/zone`：`placeTop` / `placeBottom` 的顺序、已在区内的牌、空列表、取出来能放回
- [x] 3.2 `rule/hero-skill`【观星】：观看的牌进自己的临时区且只有他可见（钉法：抓那次 cast 的临时区看 `isVisibleTo` —— **牌区事件不发到局上**，`game:on('卡牌-进入区域')` 收不到）/ 放回后牌堆一张不多不少 / X 取 `min(存活, 5)`（3 人局 = 3、6 人局 = 5）/ 不发动（拒绝）时一次 cast 都没有、牌堆不动
- [x] 3.3 `rule/hero-skill`【空城】：没手牌时【杀】/【决斗】/视为的【杀】都指定不了他（2 人局 ⇒ `canUse` 报「现在没有合法目标」）/ 候选里有别人、没有他（3 人局 ⇒ 硬指定报「不能以这个角色为目标」）/ 有手牌照旧能被指定 / 别的牌不受影响（【乐不思蜀】照样能指定他）

## 4. 收尾

- [x] 4.1 `server/bin/moe-kill.exe --test` 全绿（**1054 → 1063**）
- [x] 4.2 问题面板 information 及以上 0
- [x] 4.3 反向验证：`placeTop` 换成 `accept` ⇒ **4 红**（牌区两条 + 观星两条）；观星两行放回整段注掉 ⇒ **2 红**；拆掉空城的 hook ⇒ **2 红**（有手牌 / 别的牌那两条照旧绿）
- [x] 4.4 已知覆盖缺口：**观星那半 `placeBottom` 的调用测不出来**（占位的底堆是空的）⇒ 等「排列」询问类落地时一并钉
- [x] 4.5 停在待确认状态，等「提交」

## 5. 文档

- [x] 5.1 `architecture.md`：`OrderedZone` 行 + 新增 `placeTop` / `placeBottom` 行（含「1 = 顶」与「照 `accept` 的规矩搬」）；`setShortageHandler` 行补**已知偏离**；`getLegalTargets` 行补「加目标也要走这份名单」
- [x] 5.2 `sanguosha-rules`：新增 §9.33 诸葛亮（观星 / 空城 + 底本引文 + 分配占位 + 两条核对记载）；§9.8 的牌区接口补 `placeTop` / `placeBottom`
- [x] 5.3 `progress.md`：基线 1063、缺口表「置入牌堆顶 / 底」划掉、建议顺序改成「标准包 25 将全部落地」、本批条目（含 ⑧ 已知覆盖缺口）
