extends AudioStreamPlayer
## An AudioStreamPlayer that counts the assignments to its pitch_scale, and passes them on
## (M5_PLAN.md L27). set_script() puts it on a player that exists. No class_name: tests/ is not
## exported.

var pitch_sets := 0


func _set(property: StringName, _value: Variant) -> bool:
	if property == &"pitch_scale":
		pitch_sets += 1
	return false
