# Tasks

## 1. 规格增量（6 份）

- [x] 1.1 `specs/core-effect/spec.md`：REMOVED 7 条（效果与结算栈 / 压栈与退栈 / 结算栈的查询 / 让出与恢复 / 错误的传播 / 效果的完成信号与等待 / 即将生效与取消，各带 Reason + Migration）、MODIFIED 1 条（效果的父子关系）、ADDED 6 条（效果与记牌器 / 记牌器的查询 / 即将生效的时机 / 取消一次生效 / 效果的驱动与等待 / 失败的记录）
- [x] 1.2 `specs/core-damage/spec.md`：MODIFIED「造成伤害」——正文去掉结算栈、场景「伤害结算期间在栈上」的 THEN 改成"结束后仍留在记牌器里"，保留全部 6 个旧场景名
- [x] 1.3 `specs/core-play/spec.md`：MODIFIED 三条（使用入口 / 结算与牌的去向 / 逐目标生效），保留全部旧场景名（含「使用失败或抛错后栈恢复原状」，只改 THEN）
- [x] 1.4 `specs/core-response/spec.md`：MODIFIED「询问与应答」——把「进结算栈」改成「是一个效果（见 core-effect）」，场景名不变
- [x] 1.5 `specs/core-decision/spec.md`：MODIFIED「决策询问」——同上，场景名不变
- [x] 1.6 `specs/core-move/spec.md`：MODIFIED「把牌挪进某个牌区」——去掉「进结算栈」，场景「挪牌是一次效果」的 THEN 改成沿效果链读父效果

## 2. 主规格的 Purpose 手改（不走 delta）

- [x] 2.1 `openspec/specs/core-effect/spec.md` 的 Purpose 重写成「效果 = 任务驱动的一次结算 + 局上的只增记牌器」，并确认没有 `TBD` 占位
- [x] 2.2 `openspec/specs/core-response/spec.md` 的 Purpose 把「能从结算栈与效果链上查到」改成「能从效果链（父效果）上查到」
- [x] 2.3 `openspec/specs/core-damage/spec.md` 的 Purpose 通读一遍（正文提到的「本批只做改体力 + 时机」仍成立，如有栈相关措辞一并改掉）

## 3. 技能文档同步（5 处）

- [x] 3.1 `.agents/skills/moe-kill-dev/references/architecture.md` §12 的 `Effect` 行：`apply()` 的「记父（栈顶）→ 压入结算栈 → … → 退栈」改成「记父（当前正在结算的那个）→ 触发「即将生效」→ `settle()` → 由任务收尾」
- [x] 3.2 `.agents/skills/moe-kill-dev/SKILL.md` 目录表里「局…持有**这一局的规则内容**与**结算栈**」与「**效果**（`apply()` = 压栈 → 结算 → 退栈）」两处改成记牌器口径
- [x] 3.3 `.agents/skills/sanguosha-rules/SKILL.md` §7：把「结算走局的结算栈」「`game:getCurrentEffect()` 随时可查」「栈深上限 100 层」「结算栈已就位」等改成「效果由任务驱动、局上只有只增记牌器、嵌套深度上限 100 层、父效果可查」
- [x] 3.4 `.agents/skills/moe-kill-dev/references/code-style.md` §10 里「内核契约违反（校验不通过 / 结算栈乱序 / …）：记日志后原样上抛」这句按现状改（失败记 `.err`、交给错误处理器，不向调用方抛）
- [x] 3.5 `.agents/skills/moe-kill-dev/references/infrastructure.md` 命令速查里 `--test core.effect` 的注释「效果与结算栈套件（压退 / 嵌套 / 抛错也退 / 撤销函数 / 深度上限）」改成与套件实际用例一致的描述

## 4. 验收

- [x] 4.1 `git status` / `git diff --stat` 确认**只动了 markdown**：`server/**` 与 `.agents/skills/` 之外无改动，且没有任何 Lua 文件被改
- [x] 4.2 全仓 grep `pushEffect|getCurrentEffect|结算栈|:wait\(` —— 只剩 `openspec/changes/archive/**`（历史留档）、`setup-backend-infra/proposal.md` 的 Non-goals 一句（已报告用户，待定）与 `async-io.lua` 里 bee 自己的 `wait(ms)`；主规格与技能文档为 0
- [x] 4.3 `openspec validate --all --strict` 27/27 全绿；`core-effect` 归档后 7 条需求、无 TBD 占位、场景齐全
- [x] 4.4 `server/bin/moe-kill.exe --test` 全量 322 用例 0 失败
- [x] 4.5 归档：`openspec archive sync-effect-spec --yes`，归档后 `openspec validate --all --strict` 仍全绿

## 5. 交接给下一批（濒死与死亡）

- [x] 5.1 `sanguosha-rules/SKILL.md` 的「还没做」段后补一条「下一批（濒死与死亡）的前置条件已就位」（效果可嵌套、失败读 `.err`、入口自动「驱动 + 等」、死亡最小形状已有）
