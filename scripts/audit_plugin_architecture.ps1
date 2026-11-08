$ErrorActionPreference = "Stop"

Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host " AUDITORIA FORMAL DE ARQUITECTURA DE PLUGINS DE AUDIO     " -ForegroundColor Cyan
Write-Host "==========================================================" -ForegroundColor Cyan

# 1. VERIFICACION GATE-01: Cero Fugas de Dominio TEPUI
Write-Host "`n[1/4] Evaluando GATE-01: Zero TEPUI Domain Leaks..." -ForegroundColor Yellow
$domainKeywords = "(?i)(tepui|joropo|merengue|llanera|bandola|cumaco|quitiplas|furruco|folklore|gran[\s_]?sabana|cañ[oó]n[\s_]?del[\s_]?tepui|webview2_studio|cloudlicense|cloud_license|DEFAULT_CF_EDGE_WORKER_URL|(?<![a-z0-9])cuatro(?![a-z0-9]))"
$leaks = Get-ChildItem -Path "crates/base_plugin_*","crates/dsp_core","crates/studio_bus_comp","packages/base-plugin-ui" -Recurse -Include "*.rs","*.toml","*.tsx","*.ts" | Select-String -Pattern $domainKeywords

if ($leaks) {
    Write-Host "FAILED: Se detectaron fugas de dominio TEPUI en la plantilla:" -ForegroundColor Red
    $leaks | ForEach-Object { Write-Host " - $($_.Path):$($_.LineNumber) -> $($_.Line.Trim())" -ForegroundColor Red }
    exit 1
} else {
    Write-Host "PASS: Cero fugas de dominio detectadas en la infraestructura base." -ForegroundColor Green
}

# 2. VERIFICACION GATE-02: Seguridad en Tiempo Real (Allocations)
Write-Host "`n[2/4] Evaluando GATE-02: Real-Time Safety & Zero Allocations..." -ForegroundColor Yellow
cargo test -p base_plugin_core --features assert_process_allocs
if ($LASTEXITCODE -ne 0) {
    Write-Host "FAILED: Se detectaron asignaciones en el hilo de audio en tiempo real." -ForegroundColor Red
    exit 1
} else {
    Write-Host "PASS: Cero asignaciones dinamicas confirmadas en el camino del audio." -ForegroundColor Green
}

# 3. VERIFICACION GATE-03: Jerarquia DAG de Crates
Write-Host "`n[3/4] Evaluando GATE-03: Crate Boundaries & Clean DAG..." -ForegroundColor Yellow
$coreTree = (cargo tree -p base_plugin_core --format "{lib}") -join "`n"
if ($coreTree -match "\bwry\b" -or $coreTree -match "\btepui_synth\b" -or $coreTree -match "\bplugin_vst\b" -or $coreTree -match "\bai_bridge\b") {
    Write-Host "FAILED: base_plugin_core contiene dependencias ilegales hacia la GUI o el producto." -ForegroundColor Red
    exit 1
} else {
    Write-Host "PASS: Jerarquia DAG de crates estricta y limpia." -ForegroundColor Green
}

# 4. VERIFICACION GATE-04: Suite de Pruebas de Contrato Universal
Write-Host "`n[4/4] Evaluando GATE-04: Universal Contract Compliance..." -ForegroundColor Yellow
cargo test -p base_plugin_core --test certification_contract
if ($LASTEXITCODE -ne 0) {
    Write-Host "FAILED: La suite de contrato universal reporto fallos." -ForegroundColor Red
    exit 1
}
cargo test -p studio_bus_comp
if ($LASTEXITCODE -ne 0) {
    Write-Host "FAILED: El plugin derivado studio_bus_comp fallo la certificacion de contrato." -ForegroundColor Red
    exit 1
} else {
    Write-Host "PASS: Contrato universal certificado con exito en base_plugin_core y studio_bus_comp." -ForegroundColor Green
}

Write-Host "`n==========================================================" -ForegroundColor Green
Write-Host " CERTIFICACION EXITOSA: NIVEL ORO (TEMPLATE CERTIFIED GOLD) " -ForegroundColor Green
Write-Host "==========================================================" -ForegroundColor Green
