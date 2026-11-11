using System;
using System.Collections.Generic;
using System.Reflection;
using HarmonyLib;

namespace ScheduleOneTR
{
    /// <summary>
    /// Metin, çizilmeden hemen önce yakalanır: TMP_Text.text setter'ı ve SetText(...)
    /// aşırı yüklemeleri. Oyunun kendi veri modeline dokunulmaz — kayıt dosyaları,
    /// çok oyunculu senkronizasyon ve oyun mantığı İngilizce metinle çalışmaya devam eder.
    /// </summary>
    internal static class TmpHooks
    {
        /// <summary>Oyuncunun yazdığı alanları çevirmemek için: instance -> input field mi?</summary>
        private static readonly Dictionary<int, bool> _isInput = new Dictionary<int, bool>();

        private static int _patched;
        public static int PatchedCount => _patched;

        public static void Install(Harmony harmony)
        {
            var prefix = new HarmonyMethod(
                typeof(TmpHooks).GetMethod(nameof(Prefix), BindingFlags.Static | BindingFlags.NonPublic));

            foreach (var target in Targets())
            {
                try
                {
                    harmony.Patch(target, prefix: prefix);
                    _patched++;
                }
                catch (Exception e)
                {
                    Plugin.Log?.Warning($"Yama uygulanamadı: {target.DeclaringType?.Name}.{target.Name} ({e.Message})");
                }
            }

            if (_patched == 0)
                Plugin.Log?.Error("Hiçbir TMP metodu yamalanamadı. Mod etkisiz kalacak.");
        }

        private static IEnumerable<MethodBase> Targets()
        {
            var t = typeof(TMP_Text);

            // 1. text property setter
            var setter = AccessTools.PropertySetter(t, "text");
            if (setter != null)
                yield return setter;

            // 2. SetText(string, ...) aşırı yüklemeleri.
            //    Parametre adları TMP sürümüne göre değiştiği için konum tabanlı (__0) okuyoruz.
            foreach (var m in t.GetMethods(BindingFlags.Public | BindingFlags.Instance))
            {
                if (m.Name != "SetText")
                    continue;
                var ps = m.GetParameters();
                if (ps.Length == 0 || ps[0].ParameterType != typeof(string))
                    continue;
                yield return m;
            }
        }

        /// <summary>
        /// __0 = ilk parametre (setter'da atanan değer, SetText'te kaynak metin).
        /// Harmony konumsal parametre adlarını destekliyor; böylece TMP sürümleri arasındaki
        /// parametre adı farkları sorun olmuyor.
        /// </summary>
        private static void Prefix(TMP_Text __instance, ref string __0)
        {
            var plugin = Plugin.Instance;
            if (plugin == null || !plugin.Active || string.IsNullOrEmpty(__0))
                return;

            try
            {
                if (IsPlayerInput(__instance))
                    return;

                var translated = plugin.TranslateAndRecord(__0);
                if (translated != null)
                    __0 = translated;
            }
            catch (Exception e)
            {
                // Çeviri hatası oyunu düşürmesin.
                Plugin.Log?.Warning($"Metin çevirisinde hata: {e.Message}");
            }
        }

        private static bool IsPlayerInput(TMP_Text instance)
        {
            if (instance == null)
                return false;

            int id;
            try { id = instance.GetInstanceID(); }
            catch { return false; }

            if (_isInput.TryGetValue(id, out var known))
                return known;

            bool isInput = false;
            try
            {
                var field = instance.GetComponentInParent<TMP_InputField>();
                isInput = field != null;
            }
            catch { /* bileşen aranamadıysa çevirmeye devam */ }

            if (_isInput.Count < 20000)
                _isInput[id] = isInput;
            return isInput;
        }

        public static void ClearCaches()
        {
            _isInput.Clear();
        }
    }
}
