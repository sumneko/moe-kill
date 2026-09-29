# Tasks

## 1. 内核：Buff

- [x] 1.1 新增 `server/core/buff.lua`：`Buff : GCHost`（`name` / `owner`；`remove()` = `Delete(self)`；`__del` 里发 `'失去'`、从宿主摘掉）+ `BuffDef`（`:on('获得' / '失去', 回调)`）+ `moe.buff`；`server/core/init.lua` 装载
- [x] 1.2 `server/core/game.lua`：`declareBuff(名字)` / `getBuff(名字)`（只在加载期、按包存、同包重名报错、`resetContent` 清）—— 与 `declareCard` / `getCard` 同形
- [x] 1.3 加载器：注入全局 `Buff`（真环境 + 预解析 stub 环境两处）+ `env-meta.lua` 声明 `BuffDef`（照 `CardDef` 抄）
- [x] 1.4 `server/core/player.lua`：`buffs` 容器（引用在宿主身上）+ `addBuff(名字, 载荷?)`（挂上 → 发 `'获得'` → 返回实例）/ `getBuffs()` / `hasBuff(名字)`；类型注解
- [x] 1.5 **载荷（2026-09-30 补，用户定「用第二个参数传进来」）**：`Buff.payload`（`any?`，内核只存不解释，`'获得'` 之前就位）+ `moe.buff.create` 透传；不做「读当前正在结算的效果」那种环境值
- [x] 1.6 用例（新 `server/test/core/buff.lua`）：挂上查得到 / 同名并存 / `remove` 幂等 / `bindGC` 的资源与订阅随失去撤销 / 「失去」时实例还在宿主身上且字段可读 / `getBuffs` 返回快照 / **载荷在获得时机就读得到 + 没给载荷时为空**
- [x] 1.7 全量 `server/bin/moe-kill.exe --test` 全绿 + 问题面板 information 及以上为 0

## 2. 文档

- [x] 2.1 `architecture.md`：对象清单加 `Buff` 一行（「生命周期归内容、资源与订阅靠 `bindGC` 记在 buff 上、与创建者解耦」）
- [x] 2.2 `progress.md` 记录；首个消费者指向 `add-qinggang-sword`
