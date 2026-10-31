# A. Ítems y loot pisos 1–10
IDs snake_case estables; nombre/desc aparte. Prefijos: cur_ moneda (fuera de inventario), mat_ material, key_ progresión, con_ consumible.
Tiers: T1 p1–4 gris · T2 p5–9 azul · T3 p10 morado (fragmento legendario dorado).
Cada piso: material propio tasa alta + el del piso anterior tasa baja. key_ de p5/p10 solo de miniboss/jefe.
Todos los enemigos: cur_gold 5–15×piso; cur_mana_shard 8% (1). Cofre de misión siempre da algo.

piso | propio | secundario | cofre | miniboss/jefe
1 | wild_herb 40% | – | 3–5 herb + 50 oro | –
2 | old_bone 35%, worn_leather 25% | wild_herb 10% | 3 bone + 2 leather | –
3 | copper_ore 35% | old_bone 10% | 4 copper | –
4 | weak_essence 30% | copper_ore 10% | 2 essence + 1 mana_shard | –
5 | enchanted_cloth 25% | weak_essence 10% | 3 cloth + 2 shard | key_guardian_core 100% 1–2; key_floor5_seal 100% solo 1er clear
6 | iron_ore 30% | copper_ore 10% | 4 iron | –
7 | resonant_crystal 20% | iron_ore 10% | 2 crystal | –
8 | moon_flower 25% | resonant_crystal 5% | 3 flower | –
9 | rune_plate 15% | moon_flower 10% | 2 plate + 3 shard | –
10 | – | rune_plate 10% | 5 shard + 300 oro | key_guardian_heart 100% 1; key_legendary_fragment 2% (10% 1er clear)
(mat_ omitido en la tabla)

id | tier | stack | venta | uso
cur_gold | – | ∞ | – | construcción, forja, promoción
cur_mana_shard | – | ∞ | – | 10 = 1 invocación
mat_wild_herb | T1 | 99 | 2 | Poción Menor; recolección offline
mat_old_bone | T1 | 99 | 3 | edificios 1→2
mat_worn_leather | T1 | 99 | 3 | armadura ligera T1
mat_copper_ore | T1 | 99 | 4 | armas T1; edificios 2
mat_weak_essence | T1 | 99 | 5 | +100 XP; la devuelve el sacrificio
mat_enchanted_cloth | T2 | 99 | 10 | accesorios
mat_iron_ore | T2 | 99 | 8 | equipo T2; edificios 2→3
mat_resonant_crystal | T2 | 50 | 25 | síntesis; encantar
mat_moon_flower | T2 | 99 | 12 | Poción Mayor
mat_rune_plate | T2 | 50 | 30 | mejoras de portal
key_guardian_core | T2 | 20 | no | promo 1★→2★
key_floor5_seal | T2 | 1 | no | atajo portal p5 (no se consume)
key_guardian_heart | T3 | 10 | no | promo 2★→3★ o arma épica
key_legendary_fragment | T3 | 10 | no | 10 = invocación Raro+
con_potion_minor | T1 | 20 | 8 | cura 30% a 1
con_potion_major | T2 | 20 | 30 | cura 60% a 1 o 25% party

## Recetas (estación: inputs + oro → salida)
invocación: 10 mana_shard → héroe (sin repetidos) · 10 legendary_fragment → héroe Raro+
alquimia: 3 herb +10 → potion_minor · 2 moon_flower + 1 potion_minor +40 → potion_major
forja: 5 leather + 2 copper +50 → armadura T1 · 6 copper + 2 bone +60 → arma T1 · 4 cloth + 1 essence +80 → accesorio · 8 iron + pieza T1 +150 → pieza T2 · 2 crystal +100 → +1 pasiva · 1 heart + 10 iron + 3 plate +500 → arma épica
héroes: essence +100 XP · promo 1→2★: nivel máx + 3 core +200 · promo 2→3★: nivel máx + 1 heart +600 · síntesis: 2 héroes igual rareza + 3 crystal → rareza+1 · sacrificio → esencias + shards
construcción: 1→2: 10 bone + 8 copper +300 · 2→3: 15 iron + 2 plate +800
portal: 3 plate +500 → slot extra / reintento diario / +1 carga expedición

## Datos
Resources (adapta a lo existente): ItemData, LootEntry(item_id,chance,min,max,first_clear_only), FloorLootTable, RecipeData(station,inputs,gold,output,qty,building_level). Un script genera los .tres desde UNA tabla. LootService con RNG con semilla por piso. Inventario {id: qty}; cur_ aparte. Mapea a IDs existentes antes de crear nuevos.
