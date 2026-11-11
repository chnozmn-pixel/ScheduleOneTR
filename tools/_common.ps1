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
