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
$overlaySource = Get-Content -LiteralPath (Join-Path $ProjectRoot "Visualization\Overlay.cs") -Raw
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
Assert-True ($overlaySource -match "psm = ps\.main") "Overlay MainModule is not initialized"
Assert-True ($overlaySource -match "public float StartSpeed[\s\S]*?psm\.startSpeed\.constant") "Overlay StartSpeed getter is incorrect"
Assert-True ($overlaySource -match "psMain\.startColor = value") "Overlay StartColor setter is ineffective"

foreach ($manifestPath in @("Package\manifest.json", "Publish\ThunderStore\manifest.json")) {
    $manifest = Get-Content -LiteralPath (Join-Path $ProjectRoot $manifestPath) -Raw | ConvertFrom-Json
    Assert-True ($manifest.version_number -eq $expectedVersion) "$manifestPath version is inconsistent"
    Assert-True ($manifest.dependencies -contains "ValheimModding-Jotunn-2.30.0") "$manifestPath does not require Jotunn 2.30.0"
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
}
finally {
    $assembly.Dispose()
}

Write-Host "PASS: AdvancedTerrainModifiersCompatible $expectedVersion release checks"
Write-Host "PASS: $($tokens.Count) localization tokens match English and Russian files"
