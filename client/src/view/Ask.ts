import { html } from 'htm/preact';
import { useEffect, useState } from 'preact/hooks';
import type { Proto } from '../proto';
import type { Agent, Ask } from '../state/agent';
import { Card } from './Card';
import { answerOf, canSubmit, planText, toggle, type Selection } from './pick';
import { cardLabel } from './format';

/** 一条询问要摆些什么、交上去什么 */
export interface AskHandlers {
    /** 勾选变了 */
    onSelection(next: Selection): void;
    /** 交一包上去（App 负责记表现并回包） */
    onAnswer(result: unknown): void;
}

/** 询问条：按询问类型给控件 */
export function AskBar(props: { agent: Agent; ask: Ask; selection: Selection } & AskHandlers) {
    const { agent, ask, selection, onSelection, onAnswer } = props;
    const params = ask.params as any;
    const [left, setLeft] = useState(0);
    const [raw, setRaw] = useState('');

    // 限时倒计时（从收到询问那一刻算）
    useEffect(() => {
        const limit = (ask.params as any).timeLimit as number | undefined;
        if (!limit) {
            setLeft(0);
            return;
        }
        const until = Date.now() + limit * 1000;
        setLeft(Math.ceil(limit));
        const tick = window.setInterval(() => setLeft(Math.max(0, Math.ceil((until - Date.now()) / 1000))), 250);
        return () => window.clearInterval(tick);
    }, [ask.id]);

    const cancelable = params.cancelable !== false;
    const picked = selection.cards.length + selection.players.length + selection.heroes.length;
    const pickCards = (id: number) => {
        if (selection.viewAs !== null) {
            onSelection({ ...selection, cards: toggle(selection.cards, id) });
            return;
        }
        onSelection({ ...selection, option: id, players: [] });
    };
    const pickPlayers = (id: number) => onSelection({ ...selection, players: toggle(selection.players, id) });
    const chips = (ids: number[], pickedList: number[], onPick: (id: number) => void, asCard = false) => html`<div class="chips">
        ${ids.map((id) => html`<button
            key=${id}
            class=${pickedList.includes(id) ? 'on' : ''}
            onClick=${() => onPick(id)}
        >${asCard ? cardLabel(agent, id) : nameOf(agent, id)}</button>`)}
    </div>`;

    const body = () => {
        switch (ask.method) {
            case 'Ask.Choice':
                return html`<div class="chips">${(params.options as string[]).map((text, index) => html`<button
                    key=${index}
                    onClick=${() => onAnswer({ choice: index + 1 })}
                >${text}</button>`)}</div>`;
            case 'Ask.Select':
                return html`<div>
                    ${params.player ? html`<p class="hint">选玩家（${planText(params.player)}）</p>
                        ${chips(params.player.ids, selection.players, pickPlayers)}` : null}
                    ${params.card ? html`<p class="hint">选牌（${planText(params.card)}）</p>
                        ${chips(params.card.ids, selection.cards, (id) => onSelection({ ...selection, cards: toggle(selection.cards, id) }), true)}` : null}
                </div>`;
            case 'Ask.Use': {
                const options = (params.card ?? []) as Proto.CardWithPlan[];
                const views = (params.viewAs ?? []) as Proto.ViewAs[];
                const option = options.find((one) => one.id === selection.option);
                const view = selection.viewAs === null ? null : views[selection.viewAs];
                const target = view ? view.target : option;
                return html`<div>
                    <p class="hint">用哪张牌（点手牌，或者点这里）</p>
                    ${chips(options.map((one) => one.id), selection.option === null ? [] : [selection.option], pickCards, true)}
                    ${views.length > 0 ? html`<p class="hint">「视为」（用技能 / 装备把牌转成别的）</p>
                        <div class="chips">${views.map((one, index) => html`<button
                            key=${index}
                            class=${selection.viewAs === index ? 'on' : ''}
                            onClick=${() => onSelection({ ...selection, viewAs: index, option: null, cards: [], players: [] })}
                        >${viewLabel(agent, one)}</button>`)}</div>` : null}
                    ${view?.card ? html`<p class="hint">素材（${planText(view.card)}）</p>
                        ${chips(view.card.ids, selection.cards, (id) => onSelection({ ...selection, cards: toggle(selection.cards, id) }), true)}` : null}
                    ${target && target.max > 0 ? html`<p class="hint">给它选目标（${planText(target)}）</p>` : null}
                </div>`;
            }
            case 'Ask.UseSkill': {
                const skills = (params.skills ?? []) as Proto.SkillPlan[];
                const skill = skills.find((one) => one.id === selection.skill) ?? null;
                return html`<div>
                    <p class="hint">发动哪个技能</p>
                    <div class="chips">${skills.map((one) => html`<button
                        key=${one.id}
                        class=${selection.skill === one.id ? 'on' : ''}
                        onClick=${() => onSelection({ ...selection, skill: one.id, cards: [], players: [] })}
                    >${agent.skills.get(one.id)?.name ?? `技能 ${one.id}`}</button>`)}</div>
                    ${skill?.cards ? html`<p class="hint">要用的牌（${planText(skill.cards)}）</p>
                        ${chips(skill.cards.ids, selection.cards, (id) => onSelection({ ...selection, cards: toggle(selection.cards, id) }), true)}` : null}
                    ${skill?.targets ? html`<p class="hint">目标（${planText(skill.targets)}）</p>
                        ${chips(skill.targets.ids, selection.players, pickPlayers)}` : null}
                </div>`;
            }
            case 'Ask.Hero':
                return html`<div>
                    <p class="hint">选武将（${planText(params)}）</p>
                    <div class="chips">${((params.heroes ?? []) as string[]).map((name) => html`<button
                        key=${name}
                        class=${selection.heroes.includes(name) ? 'on' : ''}
                        onClick=${() => onSelection({
                            ...selection,
                            heroes: selection.heroes.includes(name)
                                ? selection.heroes.filter((one) => one !== name)
                                : [...selection.heroes, name],
                        })}
                    >${name}</button>`)}</div>
                </div>`;
            case 'Ask.Panel': {
                const panel = agent.panels.get(params.id as number);
                if (!panel) {
                    return html`<p class="hint">面板 ${params.id} 还没同步到（等下一条消息）</p>`;
                }
                return html`<div>
                    <p class="hint">${panel.name} · 选 ${planText(panel)}</p>
                    ${panel.rows.map((row, index) => html`<div class="chips" key=${index}>
                        ${row.title ? html`<span class="hint">${row.title}</span>` : null}
                        ${row.cards.map((id) => html`<${Card}
                            key=${id}
                            agent=${agent}
                            id=${id}
                            picked=${selection.cards.includes(id)}
                            off=${panel.disabled.includes(id)}
                            pick=${!panel.disabled.includes(id)}
                            onClick=${() => {
                                if (panel.disabled.includes(id)) {
                                    return;
                                }
                                onSelection({
                                    ...selection,
                                    cards: panel.max <= 1
                                        ? (selection.cards.includes(id) ? [] : [id])
                                        : toggle(selection.cards, id),
                                });
                            }}
                        />`)}
                    </div>`)}
                </div>`;
            }
            default:
                return html`<p class="hint">这条询问（${ask.method}）还没有控件</p>`;
        }
    };

    const needSubmit = ask.method !== 'Ask.Choice';
    return html`<div id="ask">
        <h3>${params.reason ?? ask.method}</h3>
        <p class="hint">
            ${ask.method}${left > 0 ? ` · 还剩 ${left} 秒` : ''}
            · 勾了 ${picked} 个${selection.option !== null ? ' + 一张牌' : ''}
        </p>
        ${body()}
        <div class="bar">
            ${needSubmit ? html`<button
                disabled=${!canSubmit(ask, selection)}
                onClick=${() => onAnswer(answerOf(ask, selection))}
            >确定</button>` : null}
            ${cancelable ? html`<button onClick=${() => onAnswer({})}>不选</button>` : null}
            <button onClick=${() => ask.cancel()}>取消</button>
            <span class="grow"></span>
            <input size="22" placeholder=${'{"usedViewAs":1,...}'} value=${raw} onInput=${(event: Event) => setRaw((event.target as HTMLInputElement).value)} />
            <button onClick=${() => onAnswer(parseRaw(raw, agent))}>手写发送</button>
        </div>
    </div>`;
}

/** 玩家名（认不出就给号） */
function nameOf(agent: Agent, id: number): string {
    return agent.playerLabel(id);
}

/** 一个「视为」选项怎么写 */
function viewLabel(agent: Agent, view: Proto.ViewAs): string {
    const source = view.sourceSkill !== undefined
        ? agent.skills.get(view.sourceSkill)?.name ?? `技能 ${view.sourceSkill}`
        : view.sourceCard === undefined ? null : cardLabel(agent, view.sourceCard);
    return source === null ? `视为${view.name}` : `${source} ⇒ ${view.name}`;
}

/** 手写那一包（写坏了就当空包） */
function parseRaw(raw: string, agent: Agent): unknown {
    try {
        return JSON.parse(raw || '{}');
    } catch (err) {
        agent.log(`手写的那包读不出来：${err instanceof Error ? err.message : String(err)}`);
        return {};
    }
}
