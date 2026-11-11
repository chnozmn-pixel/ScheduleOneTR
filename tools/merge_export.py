#!/usr/bin/env python3
"""
Yeni toplanan İngilizce metinleri mevcut çeviri dosyasıyla birleştirir.

Oyunu her oynadığında export/english_strings.txt büyür. Bu betik:
  - zaten çevirdiğin satırları olduğu gibi korur,
  - yalnızca yeni (henüz görülmemiş) anahtarları dosyanın sonuna ekler,
  - artık oyunda görünmeyen anahtarları silmez, sadece listeler.

Kullanım:
    python tools/merge_export.py \
        --export  "...\\UserData\\ScheduleOneTR\\export\\english_strings.txt" \
        --current "...\\UserData\\ScheduleOneTR\\languages\\tr\\00_main.txt"

--dry-run ile sadece ne olacağını gösterir, dosyaya dokunmaz.
"""

import argparse
import re
import sys
from pathlib import Path

LINE_ID = re.compile(r"^\d+\s*\|")

# Windows konsolu varsayılan olarak cp1252; Türkçe karakterler patlamasın.
for _s in (sys.stdout, sys.stderr):
    try:
        _s.reconfigure(encoding="utf-8", errors="replace")
    except Exception:  # noqa: BLE001
        pass


def strip_id(line: str) -> str:
    """'00042|Continue=Devam et' -> 'Continue=Devam et'."""
    m = LINE_ID.match(line)
    return line[m.end():] if m else line


def find_separator(line: str) -> int:
    """Kaçırılmamış ilk '=' karakterinin konumu, yoksa -1."""
    i = 0
    while i < len(line):
        if line[i] == "\\":
            i += 2
            continue
        if line[i] == "=":
            return i
        i += 1
    return -1


def parse(path: Path):
    """Dosyayı (anahtar -> değer) ve başlık satırları olarak ayırır."""
    entries = {}
    order = []
    header = []
    seen_entry = False

    if not path.exists():
        return entries, order, header

    for raw in path.read_text(encoding="utf-8-sig").splitlines():
        stripped = raw.strip()
        if not stripped or stripped.startswith("//") or stripped.startswith("#"):
            if not seen_entry:
                header.append(raw)
            continue

        stripped = strip_id(stripped)

        sep = find_separator(stripped)
        if sep < 0:
            continue

        key = stripped[:sep]
        value = stripped[sep + 1:]

        if key.startswith("@"):
            if not seen_entry:
                header.append(raw)
            continue

        seen_entry = True
        if key not in entries:
            order.append(key)
        entries[key] = value

    return entries, order, header


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--export", required=True, type=Path,
                    help="Modun ürettiği english_strings.txt")
    ap.add_argument("--current", required=True, type=Path,
                    help="Üzerinde çalıştığın çeviri dosyası (yoksa oluşturulur)")
    ap.add_argument("--dry-run", action="store_true")
    args = ap.parse_args()

    if not args.export.exists():
        print(f"HATA: export dosyası yok: {args.export}", file=sys.stderr)
        return 1

    new_entries, new_order, new_header = parse(args.export)
    cur_entries, cur_order, cur_header = parse(args.current)

    added = [k for k in new_order if k not in cur_entries]
    gone = [k for k in cur_order if k not in new_entries]
    translated = sum(1 for v in cur_entries.values() if v.strip())

    print(f"Mevcut dosya : {len(cur_entries)} satır, {translated} tanesi çevrili")
    print(f"Export       : {len(new_entries)} satır")
    print(f"Eklenecek    : {len(added)}")
    print(f"Artık yok    : {len(gone)} (silinmiyor)")

    if gone:
        print("\nOyunda artık görülmeyenler (ilk 20):")
        for k in gone[:20]:
            print(f"  {k}")

    if not added:
        print("\nYeni satır yok, dosya değişmedi.")
        return 0

    if args.dry_run:
        print("\n--dry-run: dosya yazılmadı. Eklenecekler (ilk 20):")
        for k in added[:20]:
            print(f"  {k}")
        return 0

    header = cur_header if cur_header else new_header
    lines = list(header)
    if lines and lines[-1].strip():
        lines.append("")

    n = 0
    for k in cur_order:
        n += 1
        lines.append(f"{n:05d}|{k}={cur_entries[k]}")

    lines.append("")
    lines.append("// ---- yeni eklenenler ----")
    for k in added:
        n += 1
        lines.append(f"{n:05d}|{k}=")

    args.current.parent.mkdir(parents=True, exist_ok=True)
    args.current.write_text("\n".join(lines) + "\n", encoding="utf-8")
    print(f"\nYazıldı: {args.current}  (+{len(added)} yeni satır)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
