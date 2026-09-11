param(
    [string]$ProjectRoot = (Split-Path -Parent $PSScriptRoot),
    [string]$BepInExPath = "C:\Users\nfspr\AppData\Roaming\Thunderstore Mod Manager\DataFolder\Valheim\profiles\Default\BepInEx"
)

$ErrorActionPreference = "Stop"
$expectedVersion = "1.4.4"

function Assert-True([bool]$Condition, [string]$Message) {
    if (-not $Condition) { throw "VERIFY FAILED: $Message" }
}

$pluginSource = Get-Content -LiteralPath (Join-Path $ProjectRoot "TerrainTools.cs") -Raw
$initSource = Get-Content -LiteralPath (Join-Path $ProjectRoot "Helpers\InitManager.cs") -Raw
$preciseSource = Get-Content -LiteralPath (Join-Path $ProjectRoot "Helpers\PreciseTerrainModifier.cs") -Raw
$radiusSource = Get-Content -LiteralPath (Join-Path $ProjectRoot "Helpers\RadiusModifier.cs") -Raw
$cameraSource = Get-Content -LiteralPath (Join-Path $ProjectRoot "Patches\GameCameraPatch.cs") -Raw
$shovelSource = Get-Content -LiteralPath (Join-Path $ProjectRoot "Helpers\Shovel.cs") -Raw
$overlaySource = Get-Content -LiteralPath (Join-Path $ProjectRoot "Visualization\Overlay.cs") -Raw
$overlayVisualizerSource = Get-Content -LiteralPath (Join-Path $ProjectRoot "Visualization\OverlayVisualizer.cs") -Raw
$toolVisualizersSource = Get-Content -LiteralPath (Join-Path $ProjectRoot "Visualization\ToolVisualizers.cs") -Raw
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
Assert-True ($overlayVisualizerSource -match "VertexMaskToWorld\(xPos \+ 2, yPos \+ 2\)") "paint preview is not centered between the actual paint-mask cell boundaries"
Assert-True (([regex]::Matches($toolVisualizersSource, "SnapToPaintGrid\(secondary\)")).Count -ge 2) "square paint previews are not snapped to the paint-mask grid"

foreach ($manifestPath in @("Package\manifest.json", "Publish\ThunderStore\manifest.json")) {
    $manifest = Get-Content -LiteralPath (Join-Path $ProjectRoot $manifestPath) -Raw | ConvertFrom-Json
    Assert-True ($manifest.version_number -eq $expectedVersion) "$manifestPath version is inconsistent"
    Assert-True ($manifest.dependencies -contains "ValheimModding-Jotunn-2.30.0") "$manifestPath does not require Jotunn 2.30.0"
}

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

$dllPath = Join-Path $ProjectRoot "bin\Release\net48\TerrainTools.dll"
Assert-True (Test-Path -LiteralPath $dllPath) "release DLL is missing"
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
}
finally {
    $assembly.Dispose()
}

Write-Host "PASS: AdvancedTerrainModifiersCompatible $expectedVersion release checks"
Write-Host "PASS: $($tokens.Count) localization tokens match English and Russian files"
