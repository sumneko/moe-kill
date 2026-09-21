# Design

## D1 为什么是「包」而不是「内核里的一个注入项」

`util` 的定位是「**给内容侧用的纯函数工具**」，与游戏规则无关 ⇒ 它属于**内容侧**（包），不属于内核。内核的注入面因此缩到三项：`game` / `Card` / `Depends`（前两项是这一局的资源，后两项是装载器机制 —— 这些才是内核非给不可的）。

名字用 `@tools`（英文）：与 `meta` 同理 —— **它不是规则内容**，不跟「包名用中文」的约定走。

## D2 实现要重写（包拿不到 `moe`）

原来 `env-util.lua` 里 `map` / `contains` 直接借内核的 `moe.util.map` / `moe.util.arrayHas`。包的环境只有标准库白名单（`table` / `string` / …）⇒ 三个函数都在 `@tools/工具.lua` 里**用内容侧写法重写**（纯函数、只依赖 `#` / 下标访问）：

- `filter(列表, 判定)` → 满足条件的元素组成新表；
- `map(列表, 变换)` → 对每个元素调 `变换(值, 下标)`，按下标写回（与内核 `moe.util.map` 的签名一致）；
- `contains(列表, 值)` → 线性查找。

## D3 类型面：`@tools/meta.lua`

```
---@class 工具.工具集
---@field filter fun(list: any[], predicate: fun(value: any): boolean): any[]
---@field map fun(list: any[], transform: fun(value: any, index: integer): any): any[]
---@field contains fun(list: any[], value: any): boolean

---@type 工具.工具集
util = nil
```

`---@type X` + 赋 `nil` 这种「声明一个全局变量的类型」的写法，内核 `env-meta.lua` 里本来就有（`---@type Game` + `game = nil`）⇒ 机制现成，只是**搬到了包自己的 `meta.lua`**（正是上一批 `add-package-meta` 立的那条路）。

## D4 代价：`util` 从「内核保证」变成「装了 `@tools` 才有」

- 正常来源（`./package/*`）下 `@tools` 是默认包，且逻辑名 `tools` 按字节序排在默认包最前（`t` < 中文包名的首字节）⇒ 规则包加载时 `util` 一定已就位 ⇒ 日常无感。
- 反例只有两种：明确排斥（`Depends { '!tools' }`），或来源里根本没有这个包（例如只有探针目录的测试局）。
- 于是 `server/test/rule/init.lua` 里那两条用 `util` 的用例改成 `sources = { 探针目录/*, './package/*' }` —— 顺带变成「测真的 `@tools`」，比原来测「内核注入的那份」更有意义。

## D5 遗留

「便捷函数」那件事（是否已受伤…）现在有了第二条路：**包之间直接写全局函数**（上一批开的通道）+ **`@tools` 这种工具包**（本批立的先例）。真正需要「共享的判定函数」时，按 `@tools` 的样子再开一个包即可，不必动内核。
