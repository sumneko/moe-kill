import type { Proto } from '../proto';

/** 一条要播的表现事件（视图取走播一次就丢） */
export type GameEvent =
    /** 一张牌挪了地方（`id` 有值才画得出来；暗牌只更新状态不播） */
    | { kind: 'move'; move: Proto.CardMove }
    /** 体力变了（`delta` 正数是回血） */
    | { kind: 'health'; player: number; delta: number }
    /** 轮到他了 */
    | { kind: 'turn'; player: number }
    /** 进了阶段 */
    | { kind: 'phase'; player: number; name: string }
    /** 终局了 */
    | { kind: 'over'; side: string; reason: string }
    /** 有牌搬进公共处理区了（打出的 / 使用的那张，以及五谷丰登亮出来的） */
    | { kind: 'entered'; face: Proto.CardFace };
