using HarmonyLib;
using System;
using System.Collections.Generic;
using TerrainTools.Visualization;
using UnityEngine;
using static ClutterSystem;

namespace TerrainTools.Helpers {
    [HarmonyPatch]
    public static class PreciseTerrainModifier {
        public const int FixedRadius = 1;
        public const int FixedPaintRadius = 1;
        private const int SettingsPayloadMagic = 0x41544D53; // ATMS
        private const int SettingsPayloadVersion = 1;
        private const float MinRadius = 0.5f;
        private const float MaxSmoothPower = 30f;

        internal sealed class RuntimeSettings : TerrainOp.Settings {
            internal bool IsReset;
            internal bool HasOverlay;
        }

        internal static RuntimeSettings EnsureRuntimeSettings(TerrainOp terrainOp, bool isReset = false, bool hasOverlay = false) {
            if (terrainOp.m_settings is RuntimeSettings settings) {
                settings.IsReset |= isReset;
                settings.HasOverlay |= hasOverlay;
                return settings;
            }

            settings = CopySettings(terrainOp.m_settings, isReset, hasOverlay);
            terrainOp.m_settings = settings;
            return settings;
        }

        /// <summary>
        ///     Checks if radius is set as flag for precision modifier.
        /// </summary>
        /// <param name="radius"></param>
        /// <returns></returns>
        public static bool IsPrecisionModifier(float radius)
        {
            return radius == float.NegativeInfinity;
        }

        /// <summary>
        ///     Catches invalid radius from precise terrain modifications and modifies it
        ///     to match the fixed radius before executing the ClutterSytem.ResetGrass method.
        /// </summary>
        /// <param name="__instance"></param>
        /// <param name="center"></param>
        /// <param name="radius"></param>
        [HarmonyPrefix]
        [HarmonyPatch(typeof(ClutterSystem), nameof(ClutterSystem.ResetGrass))]
        private static void ResetGrassPrefix(ClutterSystem __instance, Vector3 center, ref float radius)
        {
            if (IsPrecisionModifier(radius))
            {
                radius = FixedRadius;
            }
        }

        [HarmonyPrefix]
        [HarmonyPatch(typeof(TerrainComp), nameof(TerrainComp.ApplyOperation))]
        private static bool ApplyOperationPrefix(TerrainComp __instance, TerrainOp modifier) {
            if (!modifier || !modifier.gameObject) {
                return true;
            }

            var overlay = modifier.gameObject.GetComponentInChildren<OverlayVisualizer>();
            var settings = modifier.m_settings as RuntimeSettings;
            if (settings == null && (overlay || InitManager.IsCustomTool(modifier.gameObject))) {
                settings = EnsureRuntimeSettings(
                    modifier,
                    overlay is RemoveModificationsOverlayVisualizer,
                    overlay != null
                );
            }
            if (settings == null) return true;

            if (!HasAreaAccess(modifier, modifier.transform.position, false)) {
                Log.LogWarning("Blocked a terrain operation whose brush intersects a protected area");
                return false;
            }

            // Valheim 1.0 resolves TerrainOp settings on the owner. Claim before
            // sending so the process with this compatibility patch applies them.
            if (__instance && __instance.m_nview && __instance.m_nview.IsValid() && !__instance.m_nview.IsOwner()) {
                __instance.m_nview.ClaimOwnership();
            }

            // Set radius to -inf so I can check if custom overlay in later methods
            if (settings.HasOverlay) {
                if (settings.m_smooth) {
                    settings.m_smoothRadius = float.NegativeInfinity;
                }
                if (settings.m_raise && settings.m_raiseDelta >= 0) {
                    settings.m_raiseRadius = float.NegativeInfinity;
                    settings.m_raiseDelta = GroundLevelSpinner.Value;
                }
                if (settings.m_paintCleared) {
                    settings.m_paintRadius = float.NegativeInfinity;
                }
            }
            return true;
        }

        internal static bool HasAreaAccess(TerrainOp modifier, Vector3 position, bool flash) {
            if (!Player.m_localPlayer || !modifier) {
                return true;
            }

            var radius = modifier.GetRadius();
            if (!IsFinite(radius) || radius < 0f) {
                return false;
            }
            var settings = modifier.m_settings as RuntimeSettings;
            if (modifier.m_settings.m_square || settings?.HasOverlay == true || settings?.IsReset == true) {
                radius *= 1.414214f;
            }
            return PrivateArea.CheckAccess(position, radius, flash, true);
        }

        [HarmonyPostfix]
        [HarmonyPatch(typeof(TerrainOp), nameof(TerrainOp.GetRadius))]
        private static void GetRadiusPostfix(TerrainOp __instance, ref float __result) {
            if (!__instance) return;
            var overlay = __instance.gameObject.GetComponent<OverlayVisualizer>();
            if (overlay is RemoveModificationsOverlayVisualizer) {
                __result = Mathf.Max(__result, __instance.m_settings.m_levelRadius + 1f);
            } else if (overlay is RaiseGroundOverlayVisualizer) {
                // Awake chooses every affected Heightmap before ApplyOperation sets precision flags.
                __result = Mathf.Max(__result, PreciseRaiseMath.InfluenceRadius);
            } else if (overlay && __instance.m_settings.m_paintCleared) {
                __result = Mathf.Max(__result, FixedPaintRadius);
            }
        }

        [HarmonyPostfix]
        [HarmonyPatch(typeof(TerrainOp.Settings), nameof(TerrainOp.Settings.GetRadius))]
        private static void GetSettingsRadiusPostfix(TerrainOp.Settings __instance, ref float __result) {
            if (__instance.m_raise && IsPrecisionModifier(__instance.m_raiseRadius)) {
                __result = Mathf.Max(__result, PreciseRaiseMath.InfluenceRadius);
            }
            if ((__instance.m_smooth && IsPrecisionModifier(__instance.m_smoothRadius))
                || (__instance.m_paintCleared && IsPrecisionModifier(__instance.m_paintRadius))) {
                __result = Mathf.Max(__result, FixedRadius);
            }
        }

        private static void RemoveLegacyTerrainModifiers(Vector3 position, float radius) {
            var modifiers = new List<TerrainModifier>();
            TerrainModifier.GetModifiers(position, radius + 1f, modifiers);
            foreach (var modifier in modifiers) {
                var modifierRadius = modifier ? modifier.GetRadius() : 0f;
                if (!modifier || !modifier.m_nview
                    || !modifier.m_nview.IsValid()
                    || !modifier.m_playerModifiction
                    || modifier.GetComponentInParent<Piece>()
                    || modifier.GetComponentInParent<WearNTear>()
                    || Mathf.Abs(modifier.transform.position.x - position.x) + modifierRadius > radius
                    || Mathf.Abs(modifier.transform.position.z - position.z) + modifierRadius > radius
                    || (Player.m_localPlayer && !PrivateArea.CheckAccess(modifier.transform.position, modifierRadius, false, true))) {
                    continue;
                }
                modifier.m_nview.ClaimOwnership();
                if (ZNetScene.instance) {
                    ZNetScene.instance.Destroy(modifier.gameObject);
                }
            }
        }

        /// <summary>
        ///     Valheim 1.0 serializes only the TerrainOp prefab hash. Preserve the
        ///     runtime values changed by precision, radius, and hardness controls.
        /// </summary>
        [HarmonyPostfix]
        [HarmonyPatch(typeof(TerrainOp.Settings), nameof(TerrainOp.Settings.Serialize))]
        private static void SerializeSettingsPostfix(TerrainOp.Settings __instance, ZPackage pkg) {
            if (__instance is not RuntimeSettings settings || pkg == null) {
                return;
            }

            pkg.Write(SettingsPayloadMagic);
            pkg.Write(SettingsPayloadVersion);
            pkg.Write(settings.m_levelRadius);
            pkg.Write(settings.m_raiseRadius);
            pkg.Write(settings.m_raisePower);
            pkg.Write(settings.m_raiseDelta);
            pkg.Write(settings.m_smoothRadius);
            pkg.Write(settings.m_smoothPower);
            pkg.Write(settings.m_paintRadius);
        }

        [HarmonyPostfix]
        [HarmonyPatch(typeof(TerrainOp.Settings), nameof(TerrainOp.Settings.Deserialize))]
        private static void DeserializeSettingsPostfix(ZPackage pkg, ref TerrainOp.Settings __result) {
            const int payloadSize = sizeof(int) * 2 + sizeof(float) * 7;
            if (__result == null || pkg == null || pkg.Size() - pkg.GetPos() < sizeof(int)) {
                return;
            }

            var payloadStart = pkg.GetPos();
            if (pkg.ReadInt() != SettingsPayloadMagic) {
                pkg.SetPos(payloadStart);
                return;
            }
            if (pkg.Size() - payloadStart < payloadSize || pkg.ReadInt() != SettingsPayloadVersion) {
                Log.LogWarning("Rejected incomplete or unsupported terrain-operation settings");
                __result = null;
                return;
            }

            var source = __result as RuntimeSettings;
            var isReset = source?.IsReset ?? false;
            var hasOverlay = source?.HasOverlay ?? false;
            var settings = CopySettings(__result, isReset, hasOverlay);
            settings.m_levelRadius = pkg.ReadSingle();
            settings.m_raiseRadius = pkg.ReadSingle();
            settings.m_raisePower = pkg.ReadSingle();
            settings.m_raiseDelta = pkg.ReadSingle();
            settings.m_smoothRadius = pkg.ReadSingle();
            settings.m_smoothPower = pkg.ReadSingle();
            settings.m_paintRadius = pkg.ReadSingle();
            if (!IsValid(settings)) {
                Log.LogWarning("Rejected invalid network terrain-operation settings");
                __result = null;
                return;
            }
            __result = settings;
        }

        private static RuntimeSettings CopySettings(TerrainOp.Settings source, bool isReset, bool hasOverlay) {
            return new RuntimeSettings {
                IsReset = isReset,
                HasOverlay = hasOverlay,
                m_levelOffset = source.m_levelOffset,
                m_level = source.m_level,
                m_levelRadius = source.m_levelRadius,
                m_square = source.m_square,
                m_raise = source.m_raise,
                m_raiseRadius = source.m_raiseRadius,
                m_raisePower = source.m_raisePower,
                m_raiseDelta = source.m_raiseDelta,
                m_smooth = source.m_smooth,
                m_smoothRadius = source.m_smoothRadius,
                m_smoothPower = source.m_smoothPower,
                m_paintCleared = source.m_paintCleared,
                m_paintHeightCheck = source.m_paintHeightCheck,
                m_paintType = source.m_paintType,
                m_paintRadius = source.m_paintRadius,
                m_paintStrength = source.m_paintStrength,
                m_paintExp = source.m_paintExp,
                m_paintCurve = source.m_paintCurve,
                m_rotation = source.m_rotation,
                m_sides = source.m_sides,
                m_addMedianMax = source.m_addMedianMax,
                m_centerMultiplicationFactor = source.m_centerMultiplicationFactor,
                m_pointMultiplicationFactor = source.m_pointMultiplicationFactor,
                m_halfOffset = source.m_halfOffset
            };
        }

        private static bool IsValid(RuntimeSettings settings) {
            if (!IsRadius(settings.m_levelRadius, settings.IsReset ? FixedRadius : MinRadius)) return false;
            if (settings.m_raise && !IsPrecisionRadius(settings.m_raiseRadius, settings.HasOverlay)) return false;
            if (settings.m_smooth && !IsPrecisionRadius(settings.m_smoothRadius, settings.HasOverlay)) return false;
            if (settings.m_paintCleared && !IsPrecisionRadius(settings.m_paintRadius, settings.HasOverlay)) return false;
            if (settings.m_raise && (!IsFinite(settings.m_raisePower) || settings.m_raisePower < PreciseRaiseMath.MinPower || settings.m_raisePower > PreciseRaiseMath.MaxPower)) return false;
            if (settings.m_raise && (!IsFinite(settings.m_raiseDelta) || settings.m_raiseDelta < -1f || settings.m_raiseDelta > 1f)) return false;
            if (settings.m_smooth && (!IsFinite(settings.m_smoothPower) || settings.m_smoothPower < 1f || settings.m_smoothPower > MaxSmoothPower)) return false;
            return true;
        }

        private static bool IsPrecisionRadius(float value, bool allowPrecision) {
            return (allowPrecision && IsPrecisionModifier(value)) || IsRadius(value, MinRadius);
        }

        private static bool IsRadius(float value, float minimum) {
            return IsFinite(value) && value >= minimum && value <= TerrainTools.MaxRadius;
        }

        private static bool IsFinite(float value) {
            return !float.IsNaN(value) && !float.IsInfinity(value);
        }

        /// <summary>
        ///     Apply TerrainReset operation if valid
        /// </summary>
        /// <param name="__instance"></param>
        /// <param name="pos"></param>
        /// <param name="modifier"></param>
        [HarmonyPrefix]
        [HarmonyPatch(typeof(TerrainComp), nameof(TerrainComp.InternalDoOperation))]
        private static bool InternalDoOperationPrefix(
            TerrainComp __instance,
            Vector3 pos,
            TerrainOp.Settings modifier
        ) {
            if (modifier is RuntimeSettings { IsReset: true }) {
                var radius = Mathf.Clamp(Mathf.RoundToInt(modifier.m_levelRadius), FixedRadius, Mathf.CeilToInt(TerrainTools.MaxRadius));
                RemoveLegacyTerrainModifiers(pos, radius);
                RemoveTerrainModifications(__instance, pos, radius);
                PreciseRecolorTerrain(__instance, pos, TerrainModifier.PaintType.Reset, radius: radius);
            }
            return true;
        }

        /// <summary>
        ///     Correct m_lastOpRadius to be FixedRadius instead of -Infinity
        ///     if a Precision Modifier was the last operation applied. This
        ///     avoids issues caused by saving an invalid radius.
        /// </summary>
        /// <param name="__instance"></param>
        /// <param name="pos"></param>
        /// <param name="modifier"></param>
        [HarmonyPostfix]
        [HarmonyPatch(typeof(TerrainComp), nameof(TerrainComp.InternalDoOperation))]
        private static void InternalDoOperationPostfix(TerrainComp __instance)
        {
            if (IsPrecisionModifier(__instance.m_lastOpRadius))
            {
                __instance.m_lastOpRadius = FixedRadius;
            }
        }

        [HarmonyPrefix]
        [HarmonyPatch(typeof(TerrainComp), nameof(TerrainComp.SmoothTerrain))]
        private static bool PreciseSmoothTerrian(
            TerrainComp __instance,
            Vector3 worldPos,
            float radius
        )
        {
            if (!IsPrecisionModifier(radius)) {
                return true;
            }

            Log.LogInfo("PreciseSmoothTerrain", LogLevel.Medium);
            //var worldSize = __instance.m_hmap.m_width + 1;
            var worldSize = __instance.m_width + 1;
            __instance.m_hmap.WorldToVertex(worldPos, out int xPos, out int yPos);
            var refHeight = worldPos.y - __instance.transform.position.y;
            Log.LogInfo($"worldPos: {worldPos}, xPos: {xPos}, yPos: {yPos}, referenceH: {refHeight}", LogLevel.Medium);

            FindExtrema(xPos, worldSize, out var xMin, out var xMax);
            FindExtrema(yPos, worldSize, out var yMin, out var yMax);

            for (var i = xMin; i <= xMax; i++) {
                for (var j = yMin; j <= yMax; j++) {
                    //Log.LogInfo("SmoothTerrain");
                    //Log.LogInfo($"X: {i}, {xMin}, {xMax}");
                    //Log.LogInfo($"Y: {j}, {yMin}, {yMax}");
                    var tileIndex = j * worldSize + i;
                    var tileHeight = __instance.m_hmap.GetHeight(i, j);
                    var deltaH = refHeight - tileHeight;
                    var prevSmoothDelta = __instance.m_smoothDelta[tileIndex];
                    __instance.m_smoothDelta[tileIndex] = Mathf.Clamp(prevSmoothDelta + deltaH, -1f, 1f);
                    __instance.m_modifiedHeight[tileIndex] = true;

                    Log.LogInfo($"tilePos: ({i}, {j}), tileH: {tileHeight}, deltaH: {deltaH}, prevSmoothDelta: {prevSmoothDelta}, newSmoothDelta {__instance.m_smoothDelta[tileIndex]}", LogLevel.Medium);
                }
            }
            Log.LogInfo("[SUCCESS] Smooth Terrain Modification", LogLevel.Medium);

            return false;
        }

        [HarmonyPrefix]
        [HarmonyPatch(typeof(TerrainComp), nameof(TerrainComp.RaiseTerrain))]
        private static bool RaiseTerrainPrefix(TerrainComp __instance, Vector3 worldPos, float radius, float delta, float power) {
            if (!IsPrecisionModifier(radius)) {
                return true;
            }
            Log.LogInfo("[INIT] Raise Terrain Modification", LogLevel.Medium);
            var worldSize = __instance.m_width + 1;
            __instance.m_hmap.WorldToVertex(worldPos, out var xPos, out var yPos);
            var refHeight = worldPos.y - __instance.transform.position.y;
            Log.LogInfo(
                $"worldPos: {worldPos}, xPos: {xPos}, yPos: {yPos}, delta: {delta}, refHeight: {refHeight}",
                LogLevel.Medium
            );

            FindExtrema(xPos, worldSize, PreciseRaiseMath.ModifiedRadius, out var xMin, out var xMax);
            FindExtrema(yPos, worldSize, PreciseRaiseMath.ModifiedRadius, out var yMin, out var yMax);

            for (var i = xMin; i <= xMax; i++) {
                for (var j = yMin; j <= yMax; j++) {
                    var tileHeight = __instance.m_hmap.GetHeight(i, j);
                    var weight = PreciseRaiseMath.Weight(i - xPos, j - yPos, power);
                    if (!PreciseRaiseMath.TryGetTargetHeight(tileHeight, refHeight, delta, weight, out var targetHeight)) {
                        continue;
                    }

                    var tileIndex = j * worldSize + i;
                    var deltaH = targetHeight - tileHeight + __instance.m_smoothDelta[tileIndex];
                    __instance.m_smoothDelta[tileIndex] = 0f;
                    __instance.m_levelDelta[tileIndex] += deltaH;
                    __instance.m_levelDelta[tileIndex] = Mathf.Clamp(__instance.m_levelDelta[tileIndex], -8f, 8f);
                    __instance.m_modifiedHeight[tileIndex] = true;
                }
            }
            Log.LogInfo("[SUCCESS] Raise Terrain Modification", LogLevel.Medium);

            return false;
        }

        [HarmonyPrefix]
        [HarmonyPatch(typeof(TerrainComp), nameof(TerrainComp.PaintCleared))]
        private static bool PaintClearedPrefix(
            TerrainComp __instance,
            Vector3 worldPos,
            TerrainOp.Settings settings
        ) {
            if (!IsPrecisionModifier(settings.m_paintRadius)) {
                return true;
            }

            PreciseRecolorTerrain(__instance, worldPos, settings.m_paintType, settings.m_paintHeightCheck);
            return false;
        }


        public static void RemoveTerrainModifications(TerrainComp comp, Vector3 worldPos, int radius = FixedRadius) {
            Log.LogInfo("[INIT] Remove Terrain Modifications", LogLevel.Medium);

            var worldSize = comp.m_width + 1;
            comp.m_hmap.WorldToVertex(worldPos, out var xPos, out var yPos);
            Log.LogInfo($"worldPos: {worldPos}, vertexPos: ({xPos}, {yPos})", LogLevel.Medium);

            FindExtrema(xPos, worldSize, radius, out var xMin, out var xMax);
            FindExtrema(yPos, worldSize, radius, out var yMin, out var yMax);
            Log.LogInfo(
                $"Reset chunk {comp.transform.position}: radius={radius}, vertices=({xMin}..{xMax}, {yMin}..{yMax}), " +
                $"edge={xMin == 0 || yMin == 0 || xMax == worldSize - 1 || yMax == worldSize - 1}",
                LogLevel.Low
            );
            for (var x = xMin; x <= xMax; x++) {
                for (var y = yMin; y <= yMax; y++) {
                    var tileIndex = y * worldSize + x;
                    comp.m_levelDelta[tileIndex] = 0;
                    comp.m_smoothDelta[tileIndex] = 0;
                    comp.m_modifiedHeight[tileIndex] = false;
                    Log.LogInfo($"tilePos: ({x}, {y}), tileIndex: {tileIndex}", LogLevel.Medium);
                }
            }
            Log.LogInfo("[SUCCESS] Remove Terrain Modifications", LogLevel.Medium);
        }

        public static void PreciseRecolorTerrain(
            TerrainComp comp,
            Vector3 worldPos,
            TerrainModifier.PaintType paintType,
            bool heightCheck = false,
            int radius = FixedPaintRadius
        ) {
            Log.LogInfo("[INIT] PreciseRecolorTerrain", LogLevel.Medium);
            var tileColor = ResolveColor(paintType);

            GetPaintMaskBounds(
                comp.m_hmap,
                worldPos,
                radius,
                out var xStart,
                out var xMax,
                out var yStart,
                out var yMax
            );
            var worldSize = comp.m_width + 1;

            for (var i = xStart; i <= xMax; i++) {
                for (var j = yStart; j <= yMax; j++)
                {
                    //Log.LogInfo("EditPaint");
                    //Log.LogInfo($"X: {i}, {xMin}, {xMax}");
                    //Log.LogInfo($"Y: {j}, {yMin}, {yMax}");
                    //Try logging values of xMin and xMax along with i?
                    tileColor.a = comp.m_hmap.GetPaintMask(i, j).a;  // avoids lava
                    var tileIndex = (j * worldSize) + i;
                    comp.m_paintMask[tileIndex] = tileColor;
                    comp.m_modifiedPaint[tileIndex] = true;
                    Log.LogInfo($"tilePos: ({i}, {j}), tileIndex: {tileIndex}, tileColor: {tileColor}", LogLevel.Medium);
                }
            }
            Log.LogInfo("[SUCCESS] Color Terrain Modification", LogLevel.Medium);
        }

        public static void GetPaintMaskBounds(
            Heightmap heightmap,
            Vector3 worldPos,
            int radius,
            out int xStart,
            out int xMax,
            out int yStart,
            out int yMax
        ) {
            heightmap.WorldToVertex(worldPos, out var xPos, out var yPos);
            // Symmetric logical vertices also select both copies of an affected zone border.
            PaintGridMath.GetAxisIndices(heightmap.m_width, xPos, radius, out xStart, out xMax);
            PaintGridMath.GetAxisIndices(heightmap.m_width, yPos, radius, out yStart, out yMax);
        }

        public static bool TryGetPaintMaskWorldBounds(
            Heightmap heightmap,
            Vector3 worldPos,
            int radius,
            out Vector2 min,
            out Vector2 max
        ) {
            GetPaintMaskBounds(
                heightmap,
                worldPos,
                radius,
                out var xStart,
                out var xMax,
                out var yStart,
                out var yMax
            );

            var hasX = PaintGridMath.TryGetAxisBounds(
                heightmap.m_width,
                heightmap.m_scale,
                heightmap.transform.position.x,
                xStart,
                xMax,
                out var minX,
                out var maxX
            );
            var hasZ = PaintGridMath.TryGetAxisBounds(
                heightmap.m_width,
                heightmap.m_scale,
                heightmap.transform.position.z,
                yStart,
                yMax,
                out var minZ,
                out var maxZ
            );

            if (!hasX || !hasZ) {
                min = default;
                max = default;
                return false;
            }

            min = new Vector2(minX, minZ);
            max = new Vector2(maxX, maxZ);
            return true;
        }

        public static UnityEngine.Color ResolveColor(TerrainModifier.PaintType paintType) {
            switch (paintType) {
                case TerrainModifier.PaintType.Dirt:
                    return Heightmap.m_paintMaskDirt;
                case TerrainModifier.PaintType.Cultivate:
                    return Heightmap.m_paintMaskCultivated;
                case TerrainModifier.PaintType.Paved:
                    return Heightmap.m_paintMaskPaved;
                case TerrainModifier.PaintType.Reset:
                    return Heightmap.m_paintMaskNothing;
                default:
                    break;
            }
            return Heightmap.m_paintMaskNothing;
        }


        /// <summary>
        ///     Finds the bounds to loop over for square tools
        /// </summary>
        /// <param name="x"></param>
        /// <param name="worldSize"></param>
        /// <param name="xMin"></param>
        /// <param name="xMax"></param>
        public static void FindExtrema(int x, int worldSize, out int xMin, out int xMax) {
            FindExtrema(x, worldSize, FixedRadius, out xMin, out xMax);
        }

        private static void FindExtrema(int x, int worldSize, int radius, out int xMin, out int xMax) {
            PaintGridMath.GetAxisIndices(worldSize - 1, x, radius, out xMin, out xMax);
        }
    }
}
