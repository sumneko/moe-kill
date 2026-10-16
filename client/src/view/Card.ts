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
    /** 能拖（面板摆位） */
    draggable?: boolean;
    /** 外部给的定位样式（处理区那条牌列用） */
    style?: string;
    onClick?: () => void;
    onDragStart?: () => void;
    onDrop?: (event: DragEvent) => void;
}) {
    // 只给了牌面的（处理区那条尾巴）：不查账 —— 那些号跟账里不是一套
    const card = props.face ? undefined : props.agent.cards.get(props.id);
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
        style=${props.style}
        data-fly=${props.flyKey ?? `card:${props.id}`}
        data-red=${isRed(suit) ? '' : undefined}
        title=${[description, converted].filter(Boolean).join('\n') || undefined}
        draggable=${props.draggable ? true : undefined}
        onClick=${props.onClick}
        onDragStart=${props.onDragStart}
        onDrop=${props.onDrop}
    >
        <div class="title">
            ${face ? html`<span>${SUITS[suit] ?? suit}${face.point ?? ''}</span>` : null}
            ${face?.name ? html`<span>${face.name}</span>` : null}
        </div>
        <div class="art"></div>
    </div>`;
}
