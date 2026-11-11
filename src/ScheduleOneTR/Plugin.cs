using System;
using System.IO;
using HarmonyLib;
using MelonLoader;
using MelonLoader.Utils;
using UnityEngine;
using ScheduleOneTR;

[assembly: MelonInfo(typeof(Plugin), "Schedule I Türkçe Yama", "0.1.0", "chnoz")]
[assembly: MelonGame("TVGS", "Schedule I")]

namespace ScheduleOneTR
{
    public sealed class Plugin : MelonMod
    {
        public static Plugin Instance { get; private set; }
        public static MelonLogger.Instance Log { get; private set; }

        private readonly Translator _translator = new Translator();
        private readonly StringDump _dump = new StringDump();

        private string _baseDir;
        private float _nextScan;
        private float _nextFlush;
        private bool _fontChecked;

        // --- Ayarlar ---
        private MelonPreferences_Entry<bool> _pEnabled;
        private MelonPreferences_Entry<string> _pLanguage;
        private MelonPreferences_Entry<bool> _pExport;
        private MelonPreferences_Entry<float> _pScanInterval;
        private MelonPreferences_Entry<float> _pFlushInterval;
        private MelonPreferences_Entry<string> _pReloadKey;
        private MelonPreferences_Entry<string> _pToggleKey;
        private MelonPreferences_Entry<string> _pFallbackFont;
        private MelonPreferences_Entry<int> _pFontSampling;
        private MelonPreferences_Entry<bool> _pDiagnostics;

        private KeyCode _reloadKey = KeyCode.F9;
        private KeyCode _toggleKey = KeyCode.F10;
        private bool _hotkeysUsable = true;

        /// <summary>Hook'ların hızlıca bakacağı bayrak.</summary>
        public bool Active { get; private set; }

        public override void OnInitializeMelon()
        {
            Instance = this;
            Log = LoggerInstance;

            _baseDir = Path.Combine(MelonEnvironment.UserDataDirectory, "ScheduleOneTR");
            Directory.CreateDirectory(_baseDir);
            Directory.CreateDirectory(Path.Combine(_baseDir, "languages"));

            SetupPreferences();
            _dump.Init(_baseDir);
            _dump.Enabled = _pExport.Value;

            LoadLanguage();

            TmpHooks.Install(HarmonyInstance);
            Active = _pEnabled.Value;

            Log.Msg($"Hazır. Yamalanan metot: {TmpHooks.PatchedCount}, " +
                    $"dil: {_translator.LanguageName}, satır: {_translator.EntryCount}, " +
                    $"metin dökümü: {(_dump.Enabled ? "açık" : "kapalı")}");
            Log.Msg($"Klasör: {_baseDir}");
        }

        private void SetupPreferences()
        {
            var cat = MelonPreferences.CreateCategory("ScheduleOneTR", "Schedule I Türkçe Yama");

            _pEnabled = cat.CreateEntry("Enabled", true,
                description: "Çeviriyi aç/kapat.");
            _pLanguage = cat.CreateEntry("LanguageFolder", "tr",
                description: "UserData/ScheduleOneTR/languages altındaki klasör adı.");
            _pExport = cat.CreateEntry("ExportEnglishStrings", true,
                description: "Karşılığı bulunamayan İngilizce metinleri export/ klasörüne yaz.");
            _pScanInterval = cat.CreateEntry("ScanIntervalSeconds", 1.0f,
                description: "Sahnedeki metinlerin yeniden taranma aralığı. 0 = tarama kapalı.");
            _pFlushInterval = cat.CreateEntry("ExportFlushSeconds", 15.0f,
                description: "Metin dökümünün diske yazılma aralığı.");
            _pReloadKey = cat.CreateEntry("ReloadHotkey", "F9",
                description: "Çeviri dosyalarını oyunu kapatmadan yeniden yükler.");
            _pToggleKey = cat.CreateEntry("ToggleHotkey", "F10",
                description: "Çeviriyi anlık aç/kapat (İngilizce ile karşılaştırmak için).");
            _pFallbackFont = cat.CreateEntry("FallbackFontName", "",
                description: "Eksik karakterler için işletim sistemi fontu. Boşsa Segoe UI denenir.");
            _pFontSampling = cat.CreateEntry("FallbackFontSize", 48,
                description: "Yedek fontun atlas örnekleme boyutu.");
            _pDiagnostics = cat.CreateEntry("LogDiagnostics", false,
                description: "Font ve eşleşme teşhis kayıtlarını yaz.");

            _reloadKey = ParseKey(_pReloadKey.Value, KeyCode.F9);
            _toggleKey = ParseKey(_pToggleKey.Value, KeyCode.F10);
        }

        private static KeyCode ParseKey(string s, KeyCode fallback)
        {
            if (string.IsNullOrEmpty(s) || s.Equals("None", StringComparison.OrdinalIgnoreCase))
                return KeyCode.None;
            try { return (KeyCode)Enum.Parse(typeof(KeyCode), s, true); }
            catch { return fallback; }
        }

        // ---------------------------------------------------------------- dil

        public void LoadLanguage()
        {
            var dir = Path.Combine(_baseDir, "languages", _pLanguage.Value);
            var lang = LanguageFile.LoadDirectory(dir, w => Log.Warning(w));
            _translator.SetLanguage(lang);

            if (lang.EntryCount == 0)
            {
                Log.Warning($"'{dir}' içinde çeviri bulunamadı. " +
                            "Oyunu bir süre oynayıp export/english_strings.txt dosyasını doldur, " +
                            "sonra bu klasöre kopyala.");
            }
            else
            {
                Log.Msg($"Dil yüklendi: {lang.Name} — {lang.Exact.Count} birebir, " +
                        $"{lang.Templates.Count} şablon, {lang.Rules.Count} regex.");
            }
        }

        /// <summary>Hook'ların çağırdığı tek giriş noktası.</summary>
        public string TranslateAndRecord(string source)
        {
            var hit = _translator.Translate(source);
            if (hit == null)
                _dump.Record(source);
            return hit;
        }

        // -------------------------------------------------------------- döngü

        public override void OnUpdate()
        {
            HandleHotkeys();

            var now = Time.unscaledTime;

            if (_pScanInterval.Value > 0f && now >= _nextScan)
            {
                _nextScan = now + _pScanInterval.Value;
                if (Active)
                    SweepScene();
            }

            if (now >= _nextFlush)
            {
                _nextFlush = now + Math.Max(5f, _pFlushInterval.Value);
                _dump.FlushIfDue(0);
            }
        }

        private void HandleHotkeys()
        {
            if (!_hotkeysUsable)
                return;

            try
            {
                if (_reloadKey != KeyCode.None && Input.GetKeyDown(_reloadKey))
                {
                    LoadLanguage();
                    TmpHooks.ClearCaches();
                    _dump.Flush();
                    Log.Msg("Çeviri yeniden yüklendi.");
                }

                if (_toggleKey != KeyCode.None && Input.GetKeyDown(_toggleKey))
                {
                    Active = !Active;
                    Log.Msg($"Çeviri {(Active ? "açık" : "kapalı")}.");
                }
            }
            catch (Exception e)
            {
                // Oyun yeni Input System kullanıyorsa UnityEngine.Input istisna atar.
                _hotkeysUsable = false;
                Log.Warning($"Kısayol tuşları devre dışı: {e.Message}");
            }
        }

        /// <summary>
        /// Prefab'tan gelen ve hiç set edilmeyen metinler hook'a uğramaz. Bunları yakalamak
        /// için sahnedeki TMP bileşenlerini belirli aralıklarla tarayıp metni geri atıyoruz;
        /// atama hook'tan geçtiği için çeviri orada uygulanıyor.
        /// </summary>
        private void SweepScene()
        {
            try
            {
                var all = UnityEngine.Object.FindObjectsOfType<TMP_Text>();
                if (all == null)
                    return;

                foreach (var t in all)
                {
                    if (t == null)
                        continue;

                    string current;
                    try { current = t.text; }
                    catch { continue; }

                    if (string.IsNullOrEmpty(current))
                        continue;

                    var translated = TranslateAndRecord(current);
                    if (translated != null && !string.Equals(translated, current, StringComparison.Ordinal))
                    {
                        try { t.text = translated; } catch { }
                    }

                    if (!_fontChecked)
                        CheckFontOnce(t);

                    if (FontFallback.Ready)
                        FontFallback.AttachTo(t);
                }
            }
            catch (Exception e)
            {
                Log.Warning($"Sahne taraması başarısız: {e.Message}");
            }
        }

        private void CheckFontOnce(TMP_Text sample)
        {
            var missing = FontFallback.MissingTurkishChars(sample);
            if (missing == null)
                return;

            _fontChecked = true;
            Log.Msg($"Oyun fontunda eksik Türkçe karakterler: {missing} — yedek font devreye alınıyor.");
            FontFallback.Ensure(_pFallbackFont.Value, _pFontSampling.Value,
                m => Log.Msg(m));
        }

        public override void OnSceneWasInitialized(int buildIndex, string sceneName)
        {
            TmpHooks.ClearCaches();
            _nextScan = 0f;
            if (_pDiagnostics.Value)
                Log.Msg($"Sahne: {sceneName} — tarama sıfırlandı.");
        }

        public override void OnApplicationQuit()
        {
            _dump.Flush();
            Log.Msg($"Kapanış. Toplanan benzersiz metin: {_dump.Count}");
        }

        public override void OnPreferencesSaved()
        {
            Active = _pEnabled.Value;
            _dump.Enabled = _pExport.Value;
            _reloadKey = ParseKey(_pReloadKey.Value, KeyCode.F9);
            _toggleKey = ParseKey(_pToggleKey.Value, KeyCode.F10);
            LoadLanguage();
        }
    }
}
