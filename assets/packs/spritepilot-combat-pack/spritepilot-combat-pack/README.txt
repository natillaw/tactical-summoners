SpritePilot Combat Pack — 9 animated pixel-art assets
https://spritepilot.com/free-game-assets

Slashes, claw rakes, gunfire, lasers, arrows, parries, shockwaves, crits and ground slams — the effects that make hits feel good.

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
  combat-pack.json   the frame size, frame count and speed of every file

  Sword slash      7 frames  18 fps  plays once  sword-slash-16px_strip7.png, sword-slash-32px_strip7.png
  Claw slash       8 frames  18 fps  plays once  claw-slash-16px_strip8.png, claw-slash-32px_strip8.png
  Muzzle flash     5 frames  20 fps  plays once  muzzle-flash-16px_strip5.png, muzzle-flash-32px_strip5.png
  Laser bolt       6 frames  14 fps  loops       laser-bolt-16px_strip6.png, laser-bolt-32px_strip6.png
  Arrow            4 frames  12 fps  loops       arrow-16px_strip4.png, arrow-32px_strip4.png
  Parry flash      7 frames  18 fps  plays once  parry-flash-16px_strip7.png, parry-flash-32px_strip7.png
  Shockwave        8 frames  15 fps  plays once  shockwave-16px_strip8.png, shockwave-32px_strip8.png
  Critical hit     8 frames  15 fps  plays once  critical-hit-16px_strip8.png, critical-hit-32px_strip8.png
  Ground slam      9 frames  14 fps  plays once  ground-slam-16px_strip9.png, ground-slam-32px_strip9.png

The speeds are what each one was timed for; change them to taste.
Pixels are either fully opaque or fully transparent, so the art stays crisp
and never picks up dark fringes from blending.

USING A STRIP
The file name says how to slice it: sword-slash-32px_strip7.png is 7 frames
of 32 x 32 pixels in one row. GameMaker reads the "_strip7" by itself.
  Godot 4   AnimatedSprite2D > SpriteFrames > Add Frames from Sprite Sheet,
            Horizontal = the frame count, Vertical = 1.
  Unity     Sprite Mode Multiple, Filter Mode Point (no filter), Compression
            None; Sprite Editor > Slice > Grid By Cell Size, 32 x 32.
  Phaser    this.load.spritesheet('sword-slash', 'sword-slash-32px_strip7.png',
              { frameWidth: 32, frameHeight: 32 })
  Anywhere  use nearest-neighbor ("point") filtering and scale by whole
            numbers (2x, 3x, 4x) so the pixels stay sharp.

Step-by-step guides:
  https://spritepilot.com/blog/godot-4-sprite-animation
  https://spritepilot.com/blog/unity-sprite-sheet-animation
  https://spritepilot.com/blog/phaser-sprite-sheets-and-atlases
Preview, re-time or convert any strip in your browser:
  https://spritepilot.com/sprite-player
