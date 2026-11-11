#!/usr/bin/env python3
"""
Schedule I - oyun dosyalarindan Ingilizce metin cikarici.

Oyunu hic oynamadan, kurulum klasorunden butun metin adaylarini toplar.
Uc kaynak:

  1. IL2CPP  : Schedule I_Data/il2cpp_data/Metadata/global-metadata.dat
               icindeki string literal tablosu (oyunun tum sabit metinleri).
  2. Mono    : Schedule I_Data/Managed/Assembly-CSharp.dll icindeki #US
               (user strings) heap'i - ayni sey, Mono dali icin.
  3. Asset'ler: sahnelerdeki/prefab'lardaki TextMeshPro bilesenlerinin hazir
               metinleri. Bu adim icin UnityPy gerekir (istege bagli):
                   pip install UnityPy
               Mono dalinda type tree oldugu icin sorunsuz calisir; IL2CPP'de
               type tree olmadigindan bu adim genelde bos doner, 1. kaynak yeter.

Kullanim:
    python tools/extract_strings.py --game "C:\\...\\steamapps\\common\\Schedule I"
    python tools/extract_strings.py --game "..." --out cikti --raw

Ciktilar (varsayilan: ./extracted):
    english_strings.txt   SIRANO|metin=   -> ceviriyi buraya yaz
    english_strings.csv   id,source,translation
    all_strings.txt       filtrelenmemis ham liste (eksik var mi diye bakmak icin)

Bu betik yalnizca okur; oyun dosyalarina dokunmaz.
"""

import argparse
import csv
import re
import struct
import sys
from pathlib import Path

# ----------------------------------------------------------------- IL2CPP


IL2CPP_MAGIC = 0xFAB11BAF

# Windows konsolu varsayilan olarak cp1252; yol/metin icindeki Unicode patlamasin.
for _s in (sys.stdout, sys.stderr):
    try:
        _s.reconfigure(encoding="utf-8", errors="replace")
    except Exception:  # noqa: BLE001
        pass


def extract_il2cpp_metadata(path: Path, warn):
    """
    global-metadata.dat icindeki string literal tablosunu okur.

    Baslik duzeni (v24-v31 icin sabit):
        0x00  uint32  magic = 0xFAB11BAF
        0x04  int32   version
        0x08  int32   stringLiteralOffset
        0x0C  int32   stringLiteralSize      (bayt; her kayit 8 bayt)
        0x10  int32   stringLiteralDataOffset
        0x14  int32   stringLiteralDataSize

    Her kayit: uint32 length, int32 dataIndex
    """
    data = path.read_bytes()
    if len(data) < 24:
        warn(f"{path.name}: dosya cok kucuk.")
        return []

    magic, version = struct.unpack_from("<Ii", data, 0)
    if magic != IL2CPP_MAGIC:
        warn(f"{path.name}: beklenmeyen magic 0x{magic:08X}, atlaniyor.")
        return []

    if not (24 <= version <= 31):
        warn(f"{path.name}: metadata surumu {version} test edilmedi, yine de deneniyor.")

    lit_off, lit_size, data_off, data_size = struct.unpack_from("<iiii", data, 8)

    if lit_off <= 0 or lit_size <= 0 or data_off <= 0:
        warn(f"{path.name}: string literal tablosu bulunamadi.")
        return []
    if lit_off + lit_size > len(data) or data_off + data_size > len(data):
        warn(f"{path.name}: tablo konumu dosya disinda; surum uyumsuz olabilir.")
        return []

    count = lit_size // 8
    out = []
    for i in range(count):
        length, idx = struct.unpack_from("<Ii", data, lit_off + i * 8)
        if length == 0 or length > 1 << 20:
            continue
        start = data_off + idx
        end = start + length
        if start < data_off or end > data_off + data_size:
            continue
        try:
            out.append(data[start:end].decode("utf-8"))
        except UnicodeDecodeError:
            continue

    return out


# ------------------------------------------------------------------- Mono


def _rva_to_offset(sections, rva):
    for virt_addr, virt_size, raw_ptr, raw_size in sections:
        if virt_addr <= rva < virt_addr + max(virt_size, raw_size):
            return raw_ptr + (rva - virt_addr)
    return None


def _read_compressed_uint(buf, pos):
    """ECMA-335 sikistirilmis isaretsiz tamsayi."""
    b = buf[pos]
    if b & 0x80 == 0:
        return b, pos + 1
    if b & 0xC0 == 0x80:
        return ((b & 0x3F) << 8) | buf[pos + 1], pos + 2
    if b & 0xE0 == 0xC0:
        return (((b & 0x1F) << 24) | (buf[pos + 1] << 16)
                | (buf[pos + 2] << 8) | buf[pos + 3]), pos + 4
    raise ValueError("gecersiz sikistirilmis tamsayi")


def extract_dotnet_user_strings(path: Path, warn):
    """
    Bir .NET assembly'sinin #US (user strings) heap'ini okur.
    Buradaki her kayit, kodda ldstr ile kullanilan bir metin sabitidir.
    """
    data = path.read_bytes()

    try:
        if data[:2] != b"MZ":
            warn(f"{path.name}: PE dosyasi degil.")
            return []

        e_lfanew = struct.unpack_from("<I", data, 0x3C)[0]
        if data[e_lfanew:e_lfanew + 4] != b"PE\0\0":
            warn(f"{path.name}: PE imzasi yok.")
            return []

        coff = e_lfanew + 4
        num_sections = struct.unpack_from("<H", data, coff + 2)[0]
        opt_size = struct.unpack_from("<H", data, coff + 16)[0]
        opt = coff + 20

        magic = struct.unpack_from("<H", data, opt)[0]
        if magic == 0x10B:      # PE32
            dd = opt + 96
        elif magic == 0x20B:    # PE32+
            dd = opt + 112
        else:
            warn(f"{path.name}: bilinmeyen optional header 0x{magic:X}.")
            return []

        # Data directory 14 = CLI header
        cli_rva, cli_size = struct.unpack_from("<II", data, dd + 14 * 8)
        if cli_rva == 0:
            warn(f"{path.name}: yonetilen (managed) assembly degil.")
            return []

        sec_start = opt + opt_size
        sections = []
        for i in range(num_sections):
            s = sec_start + i * 40
            virt_size, virt_addr, raw_size, raw_ptr = struct.unpack_from("<IIII", data, s + 8)
            sections.append((virt_addr, virt_size, raw_ptr, raw_size))

        cli_off = _rva_to_offset(sections, cli_rva)
        if cli_off is None:
            warn(f"{path.name}: CLI header konumlandirilamadi.")
            return []

        md_rva, md_size = struct.unpack_from("<II", data, cli_off + 8)
        md_off = _rva_to_offset(sections, md_rva)
        if md_off is None:
            warn(f"{path.name}: metadata konumlandirilamadi.")
            return []

        if struct.unpack_from("<I", data, md_off)[0] != 0x424A5342:
            warn(f"{path.name}: metadata imzasi (BSJB) yok.")
            return []

        ver_len = struct.unpack_from("<I", data, md_off + 12)[0]
        pos = md_off + 16 + ((ver_len + 3) & ~3)
        pos += 2  # flags
        num_streams = struct.unpack_from("<H", data, pos)[0]
        pos += 2

        us_off = us_size = None
        for _ in range(num_streams):
            s_off, s_size = struct.unpack_from("<II", data, pos)
            pos += 8
            end = data.index(b"\0", pos)
            name = data[pos:end].decode("ascii", "replace")
            pos = end + 1
            pos = (pos + 3) & ~3  # 4 bayta hizala
            if name == "#US":
                us_off, us_size = md_off + s_off, s_size

        if us_off is None:
            warn(f"{path.name}: #US heap'i yok (metin sabiti yok).")
            return []

        out = []
        p = us_off + 1  # ilk bayt daima 0
        limit = us_off + us_size
        while p < limit:
            try:
                length, p = _read_compressed_uint(data, p)
            except (ValueError, IndexError):
                break
            if length == 0:
                continue
            if p + length > limit:
                break
            # Son bayt, "ASCII disi karakter var mi" bayragi
            raw = data[p:p + length - 1]
            p += length
            try:
                out.append(raw.decode("utf-16-le"))
            except UnicodeDecodeError:
                continue

        return out

    except Exception as e:  # noqa: BLE001 - tek bir dosya patlarsa digerleri devam etsin
        warn(f"{path.name}: okunamadi ({e}).")
        return []


# --------------------------------------------------------------- Unity asset


TEXT_FIELDS = ("m_text", "m_Text")


def extract_unity_assets(data_dir: Path, warn, note):
    """Sahne/prefab icindeki TextMeshPro ve UI.Text bilesenlerinin hazir metinleri."""
    try:
        import UnityPy  # type: ignore
    except ImportError:
        note("UnityPy kurulu degil, asset taramasi atlandi.  pip install UnityPy")
        return []

    targets = []
    for pattern in ("*.assets", "level*", "*.bundle", "*.unity3d"):
        targets.extend(sorted(data_dir.glob(pattern)))
    targets.extend(sorted((data_dir / "StreamingAssets").rglob("*"))
                   if (data_dir / "StreamingAssets").is_dir() else [])

    out = []
    scanned = 0
    for f in targets:
        if not f.is_file():
            continue
        try:
            env = UnityPy.load(str(f))
        except Exception:  # noqa: BLE001
            continue
        scanned += 1

        for obj in env.objects:
            try:
                if obj.type.name == "TextAsset":
                    d = obj.read()
                    text = getattr(d, "text", None) or getattr(d, "m_Script", None)
                    if isinstance(text, str) and len(text) < 200000:
                        out.append(text)
                    continue

                if obj.type.name != "MonoBehaviour":
                    continue

                tree = obj.read_typetree()
                if not isinstance(tree, dict):
                    continue
                for key in TEXT_FIELDS:
                    v = tree.get(key)
                    if isinstance(v, str) and v.strip():
                        out.append(v)
            except Exception:  # noqa: BLE001
                continue

    note(f"Asset taramasi: {scanned} dosya okundu, {len(out)} metin bulundu.")
    return out


# ------------------------------------------------------------------ filtre


# Kod kokulu / UI olmayan metinleri eleyen desenler.
REJECT = [
    re.compile(r"^\s*$"),
    re.compile(r"^[\W\d_]+$"),                              # harf yok
    re.compile(r"^(UnityEngine|System|Microsoft|Mono|TMPro|Il2Cpp)\b"),
    re.compile(r"^(Assets|Packages|Library|Temp)[/\\]"),
    re.compile(r"\.(png|jpg|jpeg|tga|psd|mat|prefab|unity|asset|anim|controller|"
               r"shader|cs|dll|so|json|xml|txt|wav|mp3|ogg|ttf|otf|fbx|obj)$", re.I),
    re.compile(r"^[a-z0-9_]+(/[a-z0-9_]+)+$", re.I),        # yol benzeri
    re.compile(r"^<[^>]*>$"),                               # sadece etiket
    re.compile(r"^\{[^}]*\}$"),                             # sadece yer tutucu
    re.compile(r"^[0-9a-fA-F]{8,}$"),                       # hex / hash
    re.compile(r"^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-"),         # guid
    re.compile(r"^(get_|set_|add_|remove_|<>|\$|__)"),      # derleyici uretimi
    re.compile(r"k__BackingField|MoveNext|\.ctor|\.cctor"),
    re.compile(r"^(https?|file|data|res)://", re.I),
    re.compile(r"^[A-Z][A-Z0-9_]{3,}$"),                    # SABIT_ISIM
    re.compile(r"^[a-z]+([A-Z][a-zA-Z0-9]*)+$"),            # camelCase tanitici
    re.compile(r"^[A-Z][a-z0-9]+([A-Z][a-zA-Z0-9]*)+$"),    # PascalCase tanitici
]

HAS_LETTER = re.compile(r"[A-Za-z]")


def looks_translatable(s: str) -> bool:
    if not (2 <= len(s) <= 400):
        return False
    if not HAS_LETTER.search(s):
        return False
    if "\x00" in s:
        return False
    for rx in REJECT:
        if rx.search(s):
            return False
    # Icinde bosluk yoksa, en azindan gercek bir kelimeye benzesin.
    if " " not in s and not re.fullmatch(r"[A-Za-z][A-Za-z'\-\.!?,:]*", s):
        return False
    return True


def shape_numbers(s: str) -> str:
    """Sayilari {0}, {1}... yapar; 'Day 5' ile 'Day 6' tek satir olur."""
    i = 0

    def repl(_m):
        nonlocal i
        out = "{%d}" % i
        i += 1
        return out

    shaped = re.sub(r"-?\d+(?:[.,]\d+)?", repl, s)
    return shaped if i <= 8 else s


def escape_key(s: str) -> str:
    s = (s.replace("\\", "\\\\")
          .replace("\n", "\\n")
          .replace("\r", "\\r")
          .replace("\t", "\\t")
          .replace("=", "\\="))
    m = re.match(r"^\d+\s*\|", s)
    if m:
        s = s[:m.end() - 1] + "\\|" + s[m.end():]
    return s


# ------------------------------------------------------------------- main


def main() -> int:
    ap = argparse.ArgumentParser(
        description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--game", required=True, type=Path,
                    help="Schedule I kurulum klasoru")
    ap.add_argument("--out", type=Path, default=Path("extracted"),
                    help="Cikti klasoru (varsayilan: ./extracted)")
    ap.add_argument("--no-assets", action="store_true",
                    help="UnityPy ile asset taramasini atla")
    ap.add_argument("--raw", action="store_true",
                    help="Filtrelenmemis ham listeyi de yaz")
    ap.add_argument("--no-shape", action="store_true",
                    help="Sayilari {0} yapma, oldugu gibi birak")
    args = ap.parse_args()

    game: Path = args.game
    if not game.is_dir():
        print(f"HATA: klasor yok: {game}", file=sys.stderr)
        return 1

    data_dir = game / "Schedule I_Data"
    if not data_dir.is_dir():
        cands = [p for p in game.glob("*_Data") if p.is_dir()]
        if not cands:
            print(f"HATA: '*_Data' klasoru bulunamadi: {game}", file=sys.stderr)
            return 1
        data_dir = cands[0]
        print(f"Not: veri klasoru olarak {data_dir.name} kullaniliyor.")

    warnings = []
    notes = []

    def warn(m):
        warnings.append(m)

    def note(m):
        notes.append(m)
        print(f"  {m}")

    raw = []

    # 1. IL2CPP
    meta = data_dir / "il2cpp_data" / "Metadata" / "global-metadata.dat"
    if meta.is_file():
        print(f"IL2CPP metadata okunuyor: {meta.name}")
        got = extract_il2cpp_metadata(meta, warn)
        print(f"  {len(got)} metin sabiti")
        raw += got
    else:
        print("IL2CPP metadata yok (Mono dali olabilir).")

    # 2. Mono
    managed = data_dir / "Managed"
    if managed.is_dir():
        dlls = [managed / "Assembly-CSharp.dll"]
        dlls += [p for p in sorted(managed.glob("Assembly-CSharp-*.dll"))]
        dlls += [p for p in sorted(managed.glob("ScheduleOne*.dll"))]
        for dll in dlls:
            if not dll.is_file():
                continue
            print(f"Managed assembly okunuyor: {dll.name}")
            got = extract_dotnet_user_strings(dll, warn)
            print(f"  {len(got)} metin sabiti")
            raw += got
    else:
        print("Managed klasoru yok (IL2CPP dali).")

    # 3. Asset'ler
    if not args.no_assets:
        print("Asset'ler taraniyor...")
        raw += extract_unity_assets(data_dir, warn, note)

    if not raw:
        print("\nHic metin cikarilamadi.", file=sys.stderr)
        for w in warnings:
            print(f"  ! {w}", file=sys.stderr)
        return 2

    # Tekille, filtrele
    seen_raw = set()
    uniq_raw = []
    for s in raw:
        s = s.strip()
        if s and s not in seen_raw:
            seen_raw.add(s)
            uniq_raw.append(s)

    kept = []
    seen = set()
    for s in uniq_raw:
        if not looks_translatable(s):
            continue
        k = s if args.no_shape else shape_numbers(s)
        if k not in seen:
            seen.add(k)
            kept.append(k)

    kept.sort(key=lambda x: (x.lower(), x))

    out_dir: Path = args.out
    out_dir.mkdir(parents=True, exist_ok=True)

    txt = out_dir / "english_strings.txt"
    with txt.open("w", encoding="utf-8", newline="\n") as f:
        f.write("// Schedule I - oyun dosyalarindan cikarilan Ingilizce metinler\n")
        f.write(f"// Kaynak: {game}\n")
        f.write(f"// Toplam: {len(kept)} satir  (ham: {len(uniq_raw)})\n")
        f.write("//\n")
        f.write("// Bicim:  SIRANO|ingilizce metin=turkce karsilik\n")
        f.write("// Esittirin SAG tarafini doldur. Sol taraf anahtar, DEGISTIRME.\n")
        f.write("// Sira numarasi sadece takip icin; mod okurken atar.\n")
        f.write("// {0} {1} yer tutucularini ve <b> <color=...> etiketlerini aynen koru.\n")
        f.write("// Bos birakilan satir cevrilmemis sayilir, oyunda Ingilizce kalir.\n")
        f.write("//\n")
        f.write("@name=Turkce\n")
        f.write("@english=Turkish\n\n")
        for i, s in enumerate(kept, 1):
            f.write(f"{i:05d}|{escape_key(s)}=\n")

    csv_path = out_dir / "english_strings.csv"
    with csv_path.open("w", encoding="utf-8-sig", newline="") as f:
        w = csv.writer(f)
        w.writerow(["id", "source", "translation"])
        for i, s in enumerate(kept, 1):
            w.writerow([f"{i:05d}", s, ""])

    if args.raw:
        rawp = out_dir / "all_strings.txt"
        rawp.write_text("\n".join(uniq_raw) + "\n", encoding="utf-8")

    print()
    print(f"Ham benzersiz metin : {len(uniq_raw)}")
    print(f"Cevrilmeye aday     : {len(kept)}")
    print(f"Yazildi             : {txt}")
    print(f"                      {csv_path}")
    if args.raw:
        print(f"                      {out_dir / 'all_strings.txt'}")

    if warnings:
        print("\nUyarilar:")
        for w in warnings:
            print(f"  ! {w}")

    print("\nSonraki adim: dosyadaki esittirlerin sagini doldur, sonra su klasore kopyala:")
    print("  Schedule I\\UserData\\ScheduleOneTR\\languages\\tr\\")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
