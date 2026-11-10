## Crafting — recetas de la herrería y el salón de alquimia. Gastan `Materials.inventory`.
## Armas y armadura se equipan al fabricarse si mejoran lo que llevas.
class_name Crafting
extends RefCounted

const RECIPES := [
	# Herrería: armas
	{"id": "espada_cobre", "station": "blacksmith", "name": "Espada de Cobre", "cost": {"mena_cobre": 4, "madera": 2}, "weapon": "sword"},
	{"id": "hacha_cobre", "station": "blacksmith", "name": "Hacha de Cobre", "cost": {"mena_cobre": 5, "madera": 2, "piedra": 2}, "weapon": "axe"},
	{"id": "maza_cobre", "station": "blacksmith", "name": "Maza de Cobre", "cost": {"mena_cobre": 4, "madera": 3, "piedra": 2}, "weapon": "mace"},
	{"id": "daga_cobre", "station": "blacksmith", "name": "Daga de Cobre", "cost": {"mena_cobre": 3, "cuero_basto": 1}, "weapon": "dagger"},
	{"id": "lanza_cobre", "station": "blacksmith", "name": "Lanza de Cobre", "cost": {"mena_cobre": 3, "madera": 4}, "weapon": "spear"},
	# Espadas con diseño propio (modelo editado de Quaternius; ver WeaponCatalog.CUSTOM)
	{"id": "espada_recluta", "station": "blacksmith", "name": "Espada de Recluta", "cost": {"mena_cobre": 3, "madera": 2}, "weapon": "sword", "model": "espada_recluta", "dps_mult": 0.95, "speed": 2.4},
	{"id": "espada_xifos", "station": "blacksmith", "name": "Xifos de Bronce", "cost": {"mena_cobre": 4, "madera": 1, "cuero_basto": 1}, "weapon": "sword", "model": "espada_xifos", "dps_mult": 1, "speed": 2.2},
	{"id": "espada_alfanje", "station": "blacksmith", "name": "Alfanje del Desierto", "cost": {"mena_cobre": 4, "cuero_basto": 2, "piedra": 1}, "weapon": "sword", "model": "espada_alfanje", "dps_mult": 1, "speed": 2.0, "stats": {"crit_chance": 0.01}},
	{"id": "espada_larga", "station": "blacksmith", "name": "Espada Larga de Acero", "cost": {"mena_cobre": 6, "madera": 2, "piedra": 2}, "weapon": "sword", "model": "espada_larga", "dps_mult": 1.1, "speed": 2.8},
	{"id": "espada_colmillo", "station": "blacksmith", "name": "Colmillo de Sangre", "cost": {"mena_cobre": 6, "hueso": 3, "polvo_arcano": 1, "cuero_basto": 2}, "weapon": "sword", "model": "espada_colmillo", "dps_mult": 1.15, "speed": 3.0, "stats": {"attack_power_bonus": 2}},
	# Herrería: armadura
	{"id": "yelmo_cobre", "station": "blacksmith", "name": "Yelmo de Cobre", "cost": {"mena_cobre": 3, "cuero_basto": 2}, "armor": "head", "stats": {"stamina": 3.0, "armor": 6.0}},
	{"id": "peto_cobre", "station": "blacksmith", "name": "Peto de Cobre", "cost": {"mena_cobre": 6, "cuero_basto": 3}, "armor": "chest", "stats": {"stamina": 5.0, "strength": 1.0, "armor": 12.0}},
	{"id": "grebas_cuero", "station": "leatherworker", "name": "Grebas de Cuero", "cost": {"cuero_basto": 3, "fibra": 3, "hueso": 1}, "armor": "legs", "stats": {"stamina": 3.0, "armor": 5.0}},
	{"id": "guantes_cuero", "station": "leatherworker", "name": "Guantes de Cuero", "cost": {"cuero_basto": 2, "fibra": 2}, "armor": "hands", "stats": {"strength": 1.0, "armor": 3.0, "attack_power_bonus": 2.0}},
	{"id": "botas_cuero", "station": "leatherworker", "name": "Botas de Cuero", "cost": {"cuero_basto": 2, "fibra": 2}, "armor": "boots", "stats": {"stamina": 2.0, "armor": 3.0, "crit_chance": 0.01}},
	# Peletería
	{"id": "casco_cuero", "station": "leatherworker", "name": "Casco de Cuero", "cost": {"cuero_basto": 3, "fibra": 1}, "armor": "head", "stats": {"stamina": 2.0, "armor": 4.0}},
	{"id": "jubon_cuero", "station": "leatherworker", "name": "Jubón de Cuero", "cost": {"cuero_basto": 5, "hueso": 1, "fibra": 2}, "armor": "chest", "stats": {"stamina": 4.0, "armor": 8.0, "attack_power_bonus": 2.0}},
	# Sastrería (tela ligera: menos armadura, más poder)
	{"id": "capucha_tela", "station": "tailor", "name": "Capucha de Tela", "cost": {"fibra": 4, "flor_silvestre": 1}, "armor": "head", "stats": {"stamina": 2.0, "armor": 2.0, "crit_chance": 0.01}},
	{"id": "tunica_tela", "station": "tailor", "name": "Túnica de Tela", "cost": {"fibra": 7, "flor_silvestre": 2, "polvo_arcano": 1}, "armor": "chest", "stats": {"stamina": 4.0, "armor": 4.0, "attack_power_bonus": 4.0}},
	{"id": "pantalon_tela", "station": "tailor", "name": "Pantalones de Tela", "cost": {"fibra": 5, "flor_silvestre": 1}, "armor": "legs", "stats": {"stamina": 3.0, "armor": 2.0, "attack_power_bonus": 2.0}},
	{"id": "guantes_tela", "station": "tailor", "name": "Guantes de Tela", "cost": {"fibra": 3, "hueso": 1}, "armor": "hands", "stats": {"stamina": 1.0, "armor": 1.0, "crit_chance": 0.01, "attack_power_bonus": 2.0}},
	{"id": "sandalias_tela", "station": "tailor", "name": "Sandalias de Tela", "cost": {"fibra": 3, "flor_silvestre": 1}, "armor": "boots", "stats": {"stamina": 2.0, "armor": 1.0, "crit_chance": 0.01}},
	# Carpintería
	{"id": "arco_corto", "station": "carpenter", "name": "Arco Corto", "cost": {"madera": 4, "fibra": 2}, "weapon": "bow"},
	{"id": "arco_largo", "station": "carpenter", "name": "Arco Largo", "cost": {"madera": 5, "fibra": 3, "cuero_basto": 1}, "weapon": "bow"},
	{"id": "baston_roble", "station": "carpenter", "name": "Bastón de Roble", "cost": {"madera": 4, "polvo_arcano": 1}, "weapon": "staff"},
	{"id": "garrote_madera", "station": "carpenter", "name": "Garrote Reforzado", "cost": {"madera": 5, "piedra": 2}, "weapon": "mace"},
	{"id": "lanza_madera", "station": "carpenter", "name": "Lanza de Madera", "cost": {"madera": 4, "piedra": 2}, "weapon": "spear"},
	# Sets de armadura de nivel bajo (visual: CharacterBuilder armor_<set>); ver ArmorSets.
	{"id": "footman_yelmo", "station": "blacksmith", "name": "Yelmo Nasal de Leva", "cost": {"mena_cobre": 3, "fibra": 2}, "armor": "head", "set": "footman", "stats": {"armor": 6.9, "stamina": 3.0}},
	{"id": "footman_peto", "station": "blacksmith", "name": "Cota de Leva", "cost": {"mena_cobre": 5, "fibra": 4, "cuero_basto": 2}, "armor": "chest", "set": "footman", "stats": {"armor": 13.8, "stamina": 6.0}},
	{"id": "footman_grebas", "station": "blacksmith", "name": "Calzas Acolchadas de Leva", "cost": {"mena_cobre": 2, "fibra": 3, "cuero_basto": 2}, "armor": "legs", "set": "footman", "stats": {"armor": 5.8, "stamina": 3.0}},
	{"id": "footman_guantes", "station": "blacksmith", "name": "Manoplas de Malla de Leva", "cost": {"mena_cobre": 2, "fibra": 2}, "armor": "hands", "set": "footman", "stats": {"armor": 3.5, "stamina": 1.0}},
	{"id": "footman_botas", "station": "blacksmith", "name": "Botas Ferradas de Leva", "cost": {"cuero_basto": 2, "fibra": 2, "mena_cobre": 1}, "armor": "boots", "set": "footman", "stats": {"armor": 3.5, "stamina": 2.0}},
	{"id": "knight_yelmo", "station": "blacksmith", "name": "Gran Yelmo de Escudero", "cost": {"mena_cobre": 5, "cuero_basto": 2}, "armor": "head", "set": "knight", "stats": {"armor": 7.8, "stamina": 3.2}},
	{"id": "knight_peto", "station": "blacksmith", "name": "Coraza de Escudero", "cost": {"mena_cobre": 9, "cuero_basto": 3, "piedra": 2}, "armor": "chest", "set": "knight", "stats": {"armor": 15.6, "stamina": 5.3}},
	{"id": "knight_grebas", "station": "blacksmith", "name": "Grebas de Escudero", "cost": {"mena_cobre": 5, "cuero_basto": 2}, "armor": "legs", "set": "knight", "stats": {"armor": 6.5, "stamina": 3.2}},
	{"id": "knight_guantes", "station": "blacksmith", "name": "Guanteletes de Escudero", "cost": {"mena_cobre": 3, "cuero_basto": 2}, "armor": "hands", "set": "knight", "stats": {"armor": 3.9, "stamina": 1.1}},
	{"id": "knight_botas", "station": "blacksmith", "name": "Escarpes de Escudero", "cost": {"mena_cobre": 3, "cuero_basto": 2}, "armor": "boots", "set": "knight", "stats": {"armor": 3.9, "stamina": 2.1}},
	{"id": "hoplite_yelmo", "station": "blacksmith", "name": "Casco Corintio de Bronce", "cost": {"mena_cobre": 4, "cuero_basto": 1}, "armor": "head", "set": "hoplite", "stats": {"armor": 6.0, "stamina": 3.0, "strength": 1.0}},
	{"id": "hoplite_peto", "station": "blacksmith", "name": "Coraza de Bronce", "cost": {"mena_cobre": 7, "cuero_basto": 2}, "armor": "chest", "set": "hoplite", "stats": {"armor": 12.0, "stamina": 5.0, "strength": 1.0}},
	{"id": "hoplite_grebas", "station": "blacksmith", "name": "Grebas de Bronce", "cost": {"mena_cobre": 4, "cuero_basto": 2}, "armor": "legs", "set": "hoplite", "stats": {"armor": 5.0, "stamina": 3.0}},
	{"id": "hoplite_guantes", "station": "blacksmith", "name": "Brazales de Bronce", "cost": {"mena_cobre": 2, "cuero_basto": 2}, "armor": "hands", "set": "hoplite", "stats": {"armor": 3.0, "stamina": 1.0}},
	{"id": "hoplite_botas", "station": "blacksmith", "name": "Sandalias Ferradas de Bronce", "cost": {"cuero_basto": 3, "mena_cobre": 1}, "armor": "boots", "set": "hoplite", "stats": {"armor": 3.0, "stamina": 2.0}},
	{"id": "norse_yelmo", "station": "blacksmith", "name": "Yelmo Astado del Norte", "cost": {"mena_cobre": 3, "hueso": 2, "cuero_basto": 1}, "armor": "head", "set": "norse", "stats": {"armor": 5.7, "stamina": 3.8}},
	{"id": "norse_peto", "station": "blacksmith", "name": "Cota de Escamas del Norte", "cost": {"mena_cobre": 5, "hueso": 2, "cuero_basto": 3}, "armor": "chest", "set": "norse", "stats": {"armor": 11.4, "stamina": 6.3, "strength": 1.0}},
	{"id": "norse_grebas", "station": "blacksmith", "name": "Pantalones Reforzados del Norte", "cost": {"cuero_basto": 3, "fibra": 2, "hueso": 1}, "armor": "legs", "set": "norse", "stats": {"armor": 4.8, "stamina": 3.8}},
	{"id": "norse_guantes", "station": "blacksmith", "name": "Brazales de Cuero del Norte", "cost": {"cuero_basto": 2, "hueso": 1}, "armor": "hands", "set": "norse", "stats": {"armor": 2.8, "stamina": 1.3}},
	{"id": "norse_botas", "station": "blacksmith", "name": "Botas de Piel del Norte", "cost": {"cuero_basto": 2, "hueso": 1, "fibra": 1}, "armor": "boots", "set": "norse", "stats": {"armor": 2.8, "stamina": 2.5, "crit_chance": 0.01}},
	{"id": "dark_yelmo", "station": "blacksmith", "name": "Yelmo Astado Ennegrecido", "cost": {"mena_cobre": 4, "hueso": 1}, "armor": "head", "set": "dark", "stats": {"armor": 4.8, "stamina": 2.7, "crit_chance": 0.01}},
	{"id": "dark_peto", "station": "blacksmith", "name": "Coraza de Púas Ennegrecida", "cost": {"mena_cobre": 7, "hueso": 2, "piedra": 1}, "armor": "chest", "set": "dark", "stats": {"armor": 9.6, "stamina": 4.5, "attack_power_bonus": 3.0, "strength": 1.0}},
	{"id": "dark_grebas", "station": "blacksmith", "name": "Grebas Ennegrecidas", "cost": {"mena_cobre": 4, "hueso": 1}, "armor": "legs", "set": "dark", "stats": {"armor": 4.0, "stamina": 2.7}},
	{"id": "dark_guantes", "station": "blacksmith", "name": "Guanteletes de Púas", "cost": {"mena_cobre": 2, "hueso": 1}, "armor": "hands", "set": "dark", "stats": {"armor": 2.4, "stamina": 0.9, "attack_power_bonus": 1.0}},
	{"id": "dark_botas", "station": "blacksmith", "name": "Botas de Hierro Negro", "cost": {"mena_cobre": 2, "cuero_basto": 2}, "armor": "boots", "set": "dark", "stats": {"armor": 2.4, "stamina": 1.8}},
	# Sets de pícaro (aspecto: piezas Quaternius recoloreadas, ver CharacterBuilder.QSETS)
	{"id": "ladron_capucha", "station": "tailor", "name": "Capucha de Ladrón", "cost": {"fibra": 3, "cuero_basto": 1}, "armor": "head", "set": "ladron", "stats": {"armor": 3.6, "stamina": 2.6}},
	{"id": "ladron_jubon", "station": "leatherworker", "name": "Jubón de Ladrón", "cost": {"cuero_basto": 4, "fibra": 2, "hueso": 1}, "armor": "chest", "set": "ladron", "stats": {"armor": 7.2, "stamina": 4.3, "attack_power_bonus": 2.0}},
	{"id": "ladron_calzas", "station": "tailor", "name": "Calzas de Ladrón", "cost": {"fibra": 3, "cuero_basto": 1}, "armor": "legs", "set": "ladron", "stats": {"armor": 3.0, "stamina": 2.6}},
	{"id": "ladron_munequeras", "station": "leatherworker", "name": "Muñequeras de Ladrón", "cost": {"cuero_basto": 2, "fibra": 1}, "armor": "hands", "set": "ladron", "stats": {"armor": 1.8, "stamina": 0.9}},
	{"id": "ladron_botas", "station": "leatherworker", "name": "Botas Silenciosas de Ladrón", "cost": {"cuero_basto": 2, "fibra": 2}, "armor": "boots", "set": "ladron", "stats": {"armor": 1.8, "stamina": 1.7, "crit_chance": 0.01}},
	{"id": "cuervo_capucha", "station": "tailor", "name": "Capucha Picuda de Cuervo", "cost": {"fibra": 3, "hueso": 1, "cuero_basto": 1}, "armor": "head", "set": "cuervo", "stats": {"armor": 3.3, "stamina": 2.4, "crit_chance": 0.01}},
	{"id": "cuervo_jubon", "station": "leatherworker", "name": "Jubón de Sombras", "cost": {"cuero_basto": 4, "fibra": 2, "hueso": 2}, "armor": "chest", "set": "cuervo", "stats": {"armor": 6.6, "stamina": 4.0, "attack_power_bonus": 3.0}},
	{"id": "cuervo_calzas", "station": "tailor", "name": "Calzas de Sombras", "cost": {"fibra": 3, "cuero_basto": 1}, "armor": "legs", "set": "cuervo", "stats": {"armor": 2.8, "stamina": 2.4}},
	{"id": "cuervo_munequeras", "station": "leatherworker", "name": "Brazales de Sombras", "cost": {"cuero_basto": 2, "hueso": 1}, "armor": "hands", "set": "cuervo", "stats": {"armor": 1.7, "stamina": 0.8, "attack_power_bonus": 1.0}},
	{"id": "cuervo_botas", "station": "leatherworker", "name": "Botas de Cuervo", "cost": {"cuero_basto": 2, "fibra": 1, "hueso": 1}, "armor": "boots", "set": "cuervo", "stats": {"armor": 1.7, "stamina": 1.6}},
	{"id": "desierto_capucha", "station": "tailor", "name": "Cofia Corta del Desierto", "cost": {"fibra": 3}, "armor": "head", "set": "desierto", "stats": {"armor": 3.0, "stamina": 3.0}},
	{"id": "desierto_jubon", "station": "leatherworker", "name": "Túnica del Desierto", "cost": {"fibra": 5, "cuero_basto": 1}, "armor": "chest", "set": "desierto", "stats": {"armor": 6.0, "stamina": 5.0}},
	{"id": "desierto_calzas", "station": "tailor", "name": "Pantalones Anchos del Desierto", "cost": {"fibra": 4}, "armor": "legs", "set": "desierto", "stats": {"armor": 2.5, "stamina": 4.0}},
	{"id": "desierto_munequeras", "station": "leatherworker", "name": "Brazales de Tela del Desierto", "cost": {"fibra": 2, "cuero_basto": 1}, "armor": "hands", "set": "desierto", "stats": {"armor": 1.5, "stamina": 1.0}},
	{"id": "desierto_botas", "station": "leatherworker", "name": "Botas del Desierto", "cost": {"cuero_basto": 2, "fibra": 2}, "armor": "boots", "set": "desierto", "stats": {"armor": 1.5, "stamina": 2.0, "crit_chance": 0.01}},
	{"id": "bosque_capucha", "station": "tailor", "name": "Capucha de Batidor", "cost": {"fibra": 3, "cuero_basto": 1}, "armor": "head", "set": "bosque", "stats": {"armor": 3.9, "stamina": 2.7}},
	{"id": "bosque_jubon", "station": "leatherworker", "name": "Coleto de Batidor", "cost": {"cuero_basto": 5, "fibra": 2, "hueso": 1}, "armor": "chest", "set": "bosque", "stats": {"armor": 7.8, "stamina": 4.5, "attack_power_bonus": 2.0}},
	{"id": "bosque_calzas", "station": "tailor", "name": "Calzas de Batidor", "cost": {"cuero_basto": 2, "fibra": 3}, "armor": "legs", "set": "bosque", "stats": {"armor": 3.3, "stamina": 2.7, "crit_chance": 0.01}},
	{"id": "bosque_munequeras", "station": "leatherworker", "name": "Brazales de Batidor", "cost": {"cuero_basto": 2, "fibra": 1}, "armor": "hands", "set": "bosque", "stats": {"armor": 2.0, "stamina": 0.9}},
	{"id": "bosque_botas", "station": "leatherworker", "name": "Botas de Batidor", "cost": {"cuero_basto": 2, "fibra": 2}, "armor": "boots", "set": "bosque", "stats": {"armor": 2.0, "stamina": 1.8}},
	{"id": "carmesi_capucha", "station": "tailor", "name": "Cofia Carmesí", "cost": {"fibra": 3, "cuero_basto": 1}, "armor": "head", "set": "carmesi", "stats": {"armor": 3.0, "stamina": 2.3, "crit_chance": 0.01}},
	{"id": "carmesi_jubon", "station": "leatherworker", "name": "Casaca Carmesí", "cost": {"fibra": 4, "cuero_basto": 3, "hueso": 1}, "armor": "chest", "set": "carmesi", "stats": {"armor": 6.0, "stamina": 3.8, "attack_power_bonus": 3.0}},
	{"id": "carmesi_calzas", "station": "tailor", "name": "Calzas Carmesí", "cost": {"fibra": 3, "cuero_basto": 1}, "armor": "legs", "set": "carmesi", "stats": {"armor": 2.5, "stamina": 2.3}},
	{"id": "carmesi_munequeras", "station": "leatherworker", "name": "Guantes Carmesí", "cost": {"cuero_basto": 2, "hueso": 1}, "armor": "hands", "set": "carmesi", "stats": {"armor": 1.5, "stamina": 0.8, "attack_power_bonus": 2.0}},
	{"id": "carmesi_botas", "station": "leatherworker", "name": "Botas de Duelista", "cost": {"cuero_basto": 3, "fibra": 1}, "armor": "boots", "set": "carmesi", "stats": {"armor": 1.5, "stamina": 1.5}},
	# Sets de mago (aspecto: tunica Peasant recoloreada + piezas añadidas, ver CharacterBuilder.QSETS)
	{"id": "aprendiz_tocado", "station": "tailor", "name": "Capucha de Aprendiz", "cost": {"fibra": 3, "polvo_arcano": 1}, "armor": "head", "set": "aprendiz", "stats": {"armor": 2.7, "stamina": 3.0}},
	{"id": "aprendiz_tunica", "station": "tailor", "name": "Túnica de Aprendiz", "cost": {"fibra": 5, "polvo_arcano": 1, "cuero_basto": 1}, "armor": "chest", "set": "aprendiz", "stats": {"armor": 5.4, "stamina": 5.0, "attack_power_bonus": 2.0}},
	{"id": "aprendiz_faldon", "station": "tailor", "name": "Faldón de Aprendiz", "cost": {"fibra": 4}, "armor": "legs", "set": "aprendiz", "stats": {"armor": 2.3, "stamina": 3.0}},
	{"id": "aprendiz_punos", "station": "tailor", "name": "Puños de Aprendiz", "cost": {"fibra": 2}, "armor": "hands", "set": "aprendiz", "stats": {"armor": 1.4, "stamina": 1.0}},
	{"id": "aprendiz_botas", "station": "leatherworker", "name": "Botas de Aprendiz", "cost": {"cuero_basto": 2, "fibra": 1}, "armor": "boots", "set": "aprendiz", "stats": {"armor": 1.4, "stamina": 2.0}},
	{"id": "brasa_tocado", "station": "tailor", "name": "Diadema de Brasa", "cost": {"mena_cobre": 2, "polvo_arcano": 2}, "armor": "head", "set": "brasa", "stats": {"armor": 2.4, "stamina": 2.3, "crit_chance": 0.01}},
	{"id": "brasa_tunica", "station": "tailor", "name": "Túnica de Brasa", "cost": {"fibra": 5, "polvo_arcano": 2, "mena_cobre": 1}, "armor": "chest", "set": "brasa", "stats": {"armor": 4.8, "stamina": 3.8, "attack_power_bonus": 3.0}},
	{"id": "brasa_faldon", "station": "tailor", "name": "Faldón de Brasa", "cost": {"fibra": 4, "polvo_arcano": 1}, "armor": "legs", "set": "brasa", "stats": {"armor": 2.0, "stamina": 2.3}},
	{"id": "brasa_punos", "station": "tailor", "name": "Brazaletes de Brasa", "cost": {"mena_cobre": 2, "polvo_arcano": 1}, "armor": "hands", "set": "brasa", "stats": {"armor": 1.2, "stamina": 0.8, "attack_power_bonus": 1.0}},
	{"id": "brasa_botas", "station": "leatherworker", "name": "Botas de Brasa", "cost": {"cuero_basto": 2, "polvo_arcano": 1}, "armor": "boots", "set": "brasa", "stats": {"armor": 1.2, "stamina": 1.5}},
	{"id": "escarcha_tocado", "station": "tailor", "name": "Capucha de Escarcha", "cost": {"fibra": 3, "hueso": 1}, "armor": "head", "set": "escarcha", "stats": {"armor": 3.3, "stamina": 3.0}},
	{"id": "escarcha_tunica", "station": "tailor", "name": "Manto de Escarcha", "cost": {"fibra": 5, "hueso": 2, "cuero_basto": 1}, "armor": "chest", "set": "escarcha", "stats": {"armor": 6.6, "stamina": 5.0, "attack_power_bonus": 2.0}},
	{"id": "escarcha_faldon", "station": "tailor", "name": "Faldón de Escarcha", "cost": {"fibra": 4, "hueso": 1}, "armor": "legs", "set": "escarcha", "stats": {"armor": 2.8, "stamina": 4.0}},
	{"id": "escarcha_punos", "station": "tailor", "name": "Puños de Piel de Escarcha", "cost": {"cuero_basto": 2, "fibra": 1}, "armor": "hands", "set": "escarcha", "stats": {"armor": 1.7, "stamina": 1.0}},
	{"id": "escarcha_botas", "station": "leatherworker", "name": "Botas de Escarcha", "cost": {"cuero_basto": 2, "hueso": 1}, "armor": "boots", "set": "escarcha", "stats": {"armor": 1.7, "stamina": 2.0, "crit_chance": 0.01}},
	{"id": "sabio_tocado", "station": "tailor", "name": "Sombrero de Sabio", "cost": {"fibra": 4, "polvo_arcano": 2}, "armor": "head", "set": "sabio", "stats": {"armor": 2.7, "stamina": 2.7, "attack_power_bonus": 1.0}},
	{"id": "sabio_tunica", "station": "tailor", "name": "Túnica de Sabio", "cost": {"fibra": 5, "polvo_arcano": 2, "cuero_basto": 1}, "armor": "chest", "set": "sabio", "stats": {"armor": 5.4, "stamina": 4.5, "attack_power_bonus": 2.0}},
	{"id": "sabio_faldon", "station": "tailor", "name": "Faldón de Sabio", "cost": {"fibra": 4, "polvo_arcano": 1}, "armor": "legs", "set": "sabio", "stats": {"armor": 2.3, "stamina": 2.7}},
	{"id": "sabio_punos", "station": "tailor", "name": "Puños de Sabio", "cost": {"fibra": 2, "polvo_arcano": 1}, "armor": "hands", "set": "sabio", "stats": {"armor": 1.4, "stamina": 0.9}},
	{"id": "sabio_botas", "station": "leatherworker", "name": "Botas de Sabio", "cost": {"cuero_basto": 2, "fibra": 1}, "armor": "boots", "set": "sabio", "stats": {"armor": 1.4, "stamina": 1.8, "crit_chance": 0.01}},
	{"id": "osario_tocado", "station": "tailor", "name": "Capucha de Osario", "cost": {"fibra": 3, "hueso": 2}, "armor": "head", "set": "osario", "stats": {"armor": 2.4, "stamina": 2.4, "crit_chance": 0.01}},
	{"id": "osario_tunica", "station": "tailor", "name": "Túnica de Osario", "cost": {"fibra": 4, "hueso": 3, "polvo_arcano": 1}, "armor": "chest", "set": "osario", "stats": {"armor": 4.8, "stamina": 4.0, "attack_power_bonus": 3.0}},
	{"id": "osario_faldon", "station": "tailor", "name": "Faldón de Osario", "cost": {"fibra": 4, "hueso": 1}, "armor": "legs", "set": "osario", "stats": {"armor": 2.0, "stamina": 2.4}},
	{"id": "osario_punos", "station": "tailor", "name": "Garras de Osario", "cost": {"hueso": 2, "cuero_basto": 1}, "armor": "hands", "set": "osario", "stats": {"armor": 1.2, "stamina": 0.8, "attack_power_bonus": 1.0}},
	{"id": "osario_botas", "station": "leatherworker", "name": "Botas de Osario", "cost": {"cuero_basto": 2, "hueso": 1}, "armor": "boots", "set": "osario", "stats": {"armor": 1.2, "stamina": 1.6}},
	# Sets de arquero (aspecto: traje Ranger recoloreado + piezas añadidas, ver CharacterBuilder.QSETS)
	{"id": "montero_tocado", "station": "leatherworker", "name": "Gorra de Montero", "cost": {"cuero_basto": 2, "fibra": 2, "hueso": 1}, "armor": "head", "set": "montero", "stats": {"armor": 4.2, "stamina": 2.7}},
	{"id": "montero_jubon", "station": "leatherworker", "name": "Jubón de Montero", "cost": {"cuero_basto": 4, "fibra": 2, "madera": 2}, "armor": "chest", "set": "montero", "stats": {"armor": 8.4, "stamina": 4.5, "attack_power_bonus": 2.0}},
	{"id": "montero_calzas", "station": "leatherworker", "name": "Calzas de Montero", "cost": {"cuero_basto": 2, "fibra": 3}, "armor": "legs", "set": "montero", "stats": {"armor": 3.5, "stamina": 2.7}},
	{"id": "montero_brazales", "station": "leatherworker", "name": "Brazales de Montero", "cost": {"cuero_basto": 2, "fibra": 1}, "armor": "hands", "set": "montero", "stats": {"armor": 2.1, "stamina": 0.9, "crit_chance": 0.01}},
	{"id": "montero_botas", "station": "leatherworker", "name": "Botas de Montero", "cost": {"cuero_basto": 2, "fibra": 2}, "armor": "boots", "set": "montero", "stats": {"armor": 2.1, "stamina": 1.8}},
	{"id": "llanura_tocado", "station": "leatherworker", "name": "Sombrero de Explorador", "cost": {"cuero_basto": 2, "fibra": 3}, "armor": "head", "set": "llanura", "stats": {"armor": 3.9, "stamina": 3.0}},
	{"id": "llanura_jubon", "station": "leatherworker", "name": "Chaleco de Explorador", "cost": {"cuero_basto": 3, "fibra": 4, "madera": 1}, "armor": "chest", "set": "llanura", "stats": {"armor": 7.8, "stamina": 5.0}},
	{"id": "llanura_calzas", "station": "leatherworker", "name": "Pantalón de Explorador", "cost": {"fibra": 4, "cuero_basto": 1}, "armor": "legs", "set": "llanura", "stats": {"armor": 3.3, "stamina": 4.0}},
	{"id": "llanura_brazales", "station": "leatherworker", "name": "Muñequeras de Explorador", "cost": {"fibra": 2, "cuero_basto": 1}, "armor": "hands", "set": "llanura", "stats": {"armor": 2.0, "stamina": 1.0}},
	{"id": "llanura_botas", "station": "leatherworker", "name": "Botas de Explorador", "cost": {"cuero_basto": 3, "fibra": 1}, "armor": "boots", "set": "llanura", "stats": {"armor": 2.0, "stamina": 2.0, "crit_chance": 0.01}},
	{"id": "guardabosques_tocado", "station": "leatherworker", "name": "Cornamenta de Guardabosques", "cost": {"hueso": 3, "cuero_basto": 1}, "armor": "head", "set": "guardabosques", "stats": {"armor": 4.5, "stamina": 3.2, "attack_power_bonus": 1.0}},
	{"id": "guardabosques_jubon", "station": "leatherworker", "name": "Coleto de Guardabosques", "cost": {"cuero_basto": 5, "fibra": 2, "hueso": 2}, "armor": "chest", "set": "guardabosques", "stats": {"armor": 9.0, "stamina": 5.3, "attack_power_bonus": 2.0}},
	{"id": "guardabosques_calzas", "station": "leatherworker", "name": "Calzas de Guardabosques", "cost": {"cuero_basto": 3, "fibra": 2}, "armor": "legs", "set": "guardabosques", "stats": {"armor": 3.8, "stamina": 4.2}},
	{"id": "guardabosques_brazales", "station": "leatherworker", "name": "Brazales de Guardabosques", "cost": {"cuero_basto": 2, "hueso": 1}, "armor": "hands", "set": "guardabosques", "stats": {"armor": 2.3, "stamina": 1.1}},
	{"id": "guardabosques_botas", "station": "leatherworker", "name": "Botas de Guardabosques", "cost": {"cuero_basto": 3, "fibra": 1}, "armor": "boots", "set": "guardabosques", "stats": {"armor": 2.3, "stamina": 2.1}},
	{"id": "centinela_tocado", "station": "leatherworker", "name": "Capucha de Centinela", "cost": {"cuero_basto": 2, "fibra": 3}, "armor": "head", "set": "centinela", "stats": {"armor": 4.8, "stamina": 3.3}},
	{"id": "centinela_jubon", "station": "leatherworker", "name": "Jubón de Centinela", "cost": {"cuero_basto": 5, "fibra": 2, "hueso": 1, "mena_cobre": 1}, "armor": "chest", "set": "centinela", "stats": {"armor": 9.6, "stamina": 5.5, "attack_power_bonus": 1.0}},
	{"id": "centinela_calzas", "station": "leatherworker", "name": "Calzas de Centinela", "cost": {"cuero_basto": 3, "fibra": 2}, "armor": "legs", "set": "centinela", "stats": {"armor": 4.0, "stamina": 3.3}},
	{"id": "centinela_brazales", "station": "leatherworker", "name": "Brazales de Centinela", "cost": {"cuero_basto": 2, "fibra": 1}, "armor": "hands", "set": "centinela", "stats": {"armor": 2.4, "stamina": 1.1}},
	{"id": "centinela_botas", "station": "leatherworker", "name": "Botas de Centinela", "cost": {"cuero_basto": 3, "fibra": 2}, "armor": "boots", "set": "centinela", "stats": {"armor": 2.4, "stamina": 2.2}},
	{"id": "dunas_tocado", "station": "leatherworker", "name": "Cinta de Plumas", "cost": {"hueso": 2, "fibra": 2, "cuero_basto": 1}, "armor": "head", "set": "dunas", "stats": {"armor": 3.6, "stamina": 2.4, "crit_chance": 0.01}},
	{"id": "dunas_jubon", "station": "leatherworker", "name": "Chaleco de Rastreador", "cost": {"cuero_basto": 4, "hueso": 3, "fibra": 1}, "armor": "chest", "set": "dunas", "stats": {"armor": 7.2, "stamina": 4.0, "attack_power_bonus": 3.0}},
	{"id": "dunas_calzas", "station": "leatherworker", "name": "Taparrabos de Rastreador", "cost": {"cuero_basto": 2, "fibra": 3}, "armor": "legs", "set": "dunas", "stats": {"armor": 3.0, "stamina": 2.4}},
	{"id": "dunas_brazales", "station": "leatherworker", "name": "Vendas de Rastreador", "cost": {"fibra": 3, "hueso": 1}, "armor": "hands", "set": "dunas", "stats": {"armor": 1.8, "stamina": 0.8, "attack_power_bonus": 1.0}},
	{"id": "dunas_botas", "station": "leatherworker", "name": "Botas de Rastreador", "cost": {"cuero_basto": 2, "fibra": 2}, "armor": "boots", "set": "dunas", "stats": {"armor": 1.8, "stamina": 1.6, "crit_chance": 0.01}},
	# Alquimia
	{"id": "pocion_vida", "station": "alchemy", "name": "Poción de Vida", "cost": {"hierba_curativa": 2, "flor_silvestre": 1}, "gives": "pocion_vida", "amount": 1},
	{"id": "elixir_fuerza", "station": "alchemy", "name": "Elixir de Fuerza", "cost": {"hongo": 2, "hierba_curativa": 1}, "gives": "elixir_fuerza", "amount": 1},
	{"id": "pocion_arcana", "station": "alchemy", "name": "Poción Arcana", "cost": {"polvo_arcano": 1, "flor_silvestre": 1}, "gives": "pocion_arcana", "amount": 1},
]
## Calidad al forjar (se revela al terminar): único y legendario no se pueden fabricar.
const ODDS := [[ItemRarity.Tier.POCO_COMUN, 0.85], [ItemRarity.Tier.RARO, 0.13], [ItemRarity.Tier.EPICO, 0.02]]
## Calidad del último objeto forjado (para sonidos/avisos de la UI).
static var last_quality: int = 0
const ITEM_LEVEL := 3  # todo lo del piso 1 se fabrica como objeto poco común de nivel 3


const GRADE2_STATS := 1.9   # las piezas de grado 2 tienen ~1.9x los stats del grado 1
const GRADE2_LEVEL := 8      # y nivel de objeto 8 (el grado 1 es nivel 3)
static var _all: Array = []


## Recetas de grado 1 (RECIPES) + sus versiones de grado 2, generadas con los materiales mejorados
## (hierro, cuero curtido, lino, roble, salvia, esencia). Las de grado 2 requieren haber llegado al piso 6.
static func all_recipes() -> Array:
	if _all.is_empty():
		_all = RECIPES.duplicate()
		for r: Dictionary in RECIPES:
			if r.has("set") or r.has("grade"):
				continue
			_all.append(_grade2(r))
	return _all


static func _grade2(r: Dictionary) -> Dictionary:
	var g := r.duplicate(true)
	g["id"] = String(r["id"]) + "_g2"
	g["grade"] = 2
	g["min_floor"] = Materials.GRADE2_FLOOR
	g["level"] = GRADE2_LEVEL
	var cost := {}
	for id: String in r["cost"]:
		cost[Materials.UPGRADE.get(id, id)] = r["cost"][id]
	g["cost"] = cost
	if r.has("stats"):
		var stats := {}
		for k: String in r["stats"]:
			stats[k] = float(r["stats"][k]) * (1.0 if k == "crit_chance" else GRADE2_STATS)
		g["stats"] = stats
	if r.has("gives"):
		g["gives"] = Materials.UPGRADE.get(String(r["gives"]), r["gives"])
	var name := String(r["name"])
	var renamed := name
	for pair: Array in [["de Cobre", "de Hierro"], ["de Cuero", "de Cuero Curtido"], ["de Tela", "de Lino"], ["Reforzado", "de Roble Reforzado"]]:
		renamed = renamed.replace(pair[0], pair[1])
	if renamed == name:
		renamed = name + (" Mayor" if r.has("gives") else (" de Roble" if r["station"] == "carpenter" else " Reforzado"))
	g["name"] = renamed
	return g


static func is_unlocked(recipe: Dictionary) -> bool:
	return CharacterProfile.max_floor >= int(recipe.get("min_floor", 1))


static func recipes_for(station: String) -> Array:
	return all_recipes().filter(func(r: Dictionary) -> bool: return r["station"] == station)


static func can_craft(recipe: Dictionary) -> bool:
	if not is_unlocked(recipe):
		return false
	for id: String in recipe["cost"]:
		if int(Materials.inventory.get(id, 0)) < int(recipe["cost"][id]):
			return false
	return true


static func cost_text(recipe: Dictionary) -> String:
	var parts: Array = []
	for id: String in recipe["cost"]:
		parts.append("%d %s (%d)" % [recipe["cost"][id], Materials.display(id), int(Materials.inventory.get(id, 0))])
	return ", ".join(parts)


static func roll_quality(rng: RandomNumberGenerator) -> int:
	var r := rng.randf()
	var acc := 0.0
	for odd: Array in ODDS:
		acc += float(odd[1])
		if r < acc:
			return int(odd[0])
	return ItemRarity.Tier.POCO_COMUN


## Fabrica la receta: gasta materiales y entrega el resultado (la calidad se sortea al forjar).
## Devuelve el mensaje para el jugador. `rng` opcional para tests.
static func craft(recipe: Dictionary, warrior: WarriorSim, rng: RandomNumberGenerator = null) -> String:
	if not is_unlocked(recipe):
		return "Requiere haber llegado al piso %d" % int(recipe["min_floor"])
	if not can_craft(recipe):
		return "Faltan materiales"
	if rng == null:
		rng = RandomNumberGenerator.new()
		rng.randomize()
	for id: String in recipe["cost"]:
		Materials.inventory[id] = int(Materials.inventory.get(id, 0)) - int(recipe["cost"][id])
	last_quality = 0
	if recipe.has("gives"):
		Materials.add(String(recipe["gives"]), int(recipe["amount"]))
		return "Creaste: %s" % recipe["name"]
	var quality := roll_quality(rng)
	last_quality = quality
	var item: Item
	if recipe.has("weapon"):
		item = ItemFactory.roll_weapon(rng, int(recipe.get("level", ITEM_LEVEL)), quality, String(recipe["weapon"]))
		item.item_name = String(recipe["name"])
		item.id = String(recipe["id"])
		_apply_sword_design(item, recipe)
	else:
		item = Item.new()
		item.id = String(recipe["id"])
		item.item_name = String(recipe["name"])
		item.slot = String(recipe["armor"])
		item.set_id = String(recipe.get("set", ""))
		item.rarity = quality
		item.item_level = int(recipe.get("level", ITEM_LEVEL))
		var power := float(ItemRarity.POWER[quality])
		for k: String in recipe["stats"]:
			item.stats[k] = float(recipe["stats"][k]) * (power if k != "crit_chance" else 1.0)
		for i in int(ItemRarity.AFFIXES[quality]) - 1:  # extras de las calidades altas
			var stat: String = ItemFactory.AFFIX_STATS[rng.randi() % ItemFactory.AFFIX_STATS.size()]
			item.stats[stat] = float(item.stats.get(stat, 0.0)) + (0.01 if stat == "crit_chance" else float(1 + rng.randi() % 3))
	var equipped := Gear.give(item, warrior)
	var where := " y lo equipaste" if equipped else (" (va a tu mochila)" if Gear.can_use(item, warrior.class_id) else " (tu clase no puede empuñarlo: va a la mochila)")
	return "Forjaste %s [%s]%s" % [item.item_name, ItemRarity.display(item.rarity), where]


## Diseños propios: modelo, velocidad (el daño se reajusta para mantener el DPS), multiplicador de DPS y extras.
static func _apply_sword_design(item: Item, recipe: Dictionary) -> void:
	item.model_id = String(recipe.get("model", ""))
	if recipe.has("speed"):
		var dps := item.dps() * float(recipe.get("dps_mult", 1.0))
		var spread := (item.weapon_max - item.weapon_min) / maxf(item.weapon_max + item.weapon_min, 1.0)
		item.weapon_speed = float(recipe["speed"])
		var avg := dps * item.weapon_speed
		item.weapon_min = roundf(avg * (1.0 - spread))
		item.weapon_max = roundf(avg * (1.0 + spread))
	for k: String in recipe.get("stats", {}):
		item.stats[k] = float(item.stats.get(k, 0.0)) + float(recipe["stats"][k])


static func category_of(recipe: Dictionary) -> String:
	if recipe.has("weapon"):
		return "Armas"
	if recipe.has("armor"):
		return "Armadura"
	return "Pociones"


static func describe_result(recipe: Dictionary, class_id: StringName = &"") -> String:
	if recipe.has("weapon") and class_id != &"" and not (String(recipe["weapon"]) in Gear.CLASS_WEAPONS.get(class_id, [])):
		return _describe_base(recipe) + "\n[color=#ff6666]Tu clase no puede empuñar este tipo de arma.[/color]"
	return _describe_base(recipe)


static func _describe_base(recipe: Dictionary) -> String:
	if recipe.has("weapon"):
		var base: Dictionary = ItemFactory.WEAPON_TYPES[recipe["weapon"]]
		var lvl := int(recipe.get("level", ITEM_LEVEL))
		var dps := (2.0 + 0.7 * lvl)
		return "%s  ·  Nv.%d
~%.1f DPS  ·  vel %.1f
[color=#aaaaaa]La calidad se revela al forjar.[/color]" % [base["name"], lvl, dps, float(base["speed"])]
	if recipe.has("armor"):
		var lines: Array = ["%s  ·  Nv.%d" % [Gear.SLOT_NAMES[recipe["armor"]], int(recipe.get("level", ITEM_LEVEL))]]
		for k: String in recipe["stats"]:
			lines.append("+%s %s" % [("%d%%" % int(recipe["stats"][k] * 100.0)) if k == "crit_chance" else str(int(recipe["stats"][k])), k])
		lines.append("[color=#aaaaaa]La calidad se revela al forjar.[/color]")
		return "
".join(lines)
	match String(recipe["gives"]):
		"pocion_vida": return "Consumible
Restaura 40% de la vida máxima. Tecla H."
		"elixir_fuerza": return "Consumible
+25% de daño durante 60 s. Tecla J."
		"pocion_arcana": return "Consumible
Restaura 60% del recurso (maná, energía, rage). Tecla K."
		"pocion_vida_mayor": return "Consumible
Restaura 70% de la vida máxima. Tecla H (se usa antes que la normal)."
		"elixir_fuerza_mayor": return "Consumible
+40% de daño durante 60 s. Tecla J (se usa antes que el normal)."
		"pocion_arcana_mayor": return "Consumible
Restaura 100% del recurso. Tecla K (se usa antes que la normal)."
	return ""
