using HarmonyLib;
using TerrainTools.Helpers;
using UnityEngine;

namespace TerrainTools.Patches {
    // Experimental 1.4.5: render mapping only; saved paint indices remain unchanged.
    [HarmonyPatch(typeof(Heightmap), nameof(Heightmap.RebuildRenderMesh))]
    internal static class HeightmapPaintGridPatch {
        [HarmonyPostfix]
        private static void Postfix(Heightmap __instance) {
            if (__instance.m_isDistantLod || !__instance.m_renderMesh) {
                return;
            }

            var side = __instance.m_width + 1;
            var uvs = Heightmap.s_tempUVs;
            if (side <= 1 || __instance.m_renderMesh.vertexCount != side * side || uvs.Count != side * side) {
                Log.LogWarning("Paint grid UV alignment skipped: unexpected Heightmap mesh dimensions.");
                return;
            }

            for (var i = 0; i < uvs.Count; i++) {
                uvs[i] = new Vector2(
                    PaintGridMath.TexelCenterUv(i % side, __instance.m_width),
                    PaintGridMath.TexelCenterUv(i / side, __instance.m_width)
                );
            }
            __instance.m_renderMesh.SetUVs(0, uvs);
        }
    }
}
