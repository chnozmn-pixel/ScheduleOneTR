using System;
using System.Collections.Generic;
using System.Text;
using System.Text.RegularExpressions;

namespace ScheduleOneTR
{
    /// <summary>
    /// Metin eşleştirme motoru. Sıcak yolda (her TMP metni atamasında) çağrıldığı için
    /// sonuçlar hem pozitif hem negatif olarak önbelleğe alınır.
    ///
    /// Eşleştirme sırası:
    ///   1. Birebir
    ///   2. Baş/son boşluk kırpılmış hali (boşluklar sonra geri eklenir)
    ///   3. Sayı şablonu  ("Day 5" -> "Day {0}")
    ///   4. Zengin metin etiketi sarmalı  ("&lt;b&gt;Continue&lt;/b&gt;" -> iç metin)
    ///   5. Regex kuralları
    /// </summary>
    internal sealed class Translator
    {
        private LanguageFile _lang = new LanguageFile();

        private readonly Dictionary<string, string> _hit =
            new Dictionary<string, string>(StringComparer.Ordinal);
        private readonly HashSet<string> _miss = new HashSet<string>(StringComparer.Ordinal);

        /// <summary>Ürettiğimiz çıktılar. Aynı metni ikinci kez çevirmeye çalışmamak için.</summary>
        private readonly HashSet<string> _outputs = new HashSet<string>(StringComparer.Ordinal);

        private static readonly Regex NumberRegex =
            new Regex(@"-?\d+(?:[.,]\d+)?", RegexOptions.Compiled | RegexOptions.CultureInvariant);

        private static readonly Regex TagWrapRegex =
            new Regex(@"^((?:<[^<>]+>)+)(.+?)((?:</[^<>]+>)+)$",
                RegexOptions.Compiled | RegexOptions.CultureInvariant | RegexOptions.Singleline);

        public int EntryCount => _lang.EntryCount;
        public string LanguageName => string.IsNullOrEmpty(_lang.Name) ? "?" : _lang.Name;

        public void SetLanguage(LanguageFile lang)
        {
            _lang = lang ?? new LanguageFile();
            _hit.Clear();
            _miss.Clear();
            _outputs.Clear();
        }

        /// <summary>
        /// Çeviri varsa döndürür, yoksa null. Girdi asla değiştirilmez.
        /// </summary>
        public string Translate(string input)
        {
            if (string.IsNullOrEmpty(input))
                return null;

            // Kendi çıktımız geri geldi (TMP metni tekrar atadı) -> dokunma.
            if (_outputs.Contains(input))
                return null;

            if (_hit.TryGetValue(input, out var cached))
                return cached;
            if (_miss.Contains(input))
                return null;

            var result = Resolve(input);

            if (result == null)
            {
                // Önbellek sınırsız büyümesin
                if (_miss.Count < 40000)
                    _miss.Add(input);
                return null;
            }

            if (_hit.Count < 40000)
                _hit[input] = result;
            _outputs.Add(result);
            return result;
        }

        private string Resolve(string input)
        {
            // 1. Birebir
            if (_lang.Exact.TryGetValue(input, out var exact))
                return exact;

            // 2. Kırpılmış hali — boşlukları koruyarak
            var trimmed = input.Trim();
            if (trimmed.Length != input.Length && trimmed.Length > 0)
            {
                if (_lang.Exact.TryGetValue(trimmed, out var t))
                {
                    var lead = input.Substring(0, input.IndexOf(trimmed[0]));
                    var tail = input.Substring(lead.Length + trimmed.Length);
                    return lead + t + tail;
                }
            }

            var core = trimmed.Length > 0 ? trimmed : input;

            // 3. Sayı şablonu
            var byTemplate = ResolveTemplate(core);
            if (byTemplate != null)
                return Rewrap(input, core, byTemplate);

            // 4. Zengin metin etiketi sarmalı
            var m = TagWrapRegex.Match(core);
            if (m.Success)
            {
                var inner = m.Groups[2].Value;
                var innerTr = _lang.Exact.TryGetValue(inner, out var iv) ? iv : ResolveTemplate(inner);
                if (innerTr != null)
                    return Rewrap(input, core, m.Groups[1].Value + innerTr + m.Groups[3].Value);
            }

            // 5. Regex kuralları
            for (int i = 0; i < _lang.Rules.Count; i++)
            {
                var rule = _lang.Rules[i];
                var match = rule.Pattern.Match(core);
                if (!match.Success || match.Length != core.Length)
                    continue;

                var replaced = match.Result(rule.Replacement);
                return Rewrap(input, core, replaced);
            }

            return null;
        }

        /// <summary>
        /// "Day 5" -> şablon "Day {0}" aranır, bulunursa sayı geri yerleştirilir.
        /// </summary>
        private string ResolveTemplate(string s)
        {
            if (_lang.Templates.Count == 0)
                return null;

            var matches = NumberRegex.Matches(s);
            if (matches.Count == 0 || matches.Count > 8)
                return null;

            var shape = new StringBuilder(s.Length);
            var values = new string[matches.Count];
            int pos = 0;
            for (int i = 0; i < matches.Count; i++)
            {
                var mm = matches[i];
                shape.Append(s, pos, mm.Index - pos);
                shape.Append('{').Append(i).Append('}');
                values[i] = mm.Value;
                pos = mm.Index + mm.Length;
            }
            shape.Append(s, pos, s.Length - pos);

            if (!_lang.Templates.TryGetValue(shape.ToString(), out var tpl))
                return null;

            return LanguageFile.PlaceholderRegex.Replace(tpl, mm =>
            {
                var idx = int.Parse(mm.Groups[1].Value);
                return idx >= 0 && idx < values.Length ? values[idx] : mm.Value;
            });
        }

        /// <summary>Kırpılmış çekirdek üzerinde çalıştıysak baş/son boşlukları geri koy.</summary>
        private static string Rewrap(string original, string core, string translated)
        {
            if (ReferenceEquals(original, core) || original.Length == core.Length)
                return translated;

            var idx = original.IndexOf(core, StringComparison.Ordinal);
            if (idx < 0)
                return translated;

            return original.Substring(0, idx) + translated + original.Substring(idx + core.Length);
        }
    }
}
