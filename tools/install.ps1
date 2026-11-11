<#
    Schedule I Turkce Yama - kurulum betigi (son kullanici icin).

    KUR.cmd bunu cagirir. Kod bilgisi gerektirmez, hicbir sey sormaz
    (MelonLoader eksikse tek bir onay ister).

    Yaptigi is:
      1. Oyunu Steam kutuphanelerinden bulur
      2. MelonLoader kurulu mu diye bakar
      3. Mod DLL'ini Mods\ klasorune kopyalar
      4. Ceviri dosyalarini UserData\ScheduleOneTR\languages\tr\ icine kopyalar
      5. Ozet yazar

    Parametreler (normalde gerekmez):
      -GameDir   oyun klasorunu elle vermek icin
      -Uninstall kurulumu geri alir
#>
[CmdletBinding()]
param(
    [string]$GameDir,
    [switch]$Uninstall
)

$ErrorActionPreference = 'Stop'
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

$here = Split-Path $PSScriptRoot -Parent      # paketin kok klasoru
. "$PSScriptRoot\_common.ps1"

function Write-Step([int]$n, [int]$of, [string]$text) {
    Write-Host ""
    Write-Host "[$n/$of] $text" -ForegroundColor Cyan
}
function Write-Ok([string]$t)   { Write-Host "      $t" -ForegroundColor Green }
function Write-Bad([string]$t)  { Write-Host "      $t" -ForegroundColor Red }
function Write-Info([string]$t) { Write-Host "      $t" }

Write-Host ""
Write-Host "  Schedule I - Turkce Yama" -ForegroundColor White
Write-Host "  ========================"

$steps = if ($Uninstall) { 3 } else { 5 }

# ----------------------------------------------------------- 1. oyunu bul

Write-Step 1 $steps "Oyun klasoru araniyor"

if ($GameDir) {
    if (-not (Test-Path -LiteralPath $GameDir -PathType Container)) {
        Write-Bad "Verdigin klasor yok: $GameDir"
        exit 1
    }
} else {
    $GameDir = Find-ScheduleOne
}

if (-not $GameDir) {
    Write-Bad "Schedule I kurulumu bulunamadi."
    Write-Host ""
    Write-Info "Oyun Steam'de kurulu degilse ya da baska bir yerdeyse,"
    Write-Info "oyunun klasorunu bu pencereye surukleyip Enter'a bas."
    Write-Host ""
    Write-Host "      Oyun klasoru: " -NoNewline
    $typed = Read-Host
    $typed = $typed.Trim().Trim('"')
    if (-not $typed -or -not (Test-Path -LiteralPath $typed -PathType Container)) {
        Write-Bad "Klasor bulunamadi, kurulum durduruldu."
        exit 1
    }
    $GameDir = $typed
}

Write-Ok $GameDir
if (-not (Test-Path (Join-Path $GameDir 'Schedule I.exe'))) {
    Write-Host "      Uyari: bu klasorde 'Schedule I.exe' yok. Yine de devam ediliyor." -ForegroundColor Yellow
}

$modsDir = Join-Path $GameDir 'Mods'
$userDir = Join-Path $GameDir 'UserData\ScheduleOneTR'
$langDst = Join-Path $userDir 'languages\tr'

# -------------------------------------------------------------- kaldirma

if ($Uninstall) {
    Write-Step 2 $steps "Mod dosyalari kaldiriliyor"
    $removed = 0
    foreach ($dll in @('ScheduleOneTR_Il2Cpp.dll','ScheduleOneTR_Mono.dll')) {
        $p = Join-Path $modsDir $dll
        if (Test-Path $p) { Remove-Item $p -Force; Write-Ok "silindi: Mods\$dll"; $removed++ }
    }
    if ($removed -eq 0) { Write-Info "Mods klasorunde mod dosyasi bulunamadi." }

    Write-Step 3 $steps "Ceviri dosyalari"
    if (Test-Path $userDir) {
        Write-Info "Ceviriler ve toplanan metinler SILINMEDI:"
        Write-Info "  $userDir"
        Write-Info "Tamamen temizlemek istersen bu klasoru elle sil."
    } else {
        Write-Info "Ceviri klasoru yok."
    }
    Write-Host ""
    Write-Host "  Yama kaldirildi. Oyun artik Ingilizce acilacak." -ForegroundColor Green
    exit 0
}

# ------------------------------------------------------- 2. MelonLoader

Write-Step 2 $steps "MelonLoader denetleniyor"

$ml6  = Join-Path $GameDir 'MelonLoader\net6\MelonLoader.dll'
$ml35 = Join-Path $GameDir 'MelonLoader\net35\MelonLoader.dll'
$hasMl = (Test-Path $ml6) -or (Test-Path $ml35)

if ($hasMl) {
    Write-Ok "kurulu"
} else {
    Write-Bad "MelonLoader kurulu degil."
    Write-Host ""
    Write-Info "Bu yama MelonLoader uzerinde calisiyor. Once onu kurmak gerekiyor;"
    Write-Info "tek seferlik bir islem."
    Write-Host ""

    $bundled = Join-Path $here 'MelonLoader.Installer.exe'
    if (Test-Path $bundled) {
        Write-Info "MelonLoader kurucusu bu pakette var. Simdi acilsin mi?"
        Write-Host "      (E / H): " -NoNewline
        if ((Read-Host).Trim().ToUpperInvariant() -eq 'E') {
            Write-Info "Kurucu aciliyor. Oyun olarak Schedule I'i secip kur,"
            Write-Info "sonra bu pencereye donup Enter'a bas."
            Start-Process $bundled | Out-Null
            Read-Host "      Kurulum bitince Enter" | Out-Null
            $hasMl = (Test-Path $ml6) -or (Test-Path $ml35)
            if ($hasMl) { Write-Ok "MelonLoader kuruldu" }
        }
    } else {
        Write-Info "Indirme sayfasi aciliyor: github.com/LavaGang/MelonLoader/releases"
        Start-Process 'https://github.com/LavaGang/MelonLoader/releases/latest' | Out-Null
        Write-Info "MelonLoader 0.7.3'u kur, sonra KUR.cmd'yi tekrar calistir."
    }

    if (-not $hasMl) {
        Write-Host ""
        Write-Host "  Kurulum yarida kaldi: once MelonLoader gerekiyor." -ForegroundColor Yellow
        exit 2
    }
}

# IL2CPP mi Mono mu?
$isMono = (Test-Path $ml35) -and -not (Test-Path $ml6)
$wantDll = if ($isMono) { 'ScheduleOneTR_Mono.dll' } else { 'ScheduleOneTR_Il2Cpp.dll' }
Write-Info ("oyun surumu: " + $(if ($isMono) { 'Mono (alternate dal)' } else { 'IL2CPP (ana dal)' }))

# ------------------------------------------------------------ 3. mod DLL

Write-Step 3 $steps "Mod dosyasi kopyalaniyor"

# DLL iki yerde olabilir: hazir pakette mod\ altinda, depodan
# calistirildiginda ise derleme ciktisinda.
$cfg = if ($isMono) { 'Mono' } else { 'IL2CPP' }
$srcDll = @(
    (Join-Path $here "mod\$wantDll"),
    (Join-Path $here "src\ScheduleOneTR\bin\$cfg\$wantDll")
) | Where-Object { Test-Path $_ } | Select-Object -First 1

if (-not $srcDll) {
    $have = @(
        foreach ($d in @((Join-Path $here 'mod'), (Join-Path $here 'src\ScheduleOneTR\bin'))) {
            if (Test-Path $d) {
                Get-ChildItem $d -Filter '*.dll' -File -Recurse -ErrorAction SilentlyContinue |
                    ForEach-Object { $_.Name }
            }
        }
    ) | Select-Object -Unique

    # Depo klasorunden calistirildiysa sorun paket degil, mod derlenmemis.
    $isRepo = Test-Path (Join-Path $here 'src\ScheduleOneTR\ScheduleOneTR.csproj')

    if ($isRepo) {
        # Kaynak kodu elimizde: dal uymasa bile burada derleyebiliriz.
        Write-Info "Mod bu makine icin henuz derlenmemis."
        Write-Info "Simdi derlenebilir; gereken her sey otomatik indirilir."
        Write-Info "Ilk sefer 5-15 dakika surebilir."
        Write-Host ""
        Write-Host "      Derlensin mi? (E / H): " -NoNewline
        if ((Read-Host).Trim().ToUpperInvariant() -eq 'E') {
            $bootstrap = Join-Path $PSScriptRoot 'bootstrap_build.ps1'
            if (-not (Test-Path $bootstrap)) {
                Write-Bad "Derleme betigi yok: $bootstrap"
                exit 3
            }
            $bsArgs = @{ GameDir = $GameDir }
            if ($isMono) { $bsArgs['Mono'] = $true }
            & $bootstrap @bsArgs
            if ($LASTEXITCODE -ne 0) { exit 3 }

            $srcDll = Join-Path $here "src\ScheduleOneTR\bin\$cfg\$wantDll"
            if (-not (Test-Path $srcDll)) {
                Write-Bad "Derleme bitti ama DLL bulunamadi."
                exit 3
            }
        } else {
            Write-Host ""
            Write-Host "  Kurulum yarida kaldi: mod derlenmedi." -ForegroundColor Yellow
            exit 3
        }
    } elseif ($have.Count -eq 0) {
        Write-Bad "Pakette mod dosyasi yok."
        Write-Info "Paket eksik indirilmis olabilir. Yeniden indir."
    } else {
        $branch = if ($isMono) { 'alternate' } else { 'ana' }
        $otherBranch = if ($isMono) { 'ana' } else { 'alternate' }
        Write-Bad "Bu paket senin oyun surumune uygun degil."
        Write-Info ""
        Write-Info "Sen Steam'in '$branch' dalini kullaniyorsun, paket ise"
        Write-Info "'$otherBranch' dal icin hazirlanmis ($($have -join ', '))."
        Write-Info ""
        Write-Info "Iki cozum var:"
        Write-Info "  1. Steam'de oyuna sag tik > Ozellikler > Beta'lar bolumunden"
        Write-Info "     '$otherBranch' dala gec (ana dal icin beta secimini kaldir)."
        Write-Info "  2. Ya da bize haber ver, '$branch' dal icin paket hazirlayalim."
    }
    # Derleme yukarida basariliysa $srcDll dolmustur; dolmadiysa cikiyoruz.
    if (-not $srcDll) { exit 3 }
}

New-Item -ItemType Directory -Path $modsDir -Force | Out-Null

# Diger surumun DLL'i varsa kaldir: ikisi birden olmamali.
$other = if ($isMono) { 'ScheduleOneTR_Il2Cpp.dll' } else { 'ScheduleOneTR_Mono.dll' }
$otherPath = Join-Path $modsDir $other
if (Test-Path $otherPath) {
    Remove-Item $otherPath -Force
    Write-Info "yanlis surum kaldirildi: $other"
}

try {
    Copy-Item $srcDll (Join-Path $modsDir $wantDll) -Force
} catch {
    Write-Bad "Kopyalanamadi: $($_.Exception.Message)"
    Write-Info "Oyun acik olabilir. Oyunu kapatip tekrar dene."
    exit 3
}
Write-Ok "Mods\$wantDll"

# ------------------------------------------------------- 4. ceviri dosyalari

Write-Step 4 $steps "Ceviri dosyalari kopyalaniyor"

$srcLang = Join-Path $here 'languages\tr'
if (-not (Test-Path $srcLang)) {
    Write-Bad "Pakette ceviri klasoru yok: languages\tr"
    exit 4
}

New-Item -ItemType Directory -Path $langDst -Force | Out-Null
$files = @(Get-ChildItem $srcLang -Filter *.txt -File)
if ($files.Count -eq 0) {
    Write-Bad "Pakette hic ceviri dosyasi yok."
    exit 4
}
foreach ($f in $files) {
    Copy-Item $f.FullName (Join-Path $langDst $f.Name) -Force
}
$lineCount = 0
foreach ($f in $files) {
    $lineCount += @([System.IO.File]::ReadAllLines($f.FullName, [System.Text.Encoding]::UTF8) |
                    Where-Object { $_ -match '^\s*\d*\s*\|?.*=.' -and $_ -notmatch '^\s*(//|@)' }).Count
}
Write-Ok "$($files.Count) dosya, yaklasik $lineCount cevrili satir"
Write-Info "konum: UserData\ScheduleOneTR\languages\tr"

# ----------------------------------------------------------------- 5. ozet

Write-Step 5 $steps "Hazir"

Write-Host ""
Write-Host "  KURULUM TAMAM" -ForegroundColor Green
Write-Host ""
Write-Host "  Simdi ne yapacaksin:" -ForegroundColor White
Write-Host "    1. Oyunu Steam'den normal sekilde baslat."
Write-Host "    2. Ilk acilis uzun surebilir, bu normal. Siyah ekranda bekle."
Write-Host "    3. Menuler Turkce gelmeli."
Write-Host ""
Write-Host "  Oyun icinde:" -ForegroundColor White
Write-Host "    F10  -  ceviriyi kapat/ac (Ingilizce ile karsilastirmak icin)"
Write-Host "    F9   -  ceviri dosyalarini yeniden yukle"
Write-Host ""
Write-Host "  Bir sey ters giderse:" -ForegroundColor White
Write-Host "    - Oyun acilmiyorsa KALDIR.cmd'yi calistir, oyun eski haline doner."
Write-Host "    - Harfler kare kare cikiyorsa haber ver (font sorunu)."
Write-Host "    - Ingilizce kalan yazilari EKSIK_METINLER.cmd ile toplayip gonder."
Write-Host ""
