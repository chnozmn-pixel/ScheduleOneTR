<#
    Schedule I Turkce Yama - tek satirlik web kurulumu.

    Kullanim (PowerShell penceresinde):
        irm https://chnozmn-pixel.github.io/ScheduleOneTR/kur.ps1 | iex

    ya da dogrudan depodan:
        irm https://raw.githubusercontent.com/chnozmn-pixel/ScheduleOneTR/main/kur.ps1 | iex

    Yaptigi is:
      1. Depoyu zip olarak indirir
      2. %LOCALAPPDATA%\ScheduleOneTR icine acar
      3. tools\install.ps1'i calistirir

    Kurulum klasoru sabit: ikinci kez calistirdiginda indirilen .NET SDK
    ve derlenmis mod yerinde kalir, islem saniyeler surer.

    Bu betik yonetici yetkisi istemez ve sisteme hicbir sey yazmaz;
    her sey kendi klasorunde ve oyun klasorunde kalir.
#>
[CmdletBinding()]
param(
    [string]$Branch = 'main',
    [string]$GameDir,
    # Oyun guncellendikten sonra: modu bastan derler
    [switch]$Force
)

$ErrorActionPreference = 'Stop'

$REPO    = 'chnozmn-pixel/ScheduleOneTR'
$homeDir = Join-Path $env:LOCALAPPDATA 'ScheduleOneTR'

function Say([string]$t, [string]$c = 'Gray') { Write-Host "  $t" -ForegroundColor $c }

Write-Host ""
Write-Host "  Schedule I - Turkce Yama" -ForegroundColor White
Write-Host "  ========================" -ForegroundColor White
Write-Host ""

# PowerShell 5.1 varsayilan olarak eski TLS kullaniyor, GitHub reddediyor
[Net.ServicePointManager]::SecurityProtocol =
    [Net.SecurityProtocolType]::Tls12 -bor [Net.ServicePointManager]::SecurityProtocol

# --------------------------------------------------------------- indirme

$zipUrl = "https://github.com/$REPO/archive/refs/heads/$Branch.zip"
$tmpZip = Join-Path ([IO.Path]::GetTempPath()) "ScheduleOneTR_$Branch.zip"
$tmpDir = Join-Path ([IO.Path]::GetTempPath()) "ScheduleOneTR_ac"

Say "Yama dosyalari indiriliyor..." 'Cyan'
Say "  kaynak: $zipUrl" 'DarkGray'

try {
    $oldProgress = $ProgressPreference
    $ProgressPreference = 'SilentlyContinue'   # ilerleme cubugu indirmeyi yavaslatiyor
    Invoke-WebRequest -Uri $zipUrl -OutFile $tmpZip -UseBasicParsing
    $ProgressPreference = $oldProgress
} catch {
    Write-Host ""
    Say "Indirilemedi: $($_.Exception.Message)" 'Red'
    Say "Internet baglantini kontrol edip tekrar dene." 'Yellow'
    return
}
Say ("  indirildi: {0:N0} KB" -f ((Get-Item $tmpZip).Length / 1KB)) 'DarkGray'

# ------------------------------------------------------------------ acma

if (Test-Path $tmpDir) { Remove-Item $tmpDir -Recurse -Force }
Expand-Archive -Path $tmpZip -DestinationPath $tmpDir -Force

# Zip tek bir "<depo>-<dal>" klasoru iceriyor
$inner = @(Get-ChildItem $tmpDir -Directory)[0]
if (-not $inner) {
    Say "Indirilen arsiv beklenen yapida degil." 'Red'
    return
}

# Kurulum klasoru sabit. Kaynak dosyalari tazeliyoruz ama .dotnet\ ve
# src\...\bin gibi uretilen seylere dokunmuyoruz: ikinci kurulumda
# 200 MB SDK ve derleme bastan yapilmasin.
Say "Hazirlaniyor: $homeDir" 'Cyan'
New-Item -ItemType Directory -Path $homeDir -Force | Out-Null
Copy-Item (Join-Path $inner.FullName '*') $homeDir -Recurse -Force

Remove-Item $tmpZip -Force -ErrorAction SilentlyContinue
Remove-Item $tmpDir -Recurse -Force -ErrorAction SilentlyContinue

# -------------------------------------------------------------- kurulum

$installer = Join-Path $homeDir 'tools\install.ps1'
if (-not (Test-Path $installer)) {
    Say "Kurulum betigi bulunamadi: $installer" 'Red'
    return
}

$psArgs = @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', $installer)
if ($GameDir) { $psArgs += @('-GameDir', $GameDir) }
if ($Force)   { $psArgs += '-Force' }

Write-Host ""
& powershell.exe @psArgs
$rc = $LASTEXITCODE

Write-Host ""
if ($rc -eq 0) {
    Say "Kurulum klasoru: $homeDir" 'DarkGray'
    Say "Kaldirmak icin:  $homeDir\KALDIR.cmd" 'DarkGray'
    Say "Oyun guncellenirse: $homeDir\GUNCELLE.cmd" 'DarkGray'
} else {
    Say "Kurulum tamamlanmadi (cikis kodu $rc)." 'Yellow'
    Say "Gunluk dosyasi: $homeDir\kurulum-log.txt" 'Yellow'
    Say "Bu dosyayi gonderirsen sorunu bulabiliriz." 'Yellow'
}
Write-Host ""
