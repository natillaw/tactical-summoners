Voxel Dungeon Pack - full
108 sprites, 482 animation strips, 3197 frames; 283 distinct environment tiles (709 images including liquid animation frames).
License: CC0 1.0 (see LICENSE.txt). Credit is welcome but not required.

loot/ creatures/ props/ fx/ items/: sheets/ = one row of frames per animation, frames/ = single frames,
gifs/ = 4x previews, atlas.png + atlas.json = the whole set in one texture with frame rects.
Animations have their own frame counts: read frameCount from atlas.json.
Creatures come in three facings: down (toward the viewer), up (away), side (facing right;
mirror for left). Files are named <asset>_<facing>_<animation>.

ui/: a UI kit (nine-slice panels, buttons, bars, slots, icons, cursors): elements/*.png, ui.png + ui.json.

environment/: 32x32 tiles, tileset.png + tileset.json, environment.tsx (Tiled: wang sets, liquid
animations), environment.tres (Godot 4 TileSet: terrains + animated liquids), autotile.json (the
47-tile blob rule as plain data) and sample.tmx (a room built from the rule).
Place water, lava and pits on a layer above the floor: surroundings are transparent.
Water v1-v3 are quiet alternatives to the bright base tile; use variants to reduce repeats.

Made from voxel model programs rendered by a small software renderer. The code was written
with AI coding agents. No image-generation model and no third-party art were used.

chest: open(8), spin(8)
barrel: spin(8)
torch: flicker(8), spin(8)
candle: flicker(8), spin(8)
lantern: flicker(8), spin(8)
crystal: glint(8), spin(8)
potion: float(8), glint(8)
sword: float(8), spin(8)
axe: float(8), spin(8)
key: float(8), spin(8)
shield: spin(8)
anvil: spin(8)
bucket: spin(8)
mage: idle(6), walk(6), cast(8), hurt(3), death(8) [side/down/up]
mage_frost: idle(6), walk(6), cast(8), hurt(3), death(8) [side/down/up]
orc: idle(6), walk(8), attack(8), hurt(3), death(8) [side/down/up]
orc_chieftain: idle(6), walk(8), attack(8), hurt(3), death(8) [side/down/up]
scorpion: idle(4), walk(6), attack(6), hurt(3), death(8) [side/down/up]
scorpion_red: idle(4), walk(6), attack(6), hurt(3), death(8) [side/down/up]
mimic: idle(4), hop(6), bite(6), hurt(3), death(8) [side/down/up]
mimic_gold: idle(4), hop(6), bite(6), hurt(3), death(8) [side/down/up]
golem: idle(6), walk(8), slam(10), hurt(3), death(12) [side/down/up]
golem_magma: idle(6), walk(8), slam(10), hurt(3), death(12) [side/down/up]
knight: idle(8), walk(8), attack(8), hurt(8), death(8) [side/down/up]
dark_knight: idle(8), walk(8), attack(8), hurt(8), death(8) [side/down/up]
skeleton: idle(8), walk(8), attack(8), hurt(8), death(8) [side/down/up]
goblin: idle(8), walk(8), attack(8), hurt(8), death(8) [side/down/up]
hobgoblin: idle(8), walk(8), attack(8), hurt(8), death(8) [side/down/up]
bat: fly(8), attack(8), hurt(8), death(8) [side/down/up]
ghost: idle(8), attack(8), hurt(8), death(8) [side/down/up]
rat: idle(8), walk(8), attack(8), hurt(8), death(8) [side/down/up]
spider: idle(4), walk(6), attack(6), hurt(3), death(8) [side/down/up]
eye: idle(8), attack(8), hurt(8), death(8) [side/down/up]
trex: idle(8), roar(8) [side/down/up]
slime_green: hop(8), idle(8), attack(8), hurt(8), death(8) [side/down/up]
slime_blue: hop(8), idle(8), attack(8), hurt(8), death(8) [side/down/up]
slime_red: hop(8), idle(8), attack(8), hurt(8), death(8) [side/down/up]
slime_purple: hop(8), idle(8), attack(8), hurt(8), death(8) [side/down/up]
mushroom_red: idle(8), hop(8), hurt(8), death(8) [side/down/up]
mushroom_blue: idle(8), hop(8), hurt(8), death(8) [side/down/up]
mushroom_purple: idle(8), hop(8), hurt(8), death(8) [side/down/up]
crate: still(1)
table: still(1)
bookshelf: still(1)
banner: still(1)
bones: still(1)
rubble: still(1)
pillar: still(1)
weaponrack: still(1)
altar: pulse(4)
brazier: flicker(6)
door_wood: open(6)
door_iron: open(6)
portcullis: raise(6)
barrel_deco: still(1)
shield_deco: still(1)
bucket_deco: still(1)
chest_deco: still(1)
crystal_deco: still(1)
torch_deco: flicker(6)
hit_spark: play(5)
venom_spit: play(4)
fireball: play(4)
explosion: play(7)
frost_shard: play(4)
lightning: play(4)
heal: play(8)
arrow: play(2)
dust_puff: play(6)
smoke: play(6)
slash: play(4)
magic_circle: play(8)
sparkle: play(6)
poison_cloud: play(6)
shield_bubble: play(6)
teleport: play(8)
level_up: play(8)
dagger: icon(1)
mace: icon(1)
bow: icon(1)
staff: icon(1)
staff_fire: icon(1)
spear: icon(1)
warhammer: icon(1)
helmet: icon(1)
chestplate: icon(1)
boots: icon(1)
ring_ruby: icon(1)
ring_silver: icon(1)
amulet_emerald: icon(1)
amulet_ruby: icon(1)
scroll: icon(1)
book_purple: icon(1)
book_red: icon(1)
book_blue: icon(1)
coin: icon(1)
coin_stack: icon(1)
gem_ruby: icon(1)
gem_emerald: icon(1)
gem_sapphire: icon(1)
potion_red: icon(1)
potion_blue: icon(1)
potion_green: icon(1)
potion_yellow: icon(1)
bread: icon(1)
meat: icon(1)
apple_red: icon(1)
apple_green: icon(1)
