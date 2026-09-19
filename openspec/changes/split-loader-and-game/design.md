# Design

## D1 判据：装载器与「一局」的生命周期不同

- **装载器**：无状态工具。一次调用 = 一次事务（建 vfs → 试跑 → 校验 → 清空 → 执行），调用结束不留东西。因此它是**模块**（`moe.loader.install(...)`）而不是类，也不该有「实例」。
- **局**：一局游戏的全部所有权 —— 桌子、随机源、公共牌区、规则内容（规则表 / 包顺序 / 包元信息 / 规则数值 / 时机注册 / 属性系统）。它是类（`Moe.Game`），实例之间互不影响。
- 于是「`rule` 与 `room` 互指」这种补丁式关系消失：包手里的 `game` **就是**那一局。

## D2 装载器往局里写什么（耦合边界）

装载器要把装好的内容放进局里，边界如下（都写成**公开字段**，不额外造写入面 —— 与「不要过度防御」一致）：

| 装载器写的 | 说明 |
| --- | --- |
| `game.cards` / `game.packages` | 规则表（包名 → 裸名 → 定义）与包的加载顺序 |
| `game.meta` | 包元信息（预解析产物） |
| `game.loadedFiles` | 本次执行过的文件（按执行完成顺序，`install` 也把它作为返回值给出） |
| `game.loading` | **加载期上下文**（见 D3） |

局提供的两个写入入口（避免装载器去动「怎么恢复初始状态」这类知识）：

- `game:resetContent()`：清空规则内容（规则表 / 包顺序 / 元信息 / 规则数值 / 时机注册 / 属性系统 / 加载结果），**不动**桌子、随机源与牌区。清空重载前调用。
- `game:declareCard(name)`：登记一条内容定义（把 `Card '杀'` 的声明落到规则表上），内部校验「只能在加载期」「名字不含 `.`」「同包不重复」，并返回定义对象。

其余内容（规则数值、时机注册、属性系统）由包通过 `game:setValue` / `game:on` / `game:getAttributeSystem` 写，装载器不插手。

## D3 包内作用域与加载期上下文

「包内裸名先取本包」需要知道**当前在哪个文件**。它是加载期状态，但查询发生在 `game:getCard` 上，所以装载器把本次加载的上下文挂到局上（`game.loading`，装完置空），`game:getCard` 读 `game.loading.current` 推出所属包。这样：

- 加载期：包内优先 ✓（与现状一致）
- 运行期：`game.loading` 为 nil ⇒ 直接按包顺序路由 ✓（与现状一致）

`Card` / `Depends` 是**装载器构造的闭包**（闭包捕获局与本次上下文），只存在于本轮文件的执行环境里；加载结束后再调（例如从回调里）会被上下文状态挡下来并报「只能在加载规则集时声明」。

## D4 为什么环境函数用 PascalCase

`Card` / `Depends` 是框架入口（与既有的 `Class` / `New` / `Extends` 同类），`game` 是环境给的对象（与 `moe` 同类）。除了「一眼区分加载期 DSL 与普通 API」，更实际的理由是**防遮蔽**：包文件里写 `local card = game:createCard('杀')` 非常自然，小写入口一遮就没了。已写进 `code-style.md` 第 8 节。

## D5 文件与类型名

| 现在 | 改后 |
| --- | --- |
| `server/core/rule/init.lua`（装载 + 内容状态） | 拆成 `server/core/loader/init.lua`（装载）与 `server/core/game.lua`（内容状态 + 场地职责） |
| `server/core/rule/vfs.lua` · `preparse.lua` · `env-meta.lua` | `server/core/loader/{vfs,preparse,env-meta}.lua` |
| `server/core/room.lua` | 并进 `server/core/game.lua` |
| `Moe.Rule.*` | `Moe.Loader.*`（装载器内部类型）/ `Moe.Game`（局）/ `Moe.CardDef`（内容定义条目） |
| `Moe.Room` | `Moe.Game` |

`moe.loader` 与 `moe.game` 与其它内核模块一样走 `includeCore`（热重载集合）。

## D6 改名与注解规范化的做法

`rule:` / `rule.` / `moe.rule` / `moe.room` 约 300 处（含测试探针字符串里的写法）是**机械替换**：先用脚本做 token 替换（`rule.` → `game.` 等），再逐文件 review diff 并跑测试；`moe.rule.create` 这类要按语义分派到 `moe.game.create` 或 `moe.loader.install`，手工处理。类型侧可选注解（26 处，`number?` → `? number`）同批规范，`server/tools/` 里照搬来的文件**不动**。

## 已知小瑕疵

`hot-reload` 里那条场景名「规则实例跨重载照常可用」保留原名（OpenSpec 的 MODIFIED 块不允许改场景名，改名要整条 REMOVE + ADD，不值得），只把正文改成「局」。等哪天这条需求本身要重写时再一并收拾。

## 被否掉的方案

- **保留 `rule` 类，只把 `room` 并进去**：`rule` 与装载器仍然混在一起，`depends` 也仍然挂在对象上。
- **装载器做成类（每个局一个实例）**：装载器没有跨调用状态，做实例只是多一层壳；来源与清单记在**局**上（`game.sources` / `game.list`），重装时复用。
- **给局加一层写入面（`game:addDefinition` / `game:setMeta` …）**：装载器也是「自己人」，把表定义成公开字段直接写，比造一堆只有装载器用的写入方法简单。
- **环境函数小写**：见 D4 的遮蔽理由。
