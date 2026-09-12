using System;

namespace TerrainTools.Helpers {
    internal static class PaintGridMath {
        internal static float TexelScale(int terrainWidth, float vertexScale) {
            return terrainWidth * vertexScale / (terrainWidth + 1f);
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
            var zoneMax = zoneCenter + halfWorldSize;
            var texelScale = TexelScale(terrainWidth, vertexScale);

            min = Math.Max(zoneMin, zoneMin + (firstPaintedTexel - 0.5f) * texelScale);
            max = Math.Min(zoneMax, zoneMin + (lastPaintedTexel + 1.5f) * texelScale);
            return true;
        }

        internal static bool TryGetVertexAxisBounds(
            int terrainWidth,
            float vertexScale,
            float zoneCenter,
            int centerVertex,
            int radius,
            out float min,
            out float max
        ) {
            var firstVertex = Math.Max(0, centerVertex - radius);
            var lastVertex = Math.Min(terrainWidth, centerVertex + radius);
            if (radius < 0 || firstVertex > lastVertex) {
                min = 0f;
                max = 0f;
                return false;
            }

            var halfWorldSize = terrainWidth * vertexScale * 0.5f;
            var zoneMin = zoneCenter - halfWorldSize;
            var zoneMax = zoneCenter + halfWorldSize;
            min = Math.Max(zoneMin, zoneMin + (firstVertex - 0.5f) * vertexScale);
            max = Math.Min(zoneMax, zoneMin + (lastVertex + 0.5f) * vertexScale);
            return true;
        }
    }
}
