# AdvancedTerrainModifiers Compatible
Quality of life building mod that improves how terrain manipulation with the hoe and cultivator works and adds new terrain manipulation tools.

> Install this package **instead of** `Searica-AdvancedTerrainModifiers`. Do not load both packages: this compatibility build intentionally keeps the original BepInEx plugin GUID so existing configuration and multiplayer checks continue to work.

This GPLv3 compatibility fork is based on Searica's AdvancedTerrainModifiers 1.4.1 (`e773c62`). Ostrix maintains the compatibility release. It avoids the EpicLoot 0.13.x `Player.Update` Harmony conflict and keeps custom terrain operations multiplayer-safe even when the installed Jotunn build lacks custom `TerrainOp` registration. Credit for the original mod and gameplay features belongs to Searica. Do not report fork-specific issues to the original author.

Version 1.4.5 targets Valheim 1.0, BepInEx 5.4.2350 and Jotunn 2.30.0. English and Russian gameplay text can be edited in `Translations/<Language>/translations.json`. Runtime compatibility must still be smoke-tested after each Valheim release.

## Version 1.4.5

- Uses one shared paint-mask bounds calculation for both square terrain painting and its preview.
- Aligns the preview to Valheim's rendered 65x65 paint-mask texels instead of the mismatched one-metre vertex-grid inverse.
- Shows a bright core frame plus a wider translucent frame for the texture-filtering feather; mip filtering can still soften the edge at distance.
- Uses the proven paint-mask preview for level and raise tools so their frames match the visible square.
- Shows matching base and target footprints for precise raising; square vegetation restoration also uses the shared paint preview.
- Prevents precision paint, raise and smooth operations from reporting a zero effective radius after their sentinel is applied.

## Version 1.4.4

- Preserves precision height, radius, hardness, smoothing and paint settings through Valheim 1.0 terrain-operation RPC serialization.
- Restores custom `TerrainOp` registration after world reloads and provides an idempotent fallback when the installed Jotunn build does not register custom terrain operations.
- Fixes terrain restoration across Heightmap boundaries and removes legacy `TerrainModifier` objects inside the selected area.
- Adds adjustable restoration radius with `Alt + mouse wheel`; the frame and center marker now scale together.
- Prevents camera zoom while changing radius or hardness and increases the default hardness scroll speed.
- Fixes overlay state, precision-height scrolling, square-tool hover information, shovel initialization and its single-action build menu.
- Adds editable English and Russian gameplay localization.
- Updates the package for BepInEx 5.4.2350 and Jotunn 2.30.0.

**Server-Side Info**: This mod does work as a client-side only mod and only needs to be installed on the server if you wish to enforce configuration settings.

**Terrain paint note**: Valheim stores terrain paint on a coarse interpolated mask. The visible edge can therefore extend slightly beyond a square preview. The same behavior was reproduced with PlanBuild's terrain-paint tool and is treated as a current engine limitation rather than a different operation area in this mod.

## Features

### Multiplayer Support
- All terrain operations, including resetting terrain modifications, work in multiplayer and are synced to other players.

### Quality of Life
- Adds descriptions of how each terrain tool works for all Vanilla terrain tools.
- All new features can be enabled/disabled from the configuration file.

### Modifiable Tool Radius
- Lets you change the radius of terrain tools using the scroll wheel.
- Configurable hotkey to enable changing radius.
- Configurable maximum tool radius.
- Camera zoom is blocked while modifying tool radius.

### Modifiable Tool Hardness
- Lets you change the "hardness" of terrain tools using the scroll wheel. "Hardness" refers to how uniformly the effect is applied over the radius of the tool, so increasing the hardness will apply the effect more uniformly (see image for example of changing hardness for the Raise Ground tool).
- Configurable hotkey to enable changing hardness.
- Camera zoom is blocked while modifying tool hardness.
<img src="https://raw.githubusercontent.com/searica/TerrainTools/main/Media/HardnessDemo.png"></img>

### New Terrain Tool
- Adds a craftable shovel that lets you lower terrain.

### New Hoe Tools
- Adds a version of each terrain tool that doesn't affect the terrain height when used.
- Adds square versions of all terrain tools that modify terrain according to the world grid (so you can enjoy clean edges).
- Adds a precision raise ground tool that lets you set the exact height you want to raise the terrain by using the scroll wheel on your mouse.
- Adds a remove terrain modifications tool that lets you reset terrain.

<img src="https://raw.githubusercontent.com/searica/TerrainTools/main/Media/HoeTools.png"></img>

### New Cultivator Tools
- Adds a version of the cultivate tool that doesn't affect the terrain height when used.
- Adds square versions of each tools tool in the cultivator that modifies terrain according to the world grid (so you can enjoy clean edges).

<img src="https://raw.githubusercontent.com/searica/TerrainTools/main/Media/CultivatorTools.png"></img>

## Instructions
If you are using a mod manager for Thunderstore simply install the mod from there. If you are not using a mod manager then, you need a modded instance of Valheim (BepInEx) and the Jotunn plugin installed.

## Configuration
Changes made to the configuration settings will be reflected in-game immediately (no restart required) and they will also sync to clients if the mod is on the server. The mod also has a built in file watcher so you can edit settings via an in-game configuration manager (changes applied upon closing the in-game configuration manager) or by changing values in the file via a text editor or mod manager.

<div class="header">
	<h3>Global Section</h3>
    These settings control the global settings and how verbose the output to the log is.
</div>
<table>
	<tbody>
		<tr>
            <th align="center">Setting</th>
            <th align="center">Server Sync</th>
			<th align="center">Description</th>
		</tr>
            <td align="center"><b>Verbosity</b></td>
            <td align="center">No</td>
			<td align="left">
                Low will log basic information about the mod. Medium will log information that is useful for troubleshooting. High will log a lot of information, do not set it to this without good reason as it will slow down your game.
				<ul>
					<li>Acceptable values: Low, Medium, High</li>
					<li>Default value: Low</li>
				</ul>
			</td>
		</tr>
        </tr>
            <td align="center"><b>HoverInfo</b></td>
            <td align="center">Yes</td>
			<td align="left">
                Set to true/enabled to show terrain height when using square terrain tools.
				<ul>
					<li>Acceptable values: False, True</li>
					<li>Default value: true</li>
				</ul>
			</td>
		</tr>
  </tbody>
</table>

<div class="header">
	<h3>Radius Section</h3>
    These settings control features related to modifying the radius of terrain tools.
</div>
<table>
	<tbody>
		<tr>
			<th align="center">Setting</th>
            <th align="center">Server Sync</th>
			<th align="center">Description</th>
		</tr>
			<td align="center"><b>RadiusModifier</b></td>
        <td align="center">Yes</td>
			<td align="left">
                Set to true/enabled to allow modifying the radius of terrain tools using the scroll wheel. Note: Radius cannot be changed on square tools except terrain restoration.
				<ul>
					<li>Acceptable values: False, True</li>
					<li>Default value: true</li>
				</ul>
			</td>
		</tr>
        </tr>
			<td align="center"><b>RadiusModKey</b></td>
            <td align="center">No</td>
			<td align="left">
                Modifier key that must be held down when using scroll wheel to change the radius of terrain tools.
				<ul>
					<li>Acceptable values: KeyCode</li>
					<li>Default value: LeftAlt</li>
				</ul>
			</td>
		</tr>
        </tr>
			<td align="center"><b>RadiusScrollScale</b></td>
            <td align="center">No</td>
			<td align="left">
                Scroll wheel change scale, larger magnitude means the radius will change faster and negative sign will reverse the direction you need to scroll to increase the radius.
				<ul>
					<li>Acceptable values: (-1, 1)</li>
					<li>Default value: 0.1</li>
				</ul>
			</td>
		</tr>
        </tr>
			<td align="center"><b>MaxRadius</b></td>
            <td align="center">Yes</td>
			<td align="left">
                Maximum radius of terrain tools.
				<ul>
					<li>Acceptable values: (4, 20)</li>
					<li>Default value: 10</li>
				</ul>
			</td>
		</tr>
  </tbody>
</table>


<div class="header">
	<h3>Hardness Section</h3>
    These settings control features related to modifying the hardness of terrain tools.
</div>
<table>
	<tbody>
		<tr>
			<th align="center">Setting</th>
            <th align="center">Server Sync</th>
			<th align="center">Description</th>
		</tr>
			<td align="center"><b>HardnessModifier</b></td>
            <td align="center">Yes</td>
			<td align="left">
                Set to true/enabled to allow modifying the hardness of terrain tools using the scroll wheel. Note: Hardness cannot be changed on square terraforming tools and tools that do not alter ground height do not have a hardness.
				<ul>
					<li>Acceptable values: False, True</li>
					<li>Default value: true</li>
				</ul>
			</td>
		</tr>
        </tr>
			<td align="center"><b>HardnessModKey</b></td>
            <td align="center">No</td>
			<td align="left">
                Modifier key that must be held down when using scroll wheel to change the hardness of terrain tools.
				<ul>
					<li>Acceptable values: KeyCode</li>
					<li>Default value: LeftControl</li>
				</ul>
			</td>
		</tr>
        </tr>
			<td align="center"><b>HardnessScrollScale</b></td>
            <td align="center">No</td>
			<td align="left">
                Scroll wheel change scale, larger magnitude means the hardness will change faster and negative sign will reverse the direction you need to scroll to increase the hardness.
				<ul>
					<li>Acceptable values: (-1, 1)</li>
					<li>Default value: 1</li>
				</ul>
			</td>
		</tr>
  </tbody>
</table>

<div class="header">
	<h3>Shovel Section</h3>
    These settings control features related to the new Shovel tool.
</div>
<table>
	<tbody>
		<tr>
			<th align="center">Setting</th>
            <th align="center">Server Sync</th>
			<th align="center">Description</th>
		</tr>
			<td align="center"><b>Shovel</b></td>
            <td align="center">Yes</td>
			<td align="left">
                Set to true/enabled to allow crafting the shovel. Setting to false/disabled will prevent crafting new shovels but will not affect existing shovels in the world.
				<ul>
					<li>Acceptable values: False, True</li>
					<li>Default value: true</li>
				</ul>
			</td>
		</tr>
        </tr>
			<td align="center"><b>ShovelToolName</b></td>
            <td align="center">Yes</td>
			<td align="left">
                Set to true/enabled to add this terrain tool to the shovel. Set to false/disabled to remove it.
				<ul>
					<li>Acceptable values: False, True</li>
					<li>Default value: true</li>
				</ul>
			</td>
		</tr>
    </tbody>
</table>

<div class="header">
	<h3>Hoe Section</h3>
    These settings control features related to the Hoe.
</div>
<table>
	<tbody>
		<tr>
			<th align="center">Setting</th>
            <th align="center">Server Sync</th>
			<th align="center">Description</th>
        </tr>
			<td align="center"><b>HoeToolName</b></td>
            <td align="center">Yes</td>
			<td align="left">
                Set to true/enabled to add this terrain tool to the hoe. Set to false/disabled to remove it.
				<ul>
					<li>Acceptable values: False, True</li>
					<li>Default value: true</li>
				</ul>
			</td>
		</tr>
    </tbody>
</table>

<div class="header">
	<h3>Cultivator Section</h3>
    These settings control features related to the Cultivator.
</div>
<table>
	<tbody>
		<tr>
			<th align="center">Setting</th>
            <th align="center">Server Sync</th>
			<th align="center">Description</th>
        </tr>
			<td align="center"><b>CultivatorToolName</b></td>
            <td align="center">Yes</td>
			<td align="left">
                Set to true/enabled to add this terrain tool to the cultivator. Set to false/disabled to remove it.
				<ul>
					<li>Acceptable values: False, True</li>
					<li>Default value: true</li>
				</ul>
			</td>
		</tr>
    </tbody>
</table>

## Known Issues
Terrain paint is stored on Valheim's interpolated paint-mask grid, so the visible texture edge may extend slightly beyond a square preview. Terrain height and restoration bounds are unaffected by this visual blending.

## Compatibility
Should usually be compatible with everything except other mods that let you change the radius of terrain manipulation tools as they will likely conflict.

### Partial Incompatibility
**ValheimPlus** While TerrainTools does work with ValheimPlus there are some UI glitches. ValheimPlus freezes the animations for the terrain tools so you can't visualize the effect size properly and the hover info on square tools does not update correctly. It may be possible to fix this via changing something in ValheimPlus's configuration.

**FastTools** While the two mods are fully compatible and you can modify the stamina cost of the Shovel using FastTools, there is currently a visual bug in FastTools that breaks the animations on the placement ghost for all terrain tools and prevents AdvancedTerrainModifiers from being able to show the change in radius. You can use [ToolTweaks](https://valheim.thunderstore.io/package/Searica/ToolTweaks/) as a compatible alternative.

## Donations/Tips
My mods will always be free to use but if you feel like saying thanks you can tip/donate.

| My Ko-fi: | [![ko-fi](https://ko-fi.com/img/githubbutton_sm.svg)](https://ko-fi.com/searica) |
|-----------|---------------|

## Source Code
Source code is available on Github.

| Repository | Link |
|------------|------|
| Maintained fork | <img height="18" src="https://github.githubassets.com/favicons/favicon-dark.svg"></img> [MaikiOS/TerrainTools](https://github.com/MaikiOS/TerrainTools) |
| Original project | <img height="18" src="https://github.githubassets.com/favicons/favicon-dark.svg"></img> [searica/TerrainTools](https://github.com/searica/TerrainTools) |

### Contributions
Report compatibility-fork issues to the maintained fork, not to the original package author.

### Credits
This mod was inspired by and is based on OCDHeim by javadevils as well as HoeRadius by aedenthorn.

## Shameless Self Plug (Other Mods By Me)
If you like this mod you might like some of my other ones.

#### Building Mods
- [More Vanilla Build Prefabs](https://thunderstore.io/c/valheim/p/Searica/More_Vanilla_Build_Prefabs/)
- [Extra Snap Points Made Easy](https://thunderstore.io/c/valheim/p/Searica/Extra_Snap_Points_Made_Easy/)
- [BuildRestrictionTweaksSync](https://thunderstore.io/c/valheim/p/Searica/BuildRestrictionTweaksSync/)
- [ToolTweaks](https://thunderstore.io/c/valheim/p/Searica/ToolTweaks/)

#### Gameplay Mods
- [CameraTweaks](https://thunderstore.io/c/valheim/p/Searica/CameraTweaks/)
- [DodgeShortcut](https://thunderstore.io/c/valheim/p/Searica/DodgeShortcut/)
- [FortifySkillsRedux](https://thunderstore.io/c/valheim/p/Searica/FortifySkillsRedux/)
- [ProjectileTweaks](https://thunderstore.io/c/valheim/p/Searica/ProjectileTweaks/)
- [SkilledCarryWeight](https://thunderstore.io/c/valheim/p/Searica/SkilledCarryWeight/)
- [SafetyStatus](https://thunderstore.io/c/valheim/p/Searica/SafetyStatus/)

