extends Node3D

## Five fictional capos have actual distinct rigs; the Twins really are two capos.

const Capo = preload("res://games/tifo_beato/world/capo_rig.gd")
const Options = preload("res://games/tifo_beato/tifo_beato_options.gd")
var rival := 0
var rigs: Array[Capo] = []

func _init(index := 0) -> void:
	rival = clampi(index, 0, 4)

func _ready() -> void:
	for index in (2 if rival == 4 else 1):
		var capo := Capo.new()
		capo.rival = rival
		capo.player_color = Color("ff5c6c")
		capo.primary = [Color("a75535"), Color("d64541"), Color("69b3d0"),
			Color("f48fb1"), Options.NAVY][rival]
		capo.outfit = {"hat": "tb_hat_fisher" if rival in [0, 1] else (
			"tb_hat_crown" if rival == 3 or index == 1 else "tb_hat_bobble"),
			"drum": "tb_drum_bass" if rival == 1 else "tb_drum_bucket"}
		if rival == 4:
			capo.position.x = -0.7 if index == 0 else 0.7
			capo.scale = Vector3.ONE * 0.85
		add_child(capo)
		rigs.append(capo)

func pose(time: float, reduced: bool, performing := true, leading_half := -1) -> void:
	for index in rigs.size():
		var leading := performing and (rival != 4 or leading_half < 0 or index == leading_half)
		rigs[index].pose(85.0 if leading else 20.0, false, time + index * 0.6, reduced)
		var body := rigs[index].get_node("ToyCapoBody") as Node3D
		body.rotation.z = 0.0 if leading else 0.08
