param(
    [string]$ProjectRoot = (Split-Path -Parent $PSScriptRoot),
    [string]$BepInExPath = "C:\Users\nfspr\AppData\Roaming\Thunderstore Mod Manager\DataFolder\Valheim\profiles\Default\BepInEx"
)

$ErrorActionPreference = "Stop"
$expectedVersion = "1.4.5"

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
$allSource = Get-ChildItem -LiteralPath $ProjectRoot -Recurse -Filter "*.cs" |
    Where-Object FullName -NotMatch "[\\/](bin|obj)[\\/]" |
    ForEach-Object { Get-Content -LiteralPath $_.FullName -Raw }
$allSourceText = $allSource -join "`n"

Assert-True ($pluginSource -match "PluginVersion = `"$([regex]::Escape($expectedVersion))`"") "plugin version is not $expectedVersion"
Assert-True ($allSourceText -notmatch "HarmonyPatch\(typeof\(Player\),\s*nameof\(Player\.Update\)\)") "Player.Update Harmony patch returned"
Assert-True ($pluginSource -match "RadiusModifier\.Tick\(Player\.m_localPlayer\)") "radius polling is not in plugin Update"
Assert-True ($pluginSource -match "HardnessModifier\.Tick\(Player\.m_localPlayer\)") "hardness polling is not in plugin Update"
Assert-True ($initSource -match "EnsureTerrainOpRegistered\(prefab\)") "TerrainOp fallback is not called"
Assert-True ($initSource -match "m_terrainOpsByHash\.TryGetValue") "TerrainOp fallback is not idempotent"
Assert-True ($initSource -match "registeredTerrainOp != terrainOp") "TerrainOp hash collisions are not guarded"
Assert-True ($initSource -match "ObjectDBUpdateRegistersPostfix") "TerrainOp fallback is not restored after ObjectDB refresh"
Assert-True ($preciseSource -match "SerializeSettingsPostfix") "runtime TerrainOp settings are not serialized"
Assert-True ($preciseSource -match "DeserializeSettingsPostfix") "runtime TerrainOp settings are not deserialized"
Assert-True ($preciseSource -match "FixedPaintRadius = 1") "square paint does not use the interpolated 3m footprint"
Assert-True ($preciseSource -notmatch "worldPos\.(x|z)\s*-=\s*0\.5f") "paint still applies the obsolete half-cell offset"
Assert-True ($preciseSource -match "m_modifiedPaint\[tileIndex\]\s*=\s*true") "paint reset is not persisted explicitly"
Assert-True ($preciseSource -match "xPos <= 0 \? xMin : xMin \+ 1" -and $preciseSource -match "yPos <= 0 \? yMin : yMin \+ 1") "paint does not update the duplicated Heightmap border"
Assert-True ($preciseSource -match "Reset chunk" -and $preciseSource -match "vertices=" -and $preciseSource -match "edge=") "chunk-boundary reset diagnostics are missing"
Assert-True ($preciseSource -match "GetRadiusPostfix") "reset radius does not select every affected Heightmap"
Assert-True ($preciseSource -match "m_levelRadius \+ 1f") "reset radius does not include neighboring Heightmaps"
Assert-True ($preciseSource -match "TerrainModifier\.GetModifiers\(position, radius \+ 1f") "reset does not remove legacy terrain modifiers"
Assert-True ($preciseSource -match "RemoveTerrainModifications\(__instance, pos, radius\)") "reset radius is not applied to height restoration"
Assert-True ($preciseSource -match "PaintType\.Reset, radius: radius") "reset radius is not applied to paint restoration"
Assert-True ($preciseSource -notmatch "ClutterSystem\.instance\.ResetGrass\(pos, radius\)") "reset still clears vegetation across the whole selected area"
Assert-True ($radiusSource -match "RemoveModificationsOverlayVisualizer") "reset tool cannot use the radius modifier"
Assert-True ($radiusSource -match "delta = Mathf\.Sign\(delta\)") "reset radius is not quantized to terrain cells"
Assert-True ($radiusSource -match "resetVisualizer\.SetScale\(lastGhostScale\)") "reset frame and cross do not scale together"
Assert-True ($pluginSource -match '"HardnessScrollScale",\s*1f') "hardness scroll still uses the slow legacy default"
Assert-True ($cameraSource -match "Input\.GetKey\(TerrainTools\.HardnessKey\)") "hardness key does not block camera zoom"
Assert-True ($shovelSource -match "UseCategories = false") "single-action shovel still uses hammer categories"
Assert-True ($overlaySource -match "psm = ps\.main") "Overlay MainModule is not initialized"
Assert-True ($overlaySource -match "public float StartSpeed[\s\S]*?psm\.startSpeed\.constant") "Overlay StartSpeed getter is incorrect"
Assert-True ($overlaySource -match "psMain\.startColor = value") "Overlay StartColor setter is ineffective"
Assert-True (([regex]::Matches($preciseSource, "GetPaintMaskBounds\(")).Count -ge 3) "paint write and preview do not share one mask-bounds calculation"
Assert-True ($paintGridMathSource -match "terrainWidth \* vertexScale / \(terrainWidth \+ 1f\)") "paint preview does not use the rendered 65x65 mask spacing"
Assert-True ($overlayVisualizerSource -match "TryGetPaintMaskWorldBounds") "paint preview does not use the shared render-grid geometry"
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
Assert-True ($raiseVisualizerSource -match "secondary\.StartSize = 2f \* PreciseTerrainModifier\.FixedRadius \* vertexScale" -and $raiseVisualizerSource -match "tertiary\.StartSize = 2f \* \(PreciseTerrainModifier\.FixedRadius \+ 1\) \* vertexScale") "raise preview does not distinguish the 2m top from the 4m affected footprint"
Assert-True ($raiseVisualizerSource -match "secondary\.LocalScale = Vector3\.one;" -and $raiseVisualizerSource -match "tertiary\.LocalScale = Vector3\.one;") "raise preview inherits a scaled paint frame"
Assert-True ($toolVisualizersSource -match "class SquarePathOverlayVisualizer[\s\S]*?SnapToPaintGrid\(secondary, tertiary\)[\s\S]*?primary\.Enabled = false;[\s\S]*?class CultivateOverlayVisualizer") "square paths do not show only their paint grid"
Assert-True ($toolVisualizersSource -match "class CultivateOverlayVisualizer[\s\S]*?SnapToPaintGrid\(secondary, tertiary\)[\s\S]*?primary\.Enabled = false;[\s\S]*?class SeedGrassOverlayVisualizer") "square cultivation does not show only its paint grid"
Assert-True ($toolVisualizersSource -match "class SeedGrassOverlayVisualizer[\s\S]*?SnapToPaintGrid\(secondary, tertiary\)[\s\S]*?class RemoveModificationsOverlayVisualizer") "replant square does not use the paint grid preview"
Assert-True ($toolVisualizersSource -notmatch "SpeedUp\(secondary\)[\s\S]{0,120}VisualizeTerraformingBounds\(secondary\)") "exact level frame is still animated"
Assert-True ($toolVisualizersSource -match "localPosition\.y = VerticalOffset\.y \+ GroundLevelSpinner\.Value") "raise target frame loses its vertical overlay offset"
Assert-True ($overlayVisualizerSource -match "TexelScale\(heightmap\.m_width, heightmap\.m_scale\) \* 0\.5f") "paint feather does not follow the rendered texel size"
Assert-True (([regex]::Matches($toolVisualizersSource, "tertiary\.StartColor = new Color\(1f, 1f, 1f, 0\.3f\)")).Count -ge 2) "paint feather is not visually distinguished"

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
function Get-AxisBounds([float]$ZoneCenter, [int]$First, [int]$Last) {
    $arguments = [object[]] @(64, [float] 1, $ZoneCenter, $First, $Last, [float] 0, [float] 0)
    $valid = [bool] $getAxisBounds.Invoke($null, $arguments)
    return @($valid, [float] $arguments[5], [float] $arguments[6])
}

$centerBounds = Get-AxisBounds 0 32 33
Assert-True $centerBounds[0] "central paint bounds are invalid"
Assert-True ([Math]::Abs((($centerBounds[1] + $centerBounds[2]) * 0.5) - 0.49230769230769234) -lt 1e-6) "paint preview center regression"
Assert-True ([Math]::Abs(($centerBounds[2] - $centerBounds[1]) - 2.953846153846154) -lt 1e-6) "two-cell bilinear support regression"

$westZoneBounds = Get-AxisBounds 0 64 64
$eastZoneBounds = Get-AxisBounds 64 0 1
$zoneUnionWidth = [Math]::Max($westZoneBounds[2], $eastZoneBounds[2]) - [Math]::Min($westZoneBounds[1], $eastZoneBounds[1])
Assert-True ([Math]::Abs($zoneUnionWidth - 3.9384615384615387) -lt 1e-5) "paint preview does not cover both sides of a Heightmap boundary"

$emptyBounds = Get-AxisBounds 0 65 64
Assert-True (-not $emptyBounds[0]) "empty neighboring Heightmap bounds are treated as painted"

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
        "Translations/English/translations.json",
        "Translations/Russian/translations.json"
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
    $translationPath = Join-Path $ProjectRoot "Package\Translations\$language\translations.json"
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
