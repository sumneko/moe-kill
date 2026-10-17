# 起前端 dev server：先清掉占着 5174 的旧实例，保证同时只有一个
# （配合 vite.config.ts 的 strictPort：真有第二个在跑，它会直接报错退出，而不是悄悄换端口）

$port = 5174
$conn = Get-NetTCPConnection -LocalPort $port -State Listen -ErrorAction SilentlyContinue | Select-Object -First 1
if ($conn) {
    $old = $conn.OwningProcess
    Write-Host "端口 $port 上还有旧实例（pid $old），先停掉它"
    Stop-Process -Id $old -Force -ErrorAction SilentlyContinue
    Start-Sleep -Milliseconds 400
}

Set-Location (Split-Path -Parent $PSScriptRoot)
npm --prefix client run dev
