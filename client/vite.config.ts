import { defineConfig } from 'vite';

export default defineConfig({
    // 前端只跟后端要一个 WebSocket；产物用相对路径，将来能从后端那个口直接发出去
    base: './',
    build: {
        target: 'es2022',
        outDir: 'dist',
    },
});
