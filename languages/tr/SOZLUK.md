# Terim sözlüğü

`10_ilk_once.txt` içindeki 3.940 satırdan çıkarıldı. Yeni satır çevirirken
buna bak, tutarlılık bozulmasın.

## Oyuna özgü

| İngilizce | Türkçe |
|---|---|
| Dealer | Torbacı |
| Customer | Müşteri |
| Supplier | Tedarikçi |
| Cartel | Kartel |
| Employee | Çalışan |
| Botanist | Yetiştirici |
| Chemist | Kimyager |
| Handler | İşleyici |
| Cleaner | Temizlikçi |
| Cash | Nakit |
| Debt | Borç |
| Product | Ürün |
| Quest / Task | Görev |
| Rank | Rütbe |
| Deal | Satış |
| Shop | Dükkân |
| Store | Mağaza |
| Item | Eşya |
| Quality | Kalite |
| Station | Tezgâh |
| Mixing Station | Karıştırma Tezgâhı |
| Drying Rack | Kurutma Rafı |
| Brick Press | Blok Presi |
| Slot | Yuva |
| Rack | Raf |
| Storage | Depolama |
| Dock | Yükleme Alanı |
| Delivery | Teslimat |
| Vehicle | Araç |
| Relationship | İlişki |
| Conversation | Konuşma |
| Tutorial | Öğretici |
| Pot | Saksı |
| Seed | Tohum |
| Trash | Çöp |
| Harvest | Hasat Et |
| Sleep | Uyu |
| Phone | Telefon |
| Key (tuş) | Tuş |
| Meth | Met |
| Cocaine | Kokain |

## Bağlama göre değişenler

| İngilizce | Türkçe | Nerede |
|---|---|---|
| Property | **Mülk** | oyun içi ev/arsa |
| Property | **Özellik** | kod/hata metni (C# property) |
| Dealer | **Torbacı** | oyun içi |
| Dealer | **Krupiye** | kart oyunu (`Dealer's turn...`) |
| Press | **Bas** | tuşa basmak |
| Press | **Pres** | blok presi |

## Biçim kuralları

- **Düğme / etiket**: Başlık Biçimi — `Kabul Et`, `Nişan Al`, `Etkinleştir`
- **Durum bildirimi**: cümle biçimi — `İptal ediliyor`, `Karıştırılıyor`
- **Hata metni**: `... yüklenirken hata oluştu:` kalıbı
- Ay kısaltmaları: `Apr → Nis`, `Aug → Ağu`
- Dil adları çevrilir: `Afrikaans → Afrikanca`
- Renk adları çevrilir: `Aqua → Su Mavisi`

## Çevrilmeyecekler

Bunlar İngilizce kalmalı, yoksa bozulurlar:

- **Konsol komutları**: `changecash {0}`, `setqueststate <quest name> <state>`,
  `packageproduct baggie`, `disablenpcasset avatar`
- **Sınıf / metot adları**: `MoveItemBehaviour.WalkToSource`,
  `NPCMovement.CheckHit:`, `BaseTreeViewController.ExpandItemByIndex`
- **Para birimi kodları**: `JPY`, `KZT`, `MXN`
- **HTML varlıkları**: `Uacute`, `Aacute`
- **Dosya adları**: `Question.ico`, `bin.hex`

## Dokunulmayacak işaretler

Anahtarda ne varsa değerde de aynen bulunmalı:

- Yer tutucular: `{0}`, `{1}` — ve `{{0}}` (log biçimi, iki süslü parantez)
- TMP etiketleri: `<b>`, `<i>`, `<color=#RRGGBB>`, `</color>`
- Oyun etiketleri: `<NAME>`, `<PRODUCT>`, `<PURPOSE>`
- Kaçışlar: `\n`, `\t`, `\=`, `\\`

Denetlemek için:

    powershell -ExecutionPolicy Bypass -File tools\check_translation.ps1 -File <dosya>
