# Çoklu oturum E2E — token harcar; günlük CI'da ÇALIŞTIRMA.
# Önkoşul: telefon USB, adb, PC extension bağlı, uygulama önce bir kez bağlanmış.

param(
    [string]$Device = ""
)

$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot
Set-Location $root

if (-not $Device) {
    $Device = (adb devices | Select-String "device$" | Select-Object -First 1)
    if ($Device) { $Device = ($Device -split "\s+")[0] }
}
if (-not $Device) {
    Write-Error "ADB cihaz yok. adb devices ile kontrol et."
}

Write-Host "E2E cihaz: $Device (RUN_E2E=true, ~5 dk, 2 agent sorusu)" -ForegroundColor Cyan

flutter test integration_test/multi_session_e2e_test.dart `
    -d $Device `
    --dart-define=RUN_E2E=true

if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

Write-Host "E2E bitti — başta PC geçmişi temizlendi; test oturumları silinmez." -ForegroundColor Green
