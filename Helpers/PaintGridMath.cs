using System;

namespace TerrainTools.Helpers {
    internal static class PaintGridMath {
        internal static float TexelCenterUv(int index, int terrainWidth) {
            return (index + 0.5f) / (terrainWidth + 1f);
        }

        internal static void GetAxisIndices(int terrainWidth, int centerIndex, int radius, out int first, out int last) {
            first = Math.Max(0, centerIndex - radius);
            last = Math.Min(terrainWidth, centerIndex + radius);
        }

        internal static bool TryGetAxisBounds(
            int terrainWidth,
            float vertexScale,
            float zoneCenter,
            int firstPaintedTexel,
            int lastPaintedTexel,
            out float min,
            out float max
        ) {
            if (firstPaintedTexel > lastPaintedTexel) {
                min = 0f;
                max = 0f;
                return false;
            }

            var halfWorldSize = terrainWidth * vertexScale * 0.5f;
            var zoneMin = zoneCenter - halfWorldSize;
            // The experimental render UVs place each texel center on its height vertex.
            min = zoneMin + firstPaintedTexel * vertexScale;
            max = zoneMin + lastPaintedTexel * vertexScale;
            return true;
        }

    }
}
