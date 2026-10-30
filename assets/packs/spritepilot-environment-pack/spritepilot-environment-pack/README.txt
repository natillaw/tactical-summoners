SpritePilot Environment Pack — 9 animated pixel-art assets
https://spritepilot.com/free-game-assets

Animated water, lava and waterfall tiles plus torches, banners, doors, traps, crumbling blocks and grass that bring a level to life.

LICENSE
CC0 1.0 (public domain): use these in any project, commercial or not,
change them and share them. No credit needed (a link to spritepilot.com is
always appreciated). See LICENSE.txt.

HOW THEY WERE MADE
Drawn pixel by pixel by code written for SpritePilot. Not AI-generated, and
not traced or adapted from anyone else's art.

WHAT'S INSIDE
  16px/ and 32px/    one PNG per asset: the frames side by side, left to right
  previews/          an animated GIF of each one at 4x size, plus a still PNG
  environment-pack.json the frame size, frame count and speed of every file

  Water            8 frames   8 fps  tiles       water-16px_strip8.png, water-32px_strip8.png
  Lava            12 frames   8 fps  tiles       lava-16px_strip12.png, lava-32px_strip12.png
  Waterfall       16 frames  16 fps  tiles       waterfall-16px_strip16.png, waterfall-32px_strip16.png
  Wall torch       8 frames  10 fps  loops       wall-torch-16px_strip8.png, wall-torch-32px_strip8.png
  Banner           8 frames  10 fps  loops       banner-16px_strip8.png, banner-32px_strip8.png
  Door             9 frames  12 fps  plays once  door-16px_strip9.png, door-32px_strip9.png
  Spike trap       8 frames  14 fps  plays once  spike-trap-16px_strip8.png, spike-trap-32px_strip8.png
  Crumbling block 10 frames  12 fps  plays once  crumbling-block-16px_strip10.png, crumbling-block-32px_strip10.png
  Tall grass      12 frames  10 fps  loops       tall-grass-16px_strip12.png, tall-grass-32px_strip12.png

The speeds are what each one was timed for; change them to taste.
Items marked "tiles" repeat seamlessly in every direction, on every frame.
Pixels are either fully opaque or fully transparent, so the art stays crisp
and never picks up dark fringes from blending.

USING A STRIP
The file name says how to slice it: water-32px_strip8.png is 8 frames
of 32 x 32 pixels in one row. GameMaker reads the "_strip8" by itself.
  Godot 4   AnimatedSprite2D > SpriteFrames > Add Frames from Sprite Sheet,
            Horizontal = the frame count, Vertical = 1.
  Unity     Sprite Mode Multiple, Filter Mode Point (no filter), Compression
            None; Sprite Editor > Slice > Grid By Cell Size, 32 x 32.
  Phaser    this.load.spritesheet('water', 'water-32px_strip8.png',
              { frameWidth: 32, frameHeight: 32 })
  Anywhere  use nearest-neighbor ("point") filtering and scale by whole
            numbers (2x, 3x, 4x) so the pixels stay sharp.

Step-by-step guides:
  https://spritepilot.com/blog/godot-4-sprite-animation
  https://spritepilot.com/blog/unity-sprite-sheet-animation
  https://spritepilot.com/blog/phaser-sprite-sheets-and-atlases
Preview, re-time or convert any strip in your browser:
  https://spritepilot.com/sprite-player
