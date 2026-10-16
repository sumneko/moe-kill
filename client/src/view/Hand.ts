import { html } from 'htm/preact';
import { useLayoutEffect, useMemo, useRef, useState } from 'preact/hooks';
import type { Agent } from '../state/agent';
import { Card } from './Card';

/** 一行最多摆几张 */
const PER_ROW = 12;
/** 手牌挪一下的时长（毫秒） */
const MOVE_MS = 260;
/** 新牌从右边多远处滑进来（画布坐标） */
const ENTER_X = 56;
/** 刚搬进手牌的先摭多久（毫秒）—— 与飞一张牌同时长，等它落地再冒出来 */
const HOLD_MS = 1000;
const EASING = 'cubic-bezier(.25, 0, .25, 1)';

/** 我的手牌：每行 12 张；行序 = 新牌在上、旧牌在下（下面那行压住上面那行） */
export function Hand(props: {
    agent: Agent;
    ids: number[];
    picked: number[];
    /** 这次询问能点的牌；`null` = 现在没有询问（既不置灰也点不动） */
    cand: number[] | null;
    onPick: (id: number) => void;
}) {
    const prev = useRef(new Map<number, { left: number; top: number }>());
    /** 见过的牌号（含正在摭着的）—— 判「这张是不是新来的」只看它 */
    const seen = useRef(new Set<number>());
    /** 刚搬进手牌、先别亮出来的那些 */
    const held = useRef(new Set<number>());
    /** 上一次亮着几张（0 = 这批是全量重建 / 开局发牌，不该摭） */
    const shownCount = useRef(0);
    const [tick, setTick] = useState(0);

    // 新到的牌先摭 1 秒：那会儿飞牌浮层还在路上，牌同时冒出来看着像重影
    // ⚠️ 要在渲染期就排除掉 —— 放 effect 里的话第一帧会先亮一下再藏
    const shown = useMemo(() => {
        const rebuild = shownCount.current === 0;
        for (const id of props.ids) {
            if (seen.current.has(id)) {
                continue;
            }
            seen.current.add(id);
            if (rebuild) {
                continue;
            }
            held.current.add(id);
            window.setTimeout(() => {
                held.current.delete(id);
                setTick((count) => count + 1);
            }, HOLD_MS);
        }
        const list = props.ids.filter((id) => !held.current.has(id));
        shownCount.current = list.length;
        return list;
    }, [props.ids, tick]);

    const rows: number[][] = [];
    for (let at = 0; at < shown.length; at += PER_ROW) {
        rows.push(shown.slice(at, at + PER_ROW));
    }

    // 位置变了的滑过去、新来的从右边滑进来（用布局坐标量，免得被「选中抬起」那点 transform 带偏）
    useLayoutEffect(() => {
        const next = new Map<number, { left: number; top: number }>();
        for (const el of document.querySelectorAll<HTMLElement>('#meHand [data-fly^="card:"]')) {
            const id = Number(el.dataset.fly?.slice('card:'.length));
            if (!Number.isFinite(id)) {
                continue;
            }
            const at = { left: el.offsetLeft, top: el.offsetTop };
            next.set(id, at);
            const before = prev.current.get(id);
            const dx = before ? before.left - at.left : ENTER_X;
            const dy = before ? before.top - at.top : 0;
            if (dx !== 0 || dy !== 0) {
                el.animate([
                    { transform: `translate(${dx}px, ${dy}px)`, opacity: before ? 1 : 0 },
                    { transform: 'none', opacity: 1 },
                ], { duration: MOVE_MS, easing: EASING });
            }
        }
        prev.current = next;
    });
    return html`<div id="meHand">
        ${rows.reverse().map((row, index) => html`<div class="row" key=${index}>
            ${row.map((id) => {
                const pick = props.cand?.includes(id) ?? false;
                return html`<${Card}
                    key=${id}
                    agent=${props.agent}
                    id=${id}
                    pick=${pick}
                    picked=${props.picked.includes(id)}
                    off=${props.cand ? !pick : false}
                    onClick=${pick ? () => props.onPick(id) : undefined}
                />`;
            })}
        </div>`)}
    </div>`;
}
