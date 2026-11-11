<#
    Modu, hicbir sey kurulu olmayan bir makinede derler.

    .NET SDK yoksa Microsoft'un resmi dotnet-install betigini indirip
    SDK'yi paketin kendi klasorune kurar (.dotnet\). Yonetici yetkisi
    gerekmez, sisteme hicbir sey yazilmaz, kaldirmak icin klasoru
    silmek yeterli.

    install.ps1 bunu cagirir; elle de calistirilabilir:
        .\tools\bootstrap_build.ps1 -GameDir "C:\...\Schedule I"
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$GameDir,

    [switch]$Mono
)

$ErrorActionPreference = 'Stop'

$root      = Split-Path $PSScriptRoot -Parent
$localSdk  = Join-Path $root '.dotnet'
$localExe  = Join-Path $localSdk 'dotnet.exe'
$config    = if ($Mono) { 'Mono' } else { 'IL2CPP' }

. "$PSScriptRoot\_common.ps1"

function Write-B([string]$t) { Write-Host "      $t" }

# ------------------------------------------------------------ SDK var mi?

function Get-UsableDotnet {
    # Once paketin kendi kurdugu SDK, sonra sistemdeki.
    $candidates = @()
    if (Test-Path $localExe) { $candidates += $localExe }
    $sys = Get-Command dotnet -ErrorAction SilentlyContinue
    if ($sys) { $candidates += $sys.Source }

    foreach ($exe in $candidates) {
        Write-Detail "aday: $exe"
        # --list-sdks hata verirse (bozuk kurulum) bu adayi atla
        $sdks = & $exe --list-sdks 2>$null
        if ($LASTEXITCODE -ne 0 -or -not $sdks) {
            Write-Detail "  surum listesi alinamadi, atlaniyor"
            continue
        }
        foreach ($line in $sdks) {
            Write-Detail "  SDK: $line"
            # "8.0.404 [C:\Program Files\dotnet\sdk]"
            if ($line -match '^(\d+)\.') {
                if ([int]$Matches[1] -ge 6) { return $exe }
            }
        }
    }
    return $null
}

Write-Host ""
Write-Host "  .NET SDK araniyor" -ForegroundColor Cyan
$dotnet = Get-UsableDotnet

if ($dotnet) {
    Write-B "bulundu: $dotnet"
} else {
    Write-B "sistemde yok, pakete kuruluyor (yaklasik 200 MB indirme)"
    Write-B "bu birkac dakika surebilir, pencereyi kapatma"
    Write-Host ""

    New-Item -ItemType Directory -Path $localSdk -Force | Out-Null
    $installer = Join-Path $localSdk 'dotnet-install.ps1'

    try {
        # TLS 1.2: PS 5.1 varsayilani eski, Microsoft sunucusu reddediyor
        [Net.ServicePointManager]::SecurityProtocol =
            [Net.SecurityProtocolType]::Tls12 -bor [Net.ServicePointManager]::SecurityProtocol
        Invoke-WebRequest -Uri 'https://dot.net/v1/dotnet-install.ps1' `
                          -OutFile $installer -UseBasicParsing
    } catch {
        Write-Host ""
        Write-Host "  .NET kurulum betigi indirilemedi." -ForegroundColor Red
        Write-B "Internet baglantini kontrol et."
        Write-B $_.Exception.Message
        exit 10
    }

    & $installer -Channel '8.0' -InstallDir $localSdk -NoPath
    if (-not (Test-Path $localExe)) {
        Write-Host ""
        Write-Host "  .NET SDK kurulamadi." -ForegroundColor Red
        exit 11
    }
    $dotnet = $localExe
    Write-B "kuruldu: $localSdk"
}

# dotnet'i bu oturumda PATH'e al; build.ps1 duz 'dotnet' cagiriyor
$dotnetDir = Split-Path $dotnet -Parent
$env:PATH = "$dotnetDir;$env:PATH"
$env:DOTNET_ROOT = $dotnetDir
$env:DOTNET_CLI_TELEMETRY_OPTOUT = '1'
$env:DOTNET_NOLOGO = '1'

# --------------------------------------------------------------- derleme

Write-Host ""
Write-Host "  Mod derleniyor ($config)" -ForegroundColor Cyan
Write-B "ilk derlemede paketler indirilecek, biraz surer"
Write-Host ""

$buildPs1 = Join-Path $root 'build.ps1'
if (-not (Test-Path $buildPs1)) {
    Write-Host "  build.ps1 bulunamadi: $buildPs1" -ForegroundColor Red
    exit 12
}

# Hashtable ile splat: dizi splatinda '-GameDir' deger sanilip
# parametre adi olarak baglanmiyor.
$buildArgs = @{ GameDir = $GameDir }
if ($Mono) { $buildArgs['Mono'] = $true }

$asmDir = Join-Path $GameDir "MelonLoader\Il2CppAssemblies"
if (Test-Path $asmDir) {
    Write-Detail "referans klasoru: $asmDir"
    Write-Detail "  $(@(Get-ChildItem $asmDir -Filter *.dll -File).Count) dll taranacak - uzun suren kisim burasi"
}
Write-Detail "calistirilan: build.ps1 -GameDir ""$GameDir""$(if ($Mono) { ' -Mono' })"
$buildStart = Get-Date

# build.ps1 hata durumunda throw ediyor; yigin izini kullaniciya
# gostermek yerine yakalayip tek satirlik mesaja ceviriyoruz.
$buildFailed = $false
try {
    & $buildPs1 @buildArgs
    if ($LASTEXITCODE -ne 0) { $buildFailed = $true }
} catch {
    $buildFailed = $true
}

if ($buildFailed) {
    Write-Host ""
    Write-Host "  Derleme basarisiz." -ForegroundColor Red
    Write-B "Yukarida 'error CS' ile baslayan satirlar var."
    Write-B "Onlari kopyalayip gonder, duzeltelim."
    exit 13
}

$dllName = if ($Mono) { 'ScheduleOneTR_Mono.dll' } else { 'ScheduleOneTR_Il2Cpp.dll' }
$dllPath = Join-Path $root "src\ScheduleOneTR\bin\$config\$dllName"
if (-not (Test-Path $dllPath)) {
    Write-Host "  Derleme bitti ama DLL yok: $dllPath" -ForegroundColor Red
    exit 14
}

$d = Get-Item $dllPath
Write-Host ""
Write-Host "  Derleme tamam: $dllName" -ForegroundColor Green
Write-Detail ("boyut: {0:N1} KB" -f ($d.Length/1KB))
Write-Detail ("sure : {0:N1} dakika" -f ((Get-Date) - $buildStart).TotalMinutes)
exit 0
