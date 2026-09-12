using TerrainTools.Helpers;
using UnityEngine;

namespace TerrainTools.Visualization
{
    // Minimal classes describing specific VFXs of specific "ToolOps" in a DSL-like form.
    public class LevelGroundOverlayVisualizer : HoverInfoEnabled
    {
        protected override void Initialize()
        {
            base.Initialize();
            Freeze(secondary);
            Freeze(tertiary);
            VisualizeRecoloringBounds(secondary);
            VisualizeRecoloringBounds(tertiary);
            tertiary.StartColor = new Color(1f, 1f, 1f, 0.3f);
        }

        protected override void OnRefresh()
        {
            SnapToPaintGrid(secondary, tertiary);
            base.OnRefresh();
            primary.Enabled = false;
            secondary.Enabled = true;
            tertiary.Enabled = true;
        }
    }

    public class RaiseGroundOverlayVisualizer : HoverInfoEnabled
    {
        protected override void Initialize()
        {
            base.Initialize();
            Freeze(secondary);
            Freeze(tertiary);
            VisualizeTerraformingBounds(secondary);
            VisualizeTerraformingBounds(tertiary);
        }

        protected override void OnRefresh()
        {
            SnapToPaintGrid(secondary, tertiary);
            secondary.StartSize = tertiary.StartSize;
            secondary.LocalScale = tertiary.LocalScale;
            secondary.Position = tertiary.Position;

            var heightmap = Heightmap.FindHeightmap(transform.position);
            if (heightmap)
            {
                heightmap.WorldToVertex(transform.position, out var x, out var z);
                var snappedPosition = secondary.Position;
                snappedPosition.x = heightmap.transform.position.x + (x - heightmap.m_width / 2) * heightmap.m_scale;
                snappedPosition.z = heightmap.transform.position.z + (z - heightmap.m_width / 2) * heightmap.m_scale;
                secondary.Position = snappedPosition;
                tertiary.Position = snappedPosition;
            }

            base.OnRefresh();
            primary.Enabled = false;
            secondary.Enabled = true;

            GroundLevelSpinner.Refresh();
            var localPosition = secondary.LocalPosition;
            localPosition.y = VerticalOffset.y + GroundLevelSpinner.Value;
            secondary.LocalPosition = localPosition;
            var pos = secondary.Position - VerticalOffset;
            if (GroundLevelSpinner.Value > 0f)
            {
                var deltaH = GroundLevelSpinner.Value;
                hoverInfo.Text = $"x: {pos.x:0}, y: {pos.y - deltaH:0.000}, z: {pos.z:0}\n\nh: +{deltaH:0.000}";
            }
            else
            {
                hoverInfo.Text = $"x: {pos.x:0}, y: {pos.y:0.000}, z: {pos.z:0}";
            }

            tertiary.Enabled = true;
        }
    }

    public class SquarePathOverlayVisualizer : HoverInfoEnabled
    {
        protected override void Initialize()
        {
            base.Initialize();
            Freeze(secondary);
            Freeze(tertiary);
            VisualizeRecoloringBounds(secondary);
            VisualizeRecoloringBounds(tertiary);
            tertiary.StartColor = new Color(1f, 1f, 1f, 0.3f);
        }

        protected override void OnRefresh()
        {
            SnapToPaintGrid(secondary, tertiary);
            base.OnRefresh();
            primary.Enabled = false;
            secondary.Enabled = true;
            tertiary.Enabled = true;
        }
    }

    public class CultivateOverlayVisualizer : HoverInfoEnabled
    {
        protected override void Initialize()
        {
            base.Initialize();
            Freeze(secondary);
            Freeze(tertiary);
            VisualizeRecoloringBounds(secondary);
            VisualizeRecoloringBounds(tertiary);
            tertiary.StartColor = new Color(1f, 1f, 1f, 0.3f);
        }

        protected override void OnRefresh()
        {
            SnapToPaintGrid(secondary, tertiary);
            base.OnRefresh();
            primary.Enabled = false;
            secondary.Enabled = true;
            tertiary.Enabled = true;
            hoverInfo.Color = secondary.Color;
        }
    }

    public class SeedGrassOverlayVisualizer : HoverInfoEnabled
    {
        protected override void Initialize()
        {
            base.Initialize();
            Freeze(secondary);
            Freeze(tertiary);
            VisualizeRecoloringBounds(secondary);
            VisualizeRecoloringBounds(tertiary);
            tertiary.StartColor = new Color(1f, 1f, 1f, 0.3f);
            // Might be able to remove these lines?
            primary.StartSize = 4.0f;
            primary.LocalPosition = new Vector3(0.0f, 2.5f, 0.0f);
        }

        protected override void OnRefresh()
        {
            SnapToPaintGrid(secondary, tertiary);
            base.OnRefresh();
            primary.Enabled = true;
            secondary.Enabled = true;
            tertiary.Enabled = true;
        }
    }

    public class RemoveModificationsOverlayVisualizer : OverlayVisualizer
    {
        internal void SetScale(Vector3 scale)
        {
            if (primary == null || scale == Vector3.zero) return;
            primary.LocalScale = scale;
            secondary.LocalScale = scale;
        }

        protected override void Initialize()
        {
            Freeze(primary);
            SpeedUp(secondary);
            VisualizeTerraformingBounds(primary);
            VisualizeIconInsideTerraformingBounds(secondary, IconCache.Cross);
            primary.StartSize = 2.0f;
            secondary.StartSize = 1.5f;
        }

        protected override void OnRefresh()
        {
            primary.Enabled = true;
            secondary.Enabled = true;
        }
    }

    public abstract class UndoRedoModificationsOverlayVisualizer : OverlayVisualizer
    {
        protected override void Initialize()
        {
            Freeze(primary);
            Freeze(secondary);
            VisualizeRecoloringBounds(primary);
            VisualizeIconInsideRecoloringBounds(secondary, Icon());
        }

        protected override void OnRefresh()
        {
            primary.Enabled = true;
            secondary.Enabled = true;
        }

        protected abstract Texture2D Icon();
    }

    public class UndoModificationsOverlayVisualizer : UndoRedoModificationsOverlayVisualizer
    {
        protected override Texture2D Icon() => IconCache.Undo;
    }

    public class RedoModificationsOverlayVisualizer : UndoRedoModificationsOverlayVisualizer
    {
        protected override Texture2D Icon() => IconCache.Redo;
    }
}
