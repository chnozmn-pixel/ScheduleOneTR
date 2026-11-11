<#
    Oyunda Ingilizce kalan metinleri toplar ve masaustune tek dosya olarak
    koyar. Kullanici o dosyayi gelistiriciye gonderir.

    EKSIK_METINLER.cmd bunu cagirir.
#>
[CmdletBinding()]
param([string]$GameDir)

$ErrorActionPreference = 'Stop'
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

. "$PSScriptRoot\_common.ps1"

Write-Host ""
Write-Host "  Ingilizce kalan metinler toplaniyor" -ForegroundColor White
Write-Host "  ==================================="
Write-Host ""

if (-not $GameDir) { $GameDir = Find-ScheduleOne }
if (-not $GameDir -or -not (Test-Path -LiteralPath $GameDir -PathType Container)) {
    Write-Host "  Oyun klasoru bulunamadi." -ForegroundColor Red
    exit 1
}

$exportDir = Join-Path $GameDir 'UserData\ScheduleOneTR\export'
$src = Join-Path $exportDir 'english_strings.txt'

if (-not (Test-Path $src)) {
    Write-Host "  Henuz toplanmis metin yok." -ForegroundColor Yellow
    Write-Host ""
    Write-Host "  Bunun icin once oyunu bir sure oynaman gerekiyor. Mod, Ingilizce"
    Write-Host "  kalan her yaziyi kendi kaydediyor; ne kadar cok ekran gezersen"
    Write-Host "  (menuler, telefon, gorevler, dukkanlar) o kadar cok toplanir."
    Write-Host ""
    Write-Host "  Oyunu oynayip ciktiktan sonra bu dosyayi tekrar calistir."
    exit 2
}

$lines = @([System.IO.File]::ReadAllLines($src, [System.Text.Encoding]::UTF8))
$count = @($lines | Where-Object { $_ -match '.=\s*$' -and $_ -notmatch '^\s*(//|@)' }).Count

$stamp = Get-Date -Format 'yyyy-MM-dd_HHmm'
$desktop = [Environment]::GetFolderPath('Desktop')
$dst = Join-Path $desktop "ScheduleOneTR_eksikler_$stamp.txt"

Copy-Item $src $dst -Force

Write-Host "  Tamam." -ForegroundColor Green
Write-Host ""
Write-Host "  Dosya masaustune kondu:"
Write-Host "    $(Split-Path $dst -Leaf)"
Write-Host ""
Write-Host "  Icinde yaklasik $count cevrilmemis satir var."
Write-Host "  Bu dosyayi gelistiriciye gonder, sonraki surumde cevrilir."
Write-Host ""
