import { html } from 'htm/preact';
import type { Agent } from '../state/agent';
import { EQUIP_ZONES, SUITS, cardFaceOf, isRed } from './format';

/** 装备的临时图标（将来换成图） */
const EQUIP_ICON: Record<string, string> = { 武器: '⚔️', 防具: '🛡️', 进攻马: '🐎', 防御马: '🐴' };

/** 装备条：**四个槽位固定**（空槽完全透明地占位）—— 牌飞行时要落到「某一个装备栏」上，位置不能随有几件而漂 */
export function EquipList(props: {
    agent: Agent;
    /** 这个装备条属于哪个玩家（落点的 `zone` 要用 `名字#他`） */
    owner: number;
    equip: Map<string, number[]>;
    /** 选中的（只给「我的」装备条） */
    picked?: number[];
    /** 这次询问能点的牌；未传 = 别人的装备（纯展示）、`null` = 没询问、数组 = 候选 */
    cand?: number[] | null;
    onPick?: (id: number) => void;
}) {
    return html`${EQUIP_ZONES.map((name) => {
        const id = (props.equip.get(name) ?? [])[0];
        const fly = `zone:${name}#${props.owner}`;
        if (id === undefined) {
            return html`<div class="equip empty" key=${name} data-fly=${fly}>
                <span class="slot">${EQUIP_ICON[name] ?? ''}</span>
                <span class="name"></span>
                <span class="suit"></span>
                <span class="point"></span>
            </div>`;
        }
        const face = cardFaceOf(props.agent, id);
        const pick = props.cand?.includes(id) ?? false;
        const cls = [
            'equip',
            pick ? 'pick' : '',
            props.picked?.includes(id) ? 'picked' : '',
            props.cand && !pick ? 'off' : '',
        ].filter((one) => one.length > 0).join(' ');
        return html`<div class=${cls} key=${name} data-fly=${fly} data-red=${isRed(face?.suit) ? '' : undefined}
            onClick=${pick && props.onPick ? () => props.onPick?.(id) : undefined}>
            <span class="slot">${EQUIP_ICON[name] ?? ''}</span>
            <span class="name">${face?.name ?? ''}</span>
            <span class="suit">${SUITS[face?.suit ?? ''] ?? ''}</span>
            <span class="point">${face?.point ?? ''}</span>
        </div>`;
    })}`;
}
