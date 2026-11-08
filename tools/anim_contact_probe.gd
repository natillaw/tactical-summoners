extends SceneTree
## Mide, para cada clip de ataque, el instante de máxima velocidad de la punta
## de la espada (el impacto). Uso: godot --headless --path . --script tools/anim_contact_probe.gd

const CLIPS := [
	"ual2/Sword_Regular_A", "ual2/Sword_Regular_B", "ual2/Sword_Regular_C",
	"ual2/Sword_Dash", "ual2/Sword_Block", "ual1/Sword_Attack", "ual2/Sword_Heavy_Combo",
	"ual2/Shield_Dash", "ual1/Roll", "ual1/Punch_Cross", "ual1/Hit_Chest", "ual1/Death01",
]

var _frames := 0
var rig: HumanoidRig

func _initialize() -> void:
	rig = HumanoidRig.new()
	root.add_child(rig)
	rig.setup("res://assets/models/characters/warrior.glb")

func _process(_d: float) -> bool:
	_frames += 1
	if _frames < 3:
		return false
	_measure()
	return true

func _measure() -> void:
	var marker := Node3D.new()
	rig.attach_to_hand(marker)
	var tip_local: Transform3D = marker.transform * Transform3D(Basis(), Vector3(0, 0.9, 0))
	var hand := rig.skeleton.find_bone("hand_r")
	for clip: String in CLIPS:
		var length := rig.length_of(clip)
		var n := 48
		var prev := Vector3.ZERO
		var speeds: Array = []
		rig.player.play(clip)
		for i in range(n + 1):
			var t := length * float(i) / float(n)
			rig.player.seek(t, true)
			var tip := (rig.skeleton.get_bone_global_pose(hand) * tip_local).origin
			if i > 0:
				speeds.append((tip - prev).length() / (length / n))
			prev = tip
		var best := 0
		for i in range(speeds.size()):
			if speeds[i] > speeds[best]:
				best = i
		var profile := ""
		for i in range(0, speeds.size(), 2):
			profile += str(int(speeds[i])) + " "
		print("%-26s len=%.2f peak=%.2f (%.1f m/s) | %s" % [clip, length, (best + 0.5) / n, speeds[best], profile])
