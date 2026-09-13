using HarmonyLib;
using TerrainTools.Helpers;
using TerrainTools.Visualization;

namespace TerrainTools.Patches {

    [HarmonyPatch]
    internal class PlayerPatch {

        [HarmonyPostfix]
        [HarmonyPatch(typeof(Player), nameof(Player.UpdatePlacementGhost))]
        private static void UpdatePlacementGhostPostfix(Player __instance) {
            if (!__instance || !__instance.InPlaceMode() || __instance.IsDead()) {
                return;
            }

            if (__instance != Player.m_localPlayer || !__instance.m_placementGhost || !__instance.m_placementGhost.activeInHierarchy) {
                return;
            }

            var overlay = __instance.m_placementGhost.GetComponent<OverlayVisualizer>();
            if (!overlay) return;

            var position = __instance.m_placementGhost.transform.position;
            var heightmap = Heightmap.FindHeightmap(position);
            if (!heightmap) {
                return;
            }

            // Use the same logical center as height and paint operations, including negative midpoints.
            heightmap.WorldToVertex(position, out var x, out var z);
            position.x = heightmap.transform.position.x + (x - heightmap.m_width / 2) * heightmap.m_scale;
            position.z = heightmap.transform.position.z + (z - heightmap.m_width / 2) * heightmap.m_scale;
            __instance.m_placementGhost.transform.position = position;

            var terrainOp = __instance.m_placementGhost.GetComponent<TerrainOp>();
            if (terrainOp && !PreciseTerrainModifier.HasAreaAccess(terrainOp, position, false)) {
                __instance.m_placementStatus = Player.PlacementStatus.PrivateZone;
            }
            overlay.Refresh();
            RadiusModifier.RefreshGhostScale(__instance);
        }
    }
}
