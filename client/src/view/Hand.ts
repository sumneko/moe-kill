import { html } from 'htm/preact';
import type { Agent } from '../state/agent';
import { Card } from './Card';

/** 一行最多摆几张 */
const PER_ROW = 12;

/** 我的手牌：每行 12 张；行序 = 新牌在上、旧牌在下（下面那行压住上面那行） */
export function Hand(props: {
    agent: Agent;
    ids: number[];
    picked: number[];
    pickable: boolean;
    onPick: (id: number) => void;
}) {
    const rows: number[][] = [];
    for (let at = 0; at < props.ids.length; at += PER_ROW) {
        rows.push(props.ids.slice(at, at + PER_ROW));
    }
    return html`<div id="meHand">
        ${rows.reverse().map((row, index) => html`<div class="row" key=${index}>
            ${row.map((id) => html`<${Card}
                key=${id}
                agent=${props.agent}
                id=${id}
                pick=${props.pickable}
                picked=${props.picked.includes(id)}
                onClick=${props.pickable ? () => props.onPick(id) : undefined}
            />`)}
        </div>`)}
    </div>`;
}
