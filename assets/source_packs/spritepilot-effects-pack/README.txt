SpritePilot Effects Pack — 7 animated pixel-art assets
https://spritepilot.com/free-game-assets

Explosions, smoke, dust, sparks, fire, splashes and magic — the effects almost every 2D game needs.

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
  effects-pack.json  the frame size, frame count and speed of every file

  Explosion       10 frames  14 fps  plays once  explosion-16px_strip10.png, explosion-32px_strip10.png
  Smoke puff       8 frames  10 fps  plays once  smoke-puff-16px_strip8.png, smoke-puff-32px_strip8.png
  Landing dust     7 frames  12 fps  plays once  landing-dust-16px_strip7.png, landing-dust-32px_strip7.png
  Hit spark        6 frames  15 fps  plays once  hit-spark-16px_strip6.png, hit-spark-32px_strip6.png
  Fire             8 frames  10 fps  loops       fire-16px_strip8.png, fire-32px_strip8.png
  Water splash     9 frames  14 fps  plays once  water-splash-16px_strip9.png, water-splash-32px_strip9.png
  Magic sparkle    8 frames  10 fps  loops       magic-sparkle-16px_strip8.png, magic-sparkle-32px_strip8.png

The speeds are what each one was timed for; change them to taste.
Pixels are either fully opaque or fully transparent, so the art stays crisp
and never picks up dark fringes from blending.

USING A STRIP
The file name says how to slice it: explosion-32px_strip10.png is 10 frames
of 32 x 32 pixels in one row. GameMaker reads the "_strip10" by itself.
  Godot 4   AnimatedSprite2D > SpriteFrames > Add Frames from Sprite Sheet,
            Horizontal = the frame count, Vertical = 1.
  Unity     Sprite Mode Multiple, Filter Mode Point (no filter), Compression
            None; Sprite Editor > Slice > Grid By Cell Size, 32 x 32.
  Phaser    this.load.spritesheet('explosion', 'explosion-32px_strip10.png',
              { frameWidth: 32, frameHeight: 32 })
  Anywhere  use nearest-neighbor ("point") filtering and scale by whole
            numbers (2x, 3x, 4x) so the pixels stay sharp.

Step-by-step guides:
  https://spritepilot.com/blog/godot-4-sprite-animation
  https://spritepilot.com/blog/unity-sprite-sheet-animation
  https://spritepilot.com/blog/phaser-sprite-sheets-and-atlases
Preview, re-time or convert any strip in your browser:
  https://spritepilot.com/sprite-player
