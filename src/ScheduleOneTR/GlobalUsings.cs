// IL2CPP ile Mono derlemeleri arasındaki tek gerçek fark tip adlarının namespace'i.
// Il2CppInterop, TMPro gibi oyun/eklenti namespace'lerinin başına "Il2Cpp" ekler.
// UnityEngine.* namespace'leri olduğu gibi kalır.
// Burada takma ad veriyoruz, böylece geri kalan kodun tamamı tek sürüm.

#if IL2CPP
global using TMP_Text = Il2CppTMPro.TMP_Text;
global using TMP_InputField = Il2CppTMPro.TMP_InputField;
global using TMP_FontAsset = Il2CppTMPro.TMP_FontAsset;
global using TMP_Settings = Il2CppTMPro.TMP_Settings;
global using AtlasPopulationMode = Il2CppTMPro.AtlasPopulationMode;
#else
global using TMP_Text = TMPro.TMP_Text;
global using TMP_InputField = TMPro.TMP_InputField;
global using TMP_FontAsset = TMPro.TMP_FontAsset;
global using TMP_Settings = TMPro.TMP_Settings;
global using AtlasPopulationMode = TMPro.AtlasPopulationMode;
#endif
