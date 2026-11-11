<#
    Schedule I - oyun dosyalarindan Ingilizce metin cikarici (kurulum gerektirmez).

    extract_strings.py ile AYNI isi yapar, ayni ciktiyi uretir; farki sudur:
    hicbir sey kurmak gerekmez. Windows'ta hazir bulunan PowerShell 5.1 ve
    .NET Framework yeter - Python, pip, UnityPy yok.

    Iki kaynaga bakar:
      1. IL2CPP : Schedule I_Data\il2cpp_data\Metadata\global-metadata.dat
                  icindeki string literal tablosu  (Steam ana dal)
      2. Mono   : Schedule I_Data\Managed\*.dll icindeki #US heap'i
                  (Steam "alternate" dali)

    UnityPy ile yapilan asset taramasi burada YOK. IL2CPP'de type tree
    bulunmadigi icin o adim zaten neredeyse hep bos donuyordu; ihtiyac
    duyarsan Python betigini kullan.

    Kullanim:
        .\tools\extract_strings.ps1
        .\tools\extract_strings.ps1 -GameDir "C:\...\steamapps\common\Schedule I"
        .\tools\extract_strings.ps1 -Raw -Out cikti

    -GameDir vermezsen Steam kutuphanelerinden otomatik bulmaya calisir.
    Cift tiklayarak calistirmak icin depo kokundeki extract.cmd dosyasini kullan.

    Bu betik yalnizca okur; oyun dosyalarina dokunmaz.
#>
[CmdletBinding()]
param(
    [string]$GameDir,
    [string]$Out = 'extracted',
    [switch]$Raw,
    [switch]$NoShape
)

$ErrorActionPreference = 'Stop'
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

# --------------------------------------------------------------- oyun yolu

. "$PSScriptRoot\_common.ps1"
$GameDir = Resolve-GameDir $GameDir

$dataDir = Join-Path $GameDir 'Schedule I_Data'
if (-not (Test-Path -LiteralPath $dataDir -PathType Container)) {
    $cand = Get-ChildItem -LiteralPath $GameDir -Directory -Filter '*_Data' -ErrorAction SilentlyContinue |
            Select-Object -First 1
    if (-not $cand) {
        Write-Host "HATA: '*_Data' klasoru bulunamadi: $GameDir" -ForegroundColor Red
        exit 1
    }
    $dataDir = $cand.FullName
    Write-Host "Not: veri klasoru olarak $($cand.Name) kullaniliyor."
}

# ------------------------------------------------- ayristirma + filtre (C#)
#
# Binari ayristirma ve regex filtresi yuz binlerce kayit uzerinde donuyor;
# saf PowerShell'de dakikalar aliyor. Ayni kodu .NET'in kendi derleyicisiyle
# (Add-Type) derliyoruz - ek kurulum gerektirmez, saniyeler surer.

if (-not ('S1Extract' -as [type])) {
Add-Type -TypeDefinition @'
using System;
using System.Collections.Generic;
using System.Text;
using System.Text.RegularExpressions;

public class S1Result {
    public List<string> Raw = new List<string>();   // ham benzersiz
    public List<string> Kept = new List<string>();  // filtrelenmis + siralanmis
}

public static class S1Extract {

    const uint IL2CPP_MAGIC = 0xFAB11BAF;

    // ----------------------------------------------------------- IL2CPP
    //  0x00 uint32 magic   0x04 int32 version
    //  0x08 int32 stringLiteralOffset      0x0C int32 stringLiteralSize
    //  0x10 int32 stringLiteralDataOffset  0x14 int32 stringLiteralDataSize
    //  Her kayit: uint32 length, int32 dataIndex
    public static List<string> Il2Cpp(byte[] d, string name, List<string> warn) {
        var outp = new List<string>();
        if (d.Length < 24) { warn.Add(name + ": dosya cok kucuk."); return outp; }

        uint magic = BitConverter.ToUInt32(d, 0);
        int version = BitConverter.ToInt32(d, 4);
        if (magic != IL2CPP_MAGIC) {
            warn.Add(name + ": beklenmeyen magic 0x" + magic.ToString("X8") + ", atlaniyor.");
            return outp;
        }
        if (version < 24 || version > 31)
            warn.Add(name + ": metadata surumu " + version + " test edilmedi, yine de deneniyor.");

        int litOff  = BitConverter.ToInt32(d, 8);
        int litSize = BitConverter.ToInt32(d, 12);
        int datOff  = BitConverter.ToInt32(d, 16);
        int datSize = BitConverter.ToInt32(d, 20);

        if (litOff <= 0 || litSize <= 0 || datOff <= 0) {
            warn.Add(name + ": string literal tablosu bulunamadi."); return outp;
        }
        if ((long)litOff + litSize > d.Length || (long)datOff + datSize > d.Length) {
            warn.Add(name + ": tablo konumu dosya disinda; surum uyumsuz olabilir."); return outp;
        }

        int count = litSize / 8;
        for (int i = 0; i < count; i++) {
            int rec = litOff + i * 8;
            uint len = BitConverter.ToUInt32(d, rec);
            int idx  = BitConverter.ToInt32(d, rec + 4);
            if (len == 0 || len > (1 << 20)) continue;
            long start = (long)datOff + idx;
            long end = start + len;
            if (start < datOff || end > (long)datOff + datSize) continue;
            try { outp.Add(Encoding.UTF8.GetString(d, (int)start, (int)len)); } catch { }
        }
        return outp;
    }

    // ------------------------------------------------------------- Mono
    static int RvaToOffset(List<int[]> sec, int rva) {
        foreach (var s in sec) {
            int va = s[0], vs = s[1], ptr = s[2], rs = s[3];
            int span = vs > rs ? vs : rs;
            if (rva >= va && rva < va + span) return ptr + (rva - va);
        }
        return -1;
    }

    static uint ReadCompressedUInt(byte[] d, ref int p) {
        byte b = d[p];
        if ((b & 0x80) == 0) { p += 1; return b; }
        if ((b & 0xC0) == 0x80) { uint v = (uint)(((b & 0x3F) << 8) | d[p + 1]); p += 2; return v; }
        if ((b & 0xE0) == 0xC0) {
            uint v = (uint)(((b & 0x1F) << 24) | (d[p + 1] << 16) | (d[p + 2] << 8) | d[p + 3]);
            p += 4; return v;
        }
        throw new Exception("gecersiz sikistirilmis tamsayi");
    }

    // Bir .NET assembly'sinin #US (user strings) heap'i: kodda ldstr ile
    // kullanilan her metin sabiti burada durur.
    public static List<string> UserStrings(byte[] d, string name, List<string> warn) {
        var outp = new List<string>();
        try {
            if (d.Length < 0x40 || d[0] != (byte)'M' || d[1] != (byte)'Z') {
                warn.Add(name + ": PE dosyasi degil."); return outp;
            }
            int e_lfanew = BitConverter.ToInt32(d, 0x3C);
            if (e_lfanew <= 0 || e_lfanew + 4 > d.Length ||
                d[e_lfanew] != (byte)'P' || d[e_lfanew + 1] != (byte)'E' ||
                d[e_lfanew + 2] != 0 || d[e_lfanew + 3] != 0) {
                warn.Add(name + ": PE imzasi yok."); return outp;
            }

            int coff = e_lfanew + 4;
            int numSections = BitConverter.ToUInt16(d, coff + 2);
            int optSize = BitConverter.ToUInt16(d, coff + 16);
            int opt = coff + 20;

            int magic = BitConverter.ToUInt16(d, opt);
            int dd;
            if (magic == 0x10B) dd = opt + 96;        // PE32
            else if (magic == 0x20B) dd = opt + 112;  // PE32+
            else { warn.Add(name + ": bilinmeyen optional header 0x" + magic.ToString("X") + "."); return outp; }

            int cliRva = BitConverter.ToInt32(d, dd + 14 * 8);   // dizin 14 = CLI header
            if (cliRva == 0) { warn.Add(name + ": yonetilen (managed) assembly degil."); return outp; }

            var sections = new List<int[]>();
            int secStart = opt + optSize;
            for (int i = 0; i < numSections; i++) {
                int s = secStart + i * 40;
                sections.Add(new int[] {
                    BitConverter.ToInt32(d, s + 12),  // VirtualAddress
                    BitConverter.ToInt32(d, s + 8),   // VirtualSize
                    BitConverter.ToInt32(d, s + 20),  // PointerToRawData
                    BitConverter.ToInt32(d, s + 16)   // SizeOfRawData
                });
            }

            int cliOff = RvaToOffset(sections, cliRva);
            if (cliOff < 0) { warn.Add(name + ": CLI header konumlandirilamadi."); return outp; }

            int mdRva = BitConverter.ToInt32(d, cliOff + 8);
            int mdOff = RvaToOffset(sections, mdRva);
            if (mdOff < 0) { warn.Add(name + ": metadata konumlandirilamadi."); return outp; }

            if (BitConverter.ToUInt32(d, mdOff) != 0x424A5342) {
                warn.Add(name + ": metadata imzasi (BSJB) yok."); return outp;
            }

            int verLen = BitConverter.ToInt32(d, mdOff + 12);
            int pos = mdOff + 16 + ((verLen + 3) & ~3);
            pos += 2;                                        // flags
            int numStreams = BitConverter.ToUInt16(d, pos);
            pos += 2;

            int usOff = -1, usSize = 0;
            for (int i = 0; i < numStreams; i++) {
                int sOff = BitConverter.ToInt32(d, pos);
                int sSize = BitConverter.ToInt32(d, pos + 4);
                pos += 8;
                int end = pos;
                while (end < d.Length && d[end] != 0) end++;
                string sname = Encoding.ASCII.GetString(d, pos, end - pos);
                pos = end + 1;
                pos = (pos + 3) & ~3;                        // 4 bayta hizala
                if (sname == "#US") { usOff = mdOff + sOff; usSize = sSize; }
            }

            if (usOff < 0) { warn.Add(name + ": #US heap'i yok (metin sabiti yok)."); return outp; }

            int p = usOff + 1;                               // ilk bayt daima 0
            int limit = usOff + usSize;
            if (limit > d.Length) limit = d.Length;
            while (p < limit) {
                uint len;
                try { len = ReadCompressedUInt(d, ref p); } catch { break; }
                if (len == 0) continue;
                if (p + len > limit) break;
                // son bayt "ASCII disi karakter var mi" bayragi
                try { outp.Add(Encoding.Unicode.GetString(d, p, (int)len - 1)); } catch { }
                p += (int)len;
            }
            return outp;
        } catch (Exception e) {
            warn.Add(name + ": okunamadi (" + e.Message + ").");
            return outp;
        }
    }

    // ----------------------------------------------------------- filtre
    static readonly RegexOptions RO = RegexOptions.Compiled | RegexOptions.CultureInvariant;
    static readonly RegexOptions ROI = RO | RegexOptions.IgnoreCase;

    static readonly Regex[] Reject = new Regex[] {
        new Regex(@"^\s*$", RO),
        new Regex(@"^[\W\d_]+$", RO),                                 // harf yok
        new Regex(@"^(UnityEngine|System|Microsoft|Mono|TMPro|Il2Cpp)\b", RO),
        new Regex(@"^(Assets|Packages|Library|Temp)[/\\]", RO),
        new Regex(@"\.(png|jpg|jpeg|tga|psd|mat|prefab|unity|asset|anim|controller|shader|cs|dll|so|json|xml|txt|wav|mp3|ogg|ttf|otf|fbx|obj)$", ROI),
        new Regex(@"^[a-z0-9_]+(/[a-z0-9_]+)+$", ROI),                // yol benzeri
        new Regex(@"^<[^>]*>$", RO),                                  // sadece etiket
        new Regex(@"^\{[^}]*\}$", RO),                                // sadece yer tutucu
        new Regex(@"^[0-9a-fA-F]{8,}$", RO),                          // hex / hash
        new Regex(@"^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-", RO),            // guid
        new Regex(@"^(get_|set_|add_|remove_|<>|\$|__)", RO),         // derleyici uretimi
        new Regex(@"k__BackingField|MoveNext|\.ctor|\.cctor", RO),
        new Regex(@"^(https?|file|data|res)://", ROI),
        new Regex(@"^[A-Z][A-Z0-9_]{3,}$", RO),                       // SABIT_ISIM
        new Regex(@"^[a-z]+([A-Z][a-zA-Z0-9]*)+$", RO),               // camelCase tanitici
        new Regex(@"^[A-Z][a-z0-9]+([A-Z][a-zA-Z0-9]*)+$", RO),       // PascalCase tanitici
    };

    static readonly Regex HasLetter = new Regex(@"[A-Za-z]", RO);
    static readonly Regex SingleWord = new Regex(@"^[A-Za-z][A-Za-z'\-\.!?,:]*$", RO);
    static readonly Regex Numbers = new Regex(@"-?\d+(?:[.,]\d+)?", RO);
    static readonly Regex LeadIndex = new Regex(@"^\d+\s*\|", RO);

    public static bool LooksTranslatable(string s) {
        if (s.Length < 2 || s.Length > 400) return false;
        if (!HasLetter.IsMatch(s)) return false;
        if (s.IndexOf('\0') >= 0) return false;
        foreach (var rx in Reject) if (rx.IsMatch(s)) return false;
        // Icinde bosluk yoksa, en azindan gercek bir kelimeye benzesin.
        if (s.IndexOf(' ') < 0 && !SingleWord.IsMatch(s)) return false;
        return true;
    }

    // Sayilari {0}, {1}... yapar; "Day 5" ile "Day 6" tek satir olur.
    public static string ShapeNumbers(string s) {
        int i = 0;
        string shaped = Numbers.Replace(s, delegate(Match m) { return "{" + (i++) + "}"; });
        return i <= 8 ? shaped : s;
    }

    public static string EscapeKey(string s) {
        s = s.Replace("\\", "\\\\")
             .Replace("\n", "\\n")
             .Replace("\r", "\\r")
             .Replace("\t", "\\t")
             .Replace("=", "\\=");
        Match m = LeadIndex.Match(s);
        if (m.Success) {
            int e = m.Index + m.Length;
            s = s.Substring(0, e - 1) + "\\|" + s.Substring(e);
        }
        return s;
    }

    // Tekille -> filtrele -> sekillendir -> sirala
    public static S1Result Process(List<string> raw, bool shape) {
        var res = new S1Result();

        var seenRaw = new HashSet<string>(StringComparer.Ordinal);
        foreach (var r in raw) {
            if (r == null) continue;
            string s = r.Trim();
            if (s.Length == 0) continue;
            if (seenRaw.Add(s)) res.Raw.Add(s);
        }

        var seen = new HashSet<string>(StringComparer.Ordinal);
        foreach (var s in res.Raw) {
            if (!LooksTranslatable(s)) continue;
            string k = shape ? ShapeNumbers(s) : s;
            if (seen.Add(k)) res.Kept.Add(k);
        }

        res.Kept.Sort(delegate(string a, string b) {
            int c = string.Compare(a.ToLowerInvariant(), b.ToLowerInvariant(), StringComparison.Ordinal);
            return c != 0 ? c : string.Compare(a, b, StringComparison.Ordinal);
        });
        return res;
    }
}
'@
}

# ----------------------------------------------------------------- topla

$warn = New-Object 'System.Collections.Generic.List[string]'
$rawList  = New-Object 'System.Collections.Generic.List[string]'

# 1. IL2CPP
$meta = Join-Path $dataDir 'il2cpp_data\Metadata\global-metadata.dat'
if (Test-Path -LiteralPath $meta) {
    Write-Host "IL2CPP metadata okunuyor: $(Split-Path $meta -Leaf)"
    $bytes = [System.IO.File]::ReadAllBytes($meta)
    $got = [S1Extract]::Il2Cpp($bytes, (Split-Path $meta -Leaf), $warn)
    Write-Host "  $($got.Count) metin sabiti"
    $rawList.AddRange($got)
    $bytes = $null
} else {
    Write-Host 'IL2CPP metadata yok (Mono dali olabilir).'
}

# 2. Mono
$managed = Join-Path $dataDir 'Managed'
if (Test-Path -LiteralPath $managed -PathType Container) {
    $dlls = @(Join-Path $managed 'Assembly-CSharp.dll')
    $dlls += @(Get-ChildItem -LiteralPath $managed -Filter 'Assembly-CSharp-*.dll' -ErrorAction SilentlyContinue |
               Sort-Object Name | Select-Object -ExpandProperty FullName)
    $dlls += @(Get-ChildItem -LiteralPath $managed -Filter 'ScheduleOne*.dll' -ErrorAction SilentlyContinue |
               Sort-Object Name | Select-Object -ExpandProperty FullName)
    foreach ($dll in $dlls) {
        if (-not (Test-Path -LiteralPath $dll -PathType Leaf)) { continue }
        $leaf = Split-Path $dll -Leaf
        Write-Host "Managed assembly okunuyor: $leaf"
        $bytes = [System.IO.File]::ReadAllBytes($dll)
        $got = [S1Extract]::UserStrings($bytes, $leaf, $warn)
        Write-Host "  $($got.Count) metin sabiti"
        $rawList.AddRange($got)
        $bytes = $null
    }
} else {
    Write-Host 'Managed klasoru yok (IL2CPP dali).'
}

if ($rawList.Count -eq 0) {
    Write-Host ''
    Write-Host 'Hic metin cikarilamadi.' -ForegroundColor Red
    foreach ($w in $warn) { Write-Host "  ! $w" -ForegroundColor Yellow }
    exit 2
}

Write-Host 'Filtreleniyor...'
$res = [S1Extract]::Process($rawList, (-not $NoShape))
$rawList = $null

# ------------------------------------------------------------------ yaz

$outDir = $Out
if (-not [System.IO.Path]::IsPathRooted($outDir)) {
    $outDir = Join-Path (Get-Location).Path $outDir
}
New-Item -ItemType Directory -Path $outDir -Force | Out-Null

$txtPath = Join-Path $outDir 'english_strings.txt'
$csvPath = Join-Path $outDir 'english_strings.csv'

$utf8NoBom = New-Object System.Text.UTF8Encoding($false)
$sw = New-Object System.IO.StreamWriter($txtPath, $false, $utf8NoBom)
try {
    $sw.NewLine = "`n"
    $sw.WriteLine('// Schedule I - oyun dosyalarindan cikarilan Ingilizce metinler')
    $sw.WriteLine("// Kaynak: $GameDir")
    $sw.WriteLine("// Toplam: $($res.Kept.Count) satir  (ham: $($res.Raw.Count))")
    $sw.WriteLine('//')
    $sw.WriteLine('// Bicim:  SIRANO|ingilizce metin=turkce karsilik')
    $sw.WriteLine('// Esittirin SAG tarafini doldur. Sol taraf anahtar, DEGISTIRME.')
    $sw.WriteLine('// Sira numarasi sadece takip icin; mod okurken atar.')
    $sw.WriteLine('// {0} {1} yer tutucularini ve <b> <color=...> etiketlerini aynen koru.')
    $sw.WriteLine('// Bos birakilan satir cevrilmemis sayilir, oyunda Ingilizce kalir.')
    $sw.WriteLine('//')
    $sw.WriteLine('@name=Turkce')
    $sw.WriteLine('@english=Turkish')
    $sw.WriteLine()
    $i = 1
    foreach ($s in $res.Kept) {
        $sw.WriteLine(('{0:00000}|{1}=' -f $i, [S1Extract]::EscapeKey($s)))
        $i++
    }
} finally { $sw.Dispose() }

$utf8Bom = New-Object System.Text.UTF8Encoding($true)
$sw = New-Object System.IO.StreamWriter($csvPath, $false, $utf8Bom)
try {
    $sw.NewLine = "`r`n"
    $sw.WriteLine('id,source,translation')
    $i = 1
    foreach ($s in $res.Kept) {
        $q = '"' + $s.Replace('"', '""') + '"'
        $sw.WriteLine(('{0:00000},{1},' -f $i, $q))
        $i++
    }
} finally { $sw.Dispose() }

if ($Raw) {
    $rawPath = Join-Path $outDir 'all_strings.txt'
    $sw = New-Object System.IO.StreamWriter($rawPath, $false, $utf8NoBom)
    try {
        $sw.NewLine = "`n"
        foreach ($s in $res.Raw) { $sw.WriteLine($s) }
    } finally { $sw.Dispose() }
}

Write-Host ''
Write-Host "Ham benzersiz metin : $($res.Raw.Count)"
Write-Host "Cevrilmeye aday     : $($res.Kept.Count)"
Write-Host "Yazildi             : $txtPath"
Write-Host "                      $csvPath"
if ($Raw) { Write-Host "                      $(Join-Path $outDir 'all_strings.txt')" }

if ($warn.Count -gt 0) {
    Write-Host ''
    Write-Host 'Uyarilar:' -ForegroundColor Yellow
    foreach ($w in $warn) { Write-Host "  ! $w" -ForegroundColor Yellow }
}

Write-Host ''
Write-Host 'Sonraki adim: dosyadaki esittirlerin sagini doldur, sonra su klasore kopyala:'
Write-Host "  $GameDir\UserData\ScheduleOneTR\languages\tr\"
