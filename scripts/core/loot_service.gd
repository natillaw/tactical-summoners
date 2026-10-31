class_name LootService
extends RefCounted
## Master prompt A: rolls tower loot from LootDefs. Pure functions over a given RNG; seed_for() gives
## a reproducible seed per floor and run so a bug can be replayed.


static func seed_for(floor_num: int, run: int) -> int:
    return hash("loot:%d:%d" % [floor_num, run])


static func floor_def(floor_num: int) -> Dictionary:
    return LootDefs.FLOORS.get(clampi(floor_num, 1, 10), {})


## What one defeated creature leaves ({id: amount}); a boss also rolls its own table.
static func enemy_drops(floor_num: int, is_boss: bool, first_clear: bool, rng: RandomNumberGenerator) -> Dictionary:
    var out := {}
    var d := floor_def(floor_num)
    _roll(d.get("drops", {}), out, rng, {})
    if is_boss:
        _roll(d.get("boss", {}), out, rng, d.get("first_chance", {}) if first_clear else {})
    return out


## The mission chest (always something) plus first-clear keys.
static func chest(floor_num: int, first_clear: bool, rng: RandomNumberGenerator) -> Dictionary:
    var out := {}
    var d := floor_def(floor_num)
    var c: Dictionary = d.get("chest", {})
    for id in c:
        var n := rng.randi_range(int(c[id][0]), int(c[id][1]))
        out[id] = n if first_clear else maxi(1, roundi(float(n) * LootDefs.REPLAY_CHEST))
    if first_clear:
        var f: Dictionary = d.get("first", {})
        for id in f:
            out[id] = int(out.get(id, 0)) + int(f[id])
    return out


static func _roll(table: Dictionary, out: Dictionary, rng: RandomNumberGenerator, chance_override: Dictionary) -> void:
    for id in table:
        var e: Array = table[id]
        if rng.randf() < float(chance_override.get(id, e[0])):
            out[id] = int(out.get(id, 0)) + rng.randi_range(int(e[1]), int(e[2]))
