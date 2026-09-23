# Design

## Decisions

### D1 每效果一块临时区，而不是「全局处理区 + 每个效果记一份名单」

方案二（保留全局 `处理` 区，效果上用标签袋记「我放进去的那些牌」）看似改动小，但账本是**平行**的：

- 每次牌被拿走 / 被别的东西挪走都要手改名单（【五谷丰登】今天就是这么写的，`table.without` 一句不能漏）；
- 漏了 ⇒ 收尾时会把已经不在手上的牌再送一次 `弃牌`（把别人的牌送走）；
- 同一张牌被两个效果各记一次（嵌套结算）⇒ 双份处置；
- 账本与 `card.zone` 是两个真相，调试时对不上。

方案一（每效果一块区）里**区域本身就是账本**：`tempZone:count()` / `list()` 永远是真相，没有第二份要同步的东西。附带两个好处：嵌套结算时一批牌一块区天然隔离；牌的位置信息（`card.zone`）能回答「这张牌在哪、属于哪次结算」。

选方案一。代价是每个效果可能多一个 `Zone` 对象 —— 用**懒建**消掉（只有真要放牌时才建，伤害 / 回复 / 纯询问零成本）。

### D2 懒建、进不了公共区表、没有区名

- `getTempZone()` 第一次被调用时才 `moe.zone.create()`；`tempZone` 字段可直接读（**无参读取用字段**，没建过就是空）。
- **不走 `game:createZone`**：公共区表是「按名字登记的公共牌区」，临时区是效果的一部分（**结构位置，不是区名**）。走公共区表会既撞名、又让快照里冒出一堆无名区。
- 因此内核**不需要认识「处理」这个名字** —— 与「内核不预设区名」的口径一致。

### D3 收尾时机 `'效果-收尾'`：内核发信号，规则决定去哪

- 触发点：这次效果的任务结完（`Task:onResolved` / `onRejected`）。取消与超时都走 `reject`（`cancel` = `reject(CANCELED)`、超时 = `reject(TIMEOUT)`）⇒ 一个 `onRejected` 全覆盖。
- 时机在 `resolve` 里**先于**叫醒等待者（`Task:resolve` 的顺序是 `_onResolved` → `resolveAwaitings`）⇒ 父效果 `await` 返回时，子效果**已经收过尾**。
- 收尾**必须**在所有子效果结完之后：`Task` 的完成点天然就是这个点。
- **内核不挪牌**：`'效果-收尾'` 只给「这次效果 + 它的临时区里还剩什么」；去向由规则定 —— `package/@基础/收尾.lua` 订阅后送 `弃牌`。这样「用掉的牌去哪」继续只由基础规则一处说了算（与既有「内核不知道弃牌堆叫什么」的口径一致）。
- 幂等：`Task` 的 `resolved` 标记保证收尾只发生一次。

### D4 `Effect` 搬到 `server/core/effect/effect.lua`

`effect/init.lua` 现在既是「模块入口」又装着基类，违反 `core/init.lua` 定下的形状（入口只做装载）。搬完：

- `server/core/effect/effect.lua` = `Effect` 基类；
- `server/core/effect/init.lua` = 一串 `include`（先 `core.effect.effect`，再各子文件）；
- `server/core/init.lua` 里那 10 行 `core.effect.*` 缩成 1 行 `include 'core.effect'`。

**为什么不放 `server/core/effect.lua`（与目录并列）**：那样 `core.effect` 这个名字会同时命中 `core/effect.lua` 与 `core/effect/init.lua`，`?.lua` 与 `?/init.lua` 谁在 `package.path` 前面决定加载哪个 —— 一个随时会踩的坑（`init.lua` 可能被整个跳过）。放目录内、名字写成 `core.effect.effect`，解析无歧义。

子文件里的 `require 'core.effect'` 一并改成 `require 'core.effect.effect'`（否则 `init.lua` → 子文件 → `require 'core.effect'` 会回到正在加载中的入口，成循环）。

### D5 暂不建 `moe.effect` 门面

`Effect` 没有工厂（`New 'Xxx'` 由各子类的 `moe.xxx.create` 负责），按既有约定「门面里只放工厂」⇒ 不建空容器。

### D7 批二：打出的牌归「发起那次结算」，不归询问自己

答复一到达，`AskCard` 的任务就 `task:resolve(答复)` 了（`AskCard:answer`）⇒ **询问自己的收尾早于它的 `'卡牌-答复'` / `'卡牌-答复后'` 时机**，所以打出的牌不能放进询问的临时区（收尾时那里还是空的，牌进去就永远留在那儿 —— 实测四条用例失败）。

它该归属**发起这次打出的那次结算**：`@基础/打出.lua` 在 `'卡牌-答复'` 里把牌放进 `ctx.parent:getTempZone()`（父 = 发起询问的那个效果，如【杀】对某个目标的 `CardEffect`），由父的收尾送 `弃牌` —— 时机上也正好是官方的「打出结算结束后置入弃牌堆」。没有父结算（装配侧 / 用例直接调 `askCard`）就直接送 `弃牌`。

别的牌不受这条影响：`'卡牌-结算前'`（用过的牌）与 `'判定-亮牌'`（判定牌）都发生在**自己那个效果正在结算**的时候，收尾一定在其后。
