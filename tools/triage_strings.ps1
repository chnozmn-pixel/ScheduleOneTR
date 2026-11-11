<#
    Cikarilan listeyi oncelik kovalarina ayirir.

    extract_strings.ps1 oyun dosyalarindaki BUTUN metin sabitlerini dokuyor.
    Bunlarin onemli bir kismi ekranda hic gorunmez: .NET istisna metinleri,
    Unity motor uyarilari, dil/yerel kodlari, CSS renk adlari, derleyici
    tanitici adlari. 16 bin satirin tamamini cevirmek bos emek.

    Bu betik hicbir seyi silmez; uc dosyaya ayirir:

        01_oncelikli.txt   oyun arayuzu olmasi cok muhtemel  -> buradan basla
        02_belki.txt       belirsiz, sonra bakilir
        99_atilan.txt      gurultu oldugu dusunulenler (denetim icin)

    Kullanim:
        .\tools\triage_strings.ps1 -In extracted\english_strings.txt
        .\tools\triage_strings.ps1 -In ... -Out ayrilmis

    Siniflandirma kusurludur. Bir sey yanlis kovaya dustuyse 99_atilan.txt'e
    bakip elle tasiyabilirsin; satir bicimi her uc dosyada ayni.
#>
[CmdletBinding()]
param(
    [string]$In = 'extracted\english_strings.txt',
    [string]$Out = 'ayrilmis'
)

$ErrorActionPreference = 'Stop'
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

if (-not (Test-Path -LiteralPath $In -PathType Leaf)) {
    Write-Host "HATA: girdi dosyasi yok: $In" -ForegroundColor Red
    Write-Host 'Once extract.cmd calistir.' -ForegroundColor Yellow
    exit 1
}

# ------------------------------------------------------------------ desenler

# Kesin gurultu: motor/kutuphane izi tasiyanlar.
$DROP = @(
    # Unity / UIElements / TMP tip ve bilesen adlari
    'Mesh|Shader|Texture|Collider|Rigidbody|Quaternion|Raycast|GameObject|MonoBehaviour',
    'VisualElement|UIElements|UIDropdownContent|RectTransform|Canvas|Sprite|Coroutine',
    'InputField \(TMP\)|\(TMP\)|TextMeshPro|Animator|AudioSource|ScriptableObject',
    # .NET / BCL istisna ve API metinleri
    'operation is not supported|Argument types do not match|Can ?not convert',
    '^(Argument|Index|Object reference|Specified|The given|Unsupported|Not supported)\b',
    '^(Cannot set|Cannot convert|Cannot read|Cannot write|Cannot create|Cannot access)\b',
    'Request header|Guid|Enumerator|IEnumerable|Dictionary|KeyValuePair|Nullable',
    # ag / kriptografi / HTTP kutuphane metinleri
    'ASN\.|X509|Certificate|Cryptograph|SSL|TLS|Socket|\bUri\b|\bHTTP\b|Gateway|Proxy',
    '^(Request|Response) (Entity|Timeout|Header|Too|URI)|^Length Required$|^Not Modified$',
    # null denetimi log satirlari: "Route is null!", "Property data is null!"
    'is null!?$|was null!?$|cannot be null',
    # Unity yazi tipi / stil ic detaylari
    'StyleProperty|Pixel Range|\bAtlas\b|\bGlyph\b|Kerning|Font Asset|Sub ?Mesh',
    # kod tanitici / bicim izi
    '\{\{\d+\}\}',          # {{0}} - log bicim kacisi
    '::|->|=>|\(\)|\[\]',
    '^(typeof|concat|substr|parseInt|toString|valueOf|push|pop|slice|splice)$',
    # tek basina kucuk harfli tanitici: 'namespace', 'predicate', 'dpshadx',
    # 'padding-box', 'space-between'. Oyun arayuzu metinleri boyle gorunmez.
    # (Gercekten UI olan bir kelime buraya duserse 99_atilan.txt'de gorunur.)
    '(?-i)^[a-z][a-z0-9_]*$',
    '(?-i)^[a-z][a-z0-9]*(-[a-z0-9]+)+$',
    '^(Abs|Acos|Asin|Atan|Ceil|Cos|Exp|Floor|Log|Pow|Round|Sign|Sin|Sqrt|Tan)\d*$',
    # dil / yerel kodlari
    '(?-i)^[a-z]{2,3}(-[A-Za-z]{2,8}){1,2}$',
    # CSS renk adlari
    '(?-i)^(alice|antique|aqua|azure|beige|bisque|black|blanched|blue|blueviolet|brown|burly|cadet|chartreuse|chocolate|coral|cornflower|cornsilk|crimson|cyan|dark|deep|dim|dodger|firebrick|floral|forest|fuchsia|gainsboro|ghost|gold|goldenrod|gray|grey|green|honeydew|hot|indian|indigo|ivory|khaki|lavender|lawn|lemon|light|lime|linen|magenta|maroon|medium|midnight|mint|misty|moccasin|navajo|navy|old|olive|orange|orchid|pale|papaya|peach|peru|pink|plum|powder|purple|rebecca|red|rosy|royal|saddle|salmon|sandy|sea|seashell|sienna|silver|sky|slate|snow|spring|steel|tan|teal|thistle|tomato|turquoise|violet|wheat|white|yellow)[a-z]*$'
)

# Oyun sozlugu: bu kelimeleri tasiyan satir oncelikli kabul edilir.
$GAME = 'cash|money|dealer|customer|deal\b|property|police|cop\b|arrest|quest|phone|' +
        'inventory|backpack|weed|meth|cocaine|dose|mix|stash|rent|employee|botanist|' +
        'chemist|handler|cleaner|cartel|supplier|shop|store|buy|sell|sold|purchase|' +
        'sleep|bed|day\b|hour|van|truck|car\b|gas|key|door|lock|craft|press|dry|' +
        'pot|soil|seed|plant|harvest|trash|bin|safe|atm|bank|launder|debt|level|' +
        'rank|xp\b|reputation|energy|health|stamina|hunger|skill|upgrade|unlock|' +
        'mission|objective|task|reward|item|price|cost|profit|loss|quality|effect'

# Arayuz isareti: yer tutucu, TMP etiketi, tus adi.
$UIMARK = '\{\d+\}|<b>|<i>|<color|<size|<sprite|^\[.{1,12}\]$'

function Test-Any([string]$s, [string[]]$pats) {
    foreach ($p in $pats) { if ($s -imatch $p) { return $true } }
    return $false
}

# ------------------------------------------------------------------- ayristir

$header = New-Object 'System.Collections.Generic.List[string]'
$rows   = New-Object 'System.Collections.Generic.List[string]'   # anahtar=deger (numarasiz)

foreach ($line in [System.IO.File]::ReadAllLines($In, [System.Text.Encoding]::UTF8)) {
    $t = $line.Trim()
    if ($t.Length -eq 0) { continue }
    if ($t.StartsWith('//') -or $t.StartsWith('@')) { $header.Add($line); continue }
    $rows.Add(($t -replace '^\d+\s*\|',''))
}

Write-Host "Girdi: $In"
Write-Host "  $($rows.Count) satir okundu"

$pri = New-Object 'System.Collections.Generic.List[string]'
$may = New-Object 'System.Collections.Generic.List[string]'
$dropped = New-Object 'System.Collections.Generic.List[string]'

foreach ($row in $rows) {
    # anahtar = esittirin solu (kacirilmis esittir anahtarin parcasi)
    $sep = -1; $i = 0
    while ($i -lt $row.Length) {
        if ($row[$i] -eq '\') { $i += 2; continue }
        if ($row[$i] -eq '=') { $sep = $i; break }
        $i++
    }
    $key = if ($sep -ge 0) { $row.Substring(0, $sep) } else { $row }

    if (Test-Any $key $DROP)      { $dropped.Add($row); continue }
    if ($key -imatch $GAME)       { $pri.Add($row); continue }
    if ($key -match $UIMARK)      { $pri.Add($row); continue }

    # Kisa etiket / dugme yazisi: "Continue", "Brick Press", "Evading arrest".
    #
    # DIKKAT: -cmatch sart. PowerShell'in -match'i buyuk/kucuk harf ayirmaz,
    # yani '^[A-Z]' her harfi yakalar ve 'padding-box', 'tcf' gibi kod
    # parcalari oncelikli kovaya duser.
    $wordCount = @($key -split '\s+' | Where-Object { $_.Length -gt 0 }).Count
    if ($key.Length -le 28 -and
        $key -cmatch '^[A-Z]' -and          # gercekten buyuk harfle basliyor
        $wordCount -le 5 -and
        $key -notmatch '\.$' -and           # nokta ile biten = cumle, UI etiketi degil
        $key -notmatch '[{}<>\\/|:]') {
        $pri.Add($row); continue
    }
    $may.Add($row)
}

# ----------------------------------------------------------------------- yaz

if (-not [System.IO.Path]::IsPathRooted($Out)) {
    $Out = Join-Path (Get-Location).Path $Out
}
New-Item -ItemType Directory -Path $Out -Force | Out-Null

$utf8NoBom = New-Object System.Text.UTF8Encoding($false)

function Write-Bucket($path, $title, $note, $items, $withHeader) {
    $sw = New-Object System.IO.StreamWriter($path, $false, $utf8NoBom)
    try {
        $sw.NewLine = "`n"
        $sw.WriteLine("// $title")
        $sw.WriteLine("// $note")
        $sw.WriteLine("// $($items.Count) satir")
        $sw.WriteLine('//')
        if ($withHeader) {
            $sw.WriteLine('@name=Turkce')
            $sw.WriteLine('@english=Turkish')
        }
        $sw.WriteLine()
        $n = 0
        foreach ($it in $items) {
            $n++
            $sw.WriteLine(('{0:00000}|{1}' -f $n, $it))
        }
    } finally { $sw.Dispose() }
}

Write-Bucket (Join-Path $Out '01_oncelikli.txt') `
    'Oncelikli - oyun arayuzu olmasi cok muhtemel' `
    'Buradan basla. Esittirin sagini doldur, sol tarafa dokunma.' $pri $true

Write-Bucket (Join-Path $Out '02_belki.txt') `
    'Belirsiz - sonra bakilir' `
    'Oyunda gorunup gorunmedigi belli degil. Oncelikli dosya bitince don.' $may $true

Write-Bucket (Join-Path $Out '99_atilan.txt') `
    'Atilanlar - gurultu oldugu dusunulenler' `
    'DENETIM ICIN. Burada olmamasi gereken bir satir gorursen elle tasi.' $dropped $false

$total = $rows.Count
Write-Host ''
Write-Host ("  01_oncelikli : {0,6}  (%{1})" -f $pri.Count, [math]::Round(100*$pri.Count/$total)) -ForegroundColor Green
Write-Host ("  02_belki     : {0,6}  (%{1})" -f $may.Count, [math]::Round(100*$may.Count/$total))
Write-Host ("  99_atilan    : {0,6}  (%{1})" -f $dropped.Count, [math]::Round(100*$dropped.Count/$total)) -ForegroundColor DarkGray
Write-Host ''
Write-Host "Yazildi: $Out"
Write-Host ''
Write-Host 'Siradaki adim: 01_oncelikli.txt dosyasini cevir, sonra oyunun'
Write-Host 'UserData\ScheduleOneTR\languages\tr\ klasorune kopyala.'
