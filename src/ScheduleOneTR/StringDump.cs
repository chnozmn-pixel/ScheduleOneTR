using System;
using System.Collections.Generic;
using System.Globalization;
using System.IO;
using System.Text;
using System.Text.RegularExpressions;

namespace ScheduleOneTR
{
    /// <summary>
    /// Oyunda görülen ve karşılığı olmayan İngilizce metinleri toplar, çevrilmeye hazır
    /// dosyalara yazar. Çeviri dosyasını elle doldurmak için asıl giriş noktası budur.
    ///
    /// Çıktılar (UserData/ScheduleOneTR/export/):
    ///   english_strings.txt  -> anahtar=değer biçimi, değerler boş. Doğrudan
    ///                           languages/tr/ içine kopyalanıp doldurulabilir.
    ///   english_strings.csv  -> source,translation başlıklı CSV (Excel / CAT araçları için).
    /// </summary>
    internal sealed class StringDump
    {
        private readonly object _lock = new object();
        private readonly HashSet<string> _seen = new HashSet<string>(StringComparer.Ordinal);
        private readonly List<string> _order = new List<string>();

        private string _dir;
        private bool _dirty;
        private DateTime _lastWrite = DateTime.MinValue;

        public bool Enabled;
        public bool ShapeNumbers = true;
        public int MinLength = 2;

        public int Count { get { lock (_lock) return _order.Count; } }

        private static readonly Regex NumberRegex =
            new Regex(@"-?\d+(?:[.,]\d+)?", RegexOptions.Compiled | RegexOptions.CultureInvariant);

        // Çevrilecek metin olmayan şeyleri ayıklamak için: sadece sayı/sembol, saat,
        // para, yüzde, dosya yolu, GUID, renk kodu gibi.
        private static readonly Regex NoiseRegex = new Regex(
            @"^(?:
                 [\s\d\p{P}\p{S}]*                     # sadece sayı, noktalama, sembol
               | \$?-?[\d.,]+%?                        # 1.234 / $50 / 12,5%
               | \d{1,2}:\d{2}(?::\d{2})?\s?(?:AM|PM)? # saat
               | [0-9a-fA-F]{6,}                       # hex / renk kodu
               | [A-Za-z]:[\\/].*                      # Windows yolu
               | .*[\\/].*\.[A-Za-z0-9]{2,4}           # dosya yolu
               | \{[^}]*\}                             # tek başına yer tutucu
             )$",
            RegexOptions.Compiled | RegexOptions.CultureInvariant |
            RegexOptions.IgnorePatternWhitespace);

        public void Init(string baseDir)
        {
            _dir = Path.Combine(baseDir, "export");
            try { Directory.CreateDirectory(_dir); } catch { /* yazma izni yoksa sessizce geç */ }
        }

        /// <summary>Çevirisi bulunamayan bir metni kaydeder.</summary>
        public void Record(string text)
        {
            if (!Enabled || string.IsNullOrEmpty(text))
                return;

            var s = text.Trim();
            if (s.Length < MinLength || s.Length > 4000)
                return;

            // İçinde hiç harf yoksa çevrilecek bir şey de yok.
            if (!HasLetter(s))
                return;

            if (NoiseRegex.IsMatch(s))
                return;

            if (ShapeNumbers)
                s = Shape(s);

            lock (_lock)
            {
                if (!_seen.Add(s))
                    return;
                _order.Add(s);
                _dirty = true;
            }
        }

        /// <summary>Sayıları {0}, {1}... yapar; "Day 5" ve "Day 6" tek satır olur.</summary>
        private static string Shape(string s)
        {
            var matches = NumberRegex.Matches(s);
            if (matches.Count == 0 || matches.Count > 8)
                return s;

            var sb = new StringBuilder(s.Length);
            int pos = 0, i = 0;
            foreach (Match m in matches)
            {
                sb.Append(s, pos, m.Index - pos);
                sb.Append('{').Append(i++).Append('}');
                pos = m.Index + m.Length;
            }
            sb.Append(s, pos, s.Length - pos);
            return sb.ToString();
        }

        private static bool HasLetter(string s)
        {
            foreach (var c in s)
                if (char.IsLetter(c))
                    return true;
            return false;
        }

        /// <summary>Belirli aralıklarla diske yazar (oyun kapanmadan kaybolmasın).</summary>
        public void FlushIfDue(double minSeconds)
        {
            if (!Enabled || !_dirty)
                return;
            if ((DateTime.UtcNow - _lastWrite).TotalSeconds < minSeconds)
                return;
            Flush();
        }

        public void Flush()
        {
            if (_dir == null)
                return;

            string[] snapshot;
            lock (_lock)
            {
                if (!_dirty)
                    return;
                snapshot = _order.ToArray();
                _dirty = false;
                _lastWrite = DateTime.UtcNow;
            }

            Array.Sort(snapshot, StringComparer.OrdinalIgnoreCase);

            WriteSafe(Path.Combine(_dir, "english_strings.txt"), () => BuildTxt(snapshot));
            WriteSafe(Path.Combine(_dir, "english_strings.csv"), () => BuildCsv(snapshot));
        }

        private static void WriteSafe(string path, Func<string> build)
        {
            try
            {
                var tmp = path + ".tmp";
                File.WriteAllText(tmp, build(), new UTF8Encoding(true));
                if (File.Exists(path))
                    File.Delete(path);
                File.Move(tmp, path);
            }
            catch (Exception e)
            {
                Plugin.Log?.Warning($"Dökümanı yazamadım ({Path.GetFileName(path)}): {e.Message}");
            }
        }

        private static string BuildTxt(string[] items)
        {
            var sb = new StringBuilder(items.Length * 64);
            sb.Append("// Schedule I - oyundan toplanan İngilizce metinler\n");
            sb.Append("// Oluşturma: ")
              .Append(DateTime.Now.ToString("yyyy-MM-dd HH:mm", CultureInfo.InvariantCulture))
              .Append("   Satır: ").Append(items.Length).Append('\n');
            sb.Append("//\n");
            sb.Append("// Biçim:  SIRANO|ingilizce metin=türkçe karşılık\n");
            sb.Append("// Eşittirin SAĞ tarafını doldur. Sol taraf anahtar, DEĞİŞTİRME.\n");
            sb.Append("// Sıra numarası sadece senin takibin için; mod okurken atar.\n");
            sb.Append("// DİKKAT: liste her yeni metinde yeniden sıralandığı için numaralar\n");
            sb.Append("//         kayabilir. Kalıcı kimlik anahtarın kendisidir, numara değil.\n");
            sb.Append("// Boş bırakılan satırlar çevrilmemiş sayılır ve oyunda İngilizce kalır.\n");
            sb.Append("// {0} {1} gibi yer tutucuları ve <color=...> <b> gibi etiketleri aynen koru.\n");
            sb.Append("// Satır sonu \\n, sekme \\t, anahtar içindeki eşittir \\= ile yazılır.\n");
            sb.Append("//\n");
            sb.Append("@name=Türkçe\n");
            sb.Append("@english=Turkish\n\n");

            int n = 0;
            foreach (var s in items)
            {
                sb.Append((++n).ToString("D5", CultureInfo.InvariantCulture)).Append('|')
                  .Append(LanguageFile.Escape(s, true)).Append("=\n");
            }
            return sb.ToString();
        }

        private static string BuildCsv(string[] items)
        {
            var sb = new StringBuilder(items.Length * 64);
            sb.Append("id,source,translation\n");
            int n = 0;
            foreach (var s in items)
            {
                sb.Append((++n).ToString("D5", CultureInfo.InvariantCulture)).Append(',')
                  .Append(Csv(s)).Append(",\n");
            }
            return sb.ToString();
        }

        private static string Csv(string s)
        {
            var needsQuote = s.IndexOfAny(new[] { ',', '"', '\n', '\r' }) >= 0;
            if (!needsQuote)
                return s;
            return "\"" + s.Replace("\"", "\"\"") + "\"";
        }
    }
}
