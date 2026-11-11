# Schedule I — Türkçe Yama

**Schedule I** oyununu Türkçeye çeviren bir yama. Menüler, görevler, telefon,
dükkânlar, uyarılar — oyunda yazan her şey Türkçe görünür.

Yaklaşık **9.700 satır** çeviri var. Oyunun kendi dosyalarına dokunmaz,
kayıtlarını bozmaz, çok oyuncuda sorun çıkarmaz.

> Hiç kod bilmeyen biri için yazıldı. Aşağıdaki adımlardan birini uygula, yeter.

---

## Kurulum

Üç yol var. **Hepsi aynı sonuca çıkar**, kolaydan zora sıralı.

### Yol 1 — Tek satır (en kolay)

Başlat menüsüne **PowerShell** yazıp aç. Siyah pencereye şunu yapıştır ve
Enter'a bas:

```powershell
irm https://raw.githubusercontent.com/chnozmn-pixel/ScheduleOneTR/main/kur.ps1 | iex
```

Yapıştırmak için: metni kopyala, pencereye **sağ tıkla**. Ctrl+V de çalışır.

Gerisini kendisi yapar. Birkaç kez `E` yazıp Enter'a basman istenecek, bir de
oyun açıldığında ana menüyü görünce oyunu kapatman gerekecek. Hepsi bu.

### Yol 2 — Zip indir

1. Bu sayfanın üstündeki yeşil **Code** düğmesi → **Download ZIP**
2. İnen dosyaya **sağ tık → Tümünü ayıkla**
3. Açılan klasördeki **`KUR.cmd`** dosyasına çift tıkla

> Zip'in **içinden** çift tıklama. Windows o zaman dosyaları geçici bir yere
> açıyor ve kurulum yarıda kalıyor. Önce ayıkla, sonra tıkla.

### Yol 3 — Elle (adım adım kendim yapmak istiyorum)

Aşağıda **[Elle kurulum](#elle-kurulum)** başlığında anlatıldı.

---

## Kurulum sırasında ne oluyor

Pencere altı adımı sırayla yazar. Her adımda ne yaptığını gösterir, bir şey
gizlemez.

| Adım | Ne yapıyor | Ne kadar sürer |
|---|---|---|
| 1 | Oyunu bilgisayarda bulur | saniyeler |
| 2 | **MelonLoader**'ı indirip kurar | 1–2 dakika |
| 3 | Oyunu bir kez açar, gerekli dosyaları ürettirir | 5–15 dakika |
| 4 | Yamayı senin bilgisayarına göre hazırlar | 5–15 dakika |
| 5 | Çeviri dosyalarını yerine koyar | saniyeler |
| 6 | Özet yazar | — |

**İlk kurulum 15–30 dakika sürebilir.** Uzun görünen adımlarda ekranda bir
süre yeni satır çıkmayabilir; takılmadı, çalışıyor. 3. adımda altmış saniyede
bir şöyle bir satır düşer:

```
        2:30 gecti | uretilen dosya:   847 | oyun: acik
```

Bu satır ilerlediğini gösterir. İkinci kez çalıştırırsan saniyeler sürer,
çünkü yapılmış olanı atlar.

### Sana düşen iki şey

1. **"(E / H):" diye sorduğunda** `E` yazıp Enter'a bas.
2. **3. adımda oyun kendiliğinden açılır.** Ana menüyü görünce **oyunu kapat**.
   Siyah pencereyi kapatma, o kendiliğinden devam eder.

Bitince `KURULUM TAMAM` yazar. Oyunu Steam'den normal şekilde başlat.

---

## Oyun içinde

| Tuş | Ne yapar |
|---|---|
| **F10** | Çeviriyi kapatır/açar — bir yazının aslını merak edersen |
| **F9** | Çeviri dosyalarını yeniden yükler (oyunu kapatmadan) |

---

## Oyun güncellenirse

Steam oyunu güncellediğinde yamanın bir kısmı eskiyebilir. Belirtiye göre:

| Ne görüyorsun | Ne yapmalı |
|---|---|
| Oyun açılıyor, **her şey** İngilizce | `GUNCELLE.cmd` çalıştır |
| Oyun **hiç açılmıyor** | `GUNCELLE.cmd` çalıştır |
| **Bazı** yazılar İngilizce | Bir şey yapma, normal — hepsi henüz çevrilmedi |

`GUNCELLE.cmd` kurulum klasörünün içinde. Tek satırla kurduysan burada:

```
%LOCALAPPDATA%\ScheduleOneTR
```

Bu yolu kopyalayıp Dosya Gezgini'nin adres çubuğuna yapıştırabilirsin.
Tek satırlık komutu tekrar çalıştırmak da aynı işi görür.

---

## Kaldırmak

Kurulum klasöründeki **`KALDIR.cmd`** dosyasına çift tıkla. Oyun eski haline
döner. **Kayıtlı oyunlarına dokunmaz.**

---

## Yardım edebilirsin

Yama, oyunda İngilizce kalan her yazıyı kendi kaydediyor. Bir süre
oynadıktan sonra **`EKSIK_METINLER.cmd`**'ye çift tıkla — masaüstüne bir
dosya koyar. Onu gönderirsen o yazılar da çevrilir.

Ne kadar çok ekran gezersen (menüler, telefon, görevler, dükkânlar, uyarılar)
o kadar işe yarar.

---

## Sorun giderme

**Önce şunu bil:** kurulum klasöründe `kurulum-log.txt` diye bir dosya oluşur.
Ekranda yazan her şey orada da durur. Sorun çıkarsa ekran görüntüsü yerine
**o dosyayı gönder**, çok daha hızlı çözülür.

| Sorun | Çözüm |
|---|---|
| Windows "bilgisayarınız korundu" diyor | **Daha fazla bilgi → Yine de çalıştır**. Dosyalar imzalı olmadığı için çıkar, normal |
| Antivirüs uyarıyor | Aynı sebep. Kaynak bu depo; istersen kodun tamamını okuyabilirsin |
| "Schedule I kurulumu bulunamadı" | Oyun klasörünü pencereye sürükleyip Enter'a bas |
| Oyun açılmıyor | `KALDIR.cmd` çalıştır, oyun eski haline döner. Sonra haber ver |
| Harfler kare kare / boş kutu | Font sorunu, haber ver. `ğ ş ı İ` harfleri etkilenir |
| Bazı yazılar İngilizce | Normal, hepsi henüz çevrilmedi. `EKSIK_METINLER.cmd` ile topla |
| Kurulum "takıldı" gibi | 3. ve 4. adım uzun sürer. Altmış saniyede bir satır düşüyorsa çalışıyordur |
| "Erişim engellendi" / yazılamıyor | `KUR.cmd`'ye sağ tık → **Yönetici olarak çalıştır** |

### Sık sorulanlar

**Kayıtlı oyunlarım bozulur mu?**
Hayır. Yama sadece ekranda görünen yazıyı değiştiriyor; oyunun kendi verisine
dokunmuyor. Kayıtlar İngilizce metinle çalışmaya devam ediyor.

**Çok oyuncuda sorun olur mu?**
Olmaz. Karşı taraf kendi dilinde görür, gönderilen veri İngilizce kalır.

**Oyunu banlar mı?**
Schedule I tek oyunculu ağırlıklı bir oyun, anti-cheat kullanmıyor. Yama
oyunun dosyalarını da değiştirmiyor.

**İnternet gerekiyor mu?**
Sadece kurulum sırasında (MelonLoader ve derleme araçları iniyor). Sonrasında
gerekmiyor.

---

## Elle kurulum

Otomatik kurulumu istemiyorsan ya da bir adımda takıldıysan, aynı işi elle
yapabilirsin.

### 1. MelonLoader

1. [MelonLoader 0.7.3](https://github.com/LavaGang/MelonLoader/releases/tag/v0.7.3)
   sayfasından **`MelonLoader.x64.zip`** indir.
2. Zip'in içindekileri **oyun klasörüne** ayıkla. Oyun klasörü genelde burası:

   ```
   C:\Program Files (x86)\Steam\steamapps\common\Schedule I
   ```

   Bulamıyorsan: Steam'de oyuna sağ tık → **Yönet → Yerel dosyalara gözat**.

3. Doğru yaptıysan oyun klasöründe `MelonLoader\` klasörü ve `version.dll`
   dosyası oluşur.

> `MelonLoader.Installer.exe` de kullanabilirsin; aynı işi yapar, oyunu
> listeden seçip Install dersin.

### 2. Oyunu bir kez aç

Steam'den başlat, **ana menüyü gör**, kapat.

Bu açılış 5–15 dakika sürebilir. MelonLoader bu sırada
`MelonLoader\Il2CppAssemblies\` klasörünü üretiyor — bir sonraki adım buna
ihtiyaç duyuyor. Sadece bir kere oluyor.

### 3. Yamayı derle

Bu adım için **.NET SDK 8** gerekiyor
([indirme sayfası](https://dotnet.microsoft.com/download/dotnet/8.0)).
Kurmak istemiyorsan `tools\bootstrap_build.ps1` betiği SDK'yı kendi klasörüne
indirip kullanıyor, sisteme bulaşmıyor.

Depo klasöründe PowerShell aç:

```powershell
.\build.ps1 -GameDir "C:\Program Files (x86)\Steam\steamapps\common\Schedule I"
```

İlk derleme 5–15 dakika sürer (oyunun binlerce dosyası taranıyor). Sonunda
şu dosya oluşur:

```
src\ScheduleOneTR\bin\IL2CPP\ScheduleOneTR_Il2Cpp.dll
```

Steam'in **alternate** dalını kullanıyorsan `-Mono` ekle; çıktı
`ScheduleOneTR_Mono.dll` olur.

### 4. Dosyaları yerine koy

İki şeyi kopyala:

| Ne | Nereye |
|---|---|
| `ScheduleOneTR_Il2Cpp.dll` | `<oyun>\Mods\` |
| `languages\tr\*.txt` (3 dosya) | `<oyun>\UserData\ScheduleOneTR\languages\tr\` |

Klasörler yoksa kendin oluştur. Oyunu başlat, menüler Türkçe gelmeli.

### Elle kaldırmak

`<oyun>\Mods\ScheduleOneTR_Il2Cpp.dll` dosyasını sil. MelonLoader'ı da
kaldırmak istersen `MelonLoader\` klasörünü ve `version.dll`'i sil.

---

## Nasıl çalışıyor

Merak edenler için, kısaca.

Oyun Unity ile yapılmış ve ekrandaki yazıları **TextMeshPro** ile çiziyor.
Yama, MelonLoader üzerinden oyuna giriyor ve **Harmony** ile `TMP_Text.text`
özelliğine bağlanıyor: oyun bir yazıyı ekrana koymadan hemen önce yama araya
girip o yazının Türkçesini veriyor.

Oyunun verisine hiç dokunmuyor. Ana menüdeki düğme veri tarafında hâlâ
`Continue`; sadece ekranda `Devam Et` görünüyor. Kayıtlar, görev mantığı, çok
oyuncu senkronizasyonu İngilizce metinle çalışmaya devam ediyor — yamayı
kaldırınca hiçbir iz kalmamasının sebebi bu.

**Eşleştirme** sırayla deneniyor: birebir → baş/son boşluk kırpılmış hâli →
sayı şablonu (`Day 5` → `Day {0}`) → tek etiket sarmalı (`<b>Continue</b>`) →
düzenli ifade kuralları.

**Font.** Oyunun yazı tipi önceden pişirilmiş bir atlas kullanıyor; atlasta
olmayan karakter kutu olarak çizilir. Türkçede risk altındakiler **ğ Ğ ş Ş ı
İ**. Yama açılışta oyunun fontunu yokluyor, eksik karakter görürse Windows
fontundan yedek bir font üretip devreye sokuyor.

Daha ayrıntısı: [docs/GELISTIRME.md](docs/GELISTIRME.md)

---

## Bilinen sınırlar

- **Dokuya gömülü yazılar** (tabelalar, posterler, afişler) çevrilmez —
  bunlar resim, yazı değil.
- **Büyük harfe çevrilen yazılarda** `i` harfi `İ` değil `I` olur. Unity'nin
  büyük harf dönüşümü Türkçe kuralını bilmiyor.
- **Oyuncunun yazdığı alanlar** çevrilmez (bilerek).
- **Oyun güncellemeleri** metinleri değiştirir; değişen satırlar İngilizce kalır.
- Hepsi çevrilmedi. Eksikleri `EKSIK_METINLER.cmd` ile toplayıp gönderebilirsin.

---

## Teşekkür

Bu yama **[MelonLoader](https://github.com/LavaGang/MelonLoader)** üzerine
kurulu. LavaGang ekibine ve MelonLoader'a katkı veren herkese teşekkürler —
onların işi olmasaydı bu yama olmazdı. MelonLoader Apache-2.0 lisanslı,
ücretsiz ve açık kaynak.

Yamanın oyuna bağlanma kısmı **[Harmony](https://github.com/pardeike/Harmony)**
(Andreas Pardeike) ve **Il2CppInterop** ile çalışıyor; ikisi de MelonLoader
ile birlikte geliyor.

Oyunun kendisi **Schedule I** — TVGS. Bu depo oyunun hiçbir dosyasını
içermez, dağıtmaz; yalnızca ekrandaki yazının görünüşünü değiştirir.

---

## Geliştiriciler için

Çeviri eklemek, metin çıkarmak, paket hazırlamak:
**[docs/GELISTIRME.md](docs/GELISTIRME.md)**

Terim sözlüğü (Customer → Müşteri gibi kararlar):
**[languages/tr/SOZLUK.md](languages/tr/SOZLUK.md)**

---

## Lisans

Yamanın kodu ve çevirileri bu deponun sahibine aittir. Oyunun hiçbir dosyası
burada bulunmaz.
