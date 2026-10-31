SpritePilot Magic & Projectiles Pack — 9 animated pixel-art assets
https://spritepilot.com/free-game-assets

Fireballs, ice shards, plasma orbs, lightning, poison, heals, shields, portals and teleports — spells and things that fly.

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
  magic-pack.json    the frame size, frame count and speed of every file

  Fireball         8 frames  12 fps  loops       fireball-16px_strip8.png, fireball-32px_strip8.png
  Ice shard        8 frames  12 fps  loops       ice-shard-16px_strip8.png, ice-shard-32px_strip8.png
  Energy orb       8 frames  12 fps  loops       energy-orb-16px_strip8.png, energy-orb-32px_strip8.png
  Lightning strike  8 frames  15 fps  plays once  lightning-strike-16px_strip8.png, lightning-strike-32px_strip8.png
  Poison cloud     8 frames   8 fps  loops       poison-cloud-16px_strip8.png, poison-cloud-32px_strip8.png
  Healing aura     8 frames  10 fps  loops       healing-aura-16px_strip8.png, healing-aura-32px_strip8.png
  Shield bubble   12 frames  12 fps  loops       shield-bubble-16px_strip12.png, shield-bubble-32px_strip12.png
  Portal           8 frames  10 fps  loops       portal-16px_strip8.png, portal-32px_strip8.png
  Teleport        12 frames  15 fps  plays once  teleport-16px_strip12.png, teleport-32px_strip12.png

The speeds are what each one was timed for; change them to taste.
Pixels are either fully opaque or fully transparent, so the art stays crisp
and never picks up dark fringes from blending.

USING A STRIP
The file name says how to slice it: fireball-32px_strip8.png is 8 frames
of 32 x 32 pixels in one row. GameMaker reads the "_strip8" by itself.
  Godot 4   AnimatedSprite2D > SpriteFrames > Add Frames from Sprite Sheet,
            Horizontal = the frame count, Vertical = 1.
  Unity     Sprite Mode Multiple, Filter Mode Point (no filter), Compression
            None; Sprite Editor > Slice > Grid By Cell Size, 32 x 32.
  Phaser    this.load.spritesheet('fireball', 'fireball-32px_strip8.png',
              { frameWidth: 32, frameHeight: 32 })
  Anywhere  use nearest-neighbor ("point") filtering and scale by whole
            numbers (2x, 3x, 4x) so the pixels stay sharp.

Step-by-step guides:
  https://spritepilot.com/blog/godot-4-sprite-animation
  https://spritepilot.com/blog/unity-sprite-sheet-animation
  https://spritepilot.com/blog/phaser-sprite-sheets-and-atlases
Preview, re-time or convert any strip in your browser:
  https://spritepilot.com/sprite-player
