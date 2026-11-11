<#
    Schedule I Türkçe Yama - derleme betiği

    Kullanım:
        .\build.ps1 -GameDir "C:\Program Files (x86)\Steam\steamapps\common\Schedule I"
        .\build.ps1 -GameDir "..." -Mono          # Steam "alternate" dalı için
        .\build.ps1 -GameDir "..." -Deploy        # derleyip doğrudan oyuna kur
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$GameDir,

    [switch]$Mono,
    [switch]$Deploy
)

$ErrorActionPreference = 'Stop'

if (-not (Test-Path $GameDir)) {
    throw "Oyun klasörü bulunamadı: $GameDir"
}

$exe = Join-Path $GameDir 'Schedule I.exe'
if (-not (Test-Path $exe)) {
    Write-Warning "'$exe' yok. Doğru klasörü verdiğinden emin ol."
}

$config = if ($Mono) { 'Mono' } else { 'IL2CPP' }

$mlProbe = if ($Mono) { 'MelonLoader\net35\MelonLoader.dll' } else { 'MelonLoader\net6\MelonLoader.dll' }
if (-not (Test-Path (Join-Path $GameDir $mlProbe))) {
    throw @"
MelonLoader bulunamadı: $GameDir\$mlProbe

Önce MelonLoader 0.7.3'ü oyuna kur ve oyunu BİR KEZ başlat.
IL2CPP'de ilk açılış, derleme için gereken assembly'leri üretir
($GameDir\MelonLoader\Il2CppAssemblies) ve birkaç dakika sürer.
"@
}

$proj = Join-Path $PSScriptRoot 'src\ScheduleOneTR\ScheduleOneTR.csproj'

$args = @(
    'build', $proj,
    '-c', $config,
    "-p:GameDir=$GameDir"
)
if ($Deploy) { $args += '-p:DeployToGame=true' }

Write-Host "Derleniyor: $config" -ForegroundColor Cyan
& dotnet @args
if ($LASTEXITCODE -ne 0) { throw "Derleme başarısız (çıkış kodu $LASTEXITCODE)." }

$outName = if ($Mono) { 'ScheduleOneTR_Mono.dll' } else { 'ScheduleOneTR_Il2Cpp.dll' }
$outPath = Join-Path $PSScriptRoot "src\ScheduleOneTR\bin\$config\$outName"

Write-Host ""
Write-Host "Tamam: $outPath" -ForegroundColor Green
if (-not $Deploy) {
    Write-Host "Kurmak için bu dosyayı '$GameDir\Mods' klasörüne kopyala (veya -Deploy kullan)."
}
