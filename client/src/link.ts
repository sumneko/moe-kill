/** 一条 WebSocket 连接：当字节流用（浏览器给的是「一条条消息」，这里拼起来，切帧归上层） */
export class WsLink {
    private readonly socket: WebSocket;
    private readonly chunks: Uint8Array[] = [];
    private size = 0;
    private waiter: (() => void) | null = null;
    private closed = false;
    private reason = '';

    constructor(url: string) {
        this.socket = new WebSocket(url);
        this.socket.binaryType = 'arraybuffer';
        this.socket.addEventListener('message', (event) => {
            const data = event.data as unknown;
            if (typeof data === 'string') {
                // 这条通道是字节流，服务端应当只发二进制
                this.fail('服务端发来了文本帧');
                return;
            }
            this.push(new Uint8Array(data as ArrayBuffer));
        });
        this.socket.addEventListener('close', () => {
            this.fail(this.reason || '连接已关闭');
        });
        this.socket.addEventListener('error', () => {
            this.fail('连接出错');
        });
    }

    /** 等连接建立 */
    open(): Promise<void> {
        if (this.socket.readyState === WebSocket.OPEN) {
            return Promise.resolve();
        }
        return new Promise((resolve, reject) => {
            this.socket.addEventListener('open', () => resolve(), { once: true });
            this.socket.addEventListener('close', () => reject(new Error('连不上')), { once: true });
        });
    }

    /** 发一帧（一帧就是一条 WebSocket 消息） */
    send(frame: ArrayBuffer): void {
        if (this.closed) {
            throw new Error(this.reason);
        }
        this.socket.send(frame);
    }

    /** 读满 `n` 个字节（不够就等） */
    async read(n: number): Promise<Uint8Array> {
        while (this.size < n) {
            if (this.closed) {
                throw new Error(this.reason);
            }
            await new Promise<void>((resolve) => {
                this.waiter = resolve;
            });
        }
        return this.take(n);
    }

    /** 关掉它 */
    close(reason = '客户端不玩了'): void {
        this.reason = reason;
        if (this.socket.readyState === WebSocket.OPEN) {
            this.socket.close(1000, reason);
        }
        this.fail(reason);
    }

    private push(chunk: Uint8Array): void {
        if (chunk.length === 0) {
            return;
        }
        this.chunks.push(chunk);
        this.size += chunk.length;
        this.wake();
    }

    private take(n: number): Uint8Array {
        const out = new Uint8Array(n);
        let filled = 0;
        while (filled < n) {
            const chunk = this.chunks[0];
            const need = n - filled;
            if (chunk.length <= need) {
                out.set(chunk, filled);
                filled += chunk.length;
                this.chunks.shift();
            } else {
                out.set(chunk.subarray(0, need), filled);
                this.chunks[0] = chunk.subarray(need);
                filled += need;
            }
        }
        this.size -= n;
        return out;
    }

    private fail(reason: string): void {
        this.closed = true;
        this.reason = reason;
        this.wake();
    }

    private wake(): void {
        const waiter = this.waiter;
        this.waiter = null;
        waiter?.();
    }
}
