using HarmonyLib;
using System;
using System.Collections.Generic;
using TerrainTools.Visualization;
using UnityEngine;
using static ClutterSystem;

namespace TerrainTools.Helpers {
    [HarmonyPatch(typeof(PreciseTerrainModifier))]
    public static class PreciseTerrainModifier {
        public const int FixedRadius = 1;
        public const int FixedPaintRadius = 1;
        private const int SettingsPayloadMagic = 0x41544D53; // ATMS
        private const int SettingsPayloadVersion = 1;

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
        private static void ApplyOperationPrefix(TerrainComp __instance, TerrainOp modifier) {
            if (!modifier || !modifier.gameObject) { return; }

            // Valheim 1.0 resolves TerrainOp settings on the owner. Claim before
            // sending so the process with this compatibility patch applies them.
            if (__instance && __instance.m_nview && !__instance.m_nview.IsOwner()) {
                __instance.m_nview.ClaimOwnership();
            }

            // Set radius to -inf so I can check if custom overlay in later methods
            if (modifier.gameObject.GetComponentInChildren<OverlayVisualizer>()) {
                if (modifier.m_settings.m_smooth) {
                    modifier.m_settings.m_smoothRadius = float.NegativeInfinity;
                }
                if (modifier.m_settings.m_raise && modifier.m_settings.m_raiseDelta >= 0) {
                    modifier.m_settings.m_raiseRadius = float.NegativeInfinity;
                    modifier.m_settings.m_raiseDelta = GroundLevelSpinner.Value;
                }
                if (modifier.m_settings.m_paintCleared) {
                    modifier.m_settings.m_paintRadius = float.NegativeInfinity;
                }
            }
        }

        [HarmonyPostfix]
        [HarmonyPatch(typeof(TerrainOp), nameof(TerrainOp.GetRadius))]
        private static void GetRadiusPostfix(TerrainOp __instance, ref float __result) {
            if (__instance && __instance.gameObject.GetComponent<RemoveModificationsOverlayVisualizer>()) {
                __result = Mathf.Max(__result, __instance.m_settings.m_levelRadius + 1f);
            }
        }

        [HarmonyPostfix]
        [HarmonyPatch(typeof(TerrainOp.Settings), nameof(TerrainOp.Settings.GetRadius))]
        private static void GetSettingsRadiusPostfix(TerrainOp.Settings __instance, ref float __result) {
            if ((__instance.m_raise && IsPrecisionModifier(__instance.m_raiseRadius))
                || (__instance.m_smooth && IsPrecisionModifier(__instance.m_smoothRadius))
                || (__instance.m_paintCleared && IsPrecisionModifier(__instance.m_paintRadius))) {
                __result = Mathf.Max(__result, FixedRadius);
            }
        }

        private static void RemoveLegacyTerrainModifiers(Vector3 position, float radius) {
            var modifiers = new List<TerrainModifier>();
            TerrainModifier.GetModifiers(position, radius + 1f, modifiers);
            foreach (var modifier in modifiers) {
                if (!modifier || !modifier.m_nview) {
                    continue;
                }
                modifier.m_nview.ClaimOwnership();
                ZNetScene.instance.Destroy(modifier.gameObject);
            }
        }

        /// <summary>
        ///     Valheim 1.0 serializes only the TerrainOp prefab hash. Preserve the
        ///     runtime values changed by precision, radius, and hardness controls.
        /// </summary>
        [HarmonyPostfix]
        [HarmonyPatch(typeof(TerrainOp.Settings), nameof(TerrainOp.Settings.Serialize))]
        private static void SerializeSettingsPostfix(TerrainOp.Settings __instance, ZPackage pkg) {
            if (__instance == null || pkg == null) {
                return;
            }

            pkg.Write(SettingsPayloadMagic);
            pkg.Write(SettingsPayloadVersion);
            pkg.Write(__instance.m_levelRadius);
            pkg.Write(__instance.m_raiseRadius);
            pkg.Write(__instance.m_raisePower);
            pkg.Write(__instance.m_raiseDelta);
            pkg.Write(__instance.m_smoothRadius);
            pkg.Write(__instance.m_smoothPower);
            pkg.Write(__instance.m_paintRadius);
        }

        [HarmonyPostfix]
        [HarmonyPatch(typeof(TerrainOp.Settings), nameof(TerrainOp.Settings.Deserialize))]
        private static void DeserializeSettingsPostfix(ZPackage pkg, ref TerrainOp.Settings __result) {
            const int payloadSize = sizeof(int) * 2 + sizeof(float) * 7;
            if (__result == null || pkg == null || pkg.Size() - pkg.GetPos() < payloadSize) {
                return;
            }

            var payloadStart = pkg.GetPos();
            if (pkg.ReadInt() != SettingsPayloadMagic || pkg.ReadInt() != SettingsPayloadVersion) {
                pkg.SetPos(payloadStart);
                return;
            }

            var settings = CopySettings(__result);
            settings.m_levelRadius = pkg.ReadSingle();
            settings.m_raiseRadius = pkg.ReadSingle();
            settings.m_raisePower = pkg.ReadSingle();
            settings.m_raiseDelta = pkg.ReadSingle();
            settings.m_smoothRadius = pkg.ReadSingle();
            settings.m_smoothPower = pkg.ReadSingle();
            settings.m_paintRadius = pkg.ReadSingle();
            __result = settings;
        }

        private static TerrainOp.Settings CopySettings(TerrainOp.Settings source) {
            return new TerrainOp.Settings {
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

        /// <summary>
        ///     Apply TerrainReset operation if valid
        /// </summary>
        /// <param name="__instance"></param>
        /// <param name="pos"></param>
        /// <param name="modifier"></param>
        [HarmonyPrefix]
        [HarmonyPatch(typeof(TerrainComp), nameof(TerrainComp.InternalDoOperation))]
        private static void InternalDoOperationPrefix(
            TerrainComp __instance,
            Vector3 pos,
            TerrainOp.Settings modifier
        ) {
            if (!modifier.m_level && !modifier.m_raise && !modifier.m_smooth && !modifier.m_paintCleared) {
                var radius = Mathf.Clamp(Mathf.RoundToInt(modifier.m_levelRadius), FixedRadius, Mathf.CeilToInt(TerrainTools.MaxRadius));
                RemoveLegacyTerrainModifiers(pos, radius);
                RemoveTerrainModifications(__instance, pos, radius);
                PreciseRecolorTerrain(__instance, pos, TerrainModifier.PaintType.Reset, radius: radius);
            }
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
        private static bool RaiseTerrainPrefix(TerrainComp __instance, Vector3 worldPos, float radius, float delta) {
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

            FindExtrema(xPos, worldSize, out var xMin, out var xMax);
            FindExtrema(yPos, worldSize, out var yMin, out var yMax);

            for (var i = xMin; i <= xMax; i++) {
                for (var j = yMin; j <= yMax; j++) {
                    var tileHeight = __instance.m_hmap.GetHeight(i, j);
                    var targetHeight = refHeight + delta;

                    if (delta < 0f && targetHeight > tileHeight) {
                        continue;
                    }

                    if (delta >= 0f) {
                        if (targetHeight < tileHeight) {
                            continue;
                        }
                        if (targetHeight > tileHeight + delta) {
                            targetHeight = tileHeight + delta;
                        }
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
            var worldSize = heightmap.m_width + 1;
            heightmap.WorldToVertexMask(worldPos, out var xPos, out var yPos);

            FindExtrema(xPos, worldSize, radius, out var xMin, out xMax);
            FindExtrema(yPos, worldSize, radius, out var yMin, out yMax);

            // Mask index zero is the duplicated west/south border. Everywhere
            // else precision paint starts at the selected cell, not its neighbour.
            xStart = xPos <= 0 ? xMin : xMin + 1;
            yStart = yPos <= 0 ? yMin : yMin + 1;
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

        public static int GetHeightRadiusCells(TerrainOp.Settings settings, float vertexScale) {
            var radius = -1;
            if (settings.m_level) {
                var levelRadius = settings.m_levelRadius / vertexScale;
                radius = Mathf.Max(
                    radius,
                    settings.m_square ? Mathf.CeilToInt(levelRadius) : Mathf.FloorToInt(levelRadius)
                );
            }
            if (settings.m_raise) {
                radius = Mathf.Max(
                    radius,
                    settings.m_raiseDelta >= 0f
                        ? FixedRadius
                        : Mathf.CeilToInt(settings.m_raiseRadius / vertexScale)
                );
            }
            if (settings.m_smooth) {
                radius = Mathf.Max(radius, FixedRadius);
            }
            return radius;
        }

        public static bool TryGetHeightWorldBounds(
            Heightmap heightmap,
            Vector3 worldPos,
            TerrainOp.Settings settings,
            out Vector2 min,
            out Vector2 max
        ) {
            var radius = GetHeightRadiusCells(settings, heightmap.m_scale);
            heightmap.WorldToVertex(worldPos, out var xPos, out var yPos);
            var hasX = PaintGridMath.TryGetVertexAxisBounds(
                heightmap.m_width,
                heightmap.m_scale,
                heightmap.transform.position.x,
                xPos,
                radius,
                out var minX,
                out var maxX
            );
            var hasZ = PaintGridMath.TryGetVertexAxisBounds(
                heightmap.m_width,
                heightmap.m_scale,
                heightmap.transform.position.z,
                yPos,
                radius,
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
            xMin = Mathf.Max(0, x - radius);
            xMax = Mathf.Min(x + radius, worldSize - 1);
        }
    }
}
