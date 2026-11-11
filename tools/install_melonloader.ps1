<#
    MelonLoader'i oyun klasorune kurar.

    Resmi surum arsivini (MelonLoader.x64.zip) GitHub'dan indirip oyun
    klasorune aciyor. MelonLoader.Installer.exe ile ayni isi yapar ama
    pencere acmaz, soru sormaz.

    install.ps1 bunu cagirir; elle de calistirilabilir:
        .\tools\install_melonloader.ps1 -GameDir "C:\...\Schedule I"
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$GameDir,

    [string]$Version = '0.7.3',

    # Mono dali 32 bit degil ama yine de acik kapi biraktik
    [ValidateSet('x64', 'x86')]
    [string]$Arch = 'x64'
)

$ErrorActionPreference = 'Stop'

function Write-B([string]$t) { Write-Host "      $t" }

$asset = "MelonLoader.$Arch.zip"
$url   = "https://github.com/LavaGang/MelonLoader/releases/download/v$Version/$asset"

# Oyun calisiyorsa version.dll kilitli olur, yazamadan once soyleyelim
$running = @(Get-Process -Name 'Schedule I' -ErrorAction SilentlyContinue)
if ($running.Count -gt 0) {
    Write-Host "  Oyun acik." -ForegroundColor Red
    Write-B "MelonLoader kurulmadan once oyunu kapatman gerekiyor."
    exit 20
}

$tmp = Join-Path ([IO.Path]::GetTempPath()) "melonloader_$Version`_$Arch.zip"

if (Test-Path $tmp) {
    # Yarim kalmis indirme kalmasin
    Remove-Item $tmp -Force -ErrorAction SilentlyContinue
}

Write-B "indiriliyor: MelonLoader $Version ($Arch), yaklasik 20 MB"
try {
    [Net.ServicePointManager]::SecurityProtocol =
        [Net.SecurityProtocolType]::Tls12 -bor [Net.ServicePointManager]::SecurityProtocol
    # Invoke-WebRequest'in ilerleme cubugu PS 5.1'de indirmeyi cok yavaslatiyor
    $oldProgress = $ProgressPreference
    $ProgressPreference = 'SilentlyContinue'
    Invoke-WebRequest -Uri $url -OutFile $tmp -UseBasicParsing
    $ProgressPreference = $oldProgress
} catch {
    Write-Host ""
    Write-Host "  MelonLoader indirilemedi." -ForegroundColor Red
    Write-B $_.Exception.Message
    Write-B "Internet baglantini kontrol et, ya da elle kur:"
    Write-B "  https://github.com/LavaGang/MelonLoader/releases/tag/v$Version"
    exit 21
}

$size = (Get-Item $tmp).Length
if ($size -lt 5MB) {
    Write-Host "  Indirilen dosya bozuk gorunuyor ($size bayt)." -ForegroundColor Red
    Remove-Item $tmp -Force -ErrorAction SilentlyContinue
    exit 22
}
Write-B ("indirildi: {0:N0} MB" -f ($size / 1MB))

Write-B "oyun klasorune aciliyor"
try {
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    $zip = [IO.Compression.ZipFile]::OpenRead($tmp)
    try {
        foreach ($entry in $zip.Entries) {
            $dst = Join-Path $GameDir $entry.FullName
            if ([string]::IsNullOrEmpty($entry.Name)) {
                # klasor girdisi
                New-Item -ItemType Directory -Path $dst -Force | Out-Null
                continue
            }
            $dstDir = Split-Path $dst -Parent
            if (-not (Test-Path $dstDir)) {
                New-Item -ItemType Directory -Path $dstDir -Force | Out-Null
            }
            [IO.Compression.ZipFileExtensions]::ExtractToFile($entry, $dst, $true)
        }
    } finally {
        $zip.Dispose()
    }
} catch {
    Write-Host ""
    Write-Host "  Arsiv acilamadi." -ForegroundColor Red
    Write-B $_.Exception.Message
    Write-B "Oyun klasorune yazma izni olmayabilir; KUR.cmd'yi yonetici"
    Write-B "olarak calistirmayi dene (sag tik > Yonetici olarak calistir)."
    exit 23
}

Remove-Item $tmp -Force -ErrorAction SilentlyContinue

# Dogrulama: net6 (IL2CPP) ya da net35 (Mono) klasoru olusmus olmali
$ok = (Test-Path (Join-Path $GameDir 'MelonLoader\net6\MelonLoader.dll')) -or
      (Test-Path (Join-Path $GameDir 'MelonLoader\net35\MelonLoader.dll'))
if (-not $ok) {
    Write-Host "  MelonLoader dosyalari beklenen yerde degil." -ForegroundColor Red
    exit 24
}

Write-B "MelonLoader $Version kuruldu"
exit 0
