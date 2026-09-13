using HarmonyLib;
using System.Collections.Generic;
using TerrainTools.Extensions;
using TerrainTools.Visualization;
using UnityEngine;

namespace TerrainTools.Helpers {
    [HarmonyPatch]
    internal static class HardnessModifier {
        /* For Raise Power the effect over the tool radius is calculated as:
         * y = (1 - x/radius)^p where x is distance from center.
         *
         * For Smooth Power the effect over the tool radius is calculated as:
         * y = 1 - (x/radius)^p
         *
         * So for smoothing, increasing the power increases the "hardness" or evenness of the effect over the area.
         *
         * But for raising, increasing the power decreases the "hardness" or evenness of the effect over the area.
         */
        private static bool SmoothToolIsInUse = false;
        private static float lastModdedSmoothPwr;
        private static float lastTotalSmoothDelta;
        private const float MinSmoothPwr = 1f;
        private const float MaxSmoothPwr = 30f;

        private static bool RaiseToolIsInUse = false;
        private static TerrainOp activeRaiseTool;
        private static float lastModdedRaisePwr;
        private static float lastTotalRaiseDelta;
        private const float MinRaisePwr = PreciseRaiseMath.MinPower;
        private const float MaxRaisePwr = PreciseRaiseMath.MaxPower;

        private const float DisplayThreshold = 0.9f; // percentage
        private static float lastDisplayedSmoothHardness;
        private static float lastDisplayedRaiseHardness;


        internal static void Tick(Player __instance) {
            if (!__instance || __instance != Player.m_localPlayer) {
                return;
            }

            if (!__instance.InPlaceMode() || Hud.IsPieceSelectionVisible()) {
                if (SmoothToolIsInUse) {
                    SmoothToolIsInUse = false;
                    lastModdedSmoothPwr = 0;
                    lastTotalSmoothDelta = 0;
                    lastDisplayedSmoothHardness = -1;
                }

                SelectRaiseTool(null);

                return;
            }

            var selectedPiece = __instance.GetSelectedPiece();
            var selectedTerrainOp = selectedPiece && selectedPiece.gameObject
                ? selectedPiece.gameObject.GetComponent<TerrainOp>()
                : null;
            SelectRaiseTool(selectedTerrainOp && selectedTerrainOp.m_settings.m_raise ? selectedTerrainOp : null);

            if (ShouldModifyHardness()) {
                SetPower(__instance, Input.mouseScrollDelta.y * TerrainTools.HardnessScrollScale);
            }
        }


        internal static bool ShouldModifyHardness() {
            return TerrainTools.IsEnableHardnessModifier && Input.GetKey(TerrainTools.HardnessKey) && Input.mouseScrollDelta.y != 0;
        }

        internal static float CurrentRaisePower(float defaultPower) {
            return RaiseToolIsInUse
                ? lastModdedRaisePwr
                : ModifyRaisePower(defaultPower, 0f);
        }

        private static void SelectRaiseTool(TerrainOp terrainOp) {
            if (activeRaiseTool == terrainOp) return;
            activeRaiseTool = terrainOp;
            RaiseToolIsInUse = false;
            lastModdedRaisePwr = 0f;
            lastTotalRaiseDelta = 0f;
            lastDisplayedRaiseHardness = -1f;
        }


        [HarmonyPrefix]
        [HarmonyPriority(Priority.High)]
        [HarmonyPatch(typeof(TerrainOp), nameof(TerrainOp.Awake))]
        private static void AwakePrefix(TerrainOp __instance) {
            if (!__instance || !__instance.gameObject) {
                return;
            }
            var overlay = __instance.gameObject.GetComponent<OverlayVisualizer>();
            if (overlay && overlay is not RaiseGroundOverlayVisualizer) return;

            if (lastTotalRaiseDelta != 0f || lastTotalSmoothDelta != 0f) {
                PreciseTerrainModifier.EnsureRuntimeSettings(__instance, false, overlay != null);
            }

            if (__instance.m_settings.m_raise) {
                __instance.m_settings.m_raisePower = ModifyRaisePower(__instance.m_settings.m_raisePower, lastTotalRaiseDelta);
                Log.LogInfo($"Applying raise Power {__instance.m_settings.m_raisePower}", LogLevel.Medium);
            }

            if (__instance.m_settings.m_smooth) {
                __instance.m_settings.m_smoothPower = ModifySmoothPower(__instance.m_settings.m_smoothPower, lastTotalSmoothDelta);
                Log.LogInfo($"Applying smooth Power {__instance.m_settings.m_smoothPower}", LogLevel.Medium);
            }
        }

        private static void SetPower(Player player, float delta) {
            var piece = player.GetSelectedPiece();
            if (!piece || !piece.gameObject) {
                return;
            }
            var overlay = piece.gameObject.GetComponent<OverlayVisualizer>();
            if (overlay && overlay is not RaiseGroundOverlayVisualizer) return;

            var terrainOp = piece.gameObject.GetComponent<TerrainOp>();
            if (!terrainOp) {
                return;
            }

            SetSmoothPower(terrainOp, delta);
            SetRaisePower(terrainOp, delta);

            var updateMsg = new List<string>();
            if (SmoothToolIsInUse) {
                var smoothHardness = GetSmoothPowerDisplayValue(lastModdedSmoothPwr);
                if (Mathf.Abs(smoothHardness - lastDisplayedSmoothHardness) > DisplayThreshold) {
                    lastDisplayedSmoothHardness = Mathf.Round(smoothHardness);
                    updateMsg.Add($"{Localization.instance.Localize("$atmc_smoothing_hardness")} {smoothHardness:0}%");
                }
            }
            if (RaiseToolIsInUse) {
                var raiseHardness = GetRaisePowerDisplayValue(lastModdedRaisePwr);
                if (Mathf.Abs(raiseHardness - lastDisplayedRaiseHardness) > DisplayThreshold) {
                    lastDisplayedRaiseHardness = Mathf.Round(raiseHardness);
                    updateMsg.Add($"{Localization.instance.Localize("$atmc_raise_hardness")} {raiseHardness:0}%");
                }
            }
            if (SmoothToolIsInUse || RaiseToolIsInUse) {
                var placementPiece = player.m_placementGhost ? player.m_placementGhost.GetComponent<Piece>() : null;
                var toolIcon = placementPiece ? placementPiece.m_icon : null;
                if (toolIcon != null && updateMsg.Count > 0) {
                    player.Message(MessageHud.MessageType.Center, string.Join("\n", updateMsg.ToArray()), icon: toolIcon, log: false);
                }
            }
        }

        private static void SetSmoothPower(TerrainOp terrainOp, float delta) {
            if (!terrainOp.m_settings.m_smooth) {
                return;
            }

            Log.LogInfo($"Adjusting Smooth Power by {delta}", LogLevel.High);

            var previousPower = SmoothToolIsInUse ? lastModdedSmoothPwr : terrainOp.m_settings.m_smoothPower;
            SmoothToolIsInUse = true;
            lastModdedSmoothPwr = ModifySmoothPower(previousPower, delta);
            lastTotalSmoothDelta += lastModdedSmoothPwr - previousPower;
            Log.LogInfo($"Total smooth power delta {lastTotalSmoothDelta}", LogLevel.High);
        }

        private static void SetRaisePower(TerrainOp terrainOp, float delta) {
            if (!terrainOp.m_settings.m_raise) {
                return;
            }

            SelectRaiseTool(terrainOp);

            delta = ConvertSmoothDeltaToRaiseDelta(delta);

            Log.LogInfo($"Adjusting Raise Power by {delta}", LogLevel.High);

            var previousPower = RaiseToolIsInUse ? lastModdedRaisePwr : terrainOp.m_settings.m_raisePower;
            RaiseToolIsInUse = true;
            lastModdedRaisePwr = ModifyRaisePower(previousPower, delta);
            lastTotalRaiseDelta += lastModdedRaisePwr - previousPower;
            Log.LogInfo($"Total raise power delta {lastTotalRaiseDelta}", LogLevel.High);
        }

        /// <summary>
        ///     Converts delta for smooth power to be appropriate for raise power
        ///     since they have different value ranges and opposite signs
        /// </summary>
        /// <param name="delta"></param>
        /// <returns></returns>
        private static float ConvertSmoothDeltaToRaiseDelta(float delta) {
            var deltaFraction = delta / (MaxSmoothPwr - MinSmoothPwr);
            return -1 * deltaFraction * (MaxRaisePwr - MinRaisePwr);
        }

        /// <summary>
        ///     Get Smooth Power as a percentage of maximum hardness
        /// </summary>
        /// <param name="power"></param>
        /// <returns></returns>
        private static float GetSmoothPowerDisplayValue(float power) {
            return ((power - MinSmoothPwr) / (MaxSmoothPwr - MinSmoothPwr)) * 100;
        }

        /// <summary>
        ///     Get Raise Power as a percentage of maximum hardness
        /// </summary>
        /// <param name="power"></param>
        /// <returns></returns>
        private static float GetRaisePowerDisplayValue(float power) {
            return ((MaxRaisePwr - power) / (MaxRaisePwr - MinRaisePwr)) * 100;
        }

        /// <summary>
        ///     Modifies power value and clamps to bounds for smooth power.
        /// </summary>
        /// <param name="power"></param>
        /// <param name="delta"></param>
        /// <returns></returns>
        private static float ModifySmoothPower(float power, float delta) {
            return Mathf.Clamp(power + delta, MinSmoothPwr, MaxSmoothPwr);
        }

        /// <summary>
        ///     Modifies power value and clamps to bounds for raise power.
        /// </summary>
        /// <param name="power"></param>
        /// <param name="delta"></param>
        /// <returns></returns>
        private static float ModifyRaisePower(float power, float delta) {
            return Mathf.Clamp(power + delta, MinRaisePwr, MaxRaisePwr);
        }
    }
}
