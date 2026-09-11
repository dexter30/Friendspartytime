extends Node3D

## Applies colorful materials to level geometry at runtime.

@export var floor_color: Color = Color(0.35, 0.7, 0.45)
@export var platform_color: Color = Color(0.55, 0.55, 0.65)
@export var accent_color: Color = Color(0.9, 0.6, 0.2)


func _ready() -> void:
	_apply_materials(self)


func _apply_materials(node: Node) -> void:
	if node is MeshInstance3D:
		var mesh_inst := node as MeshInstance3D
		var mat := StandardMaterial3D.new()
		var name_lower := node.name.to_lower()
		if "floor" in name_lower or "arena" in name_lower or "start" in name_lower or "finish" in name_lower:
			mat.albedo_color = floor_color
		elif "flag" in name_lower:
			mat.albedo_color = accent_color
			mat.emission_enabled = true
			mat.emission = accent_color * 0.5
		else:
			mat.albedo_color = platform_color
		mat.roughness = 0.7
		mesh_inst.material_override = mat

	for child in node.get_children():
		_apply_materials(child)
