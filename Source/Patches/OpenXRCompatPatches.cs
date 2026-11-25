using System.Reflection;
using HarmonyLib;
using JetBrains.Annotations;

namespace RepoXR.Patches;

/// <summary>
/// Compatibility patches for the bundled OpenXR plugin, which was built against an older Unity version than the game.
/// These are applied manually before VR is initialized (see <see cref="Plugin"/>), not by the regular patchers.
/// </summary>
[HarmonyPatch]
internal static class OpenXRCompatPatches
{
    [UsedImplicitly]
    private static MethodBase TargetMethod() =>
        AccessTools.Method(AccessTools.TypeByName("UnityEngine.XR.OpenXR.OpenXRAnalytics"), "SendInitializeEvent");

    /// <summary>
    /// Unity 6 moved <c>UnityEngine.Analytics.AnalyticsResult</c> to another module without a type forwarder, so the
    /// OpenXR analytics code throws a <see cref="System.TypeLoadException"/> while the loader is initializing.
    /// We don't need analytics, so just skip it.
    /// </summary>
    [UsedImplicitly]
    private static bool Prefix() => false;
}
