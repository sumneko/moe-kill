import { WsLink } from './link';

/** 线上的一条错误（`Proto.Error` 那一族：`code` + `message`） */
export class RpcError extends Error {
    readonly code: number;

    constructor(code: number, message: string) {
        super(message);
        this.code = code;
    }
}

/** 服务端请求的处理器：返回值当结果回包，抛 `RpcError` 当错误回包 */
export type RequestHandler = (params: any, id: number) => unknown | Promise<unknown>;

/** 通知的处理器 */
export type NotifyHandler = (params: any) => void;

/** 长度头几个字节（跟后端 `client.lua` 一致） */
const HEADER_SIZE = 4;

const encoder = new TextEncoder();
const decoder = new TextDecoder();

/** 一条连接上的 JSON-RPC 端点：4 字节长度头 + 正文，收到请求就交给处理器 */
export class Rpc {
    private readonly link: WsLink;
    private readonly pendings = new Map<number, { resolve: (result: any) => void; reject: (err: unknown) => void }>();
    private readonly requests = new Map<string, RequestHandler>();
    private readonly notifications = new Map<string, NotifyHandler>();
    private nextId = 1;
    private closed = false;

    constructor(link: WsLink) {
        this.link = link;
    }

    /** 起读循环（连接断了就把在等的请求全部收掉） */
    async run(): Promise<void> {
        try {
            for (;;) {
                const head = await this.link.read(HEADER_SIZE);
                const length = new DataView(head.buffer).getUint32(0);
                const body = await this.link.read(length);
                this.handle(JSON.parse(decoder.decode(body)) as any);
            }
        } catch (err) {
            this.close(err instanceof Error ? err.message : String(err));
        }
    }

    /** 订一个服务端请求（返回撤销订阅的函数） */
    onRequest(method: string, handler: RequestHandler): () => void {
        this.requests.set(method, handler);
        return () => {
            this.requests.delete(method);
        };
    }

    /** 订一条通知（返回撤销订阅的函数） */
    onNotify(method: string, handler: NotifyHandler): () => void {
        this.notifications.set(method, handler);
        return () => {
            this.notifications.delete(method);
        };
    }

    /** 发一条通知 */
    notify(method: string, params: unknown): void {
        this.sendMessage({ jsonrpc: '2.0', method, params });
    }

    /** 发一个请求并等回包（失败抛 `RpcError`） */
    request(method: string, params: unknown): Promise<any> {
        const id = this.nextId++;
        return new Promise((resolve, reject) => {
            this.pendings.set(id, { resolve, reject });
            this.sendMessage({ jsonrpc: '2.0', id, method, params });
        });
    }

    /** 关掉它 */
    close(reason: string): void {
        if (this.closed) {
            return;
        }
        this.closed = true;
        for (const pending of this.pendings.values()) {
            pending.reject(new RpcError(-32603, reason));
        }
        this.pendings.clear();
        this.link.close(reason);
    }

    private handle(message: any): void {
        if (typeof message?.method === 'string') {
            const params = message.params ?? {};
            if (message.id === undefined || message.id === null) {
                this.notifications.get(message.method)?.(params);
            } else {
                void this.dispatch(message.id, message.method, params);
            }
            return;
        }
        const pending = typeof message?.id === 'number' ? this.pendings.get(message.id) : undefined;
        if (!pending) {
            return;
        }
        this.pendings.delete(message.id);
        if (message.error) {
            pending.reject(new RpcError(message.error.code, message.error.message));
        } else {
            pending.resolve(message.result);
        }
    }

    private async dispatch(id: number, method: string, params: any): Promise<void> {
        const handler = this.requests.get(method);
        if (!handler) {
            this.sendMessage({ jsonrpc: '2.0', id, error: { code: -32601, message: `没有这个方法：${method}` } });
            return;
        }
        try {
            const result = await handler(params, id);
            this.sendMessage({ jsonrpc: '2.0', id, result: result ?? null });
        } catch (err) {
            if (err instanceof RpcError) {
                this.sendMessage({ jsonrpc: '2.0', id, error: { code: err.code, message: err.message } });
            } else {
                this.sendMessage({
                    jsonrpc: '2.0',
                    id,
                    error: { code: -32603, message: err instanceof Error ? err.message : String(err) },
                });
            }
        }
    }

    private sendMessage(message: unknown): void {
        if (this.closed) {
            return;
        }
        const body = encoder.encode(JSON.stringify(message));
        const frame = new ArrayBuffer(HEADER_SIZE + body.length);
        new DataView(frame).setUint32(0, body.length);
        new Uint8Array(frame).set(body, HEADER_SIZE);
        this.link.send(frame);
    }
}
