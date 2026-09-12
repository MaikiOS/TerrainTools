using HarmonyLib;
using TerrainTools.Visualization;

namespace TerrainTools.Patches {

    [HarmonyPatch]
    internal class PlayerPatch {

        [HarmonyFinalizer]
        [HarmonyPatch(typeof(Player), nameof(Player.UpdatePlacementGhost))]
        private static void UpdatePlacementGhostPostfix(Player __instance) {
            if (!__instance || !__instance.InPlaceMode() || __instance.IsDead()) {
                return;
            }

            if (!__instance.m_placementGhost || !__instance.m_placementGhost.GetComponent<OverlayVisualizer>()) {
                return;
            }

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
        }
    }
}
