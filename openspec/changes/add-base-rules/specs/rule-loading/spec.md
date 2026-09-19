# Spec Delta

## ADDED Requirements

### Requirement: 规则集执行环境的注入面

规则集文件 SHALL 在**注入的执行环境**里看到且只看到：`rule`（规则门面）、`core`（内核门面）与一份**标准库白名单**。`require`、`io`、`os` 一类 MUST NOT 被提供 —— 规则集是内容与规则，不该具备开文件 / 起进程的能力，也不该依赖项目内部的其它全局（`moe.util`、`moe.server` 等）。规则集文件里 SHALL 可以使用中文标识符。

#### Scenario: 规则集里能调内核

- **WHEN** 规则集文件里调用 `core.zone.create()`、`core.card.create()` 这类内核接口
- **THEN** 调用成功（内核能力对规则集可见）

#### Scenario: 拿不到 require 与 io

- **WHEN** 规则集文件里使用 `require` 或 `io`
- **THEN** 以错误结束（它们不在注入面里）

#### Scenario: 规则集里可以写中文标识符

- **WHEN** 规则集文件里声明中文变量、函数名或表键
- **THEN** 解析与执行都正常
