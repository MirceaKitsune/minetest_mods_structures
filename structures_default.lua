-- Default town for the Structures mod
-- Metadata: $POSITION_X, $POSITION_Y, $POSITION_Z, $SIZE_X, $SIZE_Y, $SIZE_Z, $ANGLE, $NUMBER, $NAME, $GROUP

-- Settings

-- spawning is delayed by this many seconds per structure
-- higher values give more time for other mapgen operations to finish and reduce lag, but cause towns to appear more slowly
-- example: if the delay is 0.1 and a town has 1000 structures, it will take the entire town 100 seconds to spawn
structures.mapgen_delay = 0.1
-- whether to persist the mapgen cube list into a text file
-- enabling this assures that virtual cubes are persisted between server restarts, reducing the chances of incompletely spawned towns
structures.mapgen_keep_cubes = true
-- whether to keep structures in the table after they have been placed by on_generate
-- enabling this uses more resources and may cause overlapping schematics to be spawned multiple times, but reduces the chances of structures failing to spawn
structures.mapgen_keep_structures = false
-- multiply the size of the virtual cube (determined by the largest town) by this amount
-- larger values decrease town frequency, but give more room for towns to be sorted in
structures.mapgen_cube_multiply_horizontal = 1
structures.mapgen_cube_multiply_vertical = 2

-- Functions

-- set metadata accordingly for everything in this area
local function set_signs (name, number, minp, maxp, group_name)
	-- go through each node in the given area
	local nodes = minetest.find_nodes_in_area(minp, maxp, {"default:sign_wall",})
	for _, node in ipairs(nodes) do
		local meta = minetest.get_meta(node)
		local s = number..", "..name..", "..group_name
		meta:set_string("text", s)
		meta:set_string("infotext", s)
	end
end

-- Towns

structures:define({
	name = "default_town",
	probability = 1,
	biomes = {1, 2},
	noiseparams = {
	   offset = 20,
	   scale = 20,
	   spread = {x = 250, y = 250, z = 250},
	   seed = nil,
	   octaves = 5,
	   persist = 0.6
	},
	buildings = {
		{
			name = "default_town_house_tiny_1",
			layer = 0,
			count = 15,
			offset = 0,
			alignment = 0.5,
			floors = 0,
		},
		{
			name = "default_town_house_tiny_2",
			layer = 0,
			count = 15,
			offset = 0,
			alignment = 0.5,
			floors = 0,
		},
		{
			name = "default_town_house_tiny_3",
			layer = 0,
			count = 15,
			offset = 0,
			alignment = 0.5,
			floors = 0,
		},
		{
			name = "default_town_house_small",
			layer = 0,
			count = 25,
			offset = -5,
			alignment = 0.5,
			floors = 0,
		},
		{
			name = "default_town_house_medium",
			layer = 0,
			count = 50,
			offset = -5,
			alignment = 0.5,
			floors = 0,
		},
		{
			name = "default_town_house_large_1",
			layer = 0,
			count = 25,
			offset = -5,
			alignment = 0.5,
			floors = 0,
		},
		{
			name = "default_town_house_large_2",
			layer = 0,
			count = 25,
			offset = -5,
			alignment = 0.5,
			floors = 0,
		},
		{
			name = "default_town_hotel",
			name_start = "default_town_hotel_(",
			name_end = "default_town_hotel_)",
			layer = 0,
			count = 25,
			offset = 0,
			alignment = 0.5,
			floors = 2,
		},
		{
			name = "default_town_tower",
			layer = 0,
			count = 15,
			offset = 0,
			alignment = 0.5,
			floors = 0,
		},
		{
			name = "default_town_farm",
			layer = 0,
			count = 15,
			offset = -2,
			alignment = 0.5,
			floors = 0,
		},
		{
			name = "default_town_park",
			layer = 0,
			count = 15,
			offset = 0,
			alignment = 0.5,
			floors = 0,
		},
		{
			name = "default_town_fountain",
			layer = 0,
			count = 15,
			offset = 0,
			alignment = 0.5,
			floors = 0,
		},
		{
			name = "default_town_well",
			layer = 0,
			count = 15,
			offset = -7,
			alignment = 0.5,
			floors = 0,
		},
	},
	roads = {
		{
			name_I = "default_town_road_I",
			name_L = "default_town_road_L",
			name_P = "default_town_road_P",
			name_T = "default_town_road_T",
			name_X = "default_town_road_X",
			layer = 0,
			count = 50,
			offset = -8,
			alignment = 0.75,
			branch_min = 5,
		},
	},
	spawn_structure_post = function(name, number, minp, maxp, size, angle)
		set_signs (name, number, minp, maxp, "default_town")
	end,
})
