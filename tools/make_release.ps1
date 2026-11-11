<#
    Son kullaniciya verilecek paketi hazirlar.

    Paketin icinde derlenmis DLL bulunur; kullanici hicbir sey derlemez.
    Bu yuzden bu betigi, oyunun ve .NET SDK'nin bulundugu makinede
    calistirmak gerekiyor.

    Kullanim:
        .\tools\make_release.ps1                      # derle + paketle
        .\tools\make_release.ps1 -SkipBuild           # mevcut DLL'i kullan
        .\tools\make_release.ps1 -Mono                # alternate dal icin
        .\tools\make_release.ps1 -GameDir "C:\..."    # oyun yolunu elle ver

    Cikti: dist\ScheduleOneTR-TR-<tarih>\  ve ayni adda .zip
#>
[CmdletBinding()]
param(
    [string]$GameDir,
    [switch]$Mono,
    [switch]$SkipBuild,
    [switch]$SelfBuild,
    [string]$Version
)

# -SelfBuild: oyunun olmadigi bir makinede paket hazirlamak icin.
# DLL konmaz, kaynak kod konur; KUR.cmd ilk calistiginda kullanicinin
# kendi makinesinde derler (orada oyun ve MelonLoader zaten var).
if ($SelfBuild) { $SkipBuild = $true }

$ErrorActionPreference = 'Stop'
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

$repo = Split-Path $PSScriptRoot -Parent
. "$PSScriptRoot\_common.ps1"

if (-not $Version) { $Version = Get-Date -Format 'yyyy-MM-dd' }
$config  = if ($Mono) { 'Mono' } else { 'IL2CPP' }
$dllName = if ($Mono) { 'ScheduleOneTR_Mono.dll' } else { 'ScheduleOneTR_Il2Cpp.dll' }

Write-Host ""
Write-Host "  Paket hazirlaniyor: $config / $Version" -ForegroundColor White
Write-Host ""

# ----------------------------------------------------------------- derleme

$dllPath = Join-Path $repo "src\ScheduleOneTR\bin\$config\$dllName"

if (-not $SkipBuild) {
    if (-not $GameDir) { $GameDir = Find-ScheduleOne }
    if (-not $GameDir) {
        Write-Host "  Oyun bulunamadi. Derlemek icin oyun klasoru gerekiyor." -ForegroundColor Red
        Write-Host "  -GameDir ile ver, ya da derlemeyi atlamak icin -SkipBuild kullan." -ForegroundColor Yellow
        exit 1
    }
    Write-Host "  [1/4] Derleniyor ($config)" -ForegroundColor Cyan
    $buildArgs = @{ GameDir = $GameDir }
    if ($Mono) { $buildArgs['Mono'] = $true }
    & (Join-Path $repo 'build.ps1') @buildArgs
    if ($LASTEXITCODE -ne 0) {
        Write-Host "  Derleme basarisiz. Paket hazirlanmadi." -ForegroundColor Red
        exit 1
    }
} else {
    Write-Host "  [1/4] Derleme atlandi" -ForegroundColor Cyan
}

$haveDll = Test-Path $dllPath
if (-not $haveDll -and -not $SelfBuild) {
    Write-Host ""
    Write-Host "  Derlenmis DLL yok: $dllPath" -ForegroundColor Red
    Write-Host "  Once modu derle: .\build.ps1 -GameDir ""C:\...\Schedule I""" -ForegroundColor Yellow
    Write-Host "  Ya da kaynak kodlu paket icin: -SelfBuild" -ForegroundColor Yellow
    exit 2
}
if ($haveDll) {
    Write-Host "        $dllName  ($([math]::Round((Get-Item $dllPath).Length/1KB,1)) KB)" -ForegroundColor Green
} else {
    Write-Host "        DLL yok - kaynak kodlu paket hazirlaniyor" -ForegroundColor Yellow
}

# ------------------------------------------------------------- toplama

Write-Host "  [2/4] Dosyalar toplaniyor" -ForegroundColor Cyan

$distRoot = Join-Path $repo 'dist'
$pkgName  = "ScheduleOneTR-TR-$Version"
$pkg      = Join-Path $distRoot $pkgName
if (Test-Path $pkg) { Remove-Item $pkg -Recurse -Force }
New-Item -ItemType Directory -Path (Join-Path $pkg 'tools')        -Force | Out-Null
New-Item -ItemType Directory -Path (Join-Path $pkg 'mod')          -Force | Out-Null
New-Item -ItemType Directory -Path (Join-Path $pkg 'languages\tr') -Force | Out-Null

# kullaniciya gorunen dosyalar
foreach ($f in @('KUR.cmd','KALDIR.cmd','GUNCELLE.cmd','EKSIK_METINLER.cmd','OKUBENI.txt')) {
    $src = Join-Path $repo "release\$f"
    if (-not (Test-Path $src)) { Write-Host "  eksik: release\$f" -ForegroundColor Red; exit 3 }
    Copy-Item $src $pkg -Force
}

# betikler
Copy-Item (Join-Path $repo 'tools\install.ps1')                 (Join-Path $pkg 'tools') -Force
Copy-Item (Join-Path $repo 'tools\_common.ps1')                 (Join-Path $pkg 'tools') -Force
Copy-Item (Join-Path $repo 'release\tools\collect_missing.ps1')  (Join-Path $pkg 'tools') -Force
# MelonLoader kurucusu her pakette lazim: kullanicida kurulu olmayabilir
Copy-Item (Join-Path $repo 'tools\install_melonloader.ps1')      (Join-Path $pkg 'tools') -Force

# Kaynak kodlu pakette derleme icin gerekenler de gidiyor.
if ($SelfBuild) {
    Copy-Item (Join-Path $repo 'tools\bootstrap_build.ps1') (Join-Path $pkg 'tools') -Force
    Copy-Item (Join-Path $repo 'build.ps1')                 $pkg -Force
    $srcDst = Join-Path $pkg 'src'
    New-Item -ItemType Directory -Path $srcDst -Force | Out-Null
    # bin/obj yok: kullanicinin makinesinde bastan derlenecek
    Copy-Item (Join-Path $repo 'src\*') $srcDst -Recurse -Force `
              -Exclude @('bin','obj')
    Get-ChildItem $srcDst -Directory -Recurse |
        Where-Object { $_.Name -in @('bin','obj') } |
        Remove-Item -Recurse -Force -ErrorAction SilentlyContinue
    $csFiles = @(Get-ChildItem $srcDst -Filter *.cs -File -Recurse)
    Write-Host "        kaynak kod: $($csFiles.Count) dosya" -ForegroundColor Green
}

# mod.  Her iki dalin DLL'i varsa ikisini de koyuyoruz; kurulumcu oyunun
# hangi dal oldugunu kendisi anlayip dogru olani seciyor. Tek dal varsa
# diger dali kullanan kullaniciya kurulumcu bunu aciklayacak.
if ($haveDll) { Copy-Item $dllPath (Join-Path $pkg 'mod') -Force }
$otherCfg  = if ($Mono) { 'IL2CPP' } else { 'Mono' }
$otherName = if ($Mono) { 'ScheduleOneTR_Il2Cpp.dll' } else { 'ScheduleOneTR_Mono.dll' }
$otherPath = Join-Path $repo "src\ScheduleOneTR\bin\$otherCfg\$otherName"
if (Test-Path $otherPath) {
    Copy-Item $otherPath (Join-Path $pkg 'mod') -Force
    Write-Host "        her iki dal icin DLL kondu (IL2CPP + Mono)" -ForegroundColor Green
} else {
    Write-Host "        sadece $config dali kapsaniyor ($otherCfg derlenmemis)" -ForegroundColor Yellow
}

# ceviriler
$langFiles = @(Get-ChildItem (Join-Path $repo 'languages\tr') -Filter *.txt -File)
if ($langFiles.Count -eq 0) { Write-Host "  ceviri dosyasi yok!" -ForegroundColor Red; exit 4 }
foreach ($f in $langFiles) { Copy-Item $f.FullName (Join-Path $pkg 'languages\tr') -Force }
Write-Host "        $($langFiles.Count) ceviri dosyasi" -ForegroundColor Green

# MelonLoader kurucusu varsa pakete koy (istege bagli, Apache-2.0)
$mlInst = Join-Path $repo 'release\MelonLoader.Installer.exe'
if (Test-Path $mlInst) {
    Copy-Item $mlInst $pkg -Force
    Write-Host "        MelonLoader kurucusu da eklendi" -ForegroundColor Green
} else {
    Write-Host "        MelonLoader: kurulumcu gerektiginde GitHub'dan indirecek"
}

# ------------------------------------------------------------- denetim

Write-Host "  [3/4] Paket denetleniyor" -ForegroundColor Cyan

$must = @('KUR.cmd','KALDIR.cmd','GUNCELLE.cmd','EKSIK_METINLER.cmd','OKUBENI.txt',
          'tools\install.ps1','tools\_common.ps1','tools\collect_missing.ps1',
          'tools\install_melonloader.ps1')
if ($haveDll)   { $must += "mod\$dllName" }
if ($SelfBuild) { $must += @('build.ps1','tools\bootstrap_build.ps1',
                             'src\ScheduleOneTR\ScheduleOneTR.csproj',
                             'src\ScheduleOneTR\Plugin.cs') }
$missing = @($must | Where-Object { -not (Test-Path (Join-Path $pkg $_)) })
if ($missing.Count -gt 0) {
    Write-Host "  eksik dosyalar: $($missing -join ', ')" -ForegroundColor Red
    exit 5
}
foreach ($f in $langFiles) {
    # Ciktisi sadece hata varsa gosterilir, yoksa 3 dosyanin ozeti ekrani doldurur.
    # *>&1 sart: betik Write-Host kullaniyor, o da 2>&1 ile yakalanmaz
    # (Write-Host bilgi akisina yazar), ekrani uc dosyanin ozeti doldurur.
    $chk = & (Join-Path $repo 'tools\check_translation.ps1') -File (Join-Path $pkg "languages\tr\$($f.Name)") *>&1
    if ($LASTEXITCODE -ne 0) {
        Write-Host "  ceviri dosyasinda hata: $($f.Name)" -ForegroundColor Red
        $chk | Select-Object -Last 20
        exit 6
    }
}
Write-Host "        tum dosyalar yerinde, ceviriler temiz" -ForegroundColor Green

# ------------------------------------------------------------------- zip

Write-Host "  [4/4] Zip olusturuluyor" -ForegroundColor Cyan

$zip = Join-Path $distRoot "$pkgName.zip"
if (Test-Path $zip) { Remove-Item $zip -Force }
# Paket klasorunun ICINDEKILERI zipliyoruz: kullanici zip'i acinca tek klasor
# gorur, ic ice ayni adda iki klasor olmaz.
Compress-Archive -Path (Join-Path $pkg '*') -DestinationPath $zip
Write-Host "        $([math]::Round((Get-Item $zip).Length/1KB,0)) KB" -ForegroundColor Green

Write-Host ""
Write-Host "  HAZIR" -ForegroundColor Green
Write-Host "    klasor : $pkg"
Write-Host "    zip    : $zip"
Write-Host ""
Write-Host "  Test icin: paketi baska bir klasore acip KUR.cmd'ye cift tikla."
Write-Host ""
