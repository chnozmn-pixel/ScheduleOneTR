using System;
using System.Collections.Generic;
using UnityEngine;

namespace ScheduleOneTR
{
    /// <summary>
    /// TextMeshPro font atlasları önceden pişirilmiş (static) olduğunda, atlasta bulunmayan
    /// karakterler kutu olarak çizilir. Türkçe'de risk altındaki karakterler: ğ Ğ ş Ş ı İ.
    /// (ö ü ç genelde Latin-1'de olduğu için zaten vardır.)
    ///
    /// Çözüm: işletim sistemi fontundan dinamik bir TMP_FontAsset üretip global fallback
    /// listesine ekliyoruz. Eksik karakterler oradan alınıyor, geri kalan her şey oyunun
    /// kendi fontuyla çizilmeye devam ediyor.
    /// </summary>
    internal static class FontFallback
    {
        private static TMP_FontAsset _fallback;
        private static bool _tried;

        /// <summary>Atlasta olup olmadığını kontrol ettiğimiz Türkçe karakterler.</summary>
        private const string TurkishChars = "ğĞşŞıİöÖüÜçÇ";

        public static bool Ready => _fallback != null;

        public static void Ensure(string osFontName, int samplingSize, Action<string> log)
        {
            if (_tried)
                return;
            _tried = true;

            try
            {
                Font osFont = null;

                var candidates = new List<string>();
                if (!string.IsNullOrEmpty(osFontName))
                    candidates.Add(osFontName);
                // Windows'ta bu üçünün hepsinde tam Türkçe desteği var.
                candidates.Add("Segoe UI");
                candidates.Add("Arial");
                candidates.Add("Tahoma");
                candidates.Add("Verdana");

                foreach (var name in candidates)
                {
                    try
                    {
                        osFont = Font.CreateDynamicFontFromOSFont(name, samplingSize);
                        if (osFont != null)
                        {
                            log?.Invoke($"Yedek font: {name}");
                            break;
                        }
                    }
                    catch { /* sıradakini dene */ }
                }

                if (osFont == null)
                {
                    log?.Invoke("İşletim sistemi fontu yüklenemedi; yedek font devre dışı.");
                    return;
                }

                _fallback = TMP_FontAsset.CreateFontAsset(osFont);
                if (_fallback == null)
                {
                    log?.Invoke("TMP_FontAsset oluşturulamadı; yedek font devre dışı.");
                    return;
                }

                _fallback.name = "ScheduleOneTR Fallback";
                try { _fallback.atlasPopulationMode = AtlasPopulationMode.Dynamic; } catch { }
                UnityEngine.Object.DontDestroyOnLoad(_fallback);

                RegisterGlobal(log);
            }
            catch (Exception e)
            {
                log?.Invoke($"Yedek font hazırlanamadı: {e.Message}");
                _fallback = null;
            }
        }

        private static void RegisterGlobal(Action<string> log)
        {
            try
            {
                var list = TMP_Settings.fallbackFontAssets;
                if (list != null)
                {
                    bool already = false;
                    for (int i = 0; i < list.Count; i++)
                        if (list[i] != null && list[i].name == _fallback.name)
                            already = true;

                    if (!already)
                    {
                        list.Add(_fallback);
                        log?.Invoke("Yedek font global TMP fallback listesine eklendi.");
                        return;
                    }
                    return;
                }
                log?.Invoke("TMP_Settings.fallbackFontAssets boş; font başına ekleme yapılacak.");
            }
            catch (Exception e)
            {
                log?.Invoke($"Global fallback listesine eklenemedi ({e.Message}); font başına ekleme yapılacak.");
            }
        }

        /// <summary>
        /// Global liste çalışmazsa (bazı TMP sürümlerinde boş gelir) kullanılan yol:
        /// bir metnin kendi font asset'ine yedek fontu tek seferlik ekler.
        /// </summary>
        public static void AttachTo(TMP_Text text)
        {
            if (_fallback == null || text == null)
                return;

            try
            {
                var fa = text.font;
                if (fa == null || fa == _fallback)
                    return;

                var table = fa.fallbackFontAssetTable;
                if (table == null)
                    return;

                for (int i = 0; i < table.Count; i++)
                    if (table[i] == _fallback)
                        return;

                table.Add(_fallback);
            }
            catch { /* bu font için yedek eklenemedi, önemli değil */ }
        }

        /// <summary>Oyunun fontunda eksik olan Türkçe karakterleri bildirir (teşhis için).</summary>
        public static string MissingTurkishChars(TMP_Text text)
        {
            try
            {
                var fa = text?.font;
                if (fa == null)
                    return null;

                string missing = "";
                foreach (var c in TurkishChars)
                    if (!fa.HasCharacter(c))
                        missing += c;

                return missing.Length > 0 ? missing : null;
            }
            catch
            {
                return null;
            }
        }
    }
}
