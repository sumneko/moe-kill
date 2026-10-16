import { html } from 'htm/preact';
import { useLayoutEffect, useRef } from 'preact/hooks';
import type { Agent } from '../state/agent';
import { Card } from './Card';

/** 一行最多摆几张 */
const PER_ROW = 12;
/** 手牌挪一下的时长（毫秒） */
const MOVE_MS = 260;
/** 新牌从右边多远处滑进来（画布坐标） */
const ENTER_X = 56;
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
    const rows: number[][] = [];
    for (let at = 0; at < props.ids.length; at += PER_ROW) {
        rows.push(props.ids.slice(at, at + PER_ROW));
    }
    const prev = useRef(new Map<number, { left: number; top: number }>());

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
