<#
    Ceviri dosyasini denetler. Kurulum gerektirmez.

    Modun LanguageFile.cs ayristiricisiyla ayni kurallara gore bakar:
      - anahtar degismis mi (degistiyse o satir oyunda hic eslesmez)
      - yer tutucular ({0}, {1}) iki tarafta ayni mi
      - TMP etiketleri (<b>, <color=...>) dengeli ve ayni mi
      - bos / cevrilmemis satirlar
      - ayni anahtarin iki kez gecmesi (sonraki oncekini ezer)
      - taninmayan kacis dizisi (\x gibi) - ayristirici bunu oldugu gibi birakir
      - Turkce buyuk harf tuzagi (i -> I olur, İ olmaz)

    Kullanim:
        .\tools\check_translation.ps1 -File ayrilmis\00_ilk_once_tr.txt
        .\tools\check_translation.ps1 -File ... -Source ayrilmis\00_ilk_once.txt

    -Source verirsen anahtarlar kaynak dosyayla karsilastirilir. Vermezsen
    yalnizca dosya ici tutarlilik denetlenir.

    Cikis kodu: 0 = hata yok, 1 = hata var.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$File,
    [string]$Source,
    [int]$Show = 15
)

$ErrorActionPreference = 'Stop'
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

if (-not (Test-Path -LiteralPath $File -PathType Leaf)) {
    Write-Host "HATA: dosya yok: $File" -ForegroundColor Red
    exit 1
}

# ---------------------------------------------------------------- ayristirma

# LanguageFile.FindSeparator ile ayni: ilk kacirilmamis '='
function Find-Sep([string]$s) {
    for ($i = 0; $i -lt $s.Length; $i++) {
        if ($s[$i] -eq '\') { $i++; continue }
        if ($s[$i] -eq '=') { return $i }
    }
    return -1
}

function Read-Entries([string]$path) {
    $list = New-Object 'System.Collections.Generic.List[object]'
    $n = 0
    foreach ($raw in [System.IO.File]::ReadAllLines($path, [System.Text.Encoding]::UTF8)) {
        $n++
        if ($raw.Length -eq 0) { continue }
        $t = $raw.TrimStart()
        if ($t.Length -eq 0 -or $t.StartsWith('//') -or $t.StartsWith('#')) { continue }
        $t = $t -replace '^\d+\s*\|',''          # satir numarasini at
        $sep = Find-Sep $t
        if ($sep -lt 0) {
            $list.Add([pscustomobject]@{ Line = $n; Key = $null; Value = $null; Raw = $raw })
            continue
        }
        $k = $t.Substring(0, $sep)
        $v = $t.Substring($sep + 1)
        if ($k.StartsWith('@')) { continue }     # direktif
        $list.Add([pscustomobject]@{ Line = $n; Key = $k; Value = $v; Raw = $raw })
    }
    return $list
}

$entries = Read-Entries $File
Write-Host "Dosya: $File"
Write-Host "  $($entries.Count) kayit"

# ------------------------------------------------------------------ denetim

$errors   = New-Object 'System.Collections.Generic.List[string]'
$warnings = New-Object 'System.Collections.Generic.List[string]'

# 1) '=' olmayan satirlar
foreach ($e in $entries | Where-Object { $null -eq $_.Key }) {
    $errors.Add("satir $($e.Line): '=' yok, mod bu satiri atlar -> $($e.Raw)")
}
$valid = @($entries | Where-Object { $null -ne $_.Key })

# 2) bos deger
foreach ($e in $valid | Where-Object { $_.Value.Trim().Length -eq 0 }) {
    $warnings.Add("satir $($e.Line): deger bos (cevrilmemis sayilir) -> $($e.Key)")
}

# 3) ayni anahtar iki kez.
#
# -CaseSensitive sart. LanguageFile sozlugu StringComparer.Ordinal kullanir,
# yani "ID" ile "Id" FARKLI anahtarlardir ve ikisi de gereklidir. Group-Object
# varsayilan olarak buyuk/kucuk harf ayirmaz; onsuz bu denetim "Mixing Station"
# ile "Mixing station"i cift sanar.
$dupes = $valid | Group-Object -Property Key -CaseSensitive | Where-Object { $_.Count -gt 1 }
foreach ($d in $dupes) {
    $lines = ($d.Group | ForEach-Object { $_.Line }) -join ', '
    $errors.Add("anahtar $($d.Count) kez geciyor (son okunan kazanir, satirlar: $lines) -> $($d.Name)")
}

# 4) yer tutucu esitligi.  {0} {1} ... iki tarafta ayni kume olmali.
$phRx = [regex]'\{(\d+)\}'
foreach ($e in $valid | Where-Object { $_.Value.Trim().Length -gt 0 }) {
    $kp = @($phRx.Matches($e.Key)  | ForEach-Object { $_.Groups[1].Value } | Sort-Object -Unique)
    $vp = @($phRx.Matches($e.Value) | ForEach-Object { $_.Groups[1].Value } | Sort-Object -Unique)
    if (($kp -join ',') -ne ($vp -join ',')) {
        $errors.Add("satir $($e.Line): yer tutucu uyusmuyor (anahtar: {$($kp -join '},{')} / deger: {$($vp -join '},{')}) -> $($e.Key)")
    }
}

# 5) TMP etiketleri.  Ac/kapa dengesi ve etiket adlari.
$tagRx = [regex]'</?([a-zA-Z]+)[^>]*>'
foreach ($e in $valid | Where-Object { $_.Value.Trim().Length -gt 0 }) {
    $kt = @($tagRx.Matches($e.Key)   | ForEach-Object { $_.Value -replace '=[^>]*','' } | Sort-Object)
    $vt = @($tagRx.Matches($e.Value) | ForEach-Object { $_.Value -replace '=[^>]*','' } | Sort-Object)
    if (($kt -join '') -ne ($vt -join '')) {
        $errors.Add("satir $($e.Line): etiketler uyusmuyor (anahtar: $($kt -join ' ') / deger: $($vt -join ' ')) -> $($e.Key)")
    }
}

# 6) taninmayan kacis dizisi.  Unescape yalnizca \n \r \t \\ \= \| \uXXXX tanir;
#    digerlerini ters bolu ile birlikte oldugu gibi birakir.
#
# Regex ile aranamaz: ciftleri saymak gerekir. "SOFTWARE\\Microsoft" icinde
# ikinci ters bolu bir kacisin PARCASI, yeni bir kacis degil. Ayristirici gibi
# karakter karakter yuruyoruz.
function Find-BadEscape([string]$s) {
    for ($i = 0; $i -lt $s.Length; $i++) {
        if ($s[$i] -ne '\') { continue }
        if ($i + 1 -ge $s.Length) { return '(satir sonu)' }
        $next = $s[$i + 1]
        # IndexOf: ordinal ve buyuk/kucuk harf duyarli. Ayristiricinin switch'i
        # yalnizca kucuk 'n' tanir, '\N' taninmayan kacistir.
        if ('nrt\=|u'.IndexOf([char]$next) -lt 0) { return $next }
        $i++   # kacisin ikinci karakterini atla
    }
    return $null
}
foreach ($e in $valid) {
    foreach ($side in @(@{N='anahtar';V=$e.Key}, @{N='deger';V=$e.Value})) {
        $bad = Find-BadEscape $side.V
        if ($bad) {
            $warnings.Add("satir $($e.Line): $($side.N) icinde taninmayan kacis '\$bad' -> $($e.Key)")
        }
    }
}

# 7) Turkce buyuk harf tuzagi: TMP'nin <allcaps>/Uppercase stili kulturden
#    bagimsiz, yani 'i' -> 'I' olur, 'İ' olmaz. Kucuk 'i' iceren kisa
#    etiketler risk altinda.
$iRisk = @($valid | Where-Object {
    $_.Value.Trim().Length -gt 0 -and $_.Value.Length -le 20 -and $_.Value -cmatch 'i'
})

# 8) ceviri = kaynak (dokunulmamis kopya)
$same = @($valid | Where-Object { $_.Value.Trim().Length -gt 0 -and $_.Value.Trim() -ceq $_.Key.Trim() })

# 9) kaynak dosyayla anahtar karsilastirmasi
$keyReport = $null
if ($Source) {
    if (-not (Test-Path -LiteralPath $Source -PathType Leaf)) {
        Write-Host "UYARI: kaynak dosya yok: $Source" -ForegroundColor Yellow
    } else {
        $src = Read-Entries $Source
        $srcKeys = New-Object 'System.Collections.Generic.HashSet[string]' (,[string[]]@($src | Where-Object { $null -ne $_.Key } | ForEach-Object { $_.Key }))
        $dstKeys = New-Object 'System.Collections.Generic.HashSet[string]' (,[string[]]@($valid | ForEach-Object { $_.Key }))

        $changed = @($valid | Where-Object { -not $srcKeys.Contains($_.Key) })
        $missing = @($src | Where-Object { $null -ne $_.Key -and -not $dstKeys.Contains($_.Key) })

        foreach ($c in $changed | Select-Object -First 200) {
            $errors.Add("satir $($c.Line): anahtar kaynakta yok, DEGISTIRILMIS olabilir -> $($c.Key)")
        }
        $keyReport = [pscustomobject]@{
            SourceCount = @($src | Where-Object { $null -ne $_.Key }).Count
            Changed = $changed.Count
            Missing = $missing.Count
        }
    }
}

# -------------------------------------------------------------------- rapor

function Show-List($title, $items, $color, $limit) {
    if ($items.Count -eq 0) { return }
    Write-Host ''
    Write-Host "$title ($($items.Count))" -ForegroundColor $color
    foreach ($x in ($items | Select-Object -First $limit)) { Write-Host "  $x" }
    if ($items.Count -gt $limit) { Write-Host "  ... $($items.Count - $limit) tane daha" -ForegroundColor DarkGray }
}

Write-Host ''
Write-Host '--- ozet ---'
Write-Host ("  cevrili          : {0}" -f @($valid | Where-Object { $_.Value.Trim().Length -gt 0 }).Count)
Write-Host ("  bos              : {0}" -f @($valid | Where-Object { $_.Value.Trim().Length -eq 0 }).Count)
Write-Host ("  kaynakla ayni    : {0}" -f $same.Count)
if ($keyReport) {
    Write-Host ("  kaynak kayit     : {0}" -f $keyReport.SourceCount)
    Write-Host ("  degismis anahtar : {0}" -f $keyReport.Changed) -ForegroundColor $(if($keyReport.Changed -gt 0){'Red'}else{'Green'})
    Write-Host ("  eksik anahtar    : {0}" -f $keyReport.Missing)
}
Write-Host ("  'i' harfi riskli : {0}  (buyuk harfe cevrilirse I olur, İ olmaz)" -f $iRisk.Count)

Show-List 'HATA' $errors 'Red' $Show
Show-List 'UYARI' $warnings 'Yellow' $Show

Write-Host ''
if ($errors.Count -eq 0) {
    Write-Host 'Hata bulunmadi.' -ForegroundColor Green
    exit 0
}
Write-Host "$($errors.Count) hata var." -ForegroundColor Red
exit 1
