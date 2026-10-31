class_name ExpeditionResults
extends RefCounted
## Pure rules for the end of an expedition (no state): experience per hero and the MVP.
## heroes = [{"hero": HeroData, "alive": bool, "contrib": {category: amount}}]; outcome = "success" |
## "escaped" | "failed"; kill_xp = worth of the creatures killed (EnemyDefs.XP_PER_HP x max HP, summed).
## Returns {"mvp": HeroData or null, "mvp_reason": String, "xp": {hero id: int}, "scores": {hero id: float}}.


static func contribution_scores(heroes: Array) -> Dictionary:
    var totals := {}
    for e in heroes:
        for k in (e["contrib"] as Dictionary):
            totals[k] = float(totals.get(k, 0.0)) + float(e["contrib"][k])
    var out := {}
    for e in heroes:
        var s := 0.0
        for k in ProgressionDefs.CONTRIB_WEIGHTS:
            var t := float(totals.get(k, 0.0))
            if t > 0.0:
                s += float(ProgressionDefs.CONTRIB_WEIGHTS[k]) * float((e["contrib"] as Dictionary).get(k, 0.0)) / t
        out[(e["hero"] as HeroData).id] = s
    return out


## The category where this hero's share of the squad total was largest (for "why the MVP").
static func best_category(entry: Dictionary, heroes: Array) -> String:
    var best := ""
    var best_share := 0.0
    for k in ProgressionDefs.CONTRIB_WEIGHTS:
        var t := 0.0
        for e in heroes:
            t += float((e["contrib"] as Dictionary).get(k, 0.0))
        if t <= 0.0:
            continue
        var share := float((entry["contrib"] as Dictionary).get(k, 0.0)) / t * float(ProgressionDefs.CONTRIB_WEIGHTS[k])
        if share > best_share:
            best_share = share
            best = k
    return best


static func compute(heroes: Array, outcome: String, floor_num: int, kill_xp: int) -> Dictionary:
    var res := {"mvp": null, "mvp_reason": "", "xp": {}, "scores": {}}
    var alive: Array = heroes.filter(func(e): return bool(e["alive"]))
    if alive.is_empty() or outcome == "failed":
        return res
    var scores := contribution_scores(alive)
    res["scores"] = scores
    var total_score := 0.0
    for id in scores:
        total_score += float(scores[id])
    var complete := ProgressionDefs.COMPLETE_BASE + ProgressionDefs.COMPLETE_PER_FLOOR * floor_num if outcome == "success" else 0
    var n := float(alive.size())
    for e in alive:
        var h: HeroData = e["hero"]
        var share := 1.0 / n
        if total_score > 0.0:
            share = ProgressionDefs.SHARE_FLAT / n + (1.0 - ProgressionDefs.SHARE_FLAT) * float(scores[h.id]) / total_score
        res["xp"][h.id] = complete + roundi(float(kill_xp) * share)
    if outcome == "success":
        var best: Dictionary = {}
        for e in alive:
            if best.is_empty() or float(scores[(e["hero"] as HeroData).id]) > float(scores[(best["hero"] as HeroData).id]):
                best = e
        var mvp: HeroData = best["hero"]
        res["mvp"] = mvp
        res["mvp_reason"] = String(ProgressionDefs.CONTRIB_LABELS.get(best_category(best, alive), "did a bit of everything"))
        var bonus := mini(maxi(0, mvp.xp_to_next() - mvp.xp), roundi(float(complete) * ProgressionDefs.MVP_CAP_MULT))
        res["xp"][mvp.id] = int(res["xp"][mvp.id]) + bonus
        res["mvp_bonus"] = bonus
    return res
