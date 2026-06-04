## Renders the game map with terrain, named locations, loot glow effects, and drop phase labels.
## Uses MapData for location/terrain configuration and LootManager for active loot rendering.
## Handles visual representation of the 2000x2000m battle royale map in blocky colorful style.
class_name GameMap
extends Node3D


## Emitted when the map has finished loading all terrain and locations.
signal map_loaded()


## Reference to the map data configuration.
var map_data: MapData = null

## Reference to the loot manager for rendering active loot.
var loot_manager: LootManager = null

## Whether the drop phase is currently active (controls label visibility).
var is_drop_phase_active: bool = false

## Container node for terrain meshes.
var terrain_container: Node3D = null

## Container node for named location markers and labels.
var locations_container: Node3D = null

## Container node for loot glow effects.
var loot_container: Node3D = null

## Container node for location name labels (shown during drop phase).
var labels_container: Node3D = null

## Whether the map has been fully loaded.
var is_loaded: bool = false

## Scale factor: world units (meters) to scene units.
const WORLD_SCALE: float = 1.0

## Terrain colors for the blocky art style (per terrain type).
const TERRAIN_COLORS: Dictionary = {
	MapData.TerrainType.URBAN: Color(0.55, 0.55, 0.65, 1.0),
	MapData.TerrainType.OPEN_FIELD: Color(0.45, 0.75, 0.35, 1.0),
	MapData.TerrainType.FORESTED: Color(0.2, 0.5, 0.25, 1.0),
	MapData.TerrainType.ELEVATED: Color(0.6, 0.5, 0.35, 1.0),
}

## Rarity tier glow colors for loot items.
const RARITY_GLOW_COLORS: Dictionary = {
	Enums.RarityTier.COMMON: Color(0.7, 0.7, 0.7, 1.0),
	Enums.RarityTier.UNCOMMON: Color(0.3, 0.8, 0.3, 1.0),
	Enums.RarityTier.RARE: Color(0.3, 0.5, 1.0, 1.0),
	Enums.RarityTier.EPIC: Color(0.7, 0.3, 0.9, 1.0),
	Enums.RarityTier.LEGENDARY: Color(1.0, 0.8, 0.2, 1.0),
}

## Urban location building colors for variety.
const URBAN_BUILDING_COLORS: Array = [
	Color(0.6, 0.4, 0.35),
	Color(0.5, 0.55, 0.6),
	Color(0.65, 0.6, 0.5),
	Color(0.45, 0.5, 0.55),
]

## Forested tree colors for variety.
const TREE_COLORS: Array = [
	Color(0.15, 0.45, 0.2),
	Color(0.2, 0.55, 0.25),
	Color(0.25, 0.5, 0.15),
]

## Elevated rock colors for variety.
const ROCK_COLORS: Array = [
	Color(0.5, 0.45, 0.35),
	Color(0.55, 0.5, 0.4),
	Color(0.45, 0.4, 0.3),
]

## Loot glow pulse speed (radians per second).
const LOOT_GLOW_PULSE_SPEED: float = 3.0

## Loot glow minimum intensity.
const LOOT_GLOW_MIN_INTENSITY: float = 0.6

## Loot glow maximum intensity.
const LOOT_GLOW_MAX_INTENSITY: float = 1.2


func _ready() -> void:
	_setup_containers()
	if map_data == null:
		map_data = MapData.new()
	load_map()


## Initializes the map with the given map data and optional loot manager.
func initialize(p_map_data: MapData, p_loot_manager: LootManager = null) -> void:
	map_data = p_map_data
	loot_manager = p_loot_manager
	load_map()


## Loads the entire map: terrain, locations, and loot.
## Map is fully loaded without external streaming (Requirement 11.5).
func load_map() -> void:
	if map_data == null:
		return

	_clear_map_contents()
	_setup_containers()
	_build_terrain()
	_build_named_locations()
	_setup_lighting()

	is_loaded = true
	map_loaded.emit()


## Sets the drop phase state, controlling label visibility (Requirement 11.6).
## Labels are shown during Drop Phase and hidden after it ends.
func set_drop_phase_active(active: bool) -> void:
	is_drop_phase_active = active
	if labels_container != null:
		labels_container.visible = active


## Updates loot glow effects based on active loot from the loot manager.
## Call this after loot is spawned or picked up to refresh visuals.
func refresh_loot_display() -> void:
	if loot_container == null:
		return

	# Clear existing loot visuals
	for child in loot_container.get_children():
		child.queue_free()

	if loot_manager == null:
		return

	# Create glow effect for each active loot item
	for loot_item in loot_manager.active_loot:
		if loot_item.is_picked_up:
			continue
		_create_loot_glow(loot_item)


## Returns whether the map is fully loaded and ready for gameplay.
func is_map_loaded() -> bool:
	return is_loaded


## Returns the terrain color for a given terrain type.
func get_terrain_color(terrain_type: MapData.TerrainType) -> Color:
	if TERRAIN_COLORS.has(terrain_type):
		return TERRAIN_COLORS[terrain_type]
	return Color(0.5, 0.5, 0.5, 1.0)


## Returns the texture filename for a terrain type.
func _get_terrain_texture_name(terrain_type: MapData.TerrainType) -> String:
	match terrain_type:
		MapData.TerrainType.URBAN:
			return "concrete"
		MapData.TerrainType.OPEN_FIELD:
			return "grass"
		MapData.TerrainType.FORESTED:
			return "forest_floor"
		MapData.TerrainType.ELEVATED:
			return "rock"
		_:
			return "grass"


## Returns the glow color for a given rarity tier.
func get_rarity_glow_color(rarity: Enums.RarityTier) -> Color:
	if RARITY_GLOW_COLORS.has(rarity):
		return RARITY_GLOW_COLORS[rarity]
	return Color(1.0, 1.0, 1.0, 1.0)


## Called every frame to animate loot glow effects.
func _process(delta: float) -> void:
	_animate_loot_glow(delta)


# --- Private Setup Methods ---


## Creates container nodes for organizing map elements.
## Reuses existing child nodes from the scene tree if present.
func _setup_containers() -> void:
	if terrain_container == null:
		terrain_container = get_node_or_null("TerrainContainer") as Node3D
		if terrain_container == null:
			terrain_container = Node3D.new()
			terrain_container.name = "TerrainContainer"
			add_child(terrain_container)

	if locations_container == null:
		locations_container = get_node_or_null("LocationsContainer") as Node3D
		if locations_container == null:
			locations_container = Node3D.new()
			locations_container.name = "LocationsContainer"
			add_child(locations_container)

	if labels_container == null:
		labels_container = get_node_or_null("LabelsContainer") as Node3D
		if labels_container == null:
			labels_container = Node3D.new()
			labels_container.name = "LabelsContainer"
			add_child(labels_container)
		labels_container.visible = is_drop_phase_active

	if loot_container == null:
		loot_container = get_node_or_null("LootContainer") as Node3D
		if loot_container == null:
			loot_container = Node3D.new()
			loot_container.name = "LootContainer"
			add_child(loot_container)


## Clears all map visual elements (children of containers, not the containers themselves).
func _clear_map_contents() -> void:
	if terrain_container != null:
		for child in terrain_container.get_children():
			child.queue_free()
	if locations_container != null:
		for child in locations_container.get_children():
			child.queue_free()
	if labels_container != null:
		for child in labels_container.get_children():
			child.queue_free()
	if loot_container != null:
		for child in loot_container.get_children():
			child.queue_free()
	# Remove any previously added lighting nodes
	for child in get_children():
		if child is DirectionalLight3D or child is WorldEnvironment:
			child.queue_free()
	is_loaded = false


## Builds terrain meshes for each terrain region defined in map data.
func _build_terrain() -> void:
	var regions := map_data.get_terrain_regions()
	for region in regions:
		_create_terrain_region(region)


## Creates a 3D mesh for a terrain region with appropriate color and height.
func _create_terrain_region(region: MapData.TerrainRegion) -> void:
	var mesh_instance := MeshInstance3D.new()
	var box_mesh := BoxMesh.new()

	# Convert 2D bounds to 3D terrain block
	var width: float = region.bounds.size.x * WORLD_SCALE
	var depth: float = region.bounds.size.y * WORLD_SCALE
	var height: float = _get_terrain_height(region.terrain_type)

	box_mesh.size = Vector3(width, height, depth)
	mesh_instance.mesh = box_mesh

	# Position the terrain block
	var center_x: float = (region.bounds.position.x + region.bounds.size.x / 2.0) * WORLD_SCALE
	var center_z: float = (region.bounds.position.y + region.bounds.size.y / 2.0) * WORLD_SCALE
	mesh_instance.position = Vector3(center_x, height / 2.0, center_z)

	# Apply terrain material with blocky color
	var material := StandardMaterial3D.new()
	var texture_name := _get_terrain_texture_name(region.terrain_type)
	var texture := AssetLoader.load_texture("textures/terrain/%s.png" % texture_name)
	if texture:
		material.albedo_texture = texture
		material.uv1_scale = Vector3(10, 10, 10)
	else:
		material.albedo_color = get_terrain_color(region.terrain_type)
	material.roughness = 0.9
	material.metallic = 0.0
	mesh_instance.material_override = material

	mesh_instance.name = "Terrain_%s" % MapData.TerrainType.keys()[region.terrain_type]
	terrain_container.add_child(mesh_instance)

	# Add terrain detail props based on type
	_add_terrain_details(region)


## Returns the height for a terrain type (elevated terrain is taller).
func _get_terrain_height(terrain_type: MapData.TerrainType) -> float:
	match terrain_type:
		MapData.TerrainType.URBAN:
			return 0.5
		MapData.TerrainType.OPEN_FIELD:
			return 0.2
		MapData.TerrainType.FORESTED:
			return 0.4
		MapData.TerrainType.ELEVATED:
			return 2.0
		_:
			return 0.3


## Adds detail props (buildings, trees, rocks) to a terrain region.
func _add_terrain_details(region: MapData.TerrainRegion) -> void:
	match region.terrain_type:
		MapData.TerrainType.URBAN:
			_add_urban_details(region)
		MapData.TerrainType.FORESTED:
			_add_forest_details(region)
		MapData.TerrainType.ELEVATED:
			_add_elevated_details(region)
		MapData.TerrainType.OPEN_FIELD:
			_add_field_details(region)


## Adds blocky buildings to urban terrain regions.
func _add_urban_details(region: MapData.TerrainRegion) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(region.bounds.position)
	var building_count := int(region.bounds.size.x * region.bounds.size.y / 40000.0)
	building_count = clampi(building_count, 4, 20)

	for i in range(building_count):
		var building := MeshInstance3D.new()
		var box := BoxMesh.new()
		var bw := rng.randf_range(8.0, 25.0)
		var bh := rng.randf_range(5.0, 20.0)
		var bd := rng.randf_range(8.0, 25.0)
		box.size = Vector3(bw, bh, bd)
		building.mesh = box

		var mat := StandardMaterial3D.new()
		mat.albedo_color = URBAN_BUILDING_COLORS[i % URBAN_BUILDING_COLORS.size()]
		mat.roughness = 0.85
		building.material_override = mat

		var pos_x := rng.randf_range(region.bounds.position.x + bw, region.bounds.position.x + region.bounds.size.x - bw)
		var pos_z := rng.randf_range(region.bounds.position.y + bd, region.bounds.position.y + region.bounds.size.y - bd)
		building.position = Vector3(pos_x * WORLD_SCALE, bh / 2.0 + 0.5, pos_z * WORLD_SCALE)
		building.name = "Building_%d" % i
		terrain_container.add_child(building)


## Adds blocky trees to forested terrain regions.
func _add_forest_details(region: MapData.TerrainRegion) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(region.bounds.position + Vector2(1, 1))
	var tree_count := int(region.bounds.size.x * region.bounds.size.y / 15000.0)
	tree_count = clampi(tree_count, 8, 40)

	for i in range(tree_count):
		var tree_root := Node3D.new()
		tree_root.name = "Tree_%d" % i

		# Trunk (brown box)
		var trunk := MeshInstance3D.new()
		var trunk_mesh := BoxMesh.new()
		var trunk_h := rng.randf_range(3.0, 6.0)
		trunk_mesh.size = Vector3(1.0, trunk_h, 1.0)
		trunk.mesh = trunk_mesh
		var trunk_mat := StandardMaterial3D.new()
		trunk_mat.albedo_color = Color(0.4, 0.25, 0.15)
		trunk_mat.roughness = 0.95
		trunk.material_override = trunk_mat
		trunk.position = Vector3(0, trunk_h / 2.0 + 0.4, 0)
		tree_root.add_child(trunk)

		# Canopy (green box, blocky style)
		var canopy := MeshInstance3D.new()
		var canopy_mesh := BoxMesh.new()
		var canopy_size := rng.randf_range(3.0, 5.0)
		canopy_mesh.size = Vector3(canopy_size, canopy_size * 0.8, canopy_size)
		canopy.mesh = canopy_mesh
		var canopy_mat := StandardMaterial3D.new()
		canopy_mat.albedo_color = TREE_COLORS[i % TREE_COLORS.size()]
		canopy_mat.roughness = 0.9
		canopy.material_override = canopy_mat
		canopy.position = Vector3(0, trunk_h + canopy_size * 0.3, 0)
		tree_root.add_child(canopy)

		var pos_x := rng.randf_range(region.bounds.position.x + 5, region.bounds.position.x + region.bounds.size.x - 5)
		var pos_z := rng.randf_range(region.bounds.position.y + 5, region.bounds.position.y + region.bounds.size.y - 5)
		tree_root.position = Vector3(pos_x * WORLD_SCALE, 0, pos_z * WORLD_SCALE)
		terrain_container.add_child(tree_root)


## Adds blocky rocks and cliff faces to elevated terrain regions.
func _add_elevated_details(region: MapData.TerrainRegion) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(region.bounds.position + Vector2(2, 2))
	var rock_count := int(region.bounds.size.x * region.bounds.size.y / 30000.0)
	rock_count = clampi(rock_count, 3, 15)

	for i in range(rock_count):
		var rock := MeshInstance3D.new()
		var rock_mesh := BoxMesh.new()
		var rw := rng.randf_range(4.0, 12.0)
		var rh := rng.randf_range(3.0, 8.0)
		var rd := rng.randf_range(4.0, 12.0)
		rock_mesh.size = Vector3(rw, rh, rd)
		rock.mesh = rock_mesh

		var rock_mat := StandardMaterial3D.new()
		rock_mat.albedo_color = ROCK_COLORS[i % ROCK_COLORS.size()]
		rock_mat.roughness = 0.95
		rock.material_override = rock_mat

		var pos_x := rng.randf_range(region.bounds.position.x + rw, region.bounds.position.x + region.bounds.size.x - rw)
		var pos_z := rng.randf_range(region.bounds.position.y + rd, region.bounds.position.y + region.bounds.size.y - rd)
		rock.position = Vector3(pos_x * WORLD_SCALE, 2.0 + rh / 2.0, pos_z * WORLD_SCALE)
		rock.name = "Rock_%d" % i
		# Slight random rotation for variety
		rock.rotation_degrees.y = rng.randf_range(0, 45)
		terrain_container.add_child(rock)


## Adds scattered grass patches to open field terrain.
func _add_field_details(region: MapData.TerrainRegion) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(region.bounds.position + Vector2(3, 3))
	var patch_count := int(region.bounds.size.x * region.bounds.size.y / 50000.0)
	patch_count = clampi(patch_count, 3, 12)

	for i in range(patch_count):
		var patch := MeshInstance3D.new()
		var patch_mesh := BoxMesh.new()
		var pw := rng.randf_range(5.0, 15.0)
		var pd := rng.randf_range(5.0, 15.0)
		patch_mesh.size = Vector3(pw, 0.3, pd)
		patch.mesh = patch_mesh

		var patch_mat := StandardMaterial3D.new()
		# Slightly different green shades for variety
		patch_mat.albedo_color = Color(
			0.4 + rng.randf_range(-0.05, 0.05),
			0.7 + rng.randf_range(-0.1, 0.1),
			0.3 + rng.randf_range(-0.05, 0.05)
		)
		patch_mat.roughness = 0.95
		patch.material_override = patch_mat

		var pos_x := rng.randf_range(region.bounds.position.x + pw, region.bounds.position.x + region.bounds.size.x - pw)
		var pos_z := rng.randf_range(region.bounds.position.y + pd, region.bounds.position.y + region.bounds.size.y - pd)
		patch.position = Vector3(pos_x * WORLD_SCALE, 0.35, pos_z * WORLD_SCALE)
		patch.name = "GrassPatch_%d" % i
		terrain_container.add_child(patch)


# --- Named Location Building ---


## Builds visual markers and labels for all named locations.
func _build_named_locations() -> void:
	var locations := map_data.get_named_locations()
	for location in locations:
		_create_location_marker(location)
		_create_location_label(location)


## Creates a visual marker for a named location with unique layout per terrain type.
func _create_location_marker(location: MapData.NamedLocation) -> void:
	var marker_root := Node3D.new()
	marker_root.name = "Location_%s" % location.id

	# Create unique layout based on terrain type
	match location.terrain_type:
		MapData.TerrainType.URBAN:
			_build_urban_location(marker_root, location)
		MapData.TerrainType.OPEN_FIELD:
			_build_field_location(marker_root, location)
		MapData.TerrainType.FORESTED:
			_build_forest_location(marker_root, location)
		MapData.TerrainType.ELEVATED:
			_build_elevated_location(marker_root, location)

	marker_root.position = Vector3(
		location.position.x * WORLD_SCALE,
		0,
		location.position.y * WORLD_SCALE
	)
	locations_container.add_child(marker_root)


## Creates a 3D label for a named location (visible during Drop Phase only).
func _create_location_label(location: MapData.NamedLocation) -> void:
	var label := Label3D.new()
	label.name = "Label_%s" % location.id
	label.text = location.display_name
	label.font_size = 48
	label.pixel_size = 0.5
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.modulate = Color(1.0, 1.0, 1.0, 0.95)
	label.outline_modulate = Color(0.0, 0.0, 0.0, 0.8)
	label.outline_size = 8

	# Position label above the location
	label.position = Vector3(
		location.position.x * WORLD_SCALE,
		25.0,
		location.position.y * WORLD_SCALE
	)

	labels_container.add_child(label)


## Builds a unique urban location layout (clustered buildings, streets).
func _build_urban_location(root: Node3D, location: MapData.NamedLocation) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(location.id)

	# Create a cluster of blocky buildings
	var building_count := rng.randi_range(4, 7)
	for i in range(building_count):
		var building := MeshInstance3D.new()
		var box := BoxMesh.new()
		var bw := rng.randf_range(6.0, 18.0)
		var bh := rng.randf_range(8.0, 25.0)
		var bd := rng.randf_range(6.0, 18.0)
		box.size = Vector3(bw, bh, bd)
		building.mesh = box

		var mat := StandardMaterial3D.new()
		mat.albedo_color = URBAN_BUILDING_COLORS[i % URBAN_BUILDING_COLORS.size()]
		mat.roughness = 0.8
		building.material_override = mat

		var angle := (TAU / building_count) * i + rng.randf_range(-0.3, 0.3)
		var dist := rng.randf_range(location.radius * 0.2, location.radius * 0.7)
		building.position = Vector3(
			cos(angle) * dist,
			bh / 2.0 + 0.5,
			sin(angle) * dist
		)
		building.rotation_degrees.y = rng.randf_range(0, 90)
		building.name = "LocBuilding_%d" % i
		root.add_child(building)

	# Add a ground platform for the location
	var platform := MeshInstance3D.new()
	var platform_mesh := BoxMesh.new()
	platform_mesh.size = Vector3(location.radius * 1.8, 0.3, location.radius * 1.8)
	platform.mesh = platform_mesh
	var platform_mat := StandardMaterial3D.new()
	platform_mat.albedo_color = Color(0.4, 0.4, 0.45)
	platform_mat.roughness = 0.9
	platform.material_override = platform_mat
	platform.position = Vector3(0, 0.15 + 0.5, 0)
	platform.name = "UrbanPlatform"
	root.add_child(platform)


## Builds a unique open field location layout (fences, haystacks, open structures).
func _build_field_location(root: Node3D, location: MapData.NamedLocation) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(location.id)

	# Scattered structures (barns, sheds)
	var struct_count := rng.randi_range(2, 4)
	for i in range(struct_count):
		var structure := MeshInstance3D.new()
		var box := BoxMesh.new()
		var sw := rng.randf_range(8.0, 15.0)
		var sh := rng.randf_range(4.0, 8.0)
		var sd := rng.randf_range(6.0, 12.0)
		box.size = Vector3(sw, sh, sd)
		structure.mesh = box

		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(
			0.6 + rng.randf_range(-0.1, 0.1),
			0.45 + rng.randf_range(-0.05, 0.05),
			0.3
		)
		mat.roughness = 0.9
		structure.material_override = mat

		var angle := (TAU / struct_count) * i + rng.randf_range(-0.5, 0.5)
		var dist := rng.randf_range(location.radius * 0.3, location.radius * 0.6)
		structure.position = Vector3(
			cos(angle) * dist,
			sh / 2.0 + 0.2,
			sin(angle) * dist
		)
		structure.name = "FieldStruct_%d" % i
		root.add_child(structure)

	# Add fence posts around perimeter
	var fence_count := 8
	for i in range(fence_count):
		var post := MeshInstance3D.new()
		var post_mesh := BoxMesh.new()
		post_mesh.size = Vector3(0.5, 2.0, 0.5)
		post.mesh = post_mesh
		var post_mat := StandardMaterial3D.new()
		post_mat.albedo_color = Color(0.5, 0.35, 0.2)
		post_mat.roughness = 0.95
		post.material_override = post_mat

		var angle := (TAU / fence_count) * i
		var dist := location.radius * 0.8
		post.position = Vector3(cos(angle) * dist, 1.2, sin(angle) * dist)
		post.name = "FencePost_%d" % i
		root.add_child(post)


## Builds a unique forested location layout (dense trees, clearings, log cabins).
func _build_forest_location(root: Node3D, location: MapData.NamedLocation) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(location.id)

	# Dense tree ring around the location
	var tree_count := rng.randi_range(6, 10)
	for i in range(tree_count):
		var tree := Node3D.new()
		tree.name = "LocTree_%d" % i

		var trunk := MeshInstance3D.new()
		var trunk_mesh := BoxMesh.new()
		var trunk_h := rng.randf_range(4.0, 7.0)
		trunk_mesh.size = Vector3(1.2, trunk_h, 1.2)
		trunk.mesh = trunk_mesh
		var trunk_mat := StandardMaterial3D.new()
		trunk_mat.albedo_color = Color(0.35, 0.22, 0.12)
		trunk_mat.roughness = 0.95
		trunk.material_override = trunk_mat
		trunk.position = Vector3(0, trunk_h / 2.0 + 0.4, 0)
		tree.add_child(trunk)

		var canopy := MeshInstance3D.new()
		var canopy_mesh := BoxMesh.new()
		var cs := rng.randf_range(3.5, 5.5)
		canopy_mesh.size = Vector3(cs, cs * 0.7, cs)
		canopy.mesh = canopy_mesh
		var canopy_mat := StandardMaterial3D.new()
		canopy_mat.albedo_color = TREE_COLORS[i % TREE_COLORS.size()]
		canopy_mat.roughness = 0.9
		canopy.material_override = canopy_mat
		canopy.position = Vector3(0, trunk_h + cs * 0.2, 0)
		tree.add_child(canopy)

		var angle := (TAU / tree_count) * i + rng.randf_range(-0.2, 0.2)
		var dist := rng.randf_range(location.radius * 0.4, location.radius * 0.8)
		tree.position = Vector3(cos(angle) * dist, 0, sin(angle) * dist)
		root.add_child(tree)

	# Central cabin/structure
	var cabin := MeshInstance3D.new()
	var cabin_mesh := BoxMesh.new()
	cabin_mesh.size = Vector3(10.0, 5.0, 8.0)
	cabin.mesh = cabin_mesh
	var cabin_mat := StandardMaterial3D.new()
	cabin_mat.albedo_color = Color(0.45, 0.3, 0.18)
	cabin_mat.roughness = 0.9
	cabin.material_override = cabin_mat
	cabin.position = Vector3(0, 2.9, 0)
	cabin.name = "ForestCabin"
	root.add_child(cabin)


## Builds a unique elevated location layout (cliff platforms, watchtowers).
func _build_elevated_location(root: Node3D, location: MapData.NamedLocation) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(location.id)

	# Elevated platform base
	var platform := MeshInstance3D.new()
	var platform_mesh := BoxMesh.new()
	var platform_h := rng.randf_range(4.0, 8.0)
	platform_mesh.size = Vector3(location.radius * 1.5, platform_h, location.radius * 1.5)
	platform.mesh = platform_mesh
	var platform_mat := StandardMaterial3D.new()
	platform_mat.albedo_color = Color(0.5, 0.45, 0.35)
	platform_mat.roughness = 0.95
	platform.material_override = platform_mat
	platform.position = Vector3(0, platform_h / 2.0 + 2.0, 0)
	platform.name = "ElevatedBase"
	root.add_child(platform)

	# Watchtower or structure on top
	var tower := MeshInstance3D.new()
	var tower_mesh := BoxMesh.new()
	var tw := rng.randf_range(4.0, 7.0)
	var th := rng.randf_range(6.0, 12.0)
	tower_mesh.size = Vector3(tw, th, tw)
	tower.mesh = tower_mesh
	var tower_mat := StandardMaterial3D.new()
	tower_mat.albedo_color = Color(0.55, 0.5, 0.4)
	tower_mat.roughness = 0.85
	tower.material_override = tower_mat
	tower.position = Vector3(0, platform_h + th / 2.0 + 2.0, 0)
	tower.name = "Watchtower"
	root.add_child(tower)

	# Scattered boulders around the elevated area
	var boulder_count := rng.randi_range(3, 6)
	for i in range(boulder_count):
		var boulder := MeshInstance3D.new()
		var boulder_mesh := BoxMesh.new()
		var bw := rng.randf_range(2.0, 5.0)
		var bh := rng.randf_range(2.0, 4.0)
		boulder_mesh.size = Vector3(bw, bh, bw * rng.randf_range(0.8, 1.2))
		boulder.mesh = boulder_mesh
		var boulder_mat := StandardMaterial3D.new()
		boulder_mat.albedo_color = ROCK_COLORS[i % ROCK_COLORS.size()]
		boulder_mat.roughness = 0.95
		boulder.material_override = boulder_mat

		var angle := (TAU / boulder_count) * i + rng.randf_range(-0.3, 0.3)
		var dist := rng.randf_range(location.radius * 0.5, location.radius * 0.9)
		boulder.position = Vector3(cos(angle) * dist, 2.0 + bh / 2.0, sin(angle) * dist)
		boulder.rotation_degrees.y = rng.randf_range(0, 60)
		boulder.name = "Boulder_%d" % i
		root.add_child(boulder)


# --- Loot Glow Effects ---


## Creates a glowing visual for a loot item on the ground.
func _create_loot_glow(loot_item: LootManager.LootInstance) -> void:
	var glow_node := MeshInstance3D.new()
	var sphere_mesh := SphereMesh.new()
	sphere_mesh.radius = 0.4
	sphere_mesh.height = 0.8
	glow_node.mesh = sphere_mesh

	var glow_color := get_rarity_glow_color(loot_item.rarity)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = glow_color
	mat.emission_enabled = true
	mat.emission = glow_color
	mat.emission_energy_multiplier = 1.0
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color.a = 0.7
	glow_node.material_override = mat

	# Position at loot world position
	glow_node.position = Vector3(
		loot_item.position.x * WORLD_SCALE,
		1.0,
		loot_item.position.y * WORLD_SCALE
	)
	glow_node.name = "LootGlow_%d" % loot_item.id

	# Store rarity in metadata for animation
	glow_node.set_meta("rarity", loot_item.rarity)
	glow_node.set_meta("loot_id", loot_item.id)

	loot_container.add_child(glow_node)


## Animates all loot glow effects with a pulsing intensity.
func _animate_loot_glow(delta: float) -> void:
	if loot_container == null:
		return

	var time := Time.get_ticks_msec() / 1000.0
	for child in loot_container.get_children():
		if child is MeshInstance3D and child.material_override != null:
			var mat: StandardMaterial3D = child.material_override
			if mat.emission_enabled:
				# Pulse the emission energy using a sine wave
				var pulse := (sin(time * LOOT_GLOW_PULSE_SPEED) + 1.0) / 2.0
				var intensity := lerpf(LOOT_GLOW_MIN_INTENSITY, LOOT_GLOW_MAX_INTENSITY, pulse)
				mat.emission_energy_multiplier = intensity


# --- Lighting Setup ---


## Sets up scene lighting for the blocky colorful art style.
func _setup_lighting() -> void:
	# Main directional light (sun)
	var sun := DirectionalLight3D.new()
	sun.name = "SunLight"
	sun.light_energy = 1.0
	sun.light_color = Color(1.0, 0.95, 0.85)
	sun.shadow_enabled = true
	sun.transform = Transform3D.IDENTITY
	sun.rotation_degrees = Vector3(-45, 30, 0)
	add_child(sun)

	# Fill light for softer shadows
	var fill := DirectionalLight3D.new()
	fill.name = "FillLight"
	fill.light_energy = 0.3
	fill.light_color = Color(0.8, 0.85, 1.0)
	fill.shadow_enabled = false
	fill.transform = Transform3D.IDENTITY
	fill.rotation_degrees = Vector3(-30, -120, 0)
	add_child(fill)

	# Environment sky for ambient lighting
	var env := WorldEnvironment.new()
	env.name = "WorldEnvironment"
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.5, 0.7, 0.9)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.6, 0.65, 0.7)
	environment.ambient_light_energy = 0.4
	env.environment = environment
	add_child(env)


# --- Utility Methods ---


## Returns the 3D world position for a 2D map coordinate.
func map_to_world(map_position: Vector2) -> Vector3:
	return Vector3(
		map_position.x * WORLD_SCALE,
		0.0,
		map_position.y * WORLD_SCALE
	)


## Returns the 2D map coordinate for a 3D world position.
func world_to_map(world_position: Vector3) -> Vector2:
	return Vector2(
		world_position.x / WORLD_SCALE,
		world_position.z / WORLD_SCALE
	)


## Removes a specific loot glow by loot ID (called when loot is picked up).
func remove_loot_glow(loot_id: int) -> void:
	if loot_container == null:
		return
	for child in loot_container.get_children():
		if child.has_meta("loot_id") and child.get_meta("loot_id") == loot_id:
			child.queue_free()
			return


## Returns the number of named location labels currently in the scene.
func get_location_label_count() -> int:
	if labels_container == null:
		return 0
	return labels_container.get_child_count()


## Returns whether location labels are currently visible.
func are_labels_visible() -> bool:
	if labels_container == null:
		return false
	return labels_container.visible
