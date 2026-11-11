# Geliştirme notları

> **Yamayı sadece kurmak istiyorsan bu dosya sana göre değil:**
> [README.md](../README.md) üç satırda anlatıyor. Burası çeviri eklemek,
> metin çıkarmak, derlemek ve paket hazırlamak içindir.

Steam AppID **3164500**, test edilen sürüm **v0.4.7**.

Mod oyunun metinlerini **çizilmeden hemen önce** yakalar ve senin yazdığın karşılıkla
değiştirir. Oyunun kendi veri modeline dokunmaz: kayıt dosyaları, çok oyunculu
senkronizasyon ve oyun mantığı İngilizce metinle çalışmaya devam eder.

Çevirilerin kendisi `languages/tr/` altında ve depoda tutuluyor; başka bir makinede
`git pull` yeterli. Mod ayrıca karşılığı olmayan **bütün İngilizce metinleri dosyaya
döküyor**, eksikler oradan besleniyor.

---

## İçerik

```
kur.ps1                          tek satırlık web kurulumu (irm ... | iex)
KUR.cmd / GUNCELLE.cmd           GitHub zip'ini indirenler için kısayollar;
KALDIR.cmd / EKSIK_METINLER.cmd    release/ altındaki asıl betikleri çağırır
extract.cmd                      metin çıkarıcı — çift tıkla, kurulum gerektirmez
merge.cmd                        yeni metinleri çeviriye ekler — aynı şekilde
build.ps1                        derleme betiği
release/                         son kullanıcı paketinin şablonları
  KUR.cmd / KALDIR.cmd           kullanıcının tıkladığı dosyalar
  GUNCELLE.cmd                   oyun güncellendikten sonra baştan derler
  EKSIK_METINLER.cmd             İngilizce kalanları toplar
  OKUBENI.txt                    kullanıcı kılavuzu
tools/make_release.ps1           derler + kullanıcı zip'ini üretir
tools/install.ps1                kurulumcunun asıl mantığı
tools/install_melonloader.ps1    MelonLoader'ı indirip oyuna kurar
tools/bootstrap_build.ps1        .NET SDK yoksa kurar, sonra derler
tools/check_translation.ps1      çeviri dosyasını denetler
languages/tr/00_main.txt         çeviri dosyası şablonu (boş)
tools/extract_strings.ps1        metin çıkarıcı (PowerShell, bağımlılık yok)
tools/extract_strings.py         aynısı + UnityPy ile asset taraması (Python)
tools/merge_export.ps1           birleştirici (PowerShell, bağımlılık yok)
tools/merge_export.py            aynısı (Python)
tools/_common.ps1                Steam kütüphanelerinden oyunu bulan yardımcı
src/ScheduleOneTR/
  ScheduleOneTR.csproj           IL2CPP + Mono yapılandırmaları
  Plugin.cs                      MelonMod girişi, ayarlar, sahne tarayıcı
  TmpHooks.cs                    TMP_Text.text ve SetText(...) Harmony yamaları
  Translator.cs                  eşleştirme motoru (birebir / şablon / etiket / regex)
  LanguageFile.cs                dil dosyası ayrıştırıcı
  StringDump.cs                  İngilizce metin dökümü
  FontFallback.cs                ğ ş ı İ için yedek font
  GlobalUsings.cs                IL2CPP / Mono tip takma adları
```

---

## 0. Son kullanıcıya paket hazırlamak

Kullanıcı hiçbir şey kurmaz, indirmez, ayar yapmaz. **Tek tıklama.**
MelonLoader, .NET SDK, derleme — hepsini `KUR.cmd` kendisi hallediyor.

### Kullanıcıya ne veriliyor

İki yol var, ikisi de aynı sonuca çıkıyor:

**GitHub'dan indirterek** (hazırlık gerektirmez) — kullanıcı depo
sayfasından **Code → Download ZIP** der, açar, kökteki `KUR.cmd`'ye çift
tıklar. Kökteki `KUR.cmd` / `KALDIR.cmd` / `GUNCELLE.cmd` /
`EKSIK_METINLER.cmd` bunun için var; `release\` altındaki asıl betiklere
yönlendiriyorlar.

**Zip hazırlayarak**

```powershell
.\tools\make_release.ps1             # DLL derleyip paketler
.\tools\make_release.ps1 -SelfBuild  # oyun olmayan makinede: kaynak kodu paketler
```

`dist\ScheduleOneTR-TR-<tarih>.zip` üretir ve çeviri dosyalarını denetler.
`-SkipBuild` mevcut DLL'i kullanır, `-Mono` alternate dal içindir. İki dalı
da derlersen ikisinin DLL'i birlikte gider, kurulumcu doğru olanı seçer.
`-SelfBuild` paketi DLL yerine kaynak kodu taşır; kullanıcının makinesinde
oyun ve MelonLoader zaten olduğu için derleme orada yapılabiliyor.

### Kullanıcının gördüğü

```
KUR.cmd              çift tıkla, kurulum biter
GUNCELLE.cmd         oyun güncellendikten sonra
KALDIR.cmd           yamayı kaldırır
EKSIK_METINLER.cmd   İngilizce kalan yazıları masaüstüne toplar
OKUBENI.txt          kullanım ve sık sorulanlar
```

### `KUR.cmd` altı adımda ne yapıyor

1. **Oyunu bulur** — Steam kayıt defteri, `libraryfolders.vdf`, Program
   Files. Bulamazsa klasörü pencereye sürüklemesini ister.
2. **MelonLoader** kurulu değilse `tools\install_melonloader.ps1`
   `MelonLoader.x64.zip`'i GitHub'dan indirip oyun klasörüne açar — pencere
   açılmaz, soru sorulmaz. Sürüm `-Version` ile değiştirilebilir.
3. **İlk açılışı yönetir** — IL2CPP'de mod, MelonLoader'ın ürettiği
   `Il2CppAssemblies`'e karşı derleniyor; o klasör ancak oyun bir kez
   açıldıktan sonra oluşuyor. Betik oyunu `steam://rungameid/3164500` ile
   başlatır, üretilen dosya sayısını izler, sayı sabitlenince devam eder,
   oyun kapanana kadar bekler.
4. **Mod yoksa derler** — `tools\bootstrap_build.ps1`. .NET SDK yoksa
   Microsoft'un resmi `dotnet-install.ps1` betiğiyle SDK 8'i paketin
   `.dotnet\` klasörüne kurar: yönetici yetkisi istemez, sisteme hiçbir şey
   yazmaz, kaldırmak için klasörü silmek yeter.
5. **Çevirileri kopyalar** — `UserData\ScheduleOneTR\languages\tr\`.
6. **Özet yazar** — kısayollar, sorun çıkarsa ne yapılacağı.

Her adım tekrar çalıştırılabilir: yapılmış olanı atlar.

### Oyun güncellenince

Steam oyunu güncellediğinde MelonLoader'ın ürettiği assembly'ler değişiyor,
onlara karşı derlenmiş eski DLL uymayabiliyor. Kullanıcı `GUNCELLE.cmd`'ye
çift tıklar: `install.ps1 -Force` çalışır, `bin\` ve `obj\` silinir, mod
baştan derlenir. Steam MelonLoader dosyalarını silmişse onlar da yeniden
kurulur.

Belirti tablosu `OKUBENI.txt`'te: oyun açılmıyor ya da çeviri tamamen
gittiyse `GUNCELLE.cmd`; sadece bazı yazılar İngilizceyse gerek yok.

> MelonLoader Apache-2.0 lisanslı; indirmek de, kurucusunu pakete koymak da
> serbest. `release/MelonLoader.Installer.exe` `.gitignore`'da — depoya
> girmez, paketleme sırasında varsa pakete eklenir.

**Geri bildirim döngüsü.** Mod, karşılığı olmayan metinleri oyun içinde
kaydediyor (`ExportEnglishStrings` varsayılan olarak açık). Kullanıcı
`EKSIK_METINLER.cmd`'yi çalıştırıp masaüstündeki dosyayı sana gönderir;
sen `merge.cmd` ile çeviriye eklersin.

---

## 1. Kurulum (test makinesinde)

1. **MelonLoader 0.7.3**'ü oyuna kur. 0.7.1 desteklenmiyor.
2. Oyunu **bir kez** başlat ve ana menüyü gör, sonra çık.
   IL2CPP'de bu ilk açılış, derleme için gereken assembly'leri üretir
   (`Schedule I\MelonLoader\Il2CppAssemblies`) ve birkaç dakika sürebilir.
3. Derlenmiş DLL'i `Schedule I\Mods\` içine koy.

> Steam'in **ana dalı IL2CPP**'dir → `ScheduleOneTR_Il2Cpp.dll`.
> `alternate` dalını kullanıyorsan Mono'dur → `ScheduleOneTR_Mono.dll`.
> İkisinden yalnızca birini koy.

---

## 1b. Başka bir makinede çalışmaya başlamak

```bash
git clone https://github.com/chnozmn-pixel/ScheduleOneTR.git
cd ScheduleOneTR
```

Gerekenler:

| | Ne için | Zorunlu mu |
|---|---|---|
| .NET SDK 8 | modu derlemek | modu derleyeceksen |
| MelonLoader 0.7.3 | modu çalıştırmak | oyunda denemek için |
| Python 3.9+ | `tools/*.py` betikleri | **hayır** — aşağıya bak |
| UnityPy | `pip install UnityPy`, sadece asset taraması | hayır |

**Sadece metin çıkarmak/çevirmek istiyorsan hiçbir şey kurmana gerek yok.**
Depo kökündeki `extract.cmd`'ye çift tıkla — Windows'ta hazır gelen PowerShell'le
çalışır, oyun klasörünü Steam kütüphanelerinden kendisi bulur. Ayrıntı: [§3a](#a-oyun-dosyalarından-çıkar-oynamadan-tek-seferde).

`Directory.Build.props` depoya dahil değil (her makinede oyun yolu farklı).
`src/ScheduleOneTR/Directory.Build.props.example`'ı kopyalayıp yolu düzelt,
ya da her derlemede `-GameDir` ver.

Çeviri dosyasını iki makine arasında senkron tutmanın en kolay yolu onu depoda
tutmak: `languages/tr/` altındaki dosyaları commit'le, diğer makinede `git pull`.

## 2. Derleme

.NET SDK 8 gerekir (IL2CPP hedefi net6.0, Mono hedefi net472).

```powershell
.\build.ps1 -GameDir "C:\Program Files (x86)\Steam\steamapps\common\Schedule I"
```

Mono dalı ve doğrudan kurulum için:

```powershell
.\build.ps1 -GameDir "C:\...\Schedule I" -Mono -Deploy
```

Yolu her seferinde yazmamak için `src/ScheduleOneTR/Directory.Build.props.example`
dosyasını `Directory.Build.props` adıyla kopyala ve içindeki yolu düzelt.

`csproj` referansları **joker ile** alır (`Il2CppAssemblies\*.dll`). Nedeni:
MelonLoader'ın ürettiği assembly adları sürümden sürüme değişiyor
(`Il2CppTMPro` / `Il2CppUnity.TextMeshPro` gibi). Derleme `TMP_Text` tipini
bulamazsa `GlobalUsings.cs` içindeki namespace'i, `Il2CppAssemblies` klasöründeki
gerçek DLL adına göre düzelt.

---

## 3. Çeviri iş akışı

Metinleri elde etmenin iki yolu var. **Birincisi asıl yöntem**, ikincisi onu tamamlar.

### a) Oyun dosyalarından çıkar (oynamadan, tek seferde)

İki eşdeğer betik var; **ikisi de aynı dosyaları üretir** (çıktıları birebir aynı).
Hangisini kullanacağın makinede ne kurulu olduğuna bağlı:

**1. Kurulum gerektirmeyen yol (önerilen).** Windows'ta hazır gelen PowerShell 5.1
ve .NET Framework yeter: Python yok, pip yok, UnityPy yok.

```powershell
.\extract.cmd
```

Çift tıklamak da olur. Oyun klasörünü Steam kütüphanelerinden (başka disklerdeki
kütüphaneler dahil) kendisi bulur; bulamazsa yolu sen verirsin:

```powershell
.\extract.cmd -GameDir "C:\...\steamapps\common\Schedule I"
```

Betiğin kendisi `tools/extract_strings.ps1`; doğrudan da çağırabilirsin
(`extract.cmd` sadece execution policy'yi aşıp `-Raw` ekleyen bir sarmalayıcı).

**2. Python yolu.** Aynı iş, artı UnityPy ile asset taraması:

```bash
python tools/extract_strings.py --game "C:\...\steamapps\common\Schedule I" --raw
```

PowerShell sürümünde asset taraması **yok** — IL2CPP'de type tree bulunmadığı için
o adım zaten neredeyse hep boş dönüyordu. Mono dalında asset'lerden de metin
toplamak istersen Python sürümünü kullan.

Her iki betik de oyunu hiç açmadan bütün metin sabitlerini toplar ve oyun
dosyalarına **dokunmaz, yalnızca okur**. Kaynaklar:

| Kaynak | Dosya | Not |
|---|---|---|
| IL2CPP string literal tablosu | `Schedule I_Data\il2cpp_data\Metadata\global-metadata.dat` | Ana dal. Ek kurulum gerektirmez. |
| Mono `#US` heap | `Schedule I_Data\Managed\Assembly-CSharp.dll` | `alternate` dalı. Ek kurulum gerektirmez. |
| TMP bileşen metinleri | `*.assets`, `level*`, bundle'lar | **Sadece Python sürümünde**, `pip install UnityPy` gerekir. IL2CPP'de type tree olmadığı için genelde boş döner; `--no-assets` ile atla. |

Çıktılar `extracted/` altında:

- `english_strings.txt` — `SIRANO|metin=` biçimi, doğrudan çeviri klasörüne kopyalanabilir
- `english_strings.csv` — `id,source,translation`, Excel / CAT aracı için
- `all_strings.txt` — `--raw` ile: filtrelenmemiş ham liste

Filtre kod kokulu metinleri eler: `UnityEngine.*`, camelCase tanıtıcılar, dosya yolları,
GUID'ler, hex, salt sayılar, sabit adları. Bir şeyin kaybolduğundan şüphelenirsen
`all_strings.txt`'e bak.

**Bu yöntemin sınırı:** metin sabitlerinin hepsi ekranda görünmez (hata mesajları, log
satırları, kullanılmayan kod da listeye girer) ve ekranda görünen her şey de sabit
değildir (bazı metinler çalışma anında birleştirilir). Yani liste hem biraz fazla, hem
biraz eksik olur. Fazlalığı çevirmesen bir şey olmaz; eksiği (b) kapatır.

### b) Oyundan topla (çalışma anında, doğrulama için)

Mod varsayılan olarak döküm modunda açılır. Oyunu oyna — menüler, telefon, görevler,
dükkânlar, diyaloglar, ne kadar çok ekran gezersen o kadar çok metin toplanır.

Çıktılar `Schedule I\UserData\ScheduleOneTR\export\` altında, 15 saniyede bir ve
oyun kapanırken yazılır:

| Dosya | Ne için |
|---|---|
| `english_strings.txt` | `metin=` biçimi. Doğrudan doldurup çeviri klasörüne kopyalanır. |
| `english_strings.csv` | `source,translation` sütunlu CSV. Excel / CAT aracı kullanacaksan. |

Döküm sırasında gürültü ayıklanır: salt sayılar, saat, para, yüzde, dosya yolları,
renk kodları ve içinde hiç harf olmayan metinler listeye girmez. Sayılar otomatik
olarak `{0}` yapılır — yani `Day 5` ve `Day 6` tek satır olur: `Day {0}=`.

### c) Çevir

`english_strings.txt`'i aç, eşittirin **sağını** doldur. Sol taraf anahtardır,
değiştirirsen eşleşme bozulur.

```
00001|Continue=Devam et
00002|Day {0}=Gün {0}
00003|<b>Cash</b>=<b>Nakit</b>
00004|r:"^Sold (.+) to (.+)$"=$2 kişisine $1 satıldı
```

Baştaki `00001|` sıra numarası **senin takibin için**; mod okurken atar, eşleştirmede
kullanılmaz. İstersen hiç yazmazsın. Kalıcı kimlik numara değil **anahtarın kendisidir**
— liste yeniden üretildiğinde numaralar kayabilir, anahtarlar kaymaz.

- `{0}` `{1}` yer tutucularını ve `<b>` `<color=...>` etiketlerini **aynen koru**.
- Boş bıraktığın satır çevrilmemiş sayılır, oyunda İngilizce kalır — yarım dosya sorun değil.
- Kaçışlar: `\n` `\t` `\\` ve anahtar içindeki eşittir için `\=`.

### d) Kur ve gör

Dosyayı şuraya koy:

```
Schedule I\UserData\ScheduleOneTR\languages\tr\00_main.txt
```

Klasördeki **tüm** `.txt` dosyaları ad sırasıyla okunup birleştirilir, yani
`10_telefon.txt`, `20_gorevler.txt` diye bölebilirsin. Aynı anahtar iki kez geçerse
sonradan okunan kazanır.

Oyun içinde:

- **F9** — çeviri dosyalarını yeniden yükle (oyunu kapatmadan).
- **F10** — çeviriyi anlık aç/kapat (İngilizce ile karşılaştırmak için).

### e) Yeni metinleri ekle

Oyunu oynadıkça yeni metinler çıkar. Elle kopyalamak yerine:

```powershell
.\merge.cmd
```

Kurulum gerektirmez; `export\english_strings.txt`'i oyun klasöründen, çeviri
dosyasını da depodaki `languages\tr\00_main.txt`'ten kendisi bulur. Önce ne
olacağını görmek için `.\merge.cmd -DryRun`.

Python sürümü de aynı işi yapar (çıktısı birebir aynı):

```bash
python tools/merge_export.py --export "...\export\english_strings.txt" --current "...\languages\tr\00_main.txt"
```

Çevirdiğin satırları korur, yalnızca yeni anahtarları sona ekler. Önce `--dry-run`
ile ne olacağını görebilirsin. Oyun güncellendiğinde de aynı betik işini görür:
artık görünmeyen anahtarları siler değil, listeler.

---

## 4. Ayarlar

`Schedule I\UserData\MelonPreferences.cfg`, `[ScheduleOneTR]` bölümü:

| Anahtar | Varsayılan | Açıklama |
|---|---|---|
| `Enabled` | `true` | Çeviriyi aç/kapat. |
| `LanguageFolder` | `"tr"` | `languages/` altındaki klasör adı. |
| `ExportEnglishStrings` | `true` | Metin dökümü. Yama bitince `false` yap. |
| `ScanIntervalSeconds` | `1.0` | Sahne taraması aralığı. `0` = kapalı. |
| `ExportFlushSeconds` | `15.0` | Dökümün diske yazılma aralığı. |
| `ReloadHotkey` | `"F9"` | `"None"` ile kapatılır. |
| `ToggleHotkey` | `"F10"` | |
| `FallbackFontName` | `""` | Yedek font. Boşsa Segoe UI → Arial → Tahoma denenir. |
| `FallbackFontSize` | `48` | Yedek fontun atlas örnekleme boyutu. |
| `LogDiagnostics` | `false` | Ek teşhis kaydı. |

---

## 5. Nasıl çalışıyor

**Yakalama.** Harmony ile `TMP_Text.text` setter'ına ve `SetText(string, ...)`
aşırı yüklemelerine prefix takılır; atanan metin yerine çevirisi yazılır.
Parametre adları TMP sürümüne göre değiştiği için **konumsal** (`__0`) okunur.

**Tarama.** Prefab'tan gelip hiç set edilmeyen metinler hook'a uğramaz. Saniyede bir
sahnedeki TMP bileşenleri taranır ve metin geri atanır; atama hook'tan geçtiği için
çeviri orada uygulanır.

**Eşleştirme sırası:** birebir → baş/son boşluk kırpılmış hali → sayı şablonu
(`Day 5` → `Day {0}`) → tek etiket sarmalı (`<b>Continue</b>`) → regex kuralları.
Sonuçlar hem pozitif hem negatif önbelleğe alınır; sıcak yolda sözlük araması yapılır.

**Font.** TMP atlasları önceden pişirilmiş olduğunda atlasta olmayan karakter kutu
çizilir. Türkçe'de risk altındakiler **ğ Ğ ş Ş ı İ** (ö ü ç genelde Latin-1'de var).
Mod ilk taramada oyunun fontunu yoklar; eksik karakter görürse işletim sistemi
fontundan dinamik bir `TMP_FontAsset` üretip TMP'nin global fallback listesine ekler.
Geri kalan her şey oyunun kendi fontuyla çizilmeye devam eder.

---

## 6. Bilinen sınırlar

- **Dokuya gömülü yazı** (tabelalar, posterler, afişler) çevrilmez. Bunlar için asset
  değiştirmek gerekir, bu modun kapsamı dışında.
- **Büyük harf dönüşümü.** TMP'nin `<allcaps>` / `Uppercase` stili kültürden bağımsız
  çalışır, yani `i` → `İ` değil `I` olur. Etkilenen metinleri sözlükte doğrudan büyük
  harfle yazarak çöz (`FINISH` yerine `BİTİR`).
- **Oyuncunun yazdığı alanlar** çevrilmez (`TMP_InputField` altındakiler atlanır).
- **Oyun güncellemeleri** metinleri değiştirir. Yama çökmez, değişen satırlar İngilizce
  kalır; `merge_export.py` ile yeni satırları ekle.
- **Metni geri okuyan kod.** Oyun bir etiketin `.text` değerini okuyup mantıkta
  kullanırsa o yer bozulabilir. Şimdiye kadar böyle bir yer görülmedi; bir şey
  tuhaflaşırsa F10 ile çeviriyi kapatıp karşılaştır.
- Çok oyunculuda diğer oyuncular kendi dillerinde görür; gönderilen veri İngilizce kalır.

---

## 7. Sorun giderme

MelonLoader konsolu açılışta özet yazar:

```
[Schedule I Türkçe Yama] Hazır. Yamalanan metot: 3, dil: Türkçe, satır: 0, metin dökümü: açık
```

| Belirti | Sebep |
|---|---|
| `Hiçbir TMP metodu yamalanamadı` | `GlobalUsings.cs`'teki TMP namespace'i yanlış. `Il2CppAssemblies` içindeki gerçek DLL adına bak. |
| Satır sayısı 0 | `languages/tr/` boş ya da `LanguageFolder` başka bir klasörü gösteriyor. |
| Harfler kutu çiziliyor | Yedek font devreye girmemiş. `FallbackFontName` değerini `Arial` yap. |
| `export/` boş | `ExportEnglishStrings=false`, ya da `UserData` klasörüne yazma izni yok. |
| Oyun açılmıyor | IL2CPP DLL'ini Mono dalına (veya tersi) koymuş olabilirsin. |

---

## Lisans / dağıtım

Mod kodu senin. Oyunun hiçbir dosyası depoda bulunmaz, dağıtılması da gerekmez —
kullanıcı kendi kurulumuna sadece DLL'i ve çeviri dosyasını ekler.
