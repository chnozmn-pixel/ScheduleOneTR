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
    [switch]$Uninstall,
    # Oyun guncellendikten sonra: eski DLL'i yok sayip bastan derler.
    # Oyun guncellenince MelonLoader'in urettigi assembly'ler degisiyor,
    # onlara karsi derlenmis eski mod artik uymayabiliyor.
    [switch]$Force
)

$ErrorActionPreference = 'Stop'
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

$here = Split-Path $PSScriptRoot -Parent      # paketin kok klasoru
. "$PSScriptRoot\_common.ps1"

# Ekrana yazilan her sey dosyaya da gitsin: sorun ciktiginda kullanici
# ekran goruntusu yerine bu dosyayi gonderiyor.
$logFile = Join-Path $here 'kurulum-log.txt'
try {
    Start-Transcript -Path $logFile -Force | Out-Null
    $logging = $true
} catch {
    $logging = $false
}

$startedAt = Get-Date

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
Write-Host ""
Write-Detail "tarih      : $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
Write-Detail "paket      : $here"
Write-Detail "windows    : $([Environment]::OSVersion.Version) / $(if ([Environment]::Is64BitOperatingSystem) { '64 bit' } else { '32 bit' })"
Write-Detail "powershell : $($PSVersionTable.PSVersion)"
Write-Detail "kullanici  : $(if (([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) { 'yonetici' } else { 'normal' })"
if ($logging) { Write-Detail "gunluk     : $logFile" }
if ($Force)   { Write-Detail "kip        : -Force (bastan derleme)" }

$steps = if ($Uninstall) { 3 } else { 6 }

# Steam uzerinden baslatmak icin (oyunun Steam kimligi)
$APPID = '3164500'

# ----------------------------------------------------------- 1. oyunu bul

Write-Step 1 $steps "Oyun klasoru araniyor"

if ($GameDir) {
    Write-Detail "klasor elle verildi, arama yapilmiyor"
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
$exePath = Join-Path $GameDir 'Schedule I.exe'
if (Test-Path $exePath) {
    $exe = Get-Item $exePath
    Write-Detail ("Schedule I.exe: {0:N1} MB, {1:yyyy-MM-dd}" -f ($exe.Length/1MB), $exe.LastWriteTime)
    $ver = $exe.VersionInfo.FileVersion
    if ($ver) { Write-Detail "exe surumu: $ver" }
} else {
    Write-Host "      Uyari: bu klasorde 'Schedule I.exe' yok. Yine de devam ediliyor." -ForegroundColor Yellow
}
$proc = @(Get-Process -Name 'Schedule I' -ErrorAction SilentlyContinue)
Write-Detail ("oyun su an " + $(if ($proc.Count -gt 0) { 'ACIK' } else { 'kapali' }))

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
Write-Detail "bakilan: $ml6"
Write-Detail "  -> $(if (Test-Path $ml6) { 'var' } else { 'yok' })"
Write-Detail "bakilan: $ml35"
Write-Detail "  -> $(if (Test-Path $ml35) { 'var' } else { 'yok' })"
$hasMl = (Test-Path $ml6) -or (Test-Path $ml35)

if ($hasMl) {
    $mlDll = if (Test-Path $ml6) { $ml6 } else { $ml35 }
    $mlVer = (Get-Item $mlDll).VersionInfo.FileVersion
    Write-Ok "kurulu$(if ($mlVer) { " (surum $mlVer)" })"
    $verDll = Join-Path $GameDir 'version.dll'
    Write-Detail "version.dll: $(if (Test-Path $verDll) { 'var' } else { 'YOK - oyun MelonLoader ile acilmaz' })"
} else {
    Write-Info "MelonLoader kurulu degil, simdi kuruluyor."
    Write-Info "Bu yamanin calismasi icin gerekli; tek seferlik."
    Write-Host ""

    $mlScript = Join-Path $PSScriptRoot 'install_melonloader.ps1'
    if (-not (Test-Path $mlScript)) {
        Write-Bad "Kurulum betigi yok: $mlScript"
        exit 2
    }

    & $mlScript -GameDir $GameDir
    if ($LASTEXITCODE -ne 0) {
        Write-Host ""
        Write-Host "  Kurulum yarida kaldi: MelonLoader kurulamadi." -ForegroundColor Yellow
        exit 2
    }

    $hasMl = (Test-Path $ml6) -or (Test-Path $ml35)
    if (-not $hasMl) {
        Write-Bad "MelonLoader kuruldu gorunuyor ama dosyalar bulunamadi."
        exit 2
    }
    Write-Ok "kuruldu"
}

# IL2CPP mi Mono mu?
$isMono = (Test-Path $ml35) -and -not (Test-Path $ml6)
$wantDll = if ($isMono) { 'ScheduleOneTR_Mono.dll' } else { 'ScheduleOneTR_Il2Cpp.dll' }
Write-Info ("oyun surumu: " + $(if ($isMono) { 'Mono (alternate dal)' } else { 'IL2CPP (ana dal)' }))

# --------------------------------------------- 3. ilk acilis / assembly'ler

Write-Step 3 $steps "Oyun dosyalari hazirlaniyor"

# IL2CPP'de mod, MelonLoader'in urettigi Il2CppAssemblies'e karsi derleniyor.
# Bu klasor ancak oyun MelonLoader ile BIR KEZ acildiktan sonra olusuyor.
$asmDir = Join-Path $GameDir 'MelonLoader\Il2CppAssemblies'

function Get-AsmCount {
    if (-not (Test-Path $asmDir)) { return 0 }
    return @(Get-ChildItem $asmDir -Filter *.dll -File -ErrorAction SilentlyContinue).Count
}

Write-Detail "bakilan: $asmDir"

if ($isMono) {
    Write-Ok "Mono dali, bu adim gerekmiyor"
    Write-Detail "Mono'da referanslar 'Schedule I_Data\Managed' icinden geliyor"
} elseif ((Get-AsmCount) -gt 20) {
    $n = Get-AsmCount
    Write-Ok "hazir ($n dosya)"
    $newest = Get-ChildItem $asmDir -Filter *.dll -File |
              Sort-Object LastWriteTime -Descending | Select-Object -First 1
    Write-Detail "en yeni dosya: $($newest.Name) - $($newest.LastWriteTime.ToString('yyyy-MM-dd HH:mm'))"
    if (Test-Path $exePath) {
        if ($newest.LastWriteTime -lt (Get-Item $exePath).LastWriteTime) {
            Write-Host "      Uyari: bu dosyalar oyundan eski. Oyun guncellenmis" -ForegroundColor Yellow
            Write-Host "      olabilir; ceviri bozuksa GUNCELLE.cmd calistir." -ForegroundColor Yellow
        } else {
            Write-Detail "dosyalar oyundan yeni, uyumlu gorunuyor"
        }
    }
} else {
    Write-Info "Oyunun bir kez acilmasi gerekiyor: MelonLoader ilk acilista"
    Write-Info "yamanin derlenmesi icin gereken dosyalari uretiyor."
    Write-Info "Bu acilis 5-15 dakika surebilir, siyah ekranda bekle."
    Write-Host ""
    Write-Host "      Oyun simdi baslatilsin mi? (E / H): " -NoNewline

    if ((Read-Host).Trim().ToUpperInvariant() -ne 'E') {
        Write-Host ""
        Write-Host "  Kurulum yarida kaldi." -ForegroundColor Yellow
        Write-Info "Oyunu kendin acip ana menuyu gorduktan sonra kapat,"
        Write-Info "sonra KUR.cmd'yi tekrar calistir."
        exit 5
    }

    Write-Detail "calistirilan: steam://rungameid/$APPID"
    Start-Process "steam://rungameid/$APPID"
    Write-Host ""
    Write-Info "Oyun baslatiliyor. Ana menuyu gorunce oyunu KAPAT."
    Write-Info "Bu pencere kendiliginden devam edecek, kapatma."
    Write-Host ""

    # Dosyalar olusana kadar bekle (en fazla 30 dakika)
    $waitStart = Get-Date
    $limit     = $waitStart.AddMinutes(30)
    $last      = -1
    $lastTick  = Get-Date
    while ((Get-Date) -lt $limit) {
        Start-Sleep -Seconds 5
        $n = Get-AsmCount
        $gecen = [int]((Get-Date) - $waitStart).TotalSeconds
        $acik  = @(Get-Process -Name 'Schedule I' -ErrorAction SilentlyContinue).Count -gt 0

        # Sayi degisince ya da 60 saniyede bir yaz: ekran donmus gorunmesin
        if ($n -ne $last -or ((Get-Date) - $lastTick).TotalSeconds -ge 60) {
            $dk = [int]($gecen / 60); $sn = $gecen % 60
            Write-Host ("      {0,3}:{1:00} gecti | uretilen dosya: {2,5} | oyun: {3}" -f `
                        $dk, $sn, $n, $(if ($acik) { 'acik' } else { 'henuz acilmadi' }))
            $last = $n
            $lastTick = Get-Date
        }
        if ($n -gt 20) {
            # Sayi artmayi birakinca is bitmis demektir
            Start-Sleep -Seconds 10
            if ((Get-AsmCount) -eq $n) { break }
        }
    }
    Write-Host ""

    if ((Get-AsmCount) -le 20) {
        Write-Host ""
        Write-Bad "Dosyalar uretilmedi."
        Write-Info "Oyunu elle acip ana menuyu gor, kapat, sonra KUR.cmd'yi"
        Write-Info "tekrar calistir."
        exit 5
    }
    Write-Ok "hazir ($(Get-AsmCount) dosya)"
    Write-Detail ("bekleme suresi: {0:N1} dakika" -f ((Get-Date) - $waitStart).TotalMinutes)

    # Oyun aciksa derleme ve kopyalama sirasinda dosya kilitlenmesin
    $proc = @(Get-Process -Name 'Schedule I' -ErrorAction SilentlyContinue)
    if ($proc.Count -gt 0) {
        Write-Host ""
        Write-Info "Devam etmek icin oyunu kapat. Bekliyorum..."
        $kapandi = Get-Date
        while (@(Get-Process -Name 'Schedule I' -ErrorAction SilentlyContinue).Count -gt 0) {
            Start-Sleep -Seconds 3
            $g = [int]((Get-Date) - $kapandi).TotalSeconds
            if ($g % 30 -lt 3) { Write-Detail "hala acik ($g saniyedir bekleniyor)" }
        }
        Write-Ok "oyun kapandi"
    }
}

# ------------------------------------------------------------ 4. mod DLL

Write-Step 4 $steps "Mod dosyasi kopyalaniyor"

# DLL iki yerde olabilir: hazir pakette mod\ altinda, depodan
# calistirildiginda ise derleme ciktisinda.
$cfg = if ($isMono) { 'Mono' } else { 'IL2CPP' }

# -Force: oyun guncellendi, eski derleme gecersiz olabilir. Kaynak kod
# varsa onbellegi silip bastan derliyoruz.
if ($Force -and (Test-Path (Join-Path $here 'src\ScheduleOneTR\ScheduleOneTR.csproj'))) {
    Write-Info "yeniden derleme istendi, eski ciktilar siliniyor"
    foreach ($d in @('src\ScheduleOneTR\bin', 'src\ScheduleOneTR\obj')) {
        $p = Join-Path $here $d
        if (Test-Path $p) {
            Write-Detail "siliniyor: $d"
            Remove-Item $p -Recurse -Force -ErrorAction SilentlyContinue
        } else {
            Write-Detail "zaten yok: $d"
        }
    }
}

Write-Detail "aranan dosya adi: $wantDll ($cfg)"
$aday = @(
    (Join-Path $here "mod\$wantDll"),
    (Join-Path $here "src\ScheduleOneTR\bin\$cfg\$wantDll")
)
foreach ($a in $aday) { Write-Detail "aday: $a -> $(if (Test-Path $a) { 'VAR' } else { 'yok' })" }
$srcDll = $aday | Where-Object { Test-Path $_ } | Select-Object -First 1

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

$dllInfo = Get-Item $srcDll
Write-Detail "kaynak : $srcDll"
Write-Detail ("boyut  : {0:N1} KB, derlenme: {1:yyyy-MM-dd HH:mm}" -f ($dllInfo.Length/1KB), $dllInfo.LastWriteTime)
Write-Detail "hedef  : $(Join-Path $modsDir $wantDll)"
try {
    Copy-Item $srcDll (Join-Path $modsDir $wantDll) -Force
} catch {
    Write-Bad "Kopyalanamadi: $($_.Exception.Message)"
    Write-Info "Oyun acik olabilir. Oyunu kapatip tekrar dene."
    exit 3
}
Write-Ok "Mods\$wantDll"

$digerModlar = @(Get-ChildItem $modsDir -Filter *.dll -File |
                 Where-Object { $_.Name -ne $wantDll })
if ($digerModlar.Count -gt 0) {
    Write-Detail "Mods klasorundeki diger modlar: $($digerModlar.Name -join ', ')"
}

# ------------------------------------------------------- 4. ceviri dosyalari

Write-Step 5 $steps "Ceviri dosyalari kopyalaniyor"

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
Write-Detail "kaynak: $srcLang"
Write-Detail "hedef : $langDst"
$lineCount = 0
foreach ($f in $files) {
    Copy-Item $f.FullName (Join-Path $langDst $f.Name) -Force
    $n = @([System.IO.File]::ReadAllLines($f.FullName, [System.Text.Encoding]::UTF8) |
           Where-Object { $_ -match '^\s*\d*\s*\|?.*=.' -and $_ -notmatch '^\s*(//|@)' }).Count
    $lineCount += $n
    Write-Detail ("{0,-22} {1,6} satir, {2,6:N0} KB" -f $f.Name, $n, ($f.Length/1KB))
}
Write-Ok "$($files.Count) dosya, yaklasik $lineCount cevrili satir"
Write-Info "konum: UserData\ScheduleOneTR\languages\tr"

# Onceki oyunlardan kalan metin dokumu varsa soyleyelim
$dumpFile = Join-Path $userDir 'export\english_strings.txt'
if (Test-Path $dumpFile) {
    $d = Get-Item $dumpFile
    Write-Detail ("onceki metin dokumu var: {0:N0} KB, {1:yyyy-MM-dd HH:mm}" -f ($d.Length/1KB), $d.LastWriteTime)
}

# ----------------------------------------------------------------- 5. ozet

Write-Step 6 $steps "Hazir"

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
Write-Host "    - Oyun guncellendiyse GUNCELLE.cmd'yi calistir."
Write-Host "    - Harfler kare kare cikiyorsa haber ver (font sorunu)."
Write-Host "    - Ingilizce kalan yazilari EKSIK_METINLER.cmd ile toplayip gonder."
Write-Host ""
Write-Host "  Kurulum ozeti:" -ForegroundColor White
Write-Host "    oyun     : $GameDir"
Write-Host "    mod      : Mods\$wantDll"
Write-Host "    ceviri   : $($files.Count) dosya / $lineCount satir"
Write-Host ("    sure     : {0:N1} dakika" -f ((Get-Date) - $startedAt).TotalMinutes)
if ($logging) {
    Write-Host "    gunluk   : $logFile"
    Write-Host ""
    Write-Host "  Sorun olursa bu gunluk dosyasini gonder." -ForegroundColor White
}
Write-Host ""

if ($logging) { try { Stop-Transcript | Out-Null } catch { } }
