# Design

## Context

动机见 `proposal.md`。与本文相关的现状（读代码得出）：

- 内容侧书写环境在 `server/core/loader/init.lua`：`makeEnv(extra)` 给每个文件注入 `game` / `Card` / `Depends`（大写 = 只在加载期可用的环境函数）+ 一份标准库白名单；`ctx.env` **一轮装载建一份**，注入项在**每个文件加载前刷回**。
- `Class` 已经是内核的**全局**（`server/moe-kill.lua`：`Class = class.declare`），内容沙箱里拿不到（白名单外）。
- `Class` 的实例 **metatable 就是类表**（`tools/class.lua` 的 `M.new`：`setmetatable(tbl, class)`）⇒ 往类表上写方法，所有实例立刻可用，内核零改动。名字查找顺序：实例字段（`rawget`）→ `class.__index`（`class[k]` → `__getter[k]`）。
- `M.declare` 对**已存在的类名**会复用同一张类表并 `config:reset()`（那是给热重载用的路径）；`Config:reset` 只清 `extendsKeys`（从父类复制来的字段），**类表自身的字段不动**。
- 属性系统的类型面配方（重声明类 / 收窄 `---@field`）在 `architecture.md` §9.6，附两个坑（兜底签名、基类写全）。本变更加的方法**不需要**那套配方（实测见 D5）。

## Goals / Non-Goals

**Goals:**

- 包能按**内核的写法**给内核类加方法，让「规则侧提供的能力」以对象方法的形式给出（`user:distance(target)`）。
- 类型面**天然可用**（方法与参数直接标在实体函数上），不需要包另学一套形状。
- 把由此产生的语义（VM 内全局、`Extends` 连带、实例字段遮蔽）写成明文口径。

**Non-Goals:**

- 不做按局隔离（那是 `add-worker-mode`；落地后「VM 内全局」就是「这一局」）。
- 不做护栏 / 记账 / 回撤（见 D2、D3）。
- 不把「加方法」做成运行期能力（只在装载期开口子）。
- 不改既有内核 API 与内容包的其他书写环境。

## Decisions

### D1. 口子形状：注入内核同一个 `Class`（与内核同形）

| 备选 | 形状 | 评价 |
| --- | --- | --- |
| **A 注入内核的 `Class`** | `local M = Class 'Player'` + `function M:distance(to) ... end` | **选它**。与内核同形 —— mod 作者本来就在看内核代码，照抄即可；LuaDoc 自然可用（方法与参数标在实体函数上，不必重声明整个类，因而避开 §9.6 的两个坑）；改动面最小（只是把一个已有的全局放进注入项） |
| B 收口函数 | `Install('Player', 'distance', fn)` | 能加护栏、能记账、将来能换落点；但**记账唯一的作用（重装回撤）已因 D2 消失**，而多一层写法让包与内核两套形状 |
| C 挂在局上 | `game.classes.Player.distance = fn` | 类表是 **VM 级**的东西挂到**局**上会误导成「按局的」（与「环境对象就是 `game` 本身」的直觉冲突） |

选 A。注：`Class 'Player'` 走的是 `M.declare` 复用同一张类表并 `config:reset()` 的那条路径；装载期调用是安全的（此时还没有实例），但**写入侧只能靠"注册时就已经定了"这件事保证**，不额外做检测（D2）。

类型面的写法口径（用户 2026-09-28 定）：包里写 `---@class Player` 就够，**不用**写 `: Class.Base`；只有要用 `__getter` / `__setter` 时才把基类写全（那两个字段声明在 `Class.Base` 上，写全只是为了让 LuaLS 满意）。

### D2. 无生命周期管理

规则集**加载一次、之后不卸载**（一局一个 VM、master 在启动时传入清单 —— 见 `add-worker-mode` 的 D9 / D10），清理手段是**销毁 VM**。因此：

- **不记账、不回撤、不检测重装。** 装上去的方法活到 VM 销毁。
- 上一版设计里的「记账回撤」不再需要：它唯一要解决的就是「重装后旧包的方法还在」，而重装这件事本身被删掉了。
- 顺带消失的还有「闭包冻结在安装那一轮」这个问题（不再有"另一轮"）。

### D3. 护栏：内核不挡，只能靠文档提醒

不走收口函数就没有地方拦。只写三条提醒（进 `architecture.md` §9.6）：

- **别用 `__` 开头的名字**（`__getter` / `__setter` / `__config` / `__class__` / `__super` …）—— 那是框架私有前缀，写坏它会让整个类失效。
- **别与 `__getter` / `__setter` 同名** —— `Player.acting` 是派生属性，同名会把 `player.acting` 读成**函数本身**而不是派生值。
- **别给「实例已经有同名字段」的对象装同名方法** —— 实例字段会遮蔽类方法，方法永远读不到。

代价接受：VM 隔离是兜底（一个包写坏了，最坏情况是它那个 VM 里的这一局坏掉）。

### D4. `Extends` 的连带效应写进口径

装到 `Zone` 上的方法会被复制给 `SlotZone` / `OrderedZone`（`Config:init` 的复制条件是 `if not class[k] and not k:match '^__'`，且子类 `Config:init` 重跑时会重建）。这是**特性**（「所有牌区都有 xxx」），但必须写进口径，否则以后看到 `SlotZone` 上多出个方法会莫名。

### D5. 类型面：能推断的都不用写

写法与内核同形，所以**大部分注解都不用写**（这是选择 A 的实际收益：包不用另学一套形状）。

**实测（2026-09-28，在 `server/` 下放临时文件跑问题面板，两种写法都跑过）：**

| 写什么 | 结果 |
| --- | --- |
| `function M:distance(to)`（只标 `---@param to Player` + `---@return integer`） | 挂上 `Player` 类型，调用点 `player:distance(x)` 解析成功 |
| `---@class Player`（**不写** `: Class.Base`） | 同样通过 —— 内核那份 `---@class Player: Class.Base` 会被合并进来，基类关系没丢。写全基类的好处只是**不依赖这个隐含前提** |
| `M.__getter.xxx = function (self) … end` | 两种写法都不报错（同上，`__getter` 来自合并进来的 `Class.Base`） |
| 派生字段本身 | **必须声明**：`---@type boolean` + `M.xxx = nil`（内核的 `M.acting` 就是这个写法），否则读的地方报「未定义的属性/字段」—— 这与 `: Class.Base` 无关 |
| 函数返回值 | 只要给函数写了 LuaDoc，**每个返回值都要 `---@return`**，否则报「签名不完整。第 N 个返回值缺少 @return 注解」 |

- **不需要**包重声明整个 `---@class Player` 去收窄（那是属性系统那套配方，附两个坑，这里用不上）。
- 跨包给同一个类装同名方法时，类型面是「后写者胜」，与运行期「后装覆盖」一致 —— 只有一个包能声明得对，文档提醒一句即可。

### D6. 首个应用：`distance` 上 `Player`

`package/@基础/距离.lua` 改成：

```lua
---@class Player
local M = Class 'Player'

--- 距离（谁到谁）
---@param to Player
---@return integer
function M:distance(to)
    local value = self.game.desk:getDistance(self, to)
                + self:getAttr('进攻修正')
                + to:getAttr('防御修正')
    ...
end
```

**裸全局 `distance(from, to)` 去掉**（用户 2026-09-28 定），三个调用点改读 `user:distance(target)`。

顺带好处：方法版用 `self.game` 拿桌子，不再依赖闭包捕获的注入 `game` —— 这也是「能力搬进对象」的一个实际收益。

## Risks / Trade-offs

- [没有护栏 ⇒ 写坏 `__` 名字会破坏类框架] → 接受；D3 的文档提醒 + VM 隔离兜底。
- [覆盖内核方法会让**内核内部调用点**跟着变]（例如覆盖 `game:useCard`，`server/core/effect/ask-use-card.lua` 会走新实现）→ 这正是「覆盖基础规则」的目的；文档写明这是有意能力。
- [`Extends` 把方法复制到子类，可能超出预期] → D4 写进口径。
- [装到类上却被实例字段遮蔽 ⇒ 方法永远读不到] → D3 末条提醒。
- [「VM 内全局」语义下，同一个 VM 里多局会共享方法；用例之间也可能互相污染] → 一局一个 VM 落地前接受（`add-worker-mode`）；用例里装了方法就在自己用例内收尾。
- [与 `add-worker-mode` 的时序] → 现在落地是「全局」语义；那条落地后自动变按局，本变更其余部分不变。

## Migration Plan

1. 注入 `Class`（`loader/init.lua` 的注入项 + 刷回机制覆盖到它）。
2. 类型面与文档（`env-meta.lua`、`references/architecture.md` §9.6）。
3. 首个应用：`distance` 上 `Player`，三个调用点跟着改，去掉裸全局。
0. 回滚：删掉注入项即可；包侧改动只在那 4 个文件。
