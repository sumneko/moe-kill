import { html } from 'htm/preact';
import type { Proto } from '../proto';
import type { Agent } from '../state/agent';
import { SUITS, cardFaceOf, isConverted, isRed } from './format';

/** 一张牌：标题（花色点数 + 名字）在上、图画在下 */
export function Card(props: {
    agent: Agent;
    id: number;
    /** 直接给牌面（桌面正中展示的那张：实体牌的号已经失效了） */
    face?: Proto.CardFace;
    /** 飞行动画的锚点名（不给就用牌号） */
    flyKey?: string;
    big?: boolean;
    glow?: boolean;
    pick?: boolean;
    picked?: boolean;
    off?: boolean;
    onClick?: () => void;
}) {
    const card = props.agent.cards.get(props.id);
    const face = props.face ?? cardFaceOf(props.agent, props.id);
    const suit = face?.suit ?? '';
    const cls = [
        'card',
        props.big ? 'big' : '',
        props.glow ? 'glow' : '',
        props.pick ? 'pick' : '',
        props.picked ? 'picked' : '',
        props.off ? 'off' : '',
        card?.face || card?.modifier || props.face ? '' : 'back',
    ].filter((one) => one.length > 0).join(' ');
    const description = props.agent.text(face?.name ?? '');
    const converted = isConverted(card) ? `转化自「${card?.face?.name ?? '背面'}」` : undefined;
    return html`<div
        class=${cls}
        data-fly=${props.flyKey ?? `card:${props.id}`}
        data-red=${isRed(suit) ? '' : undefined}
        title=${[description, converted].filter(Boolean).join('\n') || undefined}
        onClick=${props.onClick}
    >
        <div class="title">
            ${face ? html`<span>${SUITS[suit] ?? suit}${face.point ?? ''}</span>` : null}
            ${face?.name ? html`<span>${face.name}</span>` : null}
        </div>
        <div class="art"></div>
    </div>`;
}
