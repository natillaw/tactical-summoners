class_name RosterScreen
extends Control
## All owned heroes + a detail panel with stats, traits, passives, training and promotion.

signal back_requested

var _grid: GridContainer
var _detail: VBoxContainer
var _sort: OptionButton
var _selected_id: String = ""
var _count_label: Label
var _status_msg: String = ""        # result of the last ascension attempt


func _ready() -> void:
	var margin := UIKit.margin(20)
	add_child(margin)
	UIKit.fill(margin)
	var root := VBoxContainer.new()
	margin.add_child(root)

	var header := HBoxContainer.new()
	header.add_child(UIKit.button("< Back", func(): back_requested.emit(), Vector2(110, 40)))
	header.add_child(UIKit.label("Roster", 32, UIKit.ACCENT))
	_count_label = UIKit.label("", 16, UIKit.MUTED)
	header.add_child(_count_label)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(spacer)
	header.add_child(UIKit.label("Sort:", 16, UIKit.MUTED))
	_sort = OptionButton.new()
	for s in ["Newest", "Stars", "Level", "Name"]:
		_sort.add_item(s)
	_sort.item_selected.connect(func(_i): _rebuild())
	header.add_child(_sort)
	root.add_child(header)

	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(body)

	var left := ScrollContainer.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	body.add_child(left)
	_grid = GridContainer.new()
	_grid.columns = 4
	_grid.add_theme_constant_override("h_separation", 10)
	_grid.add_theme_constant_override("v_separation", 10)
	left.add_child(_grid)

	var right := PanelContainer.new()
	right.custom_minimum_size = Vector2(450, 0)
	body.add_child(right)
	var rscroll := ScrollContainer.new()
	rscroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	right.add_child(rscroll)
	_detail = VBoxContainer.new()
	_detail.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rscroll.add_child(_detail)

	Game.changed.connect(_rebuild)
	_rebuild()


func _sorted_heroes() -> Array:
	var list: Array = Game.heroes.values()
	match _sort.selected:
		1: list.sort_custom(func(a, b): return a.stars > b.stars or (a.stars == b.stars and a.level > b.level))
		2: list.sort_custom(func(a, b): return a.level > b.level or (a.level == b.level and a.stars > b.stars))
		3: list.sort_custom(func(a, b): return a.hero_name < b.hero_name)
		_: list.reverse()
	return list


func _rebuild() -> void:
	for c in _grid.get_children():
		c.queue_free()
	var list := _sorted_heroes()
	_count_label.text = "   %d heroes" % list.size()
	if _selected_id == "" or not Game.heroes.has(_selected_id):
		_selected_id = list[0].id if not list.is_empty() else ""
	for h in list:
		var card := HeroCard.new(h)
		card.selected = (h.id == _selected_id)
		card.card_pressed.connect(_on_card)
		_grid.add_child(card)
	_show_detail()


func _on_card(h: HeroData) -> void:
	_selected_id = h.id
	for c in _grid.get_children():
		(c as HeroCard).selected = ((c as HeroCard).hero.id == _selected_id)
	_show_detail()


func _show_detail() -> void:
	for c in _detail.get_children():
		c.queue_free()
	if _selected_id == "":
		_detail.add_child(UIKit.label("No heroes yet.\nSummon some first!", 20, UIKit.MUTED))
		return
	var h: HeroData = Game.heroes[_selected_id]
	var col := h.star_color()

	var top := HBoxContainer.new()
	_detail.add_child(top)
	var portrait := HeroPortrait.new(h, 4.0)
	top.add_child(portrait)
	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(info)
	var nm := UIKit.label(h.hero_name, 24, col)
	nm.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	nm.custom_minimum_size = Vector2(190, 0)
	info.add_child(nm)
	if h.epithet != "":
		info.add_child(UIKit.label(h.epithet, 16, UIKit.MUTED))
	info.add_child(StarRow.new(h.stars, 18.0, col))
	info.add_child(UIKit.label("%s   -   Power %d" % [h.class_title(), h.power()], 16, UIKit.TEXT))

	# level / xp
	var lv := "Level %d / %d" % [h.level, h.level_cap()]
	_detail.add_child(UIKit.label(lv, 18, UIKit.TEXT))
	if h.is_max_level():
		var cap_text := "Max level for %d-star." % h.stars
		if h.stars < HeroTables.MAX_STARS:
			cap_text += " Promote to keep growing."
		_detail.add_child(UIKit.label(cap_text, 15, UIKit.ACCENT))
	else:
		var bar := ProgressBar.new()
		bar.max_value = h.xp_to_next()
		bar.value = h.xp
		bar.custom_minimum_size = Vector2(0, 18)
		bar.show_percentage = false
		_detail.add_child(bar)
		_detail.add_child(UIKit.label("XP %d / %d" % [h.xp, h.xp_to_next()], 14, UIKit.MUTED))

	if _status_msg != "":
		_detail.add_child(UIKit.label(_status_msg, 15, UIKit.ACCENT))
	# actions
	var actions := HBoxContainer.new()
	_detail.add_child(actions)
	var train1 := UIKit.button("Train (1 book)", func(): Game.train(h, 1), Vector2(140, 40))
	train1.disabled = h.is_max_level() or Game.books < 1
	actions.add_child(train1)
	var train5 := UIKit.button("Train x5", func(): Game.train(h, 5), Vector2(100, 40))
	train5.disabled = h.is_max_level() or Game.books < 5
	actions.add_child(train5)
	# ascension (vertical slice): Sanctuary of Ascension + top level of the rank + tower materials, with RNG
	var why := Game.promotion_block(h)
	var promo := UIKit.button("Ascend (%d%%)" % roundi(Game.promotion_chance(h) * 100.0), _ascend.bind(h), Vector2(150, 40))
	promo.disabled = why != ""
	promo.tooltip_text = "Needs: %s" % SandboxScreen._res_line(Game.ascension_cost(h)) + ("
" + why if why != "" else "")
	actions.add_child(promo)
	if h.stars < HeroTables.MAX_STARS:
		_detail.add_child(UIKit.label("Ascension: %s. Luck %d. %s" % [SandboxScreen._res_line(Game.ascension_cost(h)), h.luck(),
			why if why != "" else "Ready."], 13, UIKit.MUTED))
	# training grounds: 2-star+ heroes choose one more class skill
	var tb := Game.training_block(h)
	if tb == "":
		_detail.add_child(UIKit.label("Training Grounds: choose one skill to learn (%s)" % SandboxScreen._res_line(ProgressionDefs.TRAIN_COST), 14, UIKit.ACCENT))
		var trow := HBoxContainer.new()
		_detail.add_child(trow)
		for sid in Game.training_options(h):
			var tbtn := UIKit.button(String(SkillDefs.info(sid)["name"]), _train_skill.bind(h, String(sid)), Vector2(150, 36))
			tbtn.tooltip_text = String(SkillDefs.info(sid).get("desc", ""))
			trow.add_child(tbtn)
	else:
		_detail.add_child(UIKit.label("Training: " + tb, 13, UIKit.MUTED))

	# stats
	_detail.add_child(UIKit.label("Stats", 20, UIKit.ACCENT))
	var stats := h.get_stats()
	var sg := GridContainer.new()
	sg.columns = 5
	sg.add_theme_constant_override("h_separation", 16)
	_detail.add_child(sg)
	for k in HeroTables.STAT_KEYS:
		sg.add_child(UIKit.label(HeroTables.STAT_NAMES[k], 13, UIKit.MUTED))
	for k in HeroTables.STAT_KEYS:
		sg.add_child(UIKit.label(str(stats[k]), 18, UIKit.TEXT))

	# personality
	_detail.add_child(UIKit.label("Personality", 20, UIKit.ACCENT))
	for t in h.traits:
		var td: Dictionary = HeroTables.TRAITS[t]
		_detail.add_child(_wrapped("%s - %s" % [td["name"], td["desc"]], 15, UIKit.TEXT))
	_detail.add_child(UIKit.label("Trust %d   |   Obedience %d   |   Composure %d" % [h.trust, h.obedience, h.composure], 14, UIKit.MUTED))
	if h.summon_index > 0:
		_detail.add_child(UIKit.label("Summoned #%d   |   %d recorded events" % [h.summon_index, h.events.size()], 13, UIKit.MUTED))

	_detail.add_child(UIKit.label("Passives", 20, UIKit.ACCENT))
	for p in h.passives:
		var pd: Dictionary = HeroTables.PASSIVES[p]
		_detail.add_child(_wrapped("%s: %s" % [pd["name"], pd["desc"]], 15, UIKit.TEXT))

	_detail.add_child(UIKit.label("Background", 20, UIKit.ACCENT))
	_detail.add_child(_wrapped(h.background_text, 15, UIKit.MUTED))

	# Past-Life Occupation
	_detail.add_child(UIKit.label("Past-Life Occupation", 20, UIKit.ACCENT))
	if HeroTables.PROFESSIONS.has(h.profession):
		var prof: Dictionary = HeroTables.PROFESSIONS[h.profession]
		_detail.add_child(_wrapped("%s: %s\nLobby Benefit: %s | Self-Defense: %s" % [prof["name"], prof["desc"], prof["bonus"].capitalize(), prof["action"]], 15, UIKit.TEXT))
	else:
		_detail.add_child(_wrapped("No recorded past-life occupation.", 15, UIKit.MUTED))

	# Phase 2 & 3: Simulation & Headquarters
	_detail.add_child(UIKit.label("Simulation & Headquarters", 20, UIKit.ACCENT))
	_detail.add_child(UIKit.label("HQ Assignment: %s" % (h.hq_assignment if h.hq_assignment != "" else "Idle / Quarters"), 15, UIKit.ACCENT))
	_detail.add_child(UIKit.label("Memories recorded: %d" % h.memories.size(), 14, UIKit.MUTED))
	for m in h.memories.slice(-3):
		_detail.add_child(_wrapped("• [%s] %s" % [String(m["type"]).capitalize(), String(m["text"])], 13, UIKit.TEXT))
	if h.discovered_secrets.size() > 0:
		_detail.add_child(UIKit.label("Discovered Secrets: %d" % h.discovered_secrets.size(), 14, UIKit.ACCENT))
		for sec in h.discovered_secrets:
			_detail.add_child(_wrapped("• %s" % sec, 13, UIKit.TEXT))


func _wrapped(text: String, p_size: int, color: Color) -> Label:
	var l := UIKit.label(text, p_size, color)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(380, 0)
	return l


func _ascend(h: HeroData) -> void:
	var r := Game.attempt_promotion(h)
	_status_msg = ("%s ascended to %d stars!" % [h.display_name(), h.stars]) if bool(r["ok"]) else ("The ascension failed (%d%% chance). Next try: %d%%." % [roundi(float(r["chance"]) * 100.0), roundi(Game.promotion_chance(h) * 100.0)])
	_rebuild()


func _train_skill(h: HeroData, sid: String) -> void:
	Game.train_skill(h, sid)
