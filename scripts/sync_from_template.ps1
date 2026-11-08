param(
    [string]$RemoteName = "template",
    [string]$RemoteUrl = "https://github.com/davidcastilloc/rust-webview-vst-template.git",
    [string]$Branch = "main"
)

$ErrorActionPreference = "Stop"

Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host " OPEN AUDIO STACK - SINCRONIZADOR DE SDK UPSTREAM         " -ForegroundColor Cyan
Write-Host "==========================================================" -ForegroundColor Cyan

# 1. Asegurar que el remote 'template' este registrado
$remotes = git remote
if ($remotes -notcontains $RemoteName) {
    Write-Host "[1/4] Registrando remote '$RemoteName' -> $RemoteUrl..." -ForegroundColor Yellow
    git remote add $RemoteName $RemoteUrl
} else {
    Write-Host "[1/4] Remote '$RemoteName' detectado." -ForegroundColor Green
}

# 2. Fetch de la ultima version del SDK
Write-Host "[2/4] Descargando mejoras del SDK desde $RemoteName/$Branch..." -ForegroundColor Yellow
git fetch $RemoteName $Branch

# 3. Sincronizar unicamente las capas compartidas del SDK (sin tocar crates de plugins propios)
$sdkPaths = @(
    "crates/dsp_core",
    "crates/base_plugin_core",
    "crates/base_plugin_standalone",
    "crates/base_plugin_webview",
    "crates/xtask",
    "packages/base-plugin-ui",
    "llms.txt",
    "llms-full.txt"
)

Write-Host "[3/4] Actualizando crates compartidos del SDK ($($sdkPaths -join ', '))..." -ForegroundColor Yellow
git checkout "$RemoteName/$Branch" -- $sdkPaths

# 4. Ejecutar las 4 Compuertas de Certificacion
Write-Host "[4/4] Ejecutando auditoria de 4 compuertas post-sincronizacion..." -ForegroundColor Yellow
powershell -ExecutionPolicy Bypass -File scripts/audit_plugin_architecture.ps1
if ($LASTEXITCODE -ne 0) {
    Write-Host "FAILED: La auditoria de arquitectura reporto un fallo tras sincronizar el SDK." -ForegroundColor Red
    exit 1
}

Write-Host "`n==========================================================" -ForegroundColor Green
Write-Host " SDK SINCRONIZADO Y CERTIFICADO CON EXITO                 " -ForegroundColor Green
Write-Host "==========================================================" -ForegroundColor Green
