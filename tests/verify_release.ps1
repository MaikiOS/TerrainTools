param(
    [string]$ProjectRoot = (Split-Path -Parent $PSScriptRoot),
    [string]$BepInExPath = "C:\Users\nfspr\AppData\Roaming\Thunderstore Mod Manager\DataFolder\Valheim\profiles\Default\BepInEx"
)

$ErrorActionPreference = "Stop"
$expectedVersion = "1.4.8"

function Assert-True([bool]$Condition, [string]$Message) {
    if (-not $Condition) { throw "VERIFY FAILED: $Message" }
}

$pluginSource = Get-Content -LiteralPath (Join-Path $ProjectRoot "TerrainTools.cs") -Raw
$initSource = Get-Content -LiteralPath (Join-Path $ProjectRoot "Helpers\InitManager.cs") -Raw
$preciseSource = Get-Content -LiteralPath (Join-Path $ProjectRoot "Helpers\PreciseTerrainModifier.cs") -Raw
$radiusSource = Get-Content -LiteralPath (Join-Path $ProjectRoot "Helpers\RadiusModifier.cs") -Raw
$playerSource = Get-Content -LiteralPath (Join-Path $ProjectRoot "Patches\PlayerPatch.cs") -Raw
$cameraSource = Get-Content -LiteralPath (Join-Path $ProjectRoot "Patches\GameCameraPatch.cs") -Raw
$shovelSource = Get-Content -LiteralPath (Join-Path $ProjectRoot "Helpers\Shovel.cs") -Raw
$overlaySource = Get-Content -LiteralPath (Join-Path $ProjectRoot "Visualization\Overlay.cs") -Raw
$overlayVisualizerSource = Get-Content -LiteralPath (Join-Path $ProjectRoot "Visualization\OverlayVisualizer.cs") -Raw
$toolVisualizersSource = Get-Content -LiteralPath (Join-Path $ProjectRoot "Visualization\ToolVisualizers.cs") -Raw
$paintGridMathSource = Get-Content -LiteralPath (Join-Path $ProjectRoot "Helpers\PaintGridMath.cs") -Raw
$raiseMathSource = Get-Content -LiteralPath (Join-Path $ProjectRoot "Helpers\PreciseRaiseMath.cs") -Raw
$heightmapPatchSource = Get-Content -LiteralPath (Join-Path $ProjectRoot "Patches\HeightmapPaintGridPatch.cs") -Raw
$hardnessSource = Get-Content -LiteralPath (Join-Path $ProjectRoot "Helpers\HardnessModifier.cs") -Raw
$spinnerSource = Get-Content -LiteralPath (Join-Path $ProjectRoot "Helpers\GroundLevelSpinner.cs") -Raw
$iconCacheSource = Get-Content -LiteralPath (Join-Path $ProjectRoot "Visualization\IconCache.cs") -Raw
$packageTargets = Get-Content -LiteralPath (Join-Path $ProjectRoot "ModPackageTool.targets") -Raw
$environmentProps = Get-Content -LiteralPath (Join-Path $ProjectRoot "environment.props") -Raw
$allSource = Get-ChildItem -LiteralPath $ProjectRoot -Recurse -Filter "*.cs" |
    Where-Object FullName -NotMatch "[\\/](bin|obj)[\\/]" |
    ForEach-Object { Get-Content -LiteralPath $_.FullName -Raw }
$allSourceText = $allSource -join "`n"

Assert-True ($pluginSource -match "PluginVersion = `"$([regex]::Escape($expectedVersion))`"") "plugin version is not $expectedVersion"
Assert-True ($pluginSource -match 'GetLocalization\(\)' -and $pluginSource -match 'TerrainTools\.Translations\.\{language\}\.json' -and $pluginSource -match 'new\[\] \{ "English", "Russian" \}') "embedded translations are not registered explicitly"
Assert-True ((Get-Content -LiteralPath (Join-Path $ProjectRoot "TerrainTools.csproj") -Raw) -match 'LogicalName="TerrainTools\.Translations\.English\.json"' -and (Get-Content -LiteralPath (Join-Path $ProjectRoot "TerrainTools.csproj") -Raw) -match 'LogicalName="TerrainTools\.Translations\.Russian\.json"') "translations are not embedded with stable resource names"
Assert-True ($allSourceText -notmatch "HarmonyPatch\(typeof\(Player\),\s*nameof\(Player\.Update\)\)") "Player.Update Harmony patch returned"
Assert-True ($pluginSource -match "RadiusModifier\.Tick\(Player\.m_localPlayer\)") "radius polling is not in plugin Update"
Assert-True ($pluginSource -match "HardnessModifier\.Tick\(Player\.m_localPlayer\)") "hardness polling is not in plugin Update"
Assert-True ($initSource -match "EnsureTerrainOpRegistered\(prefab\)") "TerrainOp fallback is not called"
Assert-True ($initSource -match "m_terrainOpsByHash\.TryGetValue") "TerrainOp fallback is not idempotent"
Assert-True ($initSource -match "registeredTerrainOp != terrainOp") "TerrainOp hash collisions are not guarded"
Assert-True ($initSource -match "IsCustomTool\(GameObject gameObject\)" -and $initSource -match "ToolConfigs\.ToolConfigsMap\.ContainsKey") "spawned custom tools cannot restore their runtime settings identity"
Assert-True ($initSource -match "ObjectDBUpdateRegistersPostfix") "TerrainOp fallback is not restored after ObjectDB refresh"
Assert-True ($preciseSource -match "SerializeSettingsPostfix") "runtime TerrainOp settings are not serialized"
Assert-True ($preciseSource -match "DeserializeSettingsPostfix") "runtime TerrainOp settings are not deserialized"
Assert-True ($preciseSource -match "class RuntimeSettings" -and $preciseSource -match "modifier is RuntimeSettings \{ IsReset: true \}") "foreign empty terrain operations can trigger reset"
Assert-True ($preciseSource -match "__instance is not RuntimeSettings settings" -and $preciseSource -match "InitManager\.IsCustomTool\(modifier\.gameObject\)" -and $preciseSource -match "if \(settings == null\) return true") "serialization or ownership claims are not scoped to managed operations"
Assert-True ($preciseSource -match "if \(!IsValid\(settings\)\)[\s\S]*?__result = null" -and $preciseSource -match "float\.IsNaN" -and $preciseSource -match "float\.IsInfinity") "network terrain settings are not rejected at the trust boundary"
Assert-True ($preciseSource -match "pkg\.Size\(\) - payloadStart < payloadSize[\s\S]*?__result = null") "recognized truncated network settings can fall back to a destructive prefab default"
Assert-True ($preciseSource -match "PrivateArea\.CheckAccess\(position, radius, flash, true\)") "terrain operations do not check their full protected-area footprint"
Assert-True ($preciseSource -match "settings\?\.HasOverlay == true \|\| settings\?\.IsReset == true" -and $preciseSource -match "radius \*= 1\.414214f") "square precision tools do not use a conservative ward envelope"
Assert-True ($preciseSource -match "m_playerModifiction" -and $preciseSource -match "modifier\.m_nview\.IsValid\(\)") "legacy reset is not limited to valid player terrain modifiers"
Assert-True ($preciseSource -match "Mathf\.Abs\(modifier\.transform\.position\.x - position\.x\) \+ modifierRadius > radius" -and $preciseSource -match "Mathf\.Abs\(modifier\.transform\.position\.z - position\.z\) \+ modifierRadius > radius") "reset can delete a legacy modifier that extends beyond its selected square"
Assert-True ($preciseSource -match "FixedPaintRadius = 1") "square paint does not retain its 2m core"
Assert-True ($preciseSource -notmatch "worldPos\.(x|z)\s*-=\s*0\.5f") "paint still applies the obsolete half-cell offset"
Assert-True ($preciseSource -match "m_modifiedPaint\[tileIndex\]\s*=\s*true") "paint reset is not persisted explicitly"
Assert-True ($preciseSource -match "GetAxisIndices\(heightmap\.m_width, xPos, radius, out xStart, out xMax\)" -and $preciseSource -match "GetAxisIndices\(heightmap\.m_width, yPos, radius, out yStart, out yMax\)") "paint does not use symmetric shared index bounds on both axes"
Assert-True ($preciseSource -match "Reset chunk" -and $preciseSource -match "vertices=" -and $preciseSource -match "edge=") "chunk-boundary reset diagnostics are missing"
Assert-True ($preciseSource -match "GetRadiusPostfix") "reset radius does not select every affected Heightmap"
Assert-True ($preciseSource -match "m_levelRadius \+ 1f") "reset radius does not include neighboring Heightmaps"
Assert-True ($preciseSource -match "TerrainModifier\.GetModifiers\(position, radius \+ 1f") "reset does not remove legacy terrain modifiers"
Assert-True ($preciseSource -match "GetComponentInParent<Piece>" -and $preciseSource -match "GetComponentInParent<WearNTear>") "terrain reset can delete player structures"
Assert-True ($preciseSource -notmatch "\[HarmonyPatch\(typeof\(PreciseTerrainModifier\)\)\]") "redundant class-level Harmony target returned"
Assert-True ($preciseSource -match "RemoveTerrainModifications\(__instance, pos, radius\)") "reset radius is not applied to height restoration"
Assert-True ($preciseSource -match "PaintType\.Reset, radius: radius") "reset radius is not applied to paint restoration"
Assert-True ($preciseSource -notmatch "ClutterSystem\.instance\.ResetGrass\(pos, radius\)") "reset still clears vegetation across the whole selected area"
Assert-True ($radiusSource -match "RemoveModificationsOverlayVisualizer") "reset tool cannot use the radius modifier"
Assert-True ($radiusSource -match "delta = Mathf\.Sign\(delta\)") "reset radius is not quantized to terrain cells"
Assert-True ($radiusSource -match "isResetTool \? PreciseTerrainModifier\.FixedRadius : MinRadius") "reset radius can fall below its valid minimum"
Assert-True ($radiusSource -match "resetVisualizer\.SetScale\(lastGhostScale\)") "reset frame and cross do not scale together"
Assert-True ($playerSource -match "overlay\.Refresh\(\);\s*RadiusModifier\.RefreshGhostScale\(__instance\)") "reset scale is not reapplied after preview initialization"
Assert-True ($toolVisualizersSource -match 'class RemoveModificationsOverlayVisualizer[\s\S]*?primary\.LocalScale = scale;[\s\S]*?secondary\.LocalScale = scale;') "reset preview scaling is not isolated to its overlay transforms"
Assert-True ($radiusSource -match "SelectRadiusTool\(terrainOp\)[\s\S]*?activeRadiusTool == terrainOp[\s\S]*?lastTotalDelta = 0f") "radius state leaks between selected terrain tools"
Assert-True ($radiusSource -match "IsActiveToolInstance\(__instance\)") "stale radius state can modify a different placement ghost"
Assert-True ($radiusSource -match "resetTerrainOp\.m_settings\.m_levelRadius = lastModdedRadius") "reset operation radius is not updated with its preview"
Assert-True ($pluginSource -match '"HardnessScrollScale",\s*1f') "hardness scroll still uses the slow legacy default"
Assert-True ($cameraSource -match "Input\.GetKey\(TerrainTools\.HardnessKey\)") "hardness key does not block camera zoom"
Assert-True ($cameraSource -match "matches\.Count != 1" -and $cameraSource -match "return original") "camera transpiler does not fail safely on changed IL"
Assert-True ($shovelSource -match "UseCategories = false") "single-action shovel still uses hammer categories"
Assert-True ($overlaySource -match "psm = ps\.main") "Overlay MainModule is not initialized"
Assert-True ($overlaySource -match "public float StartSpeed[\s\S]*?psm\.startSpeed\.constant") "Overlay StartSpeed getter is incorrect"
Assert-True ($overlaySource -match "psMain\.startColor = value") "Overlay StartColor setter is ineffective"
Assert-True (([regex]::Matches($preciseSource, "GetPaintMaskBounds\(")).Count -ge 3) "paint write and preview do not share one mask-bounds calculation"
Assert-True ($paintGridMathSource -match "\(index \+ 0\.5f\) / \(terrainWidth \+ 1f\)") "paint UVs do not put texel centers on height vertices"
Assert-True ($heightmapPatchSource -match "HarmonyPatch\(typeof\(Heightmap\), nameof\(Heightmap\.RebuildRenderMesh\)\)" -and $heightmapPatchSource -match "m_renderMesh\.SetUVs\(0, uvs\)") "paint UV correction does not target the native render UV channel"
Assert-True ($heightmapPatchSource -match "m_isDistantLod" -and $heightmapPatchSource -match "vertexCount != side \* side") "paint UV correction does not guard non-native mesh layouts"
Assert-True ($heightmapPatchSource -notmatch "SetVertices|SetColors|SetIndices|m_paintMask|m_modifiedPaint") "render UV correction changes geometry or saved paint data"
Assert-True ($overlayVisualizerSource -match "TryGetPaintMaskWorldBounds") "paint preview does not use the shared render-grid geometry"
Assert-True ($overlayVisualizerSource -match "SetBounds\(core, min - Vector2\.one \* featherWidth, max \+ Vector2\.one \* featherWidth\)" -and $overlayVisualizerSource -match "SetBounds\(feather, min - Vector2\.one \* featherWidth \* 2f, max \+ Vector2\.one \* featherWidth \* 2f\)") "paint preview does not show the 4m solid area and 6m blend limit"
Assert-True ($overlaySource -match "particles\.Length < ps\.particleCount[\s\S]*?new ParticleSystem\.Particle\[ps\.particleCount\][\s\S]*?GetParticles\(particles, particles\.Length\)[\s\S]*?particles\[i\]\.startSize = value[\s\S]*?SetParticles\(particles, count\)") "dynamic overlay size does not update every existing particle"
Assert-True ($overlayVisualizerSource -notmatch "VertexMaskToWorld") "paint preview still uses the mismatched vanilla vertex-grid inverse"
Assert-True ($overlayVisualizerSource -match "Heightmap\.FindHeightmap\([\s\S]*?heightmaps") "grid previews do not include every affected Heightmap"
Assert-True ($overlayVisualizerSource -match "size\.x / maxSize" -and $overlayVisualizerSource -match "size\.y / maxSize") "paint preview loses rectangular bounds at zone edges"
Assert-True ($preciseSource -match "HarmonyPatch\(typeof\(TerrainOp\.Settings\), nameof\(TerrainOp\.Settings\.GetRadius\)\)") "precision radius fix does not patch the Settings method used by terrain operations"
Assert-True ($preciseSource -match "__instance\.m_paintCleared && IsPrecisionModifier\(__instance\.m_paintRadius\)") "paint-only operations still collapse to radius zero"
Assert-True ($playerSource -match "heightmap\.WorldToVertex\(position, out var x, out var z\)") "square placement does not use native heightmap snapping"
Assert-True ($playerSource -match "position\.x = heightmap\.transform\.position\.x \+ \(x - heightmap\.m_width / 2\) \* heightmap\.m_scale" -and $playerSource -match "position\.z = heightmap\.transform\.position\.z \+ \(z - heightmap\.m_width / 2\) \* heightmap\.m_scale") "square placement does not invert the native height vertex coordinates"
Assert-True ($playerSource -notmatch "RoundToNearest") "square placement still overrides native negative-half rounding"
Assert-True ($overlayVisualizerSource -match "class HoverInfoEnabled[\s\S]*?var pos = transform\.position;") "square hover coordinates do not report the logical operation center"
Assert-True ($toolVisualizersSource -match "class LevelGroundOverlayVisualizer[\s\S]*?SnapToPaintGrid\(secondary, tertiary\)[\s\S]*?primary\.Enabled = false;[\s\S]*?secondary\.Enabled = true;[\s\S]*?tertiary\.Enabled = true;[\s\S]*?class RaiseGroundOverlayVisualizer") "level square does not use the shared paint footprint"
$raiseVisualizerSource = [regex]::Match($toolVisualizersSource, "class RaiseGroundOverlayVisualizer[\s\S]*?(?=class SquarePathOverlayVisualizer)").Value
Assert-True ($raiseVisualizerSource -notmatch "SnapToPaintGrid|WorldToVertex") "raise preview still has a separate paint or height snap"
Assert-True ($raiseVisualizerSource -match "CurrentRaisePower\(terrainOp\.m_settings\.m_raisePower\)" -and $raiseVisualizerSource -match "SlopePivot\(raisePower\)" -and $raiseVisualizerSource -match "secondary\.StartSize = Mathf\.Max\(0\.1f, 2f \* slopePivot \* vertexScale\)" -and $raiseVisualizerSource -match "tertiary\.StartSize = 2f \* PreciseRaiseMath\.InfluenceRadius \* vertexScale") "raise preview does not resize smoothly inside the fixed 4m influence"
Assert-True ($raiseVisualizerSource -match "secondary\.LocalScale = Vector3\.one;" -and $raiseVisualizerSource -match "tertiary\.LocalScale = Vector3\.one;") "raise preview inherits a scaled paint frame"
Assert-True ($toolVisualizersSource -match "class SquarePathOverlayVisualizer[\s\S]*?SnapToPaintGrid\(secondary, tertiary\)[\s\S]*?primary\.Enabled = false;[\s\S]*?class CultivateOverlayVisualizer") "square paths do not show only their paint grid"
Assert-True ($toolVisualizersSource -match "class CultivateOverlayVisualizer[\s\S]*?SnapToPaintGrid\(secondary, tertiary\)[\s\S]*?primary\.Enabled = false;[\s\S]*?class SeedGrassOverlayVisualizer") "square cultivation does not show only its paint grid"
Assert-True ($toolVisualizersSource -match "class SeedGrassOverlayVisualizer[\s\S]*?SnapToPaintGrid\(secondary, tertiary\)[\s\S]*?class RemoveModificationsOverlayVisualizer") "replant square does not use the paint grid preview"
Assert-True ($toolVisualizersSource -notmatch "SpeedUp\(secondary\)[\s\S]{0,120}VisualizeTerraformingBounds\(secondary\)") "exact level frame is still animated"
Assert-True ($toolVisualizersSource -match "localPosition\.y = VerticalOffset\.y \+ GroundLevelSpinner\.Value") "raise target frame loses its vertical overlay offset"
Assert-True ($overlayVisualizerSource -match "featherWidth = Mathf\.Max\(\s*featherWidth,\s*heightmap\.m_scale\s*\)") "paint support does not extend one corrected texel beyond the core"
Assert-True (([regex]::Matches($toolVisualizersSource, "tertiary\.StartColor = new Color\(1f, 1f, 1f, 0\.3f\)")).Count -ge 2) "paint feather is not visually distinguished"
Assert-True ($preciseSource -match "overlay is RaiseGroundOverlayVisualizer[\s\S]*?Mathf\.Max\(__result, PreciseRaiseMath\.InfluenceRadius\)") "raise fanout is not expanded before precision flags are set"
Assert-True ($preciseSource -match "m_raise && IsPrecisionModifier\(__instance\.m_raiseRadius\)[\s\S]*?Mathf\.Max\(__result, PreciseRaiseMath\.InfluenceRadius\)") "legacy precision raise radius does not include the falloff"
Assert-True ($preciseSource -match "FindExtrema\(xPos, worldSize, PreciseRaiseMath\.ModifiedRadius" -and $preciseSource -match "FindExtrema\(yPos, worldSize, PreciseRaiseMath\.ModifiedRadius") "raise does not modify the intermediate ring on both axes"
Assert-True ($preciseSource -match "GetAxisIndices\(worldSize - 1, x, radius, out xMin, out xMax\)") "height edits do not use the tested zone clipping"
Assert-True ($preciseSource -match "weight = PreciseRaiseMath\.Weight\(i - xPos, j - yPos, power\)" -and $preciseSource -match "!PreciseRaiseMath\.TryGetTargetHeight\(tileHeight, refHeight, delta, weight, out var targetHeight\)") "raise does not use the tested per-vertex falloff target and sign guards"
Assert-True (([regex]::Matches($hardnessSource, "overlay && overlay is not RaiseGroundOverlayVisualizer")).Count -eq 2) "precise raise hardness is not enabled at both input and operation creation"
Assert-True ($hardnessSource -match "SelectRaiseTool\(selectedTerrainOp && selectedTerrainOp\.m_settings\.m_raise \? selectedTerrainOp : null\)" -and $hardnessSource -match "SelectRaiseTool\(TerrainOp terrainOp\)[\s\S]*?lastTotalRaiseDelta = 0f") "raise hardness leaks when the selected tool changes without scrolling"
Assert-True ($hardnessSource -notmatch "lastDisplayedRaiseHardness = -1;[\s\S]{0,120}SetPower\(__instance, 0\)") "leaving place mode reactivates raise hardness state"
Assert-True ($hardnessSource -match "CurrentRaisePower\(float defaultPower\)[\s\S]*?RaiseToolIsInUse[\s\S]*?lastModdedRaisePwr") "raise preview cannot read the active slope setting"
Assert-True ($spinnerSource -match "IsEnableHardnessModifier && Input\.GetKey\(TerrainTools\.HardnessKey\)[\s\S]*?return 0f;[\s\S]*?Input\.GetAxis\(MouseScrollWheel\)") "hardness scroll can still change the height spinner"
Assert-True ($spinnerSource -match "lastRefreshFrame == Time\.frameCount") "height spinner can consume the same scroll input twice per frame"
Assert-True ($playerSource -match "HarmonyPostfix" -and $playerSource -match "overlay\.Refresh\(\)") "terrain overlays are not refreshed after final ghost placement"
Assert-True ($playerSource -match "m_placementGhost\.activeInHierarchy") "inactive placement ghosts can still refresh and consume input"
Assert-True ($overlayVisualizerSource -notmatch "private void Update\(\)") "terrain overlays still race the placement ghost in MonoBehaviour.Update"
Assert-True ($iconCacheSource -match "AppDomain\.CurrentDomain\.GetAssemblies") "ImageConversion assembly fallback is missing"
Assert-True ($packageTargets -match "OutputResources\)\\Translations") "debug translations are not deployed"
Assert-True ($environmentProps -notmatch "VALHEIM_SERVERR") "dedicated-server property typo returned"
Assert-True ($preciseSource -match "return radius == float\.NegativeInfinity;" -and $preciseSource -match "SettingsPayloadVersion = 1" -and $preciseSource -match "sizeof\(float\) \* 7") "legacy precision flags or the seven-float settings payload changed"
Assert-True ($pluginSource -match 'Path\.GetDirectoryName\(Info\.Location\)' -and $pluginSource -match '"Translations",\s*"TerrainTools",\s*language' -and $pluginSource -match 'AddFileByPath\(externalPath, true\)') "external localization path or override precedence is not explicit"

# Native Heightmap IL: height = floor(local / scale + 0.5) + width / 2;
# mask = floor(local / scale + 0.5 + (width + 1) / 2). Width 64 has half-index 32.
$snapCases = @(@(0, 0), @(-0.5001, -1), @(-0.5, 0), @(-0.4999, 0), @(0.4999, 0), @(0.5, 1), @(0.5001, 1), @(-1.5, -1), @(1.5, 2))
foreach ($zoneCenter in @(-64, 0, 64)) {
    foreach ($case in $snapCases) {
        $world = [float] ($zoneCenter + $case[0])
        $local = [float] ($world - $zoneCenter)
        $vertexIndex = [int] [Math]::Floor($local + 0.5) + 32
        $maskIndex = [int] [Math]::Floor($local + 0.5 + 32)
        $snapped = $zoneCenter + ($vertexIndex - 32)
        Assert-True ($vertexIndex -eq $maskIndex) "height/paint logical indices differ at x=$world"
        Assert-True ($snapped -eq $zoneCenter + $case[1]) "native snap/inverse regression at x=$world"
    }
}

$mathType = Add-Type -TypeDefinition $paintGridMathSource -PassThru
$getAxisBounds = $mathType.GetMethod("TryGetAxisBounds", [Reflection.BindingFlags] "Static,NonPublic")
$getAxisIndices = $mathType.GetMethod("GetAxisIndices", [Reflection.BindingFlags] "Static,NonPublic")
$getTexelUv = $mathType.GetMethod("TexelCenterUv", [Reflection.BindingFlags] "Static,NonPublic")
function Get-AxisBounds([float]$ZoneCenter, [int]$First, [int]$Last) {
    $arguments = [object[]] @(64, [float] 1, $ZoneCenter, $First, $Last, [float] 0, [float] 0)
    $valid = [bool] $getAxisBounds.Invoke($null, $arguments)
    return @($valid, [float] $arguments[5], [float] $arguments[6])
}

$centerBounds = Get-AxisBounds 0 31 33
Assert-True $centerBounds[0] "central paint bounds are invalid"
Assert-True ($centerBounds[1] -eq -1 -and $centerBounds[2] -eq 1) "paint core is not centered and 2m wide"
Assert-True ($centerBounds[1] - 1 -eq -2 -and $centerBounds[2] + 1 -eq 2) "paint preview does not mark the 4m solid visible area"
Assert-True ($centerBounds[1] - 2 -eq -3 -and $centerBounds[2] + 2 -eq 3) "paint preview does not mark the 6m visible blend limit"

$westZoneBounds = Get-AxisBounds 0 63 64
$eastZoneBounds = Get-AxisBounds 64 0 1
$zoneUnionWidth = [Math]::Max($westZoneBounds[2], $eastZoneBounds[2]) - [Math]::Min($westZoneBounds[1], $eastZoneBounds[1])
Assert-True ($zoneUnionWidth -eq 2) "paint core widens at a Heightmap boundary"

$emptyBounds = Get-AxisBounds 0 65 64
Assert-True (-not $emptyBounds[0]) "empty neighboring Heightmap bounds are treated as painted"

function Get-PaintAxis([float]$ZoneCenter, [float]$WorldCenter, [int]$Radius = 1) {
    $centerIndex = [int] [Math]::Floor($WorldCenter - $ZoneCenter + 0.5) + 32
    $arguments = [object[]] @(64, $centerIndex, $Radius, 0, 0)
    $null = $getAxisIndices.Invoke($null, $arguments)
    $bounds = Get-AxisBounds $ZoneCenter $arguments[3] $arguments[4]
    return @{ First = [int] $arguments[3]; Last = [int] $arguments[4]; Valid = $bounds[0]; Min = $bounds[1]; Max = $bounds[2] }
}

foreach ($width in @(32, 64)) {
    for ($index = 0; $index -le $width; $index++) {
        $uv = [float] $getTexelUv.Invoke($null, [object[]] @($index, $width))
        Assert-True ([Math]::Abs($uv * ($width + 1) - 0.5 - $index) -lt 1e-5) "render UV does not sample texel center $index/$width"
    }
}

$zones = @(-64, 0, 64)
$paintCenters = @(-64, -33, -32, -31, -23, 0, 23, 31, 32, 33, 64)
foreach ($center in $paintCenters) {
    $selected = @($zones | Where-Object { $center + 1 -ge $_ - 32 -and $center - 1 -le $_ + 32 } | ForEach-Object { Get-PaintAxis $_ $center })
    $min = ($selected.Min | Measure-Object -Minimum).Minimum
    $max = ($selected.Max | Measure-Object -Maximum).Maximum
    Assert-True ($min -eq $center - 1 -and $max -eq $center + 1) "paint core shifts or expands at $center"

    # Sample the bilinear mask through the production UVs, including both copies of a seam.
    foreach ($offset in @(-2, -1.5, -1, -0.5, 0, 0.5, 1, 1.5, 2)) {
        $world = $center + $offset
        foreach ($zone in $zones | Where-Object { $world -ge $_ - 32 -and $world -le $_ + 32 }) {
            $axis = Get-PaintAxis $zone $center
            $local = $world - $zone + 32
            $vertex = [Math]::Min(63, [int] [Math]::Floor($local))
            $uv0 = [float] $getTexelUv.Invoke($null, [object[]] @($vertex, 64))
            $uv1 = [float] $getTexelUv.Invoke($null, [object[]] @(($vertex + 1), 64))
            $texel = ($uv0 + ($uv1 - $uv0) * ($local - $vertex)) * 65 - 0.5
            $lo = [int] [Math]::Floor($texel)
            $a = [Math]::Max(0, [Math]::Min(64, $lo))
            $b = [Math]::Max(0, [Math]::Min(64, $lo + 1))
            $aValue = [int] ($a -ge $axis.First -and $a -le $axis.Last)
            $bValue = [int] ($b -ge $axis.First -and $b -le $axis.Last)
            $sample = $aValue + ($bValue - $aValue) * ($texel - $lo)
            $expected = [Math]::Max(0.0, [Math]::Min(1.0, 2.0 - [Math]::Abs($offset)))
            Assert-True ([Math]::Abs($sample - $expected) -lt 1e-5) "paint support is shifted or widened: center=$center, world=$world, zone=$zone"
        }
    }
}

foreach ($cx in @(-32, 32)) {
    foreach ($cz in @(-32, 32)) {
        $copies = @{}
        foreach ($zx in $zones | Where-Object { $cx + 1 -ge $_ - 32 -and $cx - 1 -le $_ + 32 }) {
            foreach ($zz in $zones | Where-Object { $cz + 1 -ge $_ - 32 -and $cz - 1 -le $_ + 32 }) {
                $xAxis = Get-PaintAxis $zx $cx
                $zAxis = Get-PaintAxis $zz $cz
                for ($x = $xAxis.First; $x -le $xAxis.Last; $x++) {
                    for ($z = $zAxis.First; $z -le $zAxis.Last; $z++) {
                        $key = "$($zx + $x - 32),$($zz + $z - 32)"
                        $copies[$key] = 1 + $copies[$key]
                    }
                }
            }
        }
        Assert-True ($copies.Count -eq 9 -and $copies["$cx,$cz"] -eq 4) "four-zone corner does not write the same centered 3x3 stencil to all border copies"
    }
}

$raiseMathType = Add-Type -TypeDefinition $raiseMathSource -PassThru
$getRaiseWeight = $raiseMathType.GetMethod("Weight", [Reflection.BindingFlags] "Static,NonPublic")
$getRaiseTarget = $raiseMathType.GetMethod("TryGetTargetHeight", [Reflection.BindingFlags] "Static,NonPublic")
# tile, reference, delta, should apply, original full-strength target.
# Above/below-center tiles expose the difference between scaling delta and scaling the actual change.
$raiseHeightCases = @(
    @(10.5, 10, 1, $true, 11),
    @(9.5, 10, 1, $true, 10.5),
    @(10, 10, 1, $true, 11),
    @(11, 10, 1, $true, 11),
    @(11.5, 10, 1, $false, 11.5),
    @(10.5, 10, 0, $false, 10.5),
    @(9.5, 10, 0, $true, 9.5),
    @(10.5, 10, -1, $true, 9),
    @(9.5, 10, -1, $true, 9),
    @(8.5, 10, -1, $false, 8.5)
)
foreach ($case in $raiseHeightCases) {
    foreach ($power in @([float] 0, [float] 0.05, [float] 0.5, [float] 1)) {
        foreach ($distance in @(0, 1, 2)) {
            $weight = [float] $getRaiseWeight.Invoke($null, [object[]] @($distance, 0, $power))
            $arguments = [object[]] @([float] $case[0], [float] $case[1], [float] $case[2], $weight, [float] 0)
            $applies = [bool] $getRaiseTarget.Invoke($null, $arguments)
            Assert-True ($applies -eq $case[3]) "raise falloff changes the original sign guard: tile=$($case[0]), delta=$($case[2])"
            if (-not $applies) { continue }
            $expected = $case[0] + ($case[4] - $case[0]) * $weight
            Assert-True ([Math]::Abs($arguments[4] - $expected) -lt 1e-6) "raise ring scales center delta instead of the actual height change: tile=$($case[0]), power=$power"
            if ($distance -eq 0) { Assert-True ($arguments[4] -eq $case[4]) "raise peak no longer matches the full-strength target" }
        }
    }
}

foreach ($power in @([float] 0, [float] 0.05, [float] 0.5, [float] 1, [float]::NaN)) {
    $effectivePower = if ([float]::IsNaN($power)) { 1.0 } else { [Math]::Max(0.05, [Math]::Min(1.0, $power)) }
    $topHalfExtent = (1.0 - $effectivePower) / 0.95
    $count = 0
    for ($dx = -4; $dx -le 4; $dx++) {
        for ($dz = -4; $dz -le 4; $dz++) {
            $weight = [float] $getRaiseWeight.Invoke($null, [object[]] @($dx, $dz, $power))
            $distance = [Math]::Max([Math]::Abs($dx), [Math]::Abs($dz))
            Assert-True (-not [float]::IsNaN($weight) -and $weight -ge 0 -and $weight -le 1) "raise falloff is not finite and bounded"
            if ($distance -le $topHalfExtent) { Assert-True ($weight -eq 1) "raise changes the selected top" }
            if ($distance -ge 2) { Assert-True ($weight -eq 0) "raise extends past the 4m influence" }
            if ($distance -gt $topHalfExtent -and $distance -lt 2) {
                $expectedWeight = (2.0 - $distance) / (2.0 - $topHalfExtent)
                Assert-True ([Math]::Abs($weight - $expectedWeight) -lt 1e-6) "raise slope is not linear between the top and fixed boundary"
            }
            if ($weight -gt 0) { $count++ }
        }
    }
    Assert-True ($count -eq 9) "raise does not stay inside its fixed 4m footprint"
}

$softTop = [float] $raiseMathType.GetMethod("SlopePivot", [Reflection.BindingFlags] "Static,NonPublic").Invoke($null, [object[]] @([float] 1))
$hardTop = [float] $raiseMathType.GetMethod("SlopePivot", [Reflection.BindingFlags] "Static,NonPublic").Invoke($null, [object[]] @([float] 0.05))
Assert-True ($softTop -eq 0 -and $hardTop -eq 1) "raise top preview does not resize continuously from a point to 2m"
$middleTop = [float] $raiseMathType.GetMethod("SlopePivot", [Reflection.BindingFlags] "Static,NonPublic").Invoke($null, [object[]] @([float] 0.525))
Assert-True ([Math]::Abs($middleTop - 0.5) -lt 1e-6) "raise top preview is not continuous between its limits"

foreach ($center in $paintCenters) {
    $vertices = [Collections.Generic.HashSet[int]]::new()
    foreach ($zone in $zones | Where-Object { $center + 2 -ge $_ - 32 -and $center - 2 -le $_ + 32 }) {
        $axis = Get-PaintAxis $zone $center 1
        for ($i = $axis.First; $i -le $axis.Last; $i++) { $null = $vertices.Add($zone + $i - 32) }
    }
    Assert-True ($vertices.Count -eq 3 -and ($vertices | Measure-Object -Minimum).Minimum -eq $center - 1 -and ($vertices | Measure-Object -Maximum).Maximum -eq $center + 1) "raise fanout omits or expands the modified vertices at $center"
}

foreach ($cx in @(-32, 32)) {
    foreach ($cz in @(-32, 32)) {
        $weights = @{}
        foreach ($zx in $zones | Where-Object { $cx + 2 -ge $_ - 32 -and $cx - 2 -le $_ + 32 }) {
            foreach ($zz in $zones | Where-Object { $cz + 2 -ge $_ - 32 -and $cz - 2 -le $_ + 32 }) {
                $xAxis = Get-PaintAxis $zx $cx 1
                $zAxis = Get-PaintAxis $zz $cz 1
                for ($x = $xAxis.First; $x -le $xAxis.Last; $x++) {
                    for ($z = $zAxis.First; $z -le $zAxis.Last; $z++) {
                        $wx = $zx + $x - 32
                        $wz = $zz + $z - 32
                        $key = "$wx,$wz"
                        $weight = [float] $getRaiseWeight.Invoke($null, [object[]] @(($wx - $cx), ($wz - $cz), [float] 0.5))
                        if ($weights.ContainsKey($key)) { Assert-True ($weights[$key] -eq $weight) "raise corner copies receive different slope weights" }
                        $weights[$key] = $weight
                    }
                }
            }
        }
        Assert-True ($weights.Count -eq 9) "raise four-zone fanout does not cover every modified vertex"
    }
}

Write-Host "PASS: native paint UVs, centered core/support, zone seams/corners, and precise raise falloff"

foreach ($manifestPath in @("Package\manifest.json", "Publish\ThunderStore\manifest.json")) {
    $manifest = Get-Content -LiteralPath (Join-Path $ProjectRoot $manifestPath) -Raw | ConvertFrom-Json
    Assert-True ($manifest.version_number -eq $expectedVersion) "$manifestPath version is inconsistent"
    Assert-True ($manifest.dependencies -contains "ValheimModding-Jotunn-2.30.0") "$manifestPath does not require Jotunn 2.30.0"
}

$dllPath = Join-Path $ProjectRoot "bin\Release\net48\TerrainTools.dll"
Assert-True (Test-Path -LiteralPath $dllPath) "release DLL is missing"
$zipPath = Join-Path $ProjectRoot "Publish\ThunderStore\TerrainTools.zip"
Assert-True (Test-Path -LiteralPath $zipPath) "Thunderstore ZIP is missing"
Add-Type -AssemblyName System.IO.Compression.FileSystem
$zip = [System.IO.Compression.ZipFile]::OpenRead($zipPath)
try {
    $zipEntries = @($zip.Entries.FullName)
    foreach ($requiredEntry in @(
        "manifest.json",
        "README.md",
        "CHANGELOG.md",
        "icon.png",
        "TerrainTools.dll",
        "Translations/TerrainTools/English/translations.json",
        "Translations/TerrainTools/Russian/translations.json"
    )) {
        Assert-True ($zipEntries -contains $requiredEntry) "Thunderstore ZIP is missing $requiredEntry"
    }
    Assert-True (-not ($zipEntries | Where-Object { $_ -like "*.zip" })) "Thunderstore ZIP contains a nested archive"
    $zipDll = $zip.Entries | Where-Object FullName -eq "TerrainTools.dll"
    $zipDllStream = $zipDll.Open()
    $sha256 = [Security.Cryptography.SHA256]::Create()
    try {
        $zipDllHash = [BitConverter]::ToString($sha256.ComputeHash($zipDllStream)).Replace("-", "")
    }
    finally {
        $sha256.Dispose()
        $zipDllStream.Dispose()
    }
    Assert-True ($zipDllHash -eq (Get-FileHash -LiteralPath $dllPath -Algorithm SHA256).Hash) "Thunderstore ZIP contains a stale DLL"
}
finally {
    $zip.Dispose()
}

$tokens = [regex]::Matches($allSourceText, '\$atmc_[a-z0-9_]+') |
    ForEach-Object { $_.Value.TrimStart('$') } |
    Sort-Object -Unique
foreach ($language in @("English", "Russian")) {
    $translationPath = Join-Path $ProjectRoot "Package\Translations\TerrainTools\$language\translations.json"
    Assert-True (-not (Test-Path -LiteralPath (Join-Path $ProjectRoot "Package\Translations\$language\translations.json"))) "$language translation still uses the ambiguous legacy path"
    $translations = Get-Content -LiteralPath $translationPath -Raw | ConvertFrom-Json -AsHashtable
    foreach ($token in $tokens) {
        Assert-True ($translations.ContainsKey($token)) "$language translation is missing $token"
        Assert-True (-not [string]::IsNullOrWhiteSpace($translations[$token])) "$language translation is empty for $token"
    }
    Assert-True ($translations.Count -eq $tokens.Count) "$language translation contains unused keys"
}

$cecilPath = Join-Path $BepInExPath "core\Mono.Cecil.dll"
Add-Type -Path $cecilPath
$assembly = [Mono.Cecil.AssemblyDefinition]::ReadAssembly($dllPath)
try {
    Assert-True ($assembly.Name.Version.ToString() -eq "$expectedVersion.0") "DLL assembly version is $($assembly.Name.Version)"
    $pluginType = $assembly.MainModule.Types | Where-Object FullName -eq "TerrainTools.TerrainTools"
    Assert-True ($null -ne $pluginType) "plugin type is missing"
    $pluginAttribute = $pluginType.CustomAttributes | Where-Object { $_.AttributeType.FullName -eq "BepInEx.BepInPlugin" }
    Assert-True ($null -ne $pluginAttribute) "BepInPlugin attribute is missing"
    Assert-True ($pluginAttribute.ConstructorArguments[2].Value -eq $expectedVersion) "BepInPlugin version is inconsistent"
    $initType = $assembly.MainModule.Types | Where-Object FullName -eq "TerrainTools.Helpers.InitManager"
    Assert-True ($initType.Methods.Name -contains "EnsureTerrainOpRegistered") "compiled TerrainOp fallback is missing"
    Assert-True ($initType.Methods.Name -contains "ObjectDBUpdateRegistersPostfix") "compiled ObjectDB refresh patch is missing"
    $preciseType = $assembly.MainModule.Types | Where-Object FullName -eq "TerrainTools.Helpers.PreciseTerrainModifier"
    Assert-True ($preciseType.Methods.Name -contains "SerializeSettingsPostfix") "compiled settings serializer patch is missing"
    Assert-True ($preciseType.Methods.Name -contains "DeserializeSettingsPostfix") "compiled settings deserializer patch is missing"
    Assert-True ($preciseType.Methods.Name -contains "GetSettingsRadiusPostfix") "compiled precision Settings.GetRadius patch is missing"
}
finally {
    $assembly.Dispose()
}

Write-Host "PASS: AdvancedTerrainModifiersCompatible $expectedVersion release checks"
Write-Host "PASS: $($tokens.Count) localization tokens match English and Russian files"
