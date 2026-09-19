# Spec Delta

## ADDED Requirements

### Requirement: 规则集执行环境的注入面

规则集文件 SHALL 在**注入的执行环境**里看到且只看到：`rule`（规则门面）与一份**标准库白名单**。`core`、`require`、`io`、`os` 一类 MUST NOT 被提供 —— 规则包不许直接调内核，也不可能开文件 / 起进程，也不该依赖项目内部的其它全局（`moe.util`、`moe.server` 等）。规则包需要的内核能力 SHALL 由 `rule` 上的工厂提供（`createAttributeSystem` / `createCard` / `createZone` / `createOrderedZone`），MUST NOT 由包自己构造内核对象。规则集文件里 SHALL 可以使用中文标识符。

#### Scenario: 规则集里能建对象

- **WHEN** 规则集文件里调用 `rule:createAttributeSystem()`、`rule:createCard('杀')`、`rule:createOrderedZone()`
- **THEN** 调用成功，拿到的是可用的属性系统 / 牌 / 牌区

#### Scenario: 拿不到内核门面

- **WHEN** 规则集文件里使用 `core`
- **THEN** 以错误结束（`core` 不在注入面里）

#### Scenario: 拿不到 require 与 io

- **WHEN** 规则集文件里使用 `require` 或 `io`
- **THEN** 以错误结束（它们不在注入面里）

#### Scenario: 规则集里可以写中文标识符

- **WHEN** 规则集文件里声明中文变量、函数名或表键
- **THEN** 解析与执行都正常
