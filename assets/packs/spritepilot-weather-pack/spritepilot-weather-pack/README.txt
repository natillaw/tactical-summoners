SpritePilot Weather & Ambient Pack — 9 animated pixel-art assets
https://spritepilot.com/free-game-assets

Rain, snow, lightning, falling leaves, wind, clouds, fireflies and bubbles — overlays and ambient details that set the mood.

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
  weather-pack.json  the frame size, frame count and speed of every file

  Rain            16 frames  16 fps  tiles       rain-16px_strip16.png, rain-32px_strip16.png
  Rain splash      8 frames  14 fps  plays once  rain-splash-16px_strip8.png, rain-splash-32px_strip8.png
  Lightning strike  9 frames  15 fps  plays once  lightning-16px_strip9.png, lightning-32px_strip9.png
  Snow            16 frames  10 fps  tiles       snow-16px_strip16.png, snow-32px_strip16.png
  Falling leaves  16 frames  10 fps  tiles       falling-leaves-16px_strip16.png, falling-leaves-32px_strip16.png
  Drifting cloud  12 frames   6 fps  loops       cloud-16px_strip12.png, cloud-32px_strip12.png
  Wind gust       12 frames  12 fps  loops       wind-gust-16px_strip12.png, wind-gust-32px_strip12.png
  Fireflies       16 frames  10 fps  loops       fireflies-16px_strip16.png, fireflies-32px_strip16.png
  Bubbles         16 frames  10 fps  tiles       bubbles-16px_strip16.png, bubbles-32px_strip16.png

The speeds are what each one was timed for; change them to taste.
Items marked "tiles" repeat seamlessly in every direction, on every frame.
Pixels are either fully opaque or fully transparent, so the art stays crisp
and never picks up dark fringes from blending.

USING A STRIP
The file name says how to slice it: rain-32px_strip16.png is 16 frames
of 32 x 32 pixels in one row. GameMaker reads the "_strip16" by itself.
  Godot 4   AnimatedSprite2D > SpriteFrames > Add Frames from Sprite Sheet,
            Horizontal = the frame count, Vertical = 1.
  Unity     Sprite Mode Multiple, Filter Mode Point (no filter), Compression
            None; Sprite Editor > Slice > Grid By Cell Size, 32 x 32.
  Phaser    this.load.spritesheet('rain', 'rain-32px_strip16.png',
              { frameWidth: 32, frameHeight: 32 })
  Anywhere  use nearest-neighbor ("point") filtering and scale by whole
            numbers (2x, 3x, 4x) so the pixels stay sharp.

Step-by-step guides:
  https://spritepilot.com/blog/godot-4-sprite-animation
  https://spritepilot.com/blog/unity-sprite-sheet-animation
  https://spritepilot.com/blog/phaser-sprite-sheets-and-atlases
Preview, re-time or convert any strip in your browser:
  https://spritepilot.com/sprite-player
