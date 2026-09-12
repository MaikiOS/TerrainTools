<table>
	<tbody>
		<tr>
			<th align="center">Version</th>
			<th align="center">Notes</th>
		</tr>
		<tr>
			<td align="center">1.4.5</td>
			<td align="left">
				<ul>
					<li>Unified square paint writes and previews around one paint-mask bounds calculation.</li>
					<li>Aligned the preview with Valheim's rendered 65x65 mask spacing and included its bilinear transition area.</li>
					<li>Added a translucent outer frame to distinguish the texture-filtering feather from the paint core.</li>
					<li>Used the proven paint-mask preview for level and raise tools so their frames match the visible square.</li>
					<li>Matched the base and target footprints for precise raising, centered them on the height vertex actually modified by Valheim, and added the shared paint preview to square vegetation restoration.</li>
					<li>Fixed precision operations reporting a zero effective radius after applying their sentinel.</li>
				</ul>
			</td>
		</tr>
		<tr>
			<td align="center">1.4.4</td>
			<td align="left">
				<ul>
					<li>Preserved runtime TerrainOp settings across Valheim 1.0 RPC serialization, fixing precise height, radius, hardness, and square paint results.</li>
					<li>Restored custom TerrainOp registration after leaving and re-entering a world.</li>
					<li>Aligned square paint previews to Valheim's interpolated paint-mask grid and documented the engine-level texture-edge limitation.</li>
					<li>Restored terrain across Heightmap borders and legacy TerrainModifiers, added Alt + wheel restoration radius control, and scaled the frame and center marker together.</li>
					<li>Prevented camera zoom while adjusting terrain tools and increased the default hardness scroll speed.</li>
					<li>Added a conditional custom TerrainOp registration fallback for unpatched Jotunn builds; it is a no-op when Jotunn already registered the prefab.</li>
					<li>Fixed the shared overlay state that broke square-tool hover information and precision height scrolling.</li>
					<li>Added editable English and Russian gameplay translations.</li>
					<li>Fixed config hot reload lifetime/error recovery, embedded icon loading, shovel creation guards, and clamped radius/hardness scroll accumulation.</li>
					<li>Updated the build and package dependency to Jotunn 2.30.0 for Valheim 1.0.</li>
				</ul>
			</td>
		</tr>
		<tr>
			<td align="center">1.4.3</td>
			<td align="left">
				<ul>
					<li>Updated terrain-paint and player-message calls for the Valheim 1.0 API.</li>
					<li>Fixed the invalid internal name of the square paved-road prefab.</li>
				</ul>
			</td>
		</tr>
		<tr>
			<td align="center">1.4.2</td>
			<td align="left">
				<ul>
					<li>Compatibility fork: moved radius and hardness input polling from Harmony patches on Player.Update to the plugin's own Unity Update method.</li>
					<li>Fixes the startup hang seen when loading after EpicLoot 0.13.x.</li>
				</ul>
			</td>
		</tr>
		<tr>
			<td align="center">1.4.1</td>
			<td align="left">
				<ul>
					<li>Updated to Jotunn 2.22.0 and restored pre Bog Witch config syncing behaviour so configs are only synced if the mod is installed on the server.</li>
				</ul>
			</td>
		</tr>
		<tr>
			<td align="center">1.4.0</td>
			<td align="left">
				<ul>
					<li>Quick update to get things working with the Bog Witch update. Game breaking bugs are fixed but still need to do more testing to check for any new edge cases.</li>
				</ul>
			</td>
		</tr>
		<tr>
			<td align="center">1.3.3</td>
			<td align="left">
				<ul>
					<li>Minor bugfix for changing config while in-game. Warning should no longer be triggered and piece ordering should remain correct.</li>
					<li>Updated Jotunn.</li>
				</ul>
			</td>
		</tr>
		<tr>
			<td align="center">1.3.2</td>
			<td align="left">
				<ul>
					<li>Bugfix for another issue with lava in Ashlands when using precision terrain tools.</li>
					<li>I swear stuff related to lava is fixed now and if it isn't I'll have to figure out why.</li>
				</ul>
			</td>
		</tr>
		<tr>
			<td align="center">1.3.1</td>
			<td align="left">
				<ul>
					<li>Bugfix for issues with lava in Ashlands when using precision raise ground.</li>
				</ul>
			</td>
		</tr>
		<tr>
			<td align="center">1.3.0</td>
			<td align="left">
				<ul>
					<li>Updated for Ashlands release.</li>
					<li>Note: Ashlands has some bugs with terrain paint (grass, dirt, etc) which cause visual errors.</li>
					<li>Note: This version loads without errors but may have some issues given the bugs in Vanilla terrain right now, except fixes once Vanilla is patched.</li>
				</ul>
			</td>
		</tr>
		<tr>
			<td align="center">1.2.6</td>
			<td align="left">
				<ul>
					<li>Fixed bug where disabling specific terrain modifiers would not update correctly.</li>
				</ul>
			</td>
		</tr>
		<tr>
			<td align="center">1.2.5</td>
			<td align="left">
				<ul>
					<li>Changed how embedded textures are loaded to prevent errors on Linux systems that do not have optional dependencies for the .Net framework.</li>
				</ul>
			</td>
		</tr>
		<tr>
			<td align="center">1.2.4</td>
			<td align="left">
				<ul>
					<li>Fixed bug that could cause NRE when swapping between Hoe and Hammer pieces.</li>
					<li>Updated Jotunn.</li>
					<li>Minor performance improvement.</li>
				</ul>
			</td>
		</tr>
		<tr>
			<td align="center">1.2.3</td>
			<td align="left">
				<ul>
					<li>Square terrain tools now automatically snap to the world grid.</li>
					<li>Bugfix for visual artifact that caused placement ghosts to persist after placement when placed on zone borders.</li>
				</ul>
			</td>
		</tr>
		<tr>
			<td align="center">1.2.2</td>
			<td align="left">
				<ul>
					<li>Change hotkeys to not be synced with server.</li>
				</ul>
			</td>
		</tr>
		<tr>
			<td align="center">1.2.1</td>
			<td align="left">
				<ul>
					<li>Minor performance optimizations.</li>
					<li>Fixed bug where radius couldn't be changed under specific conditions in multiplayer.</li>
					<li>Fixed bug where hardness scroll rate was being ignored.</li>
					<li>Hopefully fixed bug where the reset terrain tool would sometimes not work in multiplayer if not all players had the mod.</li>
				</ul>
			</td>
		</tr>
		<tr>
			<td align="center">1.2.0</td>
			<td align="left">
				<b>Update Info</b>
				<ul>
					<li>Changed configuration file format to handle the new tool. <b>You need to regenerate your config file.</b></li>
					<li>Updated README with visual examples to better explain "Hardness".</li>
				</ul>
				<b>Features</b>
				<ul>
					<li>Added a new tool that lets you lower the ground. You'll need to delve into some crypts and find some metal to make it though.</li>
					<li>Changed hardness to display as a percentage and state whether the hardness is being changed for smoothing or for raising ground.</li>
					<li>Updated all tool descriptions to explain how to smooth terrain instead of leveling it (this is actually a Vanilla feature but the game never tells you it exists).</li>
				</ul>
				<b>Bug Fixes</b>
				<ul>
					<li>Fixed bug where the radius of the pathen tool would not visually update even though it was changed.</li>
					<li>Fixed bug where radius of raise ground would visually reset after placing it.</li>
				</ul>
			</td>
		</tr>
		<tr>
			<td align="center">1.1.0</td>
			<td align="left">
				<ul>
					<li>Added feature that to allow changing tool hardness. See README for details.</li>
					<li>Icons used in the mod are now embedded in the dll</li>
					<li>Changed hover info on square terrain tools to use the same x,y,z convention as unity where y = height.</li>
					<li>Precision raise ground tool now displays both the change in height and the world coordinates.</li>
					<li>Sharpened image in mod icon.</li>
					<li>Updated README</li>
				</ul>
			</td>
		</tr>
		<tr>
			<td align="center">1.0.0-1.0.2</td>
			<td align="left">
				<ul>
					<li>Initial release.</li>
					<li>Fix image links to github in README.</li>
					<li>Fix manifest description.</li>
					<li>Really wish Thunderstore let me edit typos without uploading a new version.</li>
				</ul>
			</td>
		</tr>
	</tbody>
</table>
