Sprite Kitchen - Combat Essentials | v0.1

8 one-shot effects. 73 frames total, including one transparent final frame per clip.
Native frame cells: 64 x 64 pixels. Playback: 24 frames per second.

Included: Crescent Slash (8 frames), Cross Slash (10), Hit Spark (7),
Dash Dust (9), Landing Dust (9), Fire Impact (10), Electric Impact (10), Arcane Burst (10).

Import spritesheets as horizontal strips with 64x64 cells and no spacing.
Frame counts are in filenames. Use nearest-neighbor / Point filtering.
Read metadata/*.json or manifest.json for each effect's pixel origin.
Origins are measured from the top-left of each cell.
Animations play once. Remove the effect instance when playback finishes.
The final transparent frame ensures the effect clears cleanly.

spritesheets/ : transparent native PNG strips for game engines
frames/       : separate transparent PNG frames, numbered from 00
metadata/     : frame rectangles, timing and origin data
previews/     : enlarged checkerboard GIFs for viewing only
manifest.json : pack contents and per-effect specifications

Preview GIFs repeat after a short pause; the native game clips do not loop.
No engine project files are included. Import has not been tested in a game engine.

Creation: AI-assisted design recipes and documentation; procedural rendering
through PixelLab's MCP VFX Workbench. No image-generation model was used.

LICENSE
You may use these assets in personal and commercial game projects.
Modification is allowed. Credit is appreciated but optional.
Standalone asset-pack redistribution or resale is not allowed.
Do not use the assets to train AI models. See LICENSE.txt for the full terms.
