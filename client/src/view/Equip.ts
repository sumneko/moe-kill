import { html } from 'htm/preact';
import type { Agent } from '../state/agent';
import { EQUIP_ZONES, SUITS, cardFaceOf, isRed } from './format';

/** 装备的临时图标（将来换成图） */
const EQUIP_ICON: Record<string, string> = { 武器: '⚔️', 防具: '🛡️', 进攻马: '🐎', 防御马: '🐴' };

/** 装备条：图标 / 名字 / 花色 / 点数 四列对齐；一件都没有就写「无装备」 */
export function EquipList(props: { agent: Agent; equip: Map<string, number[]> }) {
    const rows = EQUIP_ZONES.flatMap((name) => (props.equip.get(name) ?? []).map((id) => ({ name, id })));
    if (rows.length === 0) {
        return html`<div class="equip none">无装备</div>`;
    }
    return html`${rows.map(({ name, id }) => {
        const face = cardFaceOf(props.agent, id);
        return html`<div class="equip" key=${id} data-red=${isRed(face?.suit) ? '' : undefined}>
            <span class="slot">${EQUIP_ICON[name] ?? ''}</span>
            <span class="name">${face?.name ?? ''}</span>
            <span class="suit">${SUITS[face?.suit ?? ''] ?? ''}</span>
            <span class="point">${face?.point ?? ''}</span>
        </div>`;
    })}`;
}
