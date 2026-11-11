using System;
using System.Collections.Generic;
using System.Globalization;
using System.IO;
using System.Text;
using System.Text.RegularExpressions;

namespace ScheduleOneTR
{
    /// <summary>
    /// Bir dil dosyasının içeriği. Dosya formatı düz metin, UTF-8:
    ///
    ///   // yorum satırı
    ///   @name=Türkçe
    ///   @english=Turkish
    ///
    ///   00001|Continue=Devam et
    ///   00002|Day {0}=Gün {0}
    ///   00003|It'll cost &lt;PRICE&gt;.=Fiyatı &lt;PRICE&gt;.
    ///   00004|r:"^Sold (.+) to (.+)$"=$1 -> $2 satıldı
    ///
    /// Satır başındaki "00001|" sıra numarası çevirmen içindir: okunurken atılır,
    /// eşleştirmede kullanılmaz. Yazmasan da olur. Anahtarın kendisi gerçekten
    /// rakam+| ile başlıyorsa \| ile kaçır.
    ///
    /// Kaçışlar: \n \t \\ ve anahtarın içinde geçen eşittir için \=
    /// Değeri boş bırakılan satır "henüz çevrilmedi" sayılır ve atlanır.
    /// </summary>
    internal sealed class LanguageFile
    {
        public string Name = "";
        public string English = "";

        /// <summary>Birebir eşleşen metinler.</summary>
        public readonly Dictionary<string, string> Exact =
            new Dictionary<string, string>(StringComparer.Ordinal);

        /// <summary>Sayıları {0}, {1}... ile şablonlanmış metinler.</summary>
        public readonly Dictionary<string, string> Templates =
            new Dictionary<string, string>(StringComparer.Ordinal);

        /// <summary>Regex kuralları. Dosyadaki sırayı korur.</summary>
        public readonly List<RegexRule> Rules = new List<RegexRule>();

        public int EntryCount => Exact.Count + Templates.Count + Rules.Count;

        internal sealed class RegexRule
        {
            public Regex Pattern;
            public string Replacement;
            public string Source;
        }

        public static LanguageFile LoadDirectory(string dir, Action<string> warn)
        {
            var lang = new LanguageFile();
            if (!Directory.Exists(dir))
                return lang;

            var files = Directory.GetFiles(dir, "*.txt", SearchOption.AllDirectories);
            Array.Sort(files, StringComparer.OrdinalIgnoreCase);
            foreach (var f in files)
                lang.MergeFile(f, warn);

            return lang;
        }

        public void MergeFile(string path, Action<string> warn)
        {
            string[] lines;
            try
            {
                lines = File.ReadAllLines(path, new UTF8Encoding(false));
            }
            catch (Exception e)
            {
                warn?.Invoke($"'{Path.GetFileName(path)}' okunamadı: {e.Message}");
                return;
            }

            var fileName = Path.GetFileName(path);

            for (int i = 0; i < lines.Length; i++)
            {
                var raw = lines[i];
                if (raw.Length == 0)
                    continue;

                // BOM'u ilk satırdan at
                if (i == 0 && raw.Length > 0 && raw[0] == '﻿')
                    raw = raw.Substring(1);

                var trimmed = raw.TrimStart();
                if (trimmed.Length == 0 || trimmed.StartsWith("//", StringComparison.Ordinal) ||
                    trimmed.StartsWith("#", StringComparison.Ordinal))
                    continue;

                // Çevirmen kolaylığı için satır başına konan "00042|" sıra numarasını at.
                trimmed = StripLineId(trimmed);

                int sep = FindSeparator(trimmed);
                if (sep < 0)
                {
                    warn?.Invoke($"{fileName}:{i + 1} '=' yok, satır atlandı.");
                    continue;
                }

                var key = Unescape(trimmed.Substring(0, sep));
                var value = Unescape(trimmed.Substring(sep + 1));

                // Direktifler
                if (key.StartsWith("@", StringComparison.Ordinal))
                {
                    switch (key.Substring(1).Trim().ToLowerInvariant())
                    {
                        case "name": Name = value; break;
                        case "english": English = value; break;
                        default: /* bilinmeyen direktifi yok say */ break;
                    }
                    continue;
                }

                if (key.Length == 0)
                    continue;

                // Değer boş -> henüz çevrilmemiş, atla.
                if (value.Length == 0)
                    continue;

                // Regex kuralı: r:"desen"=karşılık
                if (key.StartsWith("r:", StringComparison.Ordinal))
                {
                    var pat = key.Substring(2).Trim();
                    if (pat.Length >= 2 && pat[0] == '"' && pat[pat.Length - 1] == '"')
                        pat = pat.Substring(1, pat.Length - 2);

                    try
                    {
                        Rules.Add(new RegexRule
                        {
                            Pattern = new Regex(pat, RegexOptions.Compiled | RegexOptions.CultureInvariant),
                            Replacement = value,
                            Source = $"{fileName}:{i + 1}",
                        });
                    }
                    catch (Exception e)
                    {
                        warn?.Invoke($"{fileName}:{i + 1} geçersiz regex: {e.Message}");
                    }
                    continue;
                }

                // Şablon mu (içinde {0} gibi yer tutucu var mı), düz metin mi?
                if (PlaceholderRegex.IsMatch(key))
                    Templates[key] = value;
                else
                    Exact[key] = value;
            }
        }

        private static readonly Regex LineIdRegex =
            new Regex(@"^\d+\s*\|", RegexOptions.Compiled | RegexOptions.CultureInvariant);

        /// <summary>
        /// "00042|Continue=Devam et" -> "Continue=Devam et".
        /// Anahtarı gerçekten rakam+| ile başlayan satırlar \| ile kaçırılır.
        /// </summary>
        private static string StripLineId(string line)
        {
            var m = LineIdRegex.Match(line);
            return m.Success ? line.Substring(m.Length) : line;
        }

        internal static readonly Regex PlaceholderRegex =
            new Regex(@"\{(\d+)\}", RegexOptions.Compiled | RegexOptions.CultureInvariant);

        /// <summary>
        /// Anahtarı değerden ayıran ilk kaçırılmamış '=' karakterini bulur.
        /// </summary>
        private static int FindSeparator(string s)
        {
            for (int i = 0; i < s.Length; i++)
            {
                if (s[i] == '\\')
                {
                    i++; // sonraki karakter kaçırılmış, atla
                    continue;
                }
                if (s[i] == '=')
                    return i;
            }
            return -1;
        }

        internal static string Unescape(string s)
        {
            if (s.IndexOf('\\') < 0)
                return s.Trim();

            var sb = new StringBuilder(s.Length);
            for (int i = 0; i < s.Length; i++)
            {
                var c = s[i];
                if (c != '\\' || i + 1 >= s.Length)
                {
                    sb.Append(c);
                    continue;
                }

                i++;
                switch (s[i])
                {
                    case 'n': sb.Append('\n'); break;
                    case 'r': sb.Append('\r'); break;
                    case 't': sb.Append('\t'); break;
                    case '\\': sb.Append('\\'); break;
                    case '=': sb.Append('='); break;
                    case '|': sb.Append('|'); break;
                    case 'u':
                        if (i + 4 < s.Length &&
                            int.TryParse(s.Substring(i + 1, 4), NumberStyles.HexNumber,
                                CultureInfo.InvariantCulture, out var cp))
                        {
                            sb.Append((char)cp);
                            i += 4;
                        }
                        else sb.Append("\\u");
                        break;
                    default:
                        sb.Append('\\').Append(s[i]);
                        break;
                }
            }
            return sb.ToString().Trim();
        }

        /// <summary>Dışa yazarken ters işlem: satır sonları ve '=' kaçırılır.</summary>
        internal static string Escape(string s, bool isKey)
        {
            var sb = new StringBuilder(s.Length + 8);
            foreach (var c in s)
            {
                switch (c)
                {
                    case '\n': sb.Append("\\n"); break;
                    case '\r': sb.Append("\\r"); break;
                    case '\t': sb.Append("\\t"); break;
                    case '\\': sb.Append("\\\\"); break;
                    case '=': sb.Append(isKey ? "\\=" : "="); break;
                    default: sb.Append(c); break;
                }
            }

            var outp = sb.ToString();

            // Anahtarın kendisi "123|" ile başlıyorsa, satır numarası sanılmasın.
            if (isKey)
            {
                var m = LineIdRegex.Match(outp);
                if (m.Success)
                    outp = outp.Substring(0, m.Length - 1) + "\\|" + outp.Substring(m.Length);
            }

            return outp;
        }
    }
}
