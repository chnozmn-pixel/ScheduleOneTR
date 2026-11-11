<#
    Yeni toplanan Ingilizce metinleri mevcut ceviri dosyasiyla birlestirir.
    merge_export.py ile ayni isi yapar; farki: hicbir sey kurmak gerekmez.

    Oyunu her oynadiginda export/english_strings.txt buyur. Bu betik:
      - zaten cevirdigin satirlari oldugu gibi korur,
      - yalnizca yeni (henuz gorulmemis) anahtarlari dosyanin sonuna ekler,
      - artik oyunda gorunmeyen anahtarlari silmez, sadece listeler.

    Kullanim:
        .\tools\merge_export.ps1
        .\tools\merge_export.ps1 -DryRun
        .\tools\merge_export.ps1 -Export "...\export\english_strings.txt" `
                                 -Current "...\languages\tr\00_main.txt"

    Yol vermezsen:
      -Export  : <oyun>\UserData\ScheduleOneTR\export\english_strings.txt
      -Current : <depo>\languages\tr\00_main.txt   (git ile senkron tutulan dosya)

    -DryRun ile sadece ne olacagini gosterir, dosyaya dokunmaz.
#>
[CmdletBinding()]
param(
    [string]$Export,
    [string]$Current,
    [string]$GameDir,
    [switch]$DryRun
)

$ErrorActionPreference = 'Stop'
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

. "$PSScriptRoot\_common.ps1"

# ------------------------------------------------------------------ yollar

if (-not $Export) {
    $GameDir = Resolve-GameDir $GameDir
    $Export = Join-Path $GameDir 'UserData\ScheduleOneTR\export\english_strings.txt'
}
if (-not $Current) {
    $Current = Join-Path (Split-Path $PSScriptRoot -Parent) 'languages\tr\00_main.txt'
}

if (-not (Test-Path -LiteralPath $Export -PathType Leaf)) {
    Write-Host "HATA: export dosyasi yok: $Export" -ForegroundColor Red
    Write-Host 'Modu dokum modunda bir kez oynatman gerekiyor (ExportEnglishStrings=true).' -ForegroundColor Yellow
    exit 1
}

Write-Host "Export  : $Export"
Write-Host "Mevcut  : $Current"

# --------------------------------------------------------------- ayristirma

$LINE_ID = [regex]'^\d+\s*\|'

function Strip-Id([string]$line) {
    $m = $LINE_ID.Match($line)
    if ($m.Success) { return $line.Substring($m.Length) }
    return $line
}

# Kacirilmamis ilk '=' konumu, yoksa -1
function Find-Separator([string]$line) {
    $i = 0
    while ($i -lt $line.Length) {
        if ($line[$i] -eq '\') { $i += 2; continue }
        if ($line[$i] -eq '=') { return $i }
        $i++
    }
    return -1
}

# Dosyayi (anahtar -> deger) + baslik satirlari olarak ayirir.
function Parse-LangFile([string]$path) {
    $entries = New-Object 'System.Collections.Generic.Dictionary[string,string]'
    $order   = New-Object 'System.Collections.Generic.List[string]'
    $header  = New-Object 'System.Collections.Generic.List[string]'
    $seenEntry = $false

    if (Test-Path -LiteralPath $path -PathType Leaf) {
        foreach ($raw in [System.IO.File]::ReadAllLines($path, [System.Text.Encoding]::UTF8)) {
            $stripped = $raw.Trim()
            if ($stripped.Length -eq 0 -or $stripped.StartsWith('//') -or $stripped.StartsWith('#')) {
                if (-not $seenEntry) { $header.Add($raw) }
                continue
            }

            $stripped = Strip-Id $stripped
            $sep = Find-Separator $stripped
            if ($sep -lt 0) { continue }

            $key = $stripped.Substring(0, $sep)
            $val = $stripped.Substring($sep + 1)

            if ($key.StartsWith('@')) {
                if (-not $seenEntry) { $header.Add($raw) }
                continue
            }

            $seenEntry = $true
            if (-not $entries.ContainsKey($key)) { $order.Add($key) }
            $entries[$key] = $val
        }
    }

    return [pscustomobject]@{ Entries = $entries; Order = $order; Header = $header }
}

$new = Parse-LangFile $Export
$cur = Parse-LangFile $Current

$added = @($new.Order | Where-Object { -not $cur.Entries.ContainsKey($_) })
$gone  = @($cur.Order | Where-Object { -not $new.Entries.ContainsKey($_) })
$translated = @($cur.Entries.Values | Where-Object { $_.Trim().Length -gt 0 }).Count

Write-Host ''
Write-Host "Mevcut dosya : $($cur.Entries.Count) satir, $translated tanesi cevrili"
Write-Host "Export       : $($new.Entries.Count) satir"
Write-Host "Eklenecek    : $($added.Count)"
Write-Host "Artik yok    : $($gone.Count) (silinmiyor)"

if ($gone.Count -gt 0) {
    Write-Host ''
    Write-Host 'Oyunda artik gorulmeyenler (ilk 20):'
    foreach ($k in ($gone | Select-Object -First 20)) { Write-Host "  $k" }
}

if ($added.Count -eq 0) {
    Write-Host ''
    Write-Host 'Yeni satir yok, dosya degismedi.' -ForegroundColor Green
    exit 0
}

if ($DryRun) {
    Write-Host ''
    Write-Host '-DryRun: dosya yazilmadi. Eklenecekler (ilk 20):' -ForegroundColor Yellow
    foreach ($k in ($added | Select-Object -First 20)) { Write-Host "  $k" }
    exit 0
}

# ------------------------------------------------------------------ yaz

$header = if ($cur.Header.Count -gt 0) { $cur.Header } else { $new.Header }
$lines = New-Object 'System.Collections.Generic.List[string]'
foreach ($h in $header) { $lines.Add($h) }
if ($lines.Count -gt 0 -and $lines[$lines.Count - 1].Trim().Length -gt 0) { $lines.Add('') }

$n = 0
foreach ($k in $cur.Order) {
    $n++
    $lines.Add(('{0:00000}|{1}={2}' -f $n, $k, $cur.Entries[$k]))
}

$lines.Add('')
$lines.Add('// ---- yeni eklenenler ----')
foreach ($k in $added) {
    $n++
    $lines.Add(('{0:00000}|{1}=' -f $n, $k))
}

$dir = Split-Path $Current -Parent
if ($dir -and -not (Test-Path -LiteralPath $dir)) {
    New-Item -ItemType Directory -Path $dir -Force | Out-Null
}

$utf8NoBom = New-Object System.Text.UTF8Encoding($false)
$sw = New-Object System.IO.StreamWriter($Current, $false, $utf8NoBom)
try {
    $sw.NewLine = "`n"
    foreach ($l in $lines) { $sw.WriteLine($l) }
} finally { $sw.Dispose() }

Write-Host ''
Write-Host "Yazildi: $Current  (+$($added.Count) yeni satir)" -ForegroundColor Green
