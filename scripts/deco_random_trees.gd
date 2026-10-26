extends TileMapLayer

@export var tree_source_id := 0
@export var random_tree_marker := Vector2i(0, 0)

# Cada variante con su peso (mayor = más común).
# (1,0) es la más común, (0,4) la más rara.
var tree_variants := {
	Vector2i(1, 0): 10.0,
	Vector2i(0, 1): 5.0,
	Vector2i(0, 2): 4.0,
	Vector2i(0, 3): 1.0,
}

func _ready() -> void:
	var random_cells := get_used_cells_by_id(tree_source_id, random_tree_marker)
	var total_weight := 0.0
	for w in tree_variants.values():
		total_weight += w

	for cell in random_cells:
		var tree: Vector2i = _pick_weighted(tree_variants, total_weight)
		set_cell(cell, tree_source_id, tree, 0)


func _pick_weighted(variants: Dictionary, total_weight: float) -> Vector2i:
	var roll := randf() * total_weight
	for variant in variants:
		roll -= variants[variant]
		if roll <= 0.0:
			return variant
	# Fallback por seguridad numérica
	return variants.keys().back()
