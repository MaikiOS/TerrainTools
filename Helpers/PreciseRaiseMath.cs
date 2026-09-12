using System;

namespace TerrainTools.Helpers {
    internal static class PreciseRaiseMath {
        internal const int ModifiedRadius = 2;
        internal const int InfluenceRadius = 3;
        internal const float MinPower = 0.05f;
        internal const float MaxPower = 1f;

        internal static bool TryGetTargetHeight(float tileHeight, float refHeight, float delta, float weight, out float targetHeight) {
            // Preserve the original full-strength target, sign guards, and per-click cap.
            targetHeight = refHeight + delta;
            if (delta < 0f && targetHeight > tileHeight) return false;
            if (delta >= 0f) {
                if (targetHeight < tileHeight) return false;
                if (targetHeight > tileHeight + delta) targetHeight = tileHeight + delta;
            }

            // Falloff scales the actual height change, not the target's offset from the center.
            if (weight < 1f) targetHeight = tileHeight + (targetHeight - tileHeight) * weight;
            return true;
        }

        internal static float Weight(int dx, int dz, float power) {
            var distance = Math.Max(Math.Abs(dx), Math.Abs(dz));
            if (distance >= InfluenceRadius) return 0f;

            var slopePivot = SlopePivot(power);
            if (distance <= slopePivot) return 1f;
            return (InfluenceRadius - distance) / (InfluenceRadius - slopePivot);
        }

        internal static float SlopePivot(float power) {
            power = float.IsNaN(power) ? MaxPower : Math.Max(MinPower, Math.Min(MaxPower, power));
            var hardness = (MaxPower - power) / (MaxPower - MinPower);
            return ModifiedRadius * hardness;
        }

        internal static int TopVertexRadius(float power) {
            return (int) Math.Floor(SlopePivot(power) + 0.0001f);
        }
    }
}
