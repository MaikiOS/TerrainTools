# AdvancedTerrainModifiers Compatible roadmap

**English** | [Русский](ROADMAP_RU.md)

**Document status:** September 13, 2026  
**Stable baseline:** 1.4.8 for Valheim 1.0, BepInExPack Valheim 5.4.2350 and Jotunn 2.30.0

This roadmap covers the maintained compatibility fork. It combines the original author's stated design interests, open upstream requests and experiments developed while restoring Valheim 1.0 compatibility. It is a direction, not a release promise. Experimental features stay outside the stable package until their preview, terrain effect and multiplayer behavior agree.

## Status key

- **Done** — shipped in the stable compatibility release.
- **Next** — scoped work suitable for the next stable cycle.
- **Research** — design or engine constraints are not resolved yet.
- **Experimental** — a prototype may exist, but it is not release-ready.
- **Contributor-friendly** — can be developed and reviewed independently.

## Stable baseline — completed in 1.4.8

- Valheim 1.0/Jotunn 2.30 compatibility and coexistence with EpicLoot without the old `Player.Update` transpiler conflict.
- Custom terrain-operation registration and synchronization when the installed Jotunn build does not register those operations itself.
- Square paint preview and paint execution use the same paint-mask bounds.
- Precise raising previews the height vertex that Valheim actually modifies and keeps its stable effect bounded to the intended footprint.
- Preview refresh runs after Valheim positions the placement ghost, fixing the known one-frame jitter/Tab race in the clean test profile.
- Terrain reset is limited to its dedicated tool and skips structures, protected areas and unrelated legacy modifiers.
- Embedded English/Russian defaults plus editable external translations in a mod-owned, collision-resistant path.
- Malformed custom terrain RPC values are rejected, and ownership changes are restricted to operations managed by this mod.

Small texture blending beyond the paint frame remains a Valheim paint-mask rendering limitation. It must not be described as a height-operation or networking defect.

## Next stable cycle

### 1. Close the remaining usability gaps

- **Remember radius and hardness per tool/mode** instead of resetting them whenever the player switches tools or modes. This follows [upstream request #6](https://github.com/searica/TerrainTools/issues/6). **Contributor-friendly.**
- **Audit area-based terrain restoration** against [upstream request #5](https://github.com/searica/TerrainTools/issues/5): document the current footprint, verify radius changes, protected-area checks and structure safety, then decide whether a separate circular/square selector is still needed.
- Keep the fixes corresponding to [hover information #7](https://github.com/searica/TerrainTools/issues/7), [precision-raise scrolling #8](https://github.com/searica/TerrainTools/issues/8) and [localization #3](https://github.com/searica/TerrainTools/issues/3) covered by regression checks.
- Add a configuration switch before changing the default preview style. Players who want vanilla-like information density must be able to keep it.

### 2. Make the preview contract explicit

Every terrain tool must use one shared set of calculated bounds for both the visible gizmo and the applied operation. A preview is correct only when it communicates:

- the area changed with full strength;
- the transition/falloff area;
- the target height or depth, when applicable;
- the fact that Valheim's fixed height grid can quantize an otherwise smooth shape.

The clean-profile checks must cover selecting a tool, opening/closing the build menu with Tab, changing radius/hardness/height, switching tools and returning to the same tool.

## New gizmo design

### Paint-only tools — Research

The preferred direction is a contour projected onto the actual terrain surface:

- gold inner contour: full-strength paint footprint;
- white outer contour: end of texture blending/falloff;
- optional height/depth indicator retained where it provides useful information;
- current flat/vanilla-like preview remains available through configuration or a hotkey.

Searica said a contour preview for paint tools was something they had wanted to implement. Community review also identified the tradeoff: surface projection is clearer for coverage, but a flat preview can communicate depth better. The design should support both rather than force one compromise on every tool.

### Height-changing tools — Research

The original author's proposed model is the starting point:

1. an outer contour conforms to the existing terrain and marks the absolute influence boundary;
2. an inner square stays flat at the target height and shows the final top footprint;
3. a transition contour expands between them to communicate the slope/falloff;
4. height adjustment remains relative to the fixed inner target surface.

This must be optional and must not reveal more global position information than the configured vanilla-like experience intends, especially for no-map play.

## Brush rotation and precise shape control

### Paint-only square rotation — Experimental

- Prototype smooth rotation with **Shift + mouse wheel**.
- Rotate preview and paint sampling from the same transform; visual-only rotation is not acceptable.
- Start with paint-only tools because paint-mask sampling can be rotated without changing Valheim's height mesh.
- Test zone borders, negative world coordinates, repeated overlapping strokes and reload persistence.

An isolated prototype branch exists, but rotation is intentionally absent from 1.4.8.

### Height-tool rotation — Research

Valheim's terrain height mesh is fixed and triangulated. Arbitrarily rotated height brushes can produce stair-stepped edges and cannot create a genuinely rotated vertex grid. An optional snapped/quantized mode may still be useful, but only if the preview shows the exact affected vertices and the operation remains bounded. This is not yet approved for a stable release.

### Precise raise: top footprint and slope — Research

- Keep a stable **4 m outer influence boundary**; terrain must not change beyond it.
- Scale the inner gold target footprint smoothly inside that boundary.
- Let the player control the transition from a near-vertical wall to a broad slope or point-like hill.
- Show the flat target top and the complete falloff before placement.
- Use one calculation for the preview, local execution and synchronized execution.

## Compatibility, multiplayer and quality gates

Every behavior-changing contribution must demonstrate:

- single-player and dedicated-server behavior;
- host/client agreement on bounds, height, paint and protected-area decisions;
- mixed-client behavior, with vanilla compatibility documented rather than assumed;
- ward/private-area and structure safety over the entire footprint, not only its center;
- save/reload persistence and zone-boundary behavior;
- clean-profile testing plus conflict testing with mods that patch placement or terrain tools;
- stable preview after Tab, tool switching and camera movement;
- no per-frame log spam, avoidable allocations or fragile hard-coded asset paths.

Code must remain understandable and maintainable without an AI tool. Do not submit decompiled Valheim source or other copyrighted game code. AI-assisted contributions receive the same review for security, networking, licensing and maintainability as any other code.

## Localization direction

The implemented model matches the original author's preference:

- embedded translations provide reliable defaults;
- external files can override them for testing, corrections and custom piece names;
- language-specific subdirectories and the TerrainTools-owned path protect against mod-manager directory flattening and filename collisions.

Future languages are **contributor-friendly**. English and Russian key parity must remain intact, and a new language should cover the complete current key set.

## Suggested contributor tasks

Good independent starting points:

1. implement and test per-tool radius/hardness memory;
2. add automated localization key-parity validation;
3. write a reproducible clean-profile checklist for preview and multiplayer tests;
4. prototype the optional projected paint contour without changing terrain execution;
5. investigate a zero-allocation shared transform for rotated paint preview and sampling;
6. document compatibility results for ToolTweaks, ValheimPlus, FastTools and Valheim Community Patch.

Please open an issue in the [maintained fork](https://github.com/MaikiOS/TerrainTools/issues) before starting a large change. Describe the player-facing behavior, engine constraints, test plan and whether the work belongs in the stable or experimental track. Alternative designs are welcome.

## Attribution and decision ownership

TerrainTools and AdvancedTerrainModifiers were created by Searica. The points attributed above to the original author summarize their public issue replies and community review; they are design input, not an obligation or release commitment. Ostrix maintains this compatibility fork, and upstream inclusion remains the original maintainer's decision through [pull request #9](https://github.com/searica/TerrainTools/pull/9).
