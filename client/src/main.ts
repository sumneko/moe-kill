import './style.css';
import { Agent, type Ask } from './agent';
import type { Proto } from './proto';

/** 后端默认听这个口 */
const DEFAULT_PORT = 31415;

/** 花色符号 */
const SUITS: Record<string, string> = { 黑桃: '♠', 红桃: '♥', 梅花: '♣', 方块: '♦' };

const ESCAPES: Record<string, string> = {
    '&': '&amp;',
    '<': '&lt;',
    '>': '&gt;',
    '"': '&quot;',
    "'": '&#39;',
};

const agent = new Agent();

/** 这次询问勾了哪些（只跟当前这条询问有关，换一条就清） */
const picked = {
    player: new Set<number>(),
    card: new Set<number>(),
    hero: new Set<string>(),
};
let pickedFor = -1;

/** 取一个元素（拿不到就当场炸 —— 界面写错了要早发现） */
function el<T extends HTMLElement>(id: string): T {
    const found = document.getElementById(id);
    if (!found) {
        throw new Error(`界面上没有 #${id}`);
    }
    return found as T;
}

/** 转义（服务器与别人的名字都要过一遍） */
function esc(text: unknown): string {
    return String(text ?? '').replace(/[&<>"']/g, (char) => ESCAPES[char] ?? char);
}

function cardLabel(id: number): string {
    const face = agent.cards.get(id)?.face;
    if (!face) {
        return `#${id}（背面）`;
    }
    const suit = SUITS[face.suit ?? ''] ?? face.suit ?? '';
    return `#${id} ${face.name ?? '?'}${suit}${face.point ?? ''}`;
}

function customText(player: Proto.Player): string {
    const entries = Object.entries(player.custom ?? {});
    if (entries.length === 0) {
        return '';
    }
    return entries
        .map(([key, value]) => ` <span class="tag">${esc(key)}: ${esc(JSON.stringify(value))}</span>`)
        .join('');
}

function describePlan(plan: { min: number; max: number }): string {
    return plan.min === plan.max ? `要 ${plan.min} 个` : `要 ${plan.min}~${plan.max} 个`;
}

const app = el<HTMLDivElement>('app');
app.innerHTML = `
    <header>
        <label>服务器 <input id="url" size="26" /></label>
        <button data-act="connect">连接</button>
        <button data-act="disconnect">断开</button>
        <span id="status" class="muted"></span>
    </header>
    <header>
        <label>名字 <input id="name" size="12" /></label>
        <button data-act="join">加入</button>
        <button data-act="resync">重新同步</button>
    </header>
    <main>
        <section><h2>房间</h2><div id="room"></div></section>
        <section><h2>局面</h2><div id="table"></div></section>
        <section class="ask"><h2>询问</h2><div id="ask"></div></section>
    </main>
    <aside><h2>事件</h2><div id="log"></div></aside>
`;

el<HTMLInputElement>('url').value = `ws://${location.hostname || 'localhost'}:${DEFAULT_PORT}`;
el<HTMLInputElement>('name').value = '玩家';

function renderRoom(): string {
    const players = [...agent.players.values()].sort((left, right) => left.base.seat - right.base.seat);
    if (players.length === 0) {
        return '<p class="muted">还没人</p>';
    }
    const seats = agent.seats || players.length;
    const list = players
        .map((player) => `<li>${esc(player.base.userName)}（座位 ${player.base.seat}，号 ${player.base.id}）${customText(player)}</li>`)
        .join('');
    return `<p>${players.length} / ${seats} 人</p><ul>${list}</ul>`;
}

function renderTable(): string {
    const turn = agent.turnPlayer === null ? '——' : agent.playerLabel(agent.turnPlayer);
    const me = agent.me === null ? '——' : agent.playerLabel(agent.me);
    const skills = [...agent.skills.values()]
        .map((skill) => `<span class="tag">${esc(skill.name)}${skill.disabled ? '（禁用）' : ''}${skill.auto ? '（自动）' : ''}</span>`)
        .join('');

    const zones = new Map<string, number[]>();
    for (const card of agent.cards.values()) {
        const zone = card.zone ?? '';
        const ids = zones.get(zone) ?? [];
        ids.push(card.id);
        zones.set(zone, ids);
    }
    const zoneList = [...zones.entries()]
        .sort(([left], [right]) => (left < right ? -1 : 1))
        .map(([zone, ids]) => `<div class="zone"><b>${esc(zone || '(没区)')}</b> ${ids.map((id) => `<span class="card">${esc(cardLabel(id))}</span>`).join('')}</div>`)
        .join('');

    return `
        <p>回合：${esc(turn)} · 阶段：${esc(agent.phase ?? '——')} · 我是：${esc(me)}</p>
        ${agent.over ? `<p class="over">终局：${esc(agent.over.side)} —— ${esc(agent.over.reason)}</p>` : ''}
        <p>技能：${skills || '——'}</p>
        ${zoneList || '<p class="muted">盘面上一张牌都没有</p>'}
    `;
}

function chip(kind: string, id: number, text: string, on: boolean): string {
    return `<button class="chip${on ? ' on' : ''}" data-act="pick" data-kind="${kind}" data-id="${id}">${esc(text)}</button>`;
}

function selectBody(params: any): string {
    const parts: string[] = [];
    const playerPlan = params.player as { ids: number[]; min: number; max: number } | undefined;
    if (playerPlan) {
        const chips = playerPlan.ids.map((id) => chip('player', id, agent.playerLabel(id), picked.player.has(id))).join('');
        parts.push(`<p>选玩家（${describePlan(playerPlan)}）</p><div class="chips">${chips}</div>`);
    }
    const cardPlan = params.card as { ids: number[]; min: number; max: number } | undefined;
    if (cardPlan) {
        const chips = cardPlan.ids.map((id) => chip('card', id, cardLabel(id), picked.card.has(id))).join('');
        parts.push(`<p>选牌（${describePlan(cardPlan)}）</p><div class="chips">${chips}</div>`);
    }
    return parts.join('') || '<p class="muted">这次没给候选</p>';
}

function heroBody(params: any): string {
    const range = describePlan(params);
    const heroes = params.heroes as string[] | undefined;
    if (!heroes) {
        return `<p>候选没限定（${range}）—— 直接写武将全名，逗号分开</p><input id="hero-free" size="30" />`;
    }
    const chips = heroes
        .map((name) => `<button class="chip${picked.hero.has(name) ? ' on' : ''}" data-act="pick-hero" data-name="${esc(name)}">${esc(name)}</button>`)
        .join('');
    return `<p>选武将（${range}）</p><div class="chips">${chips}</div>`;
}

function rawBody(): string {
    return `<p>这条询问界面还没做专门的控件，直接写回应（照 <code>Proto.Result.*</code> 的形状）：</p>
        <textarea id="raw" rows="3" cols="48">{}</textarea>
        <div><button data-act="send-raw">发送</button></div>`;
}

function askBody(ask: Ask, params: any): string {
    switch (ask.method) {
        case 'Ask.Choice':
            return `<div class="chips">${(params.options as string[])
                .map((text, index) => `<button data-act="answer" data-json='${esc(JSON.stringify({ choice: index + 1 }))}'>${esc(text)}</button>`)
                .join('')}</div>`;
        case 'Ask.Select':
            return selectBody(params);
        case 'Ask.Hero':
            return heroBody(params);
        default:
            return rawBody();
    }
}

function askFoot(ask: Ask, params: any): string {
    const buttons: string[] = [];
    if (ask.method === 'Ask.Select' || ask.method === 'Ask.Hero') {
        buttons.push('<button data-act="submit-ask">确定</button>');
    }
    if (params.cancelable !== false) {
        buttons.push('<button data-act="pass-ask">不选</button>');
    }
    buttons.push('<button data-act="cancel-ask">取消</button>');
    return `<div class="bar">${buttons.join('')}</div>`;
}

function renderAsk(): string {
    const ask = agent.asks[0];
    if (!ask) {
        return '<p class="muted">没有在问什么</p>';
    }
    if (ask.id !== pickedFor) {
        pickedFor = ask.id;
        picked.player.clear();
        picked.card.clear();
        picked.hero.clear();
    }
    const params = ask.params as any;
    const limit = params.timeLimit ? ` · 限时 ${params.timeLimit} 秒` : '';
    return `<h3>${esc(params.reason ?? ask.method)}</h3>
        <p class="muted">${esc(ask.method)}${esc(limit)} · 我勾了 ${picked.player.size + picked.card.size + picked.hero.size} 个</p>
        ${askBody(ask, params)}
        ${askFoot(ask, params)}`;
}

function render(): void {
    el('status').textContent = agent.connected ? '已连接' : '没连上';
    el('room').innerHTML = renderRoom();
    el('table').innerHTML = renderTable();
    el('ask').innerHTML = renderAsk();
    el('log').innerHTML = agent.logs
        .slice(-80)
        .reverse()
        .map((line) => `<div>${esc(line)}</div>`)
        .join('');
}

function currentAsk(): Ask | null {
    return agent.asks[0] ?? null;
}

function pick(kind: string, id: number): void {
    const set = kind === 'player' ? picked.player : picked.card;
    if (set.has(id)) {
        set.delete(id);
    } else {
        set.add(id);
    }
    render();
}

function pickHero(name: string): void {
    if (picked.hero.has(name)) {
        picked.hero.delete(name);
    } else {
        picked.hero.add(name);
    }
    render();
}

function submitAsk(): void {
    const ask = currentAsk();
    if (!ask) {
        return;
    }
    const params = ask.params as any;
    if (ask.method === 'Ask.Hero') {
        if (!params.heroes) {
            const names = el<HTMLInputElement>('hero-free').value
                .split(/[,，]/)
                .map((one) => one.trim())
                .filter((one) => one !== '');
            ask.answer(names.length > 0 ? { heroes: names } : {});
            return;
        }
        ask.answer(picked.hero.size > 0 ? { heroes: [...picked.hero] } : {});
        return;
    }
    const result: Record<string, number[]> = {};
    if (params.player && picked.player.size > 0) {
        result.player = [...picked.player];
    }
    if (params.card && picked.card.size > 0) {
        result.card = [...picked.card];
    }
    ask.answer(result);
}

function sendRaw(): void {
    const ask = currentAsk();
    if (!ask) {
        return;
    }
    const text = el<HTMLTextAreaElement>('raw').value;
    try {
        ask.answer(JSON.parse(text));
    } catch (err) {
        agent.log(`这串回应不是 JSON：${err instanceof Error ? err.message : String(err)}`);
        render();
    }
}

async function connect(): Promise<void> {
    const url = el<HTMLInputElement>('url').value.trim();
    try {
        await agent.connect(url);
    } catch (err) {
        agent.log(`连不上：${err instanceof Error ? err.message : String(err)}`);
        render();
    }
}

async function run(action: () => Promise<void>): Promise<void> {
    try {
        await action();
    } catch (err) {
        agent.log(`做不了：${err instanceof Error ? err.message : String(err)}`);
        render();
    }
}

app.addEventListener('click', (event) => {
    const button = (event.target as HTMLElement).closest<HTMLElement>('button[data-act]');
    if (!button) {
        return;
    }
    switch (button.dataset.act) {
        case 'connect':
            void connect();
            break;
        case 'disconnect':
            agent.close();
            break;
        case 'join':
            void run(() => agent.join(el<HTMLInputElement>('name').value.trim()));
            break;
        case 'resync':
            void run(() => agent.resync());
            break;
        case 'pick': {
            const kind = button.dataset.kind ?? '';
            const id = Number(button.dataset.id ?? '0');
            pick(kind, id);
            break;
        }
        case 'pick-hero':
            pickHero(button.dataset.name ?? '');
            break;
        case 'answer':
            currentAsk()?.answer(JSON.parse(button.dataset.json ?? '{}'));
            break;
        case 'submit-ask':
            submitAsk();
            break;
        case 'pass-ask':
            currentAsk()?.answer({});
            break;
        case 'cancel-ask':
            currentAsk()?.cancel();
            break;
        case 'send-raw':
            sendRaw();
            break;
    }
});

for (const id of ['url', 'name']) {
    el<HTMLInputElement>(id).addEventListener('keydown', (event) => {
        if (event.key !== 'Enter') {
            return;
        }
        if (id === 'url') {
            void connect();
        } else {
            void run(() => agent.join(el<HTMLInputElement>('name').value.trim()));
        }
    });
}

agent.onChange = render;
render();
