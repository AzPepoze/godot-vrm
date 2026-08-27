extends Node3D


# Called when the node enters the scene tree for the first time.
func _ready():
	_play_wiggle("ImportZone/Godette_vrm_v4")
	_play_wiggle("AliciaSolid_vrm-051")
	_play_wiggle("AliciaSolid_vrm-052")


func _play_wiggle(path: String):
	var node = get_node_or_null(path)
	if not node:
		return
	var anim_player: AnimationPlayer = node.get_node_or_null("AnimationPlayer")
	if not anim_player:
		return
	if anim_player.has_animation("sample/wiggle4"):
		var anim: Animation = anim_player.get_animation("sample/wiggle4")
		if anim:
			anim.loop_mode = Animation.LOOP_LINEAR
			anim_player.play("sample/wiggle4")
