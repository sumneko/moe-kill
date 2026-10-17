import { defineConfig } from 'vite';

export default defineConfig({
    // 前端只跟后端要一个 WebSocket；产物用相对路径，将来能从后端那个口直接发出去
    base: './',
    // 端口写死：同时开第二个实例会直接报错退出，而不是悄悄换到 5174 去跟第一个抢缓存
    server: {
        port: 5174,
        strictPort: true,
    },
    build: {
        target: 'es2022',
        outDir: 'dist',
    },
});
