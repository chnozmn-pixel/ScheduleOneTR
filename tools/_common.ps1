<#
    tools/*.ps1 betiklerinin paylastigi yardimcilar.
    Dot-source ile yuklenir:  . "$PSScriptRoot\_common.ps1"
#>

# Schedule I kurulumunu Steam kutuphanelerinden bulur (baska disklerdekiler dahil).
# Bulamazsa $null doner.
function Find-ScheduleOne {
    $libs = New-Object System.Collections.Generic.List[string]

    foreach ($key in @('HKCU:\Software\Valve\Steam', 'HKLM:\SOFTWARE\WOW6432Node\Valve\Steam')) {
        try {
            $p = (Get-ItemProperty -Path $key -ErrorAction Stop).InstallPath
            if ($p) { $libs.Add($p) }
        } catch { }
    }
    foreach ($p in @("${env:ProgramFiles(x86)}\Steam", "$env:ProgramFiles\Steam")) {
        if (Test-Path $p) { $libs.Add($p) }
    }

    # libraryfolders.vdf: diger disklerdeki kutuphaneler
    foreach ($lib in @($libs)) {
        $vdf = Join-Path $lib 'steamapps\libraryfolders.vdf'
        if (-not (Test-Path $vdf)) { continue }
        foreach ($m in [regex]::Matches((Get-Content $vdf -Raw), '"path"\s*"([^"]+)"')) {
            # Parantez sart: PowerShell metot cagrisi icindeki virgulu argument
            # ayiricisi sayar, -replace'in virgulu de dahil.
            $libs.Add(($m.Groups[1].Value -replace '\\\\', '\'))
        }
    }

    foreach ($lib in ($libs | Select-Object -Unique)) {
        $cand = Join-Path $lib 'steamapps\common\Schedule I'
        if (Test-Path (Join-Path $cand 'Schedule I.exe')) { return $cand }
        if (Test-Path $cand) { return $cand }
    }
    return $null
}

# Dosyayi, baska bir surec acik tutsa bile okur.
#
# [IO.File]::ReadAllBytes varsayilan olarak FileShare.Read ile acar; oyun
# calisirken global-metadata.dat veya Assembly-CSharp.dll kilitli olabilir ve
# bu "another process" hatasi verir. Biz FileShare.ReadWrite + Delete ile
# aciyoruz: paylasimi en gevsek biz talep ediyoruz, boylece oyun acikken de
# okunur. Yalnizca okuma; dosyaya hicbir sey yazilmaz.
#
# Okunamazsa $null doner ve sebebi $Warn listesine yazar.
function Read-GameFileBytes([string]$Path, $Warn) {
    $name = Split-Path $Path -Leaf
    $fs = $null
    try {
        $fs = New-Object System.IO.FileStream(
            $Path,
            [System.IO.FileMode]::Open,
            [System.IO.FileAccess]::Read,
            ([System.IO.FileShare]::ReadWrite -bor [System.IO.FileShare]::Delete))

        $len = $fs.Length
        if ($len -gt [int]::MaxValue) {
            if ($null -ne $Warn) { $Warn.Add("${name}: dosya cok buyuk ($len bayt).") }
            return $null
        }

        $buf = New-Object byte[] $len
        $read = 0
        while ($read -lt $len) {
            $n = $fs.Read($buf, $read, [int]($len - $read))
            if ($n -le 0) { break }
            $read += $n
        }
        if ($read -lt $len) {
            if ($null -ne $Warn) { $Warn.Add("${name}: dosya tam okunamadi ($read/$len bayt).") }
            return $null
        }
        return $buf
    } catch {
        if ($null -ne $Warn) { $Warn.Add("${name}: okunamadi - $($_.Exception.Message)") }
        return $null
    } finally {
        if ($fs) { $fs.Dispose() }
    }
}

# Verilen yol bossa oyunu bulur, yoksa hata yazip betigi bitirir.
function Resolve-GameDir([string]$GameDir) {
    if ($GameDir) {
        if (-not (Test-Path -LiteralPath $GameDir -PathType Container)) {
            Write-Host "HATA: klasor yok: $GameDir" -ForegroundColor Red
            exit 1
        }
        return $GameDir
    }

    Write-Host 'Oyun klasoru araniyor...'
    $found = Find-ScheduleOne
    if (-not $found) {
        Write-Host ''
        Write-Host 'HATA: Schedule I kurulumu bulunamadi.' -ForegroundColor Red
        Write-Host 'Yolu kendin ver:' -ForegroundColor Yellow
        Write-Host '  -GameDir "C:\...\steamapps\common\Schedule I"'
        exit 1
    }
    Write-Host "Bulundu: $found" -ForegroundColor Green
    return $found
}
