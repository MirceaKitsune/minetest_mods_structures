-- Default town for the Structures mod

local path_schematics = minetest.get_modpath("structures").."/schematics/"

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
		-- remove path from the name
		name = string.gsub(name, path_schematics.."default_town_", "")
		name = string.gsub(name, ".mts", "")

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
			name = path_schematics.."default_town_house_tiny_1.mts",
			layer = 0,
			count = 15,
			offset = 0,
			alignment = 0.5,
			floors_min = 0,
			floors_max = 0,
		},
		{
			name = path_schematics.."default_town_house_tiny_2.mts",
			layer = 0,
			count = 15,
			offset = 0,
			alignment = 0.5,
			floors_min = 0,
			floors_max = 0,
		},
		{
			name = path_schematics.."default_town_house_tiny_3.mts",
			layer = 0,
			count = 15,
			offset = 0,
			alignment = 0.5,
			floors_min = 0,
			floors_max = 0,
		},
		{
			name = path_schematics.."default_town_house_small.mts",
			layer = 0,
			count = 25,
			offset = -5,
			alignment = 0.5,
			floors_min = 0,
			floors_max = 0,
		},
		{
			name = path_schematics.."default_town_house_medium.mts",
			layer = 0,
			count = 50,
			offset = -5,
			alignment = 0.5,
			floors_min = 0,
			floors_max = 0,
		},
		{
			name = path_schematics.."default_town_house_large_1.mts",
			layer = 0,
			count = 25,
			offset = -5,
			alignment = 0.5,
			floors_min = 0,
			floors_max = 0,
		},
		{
			name = path_schematics.."default_town_house_large_2.mts",
			layer = 0,
			count = 25,
			offset = -5,
			alignment = 0.5,
			floors_min = 0,
			floors_max = 0,
		},
		{
			name = path_schematics.."default_town_hotel.mts",
			name_start = path_schematics.."default_town_hotel_start.mts",
			name_end = path_schematics.."default_town_hotel_end.mts",
			layer = 0,
			count = 25,
			offset = 0,
			alignment = 0.5,
			floors_min = 1,
			floors_max = 3,
		},
		{
			name = path_schematics.."default_town_tower.mts",
			layer = 0,
			count = 15,
			offset = 0,
			alignment = 0.5,
			floors_min = 0,
			floors_max = 0,
		},
		{
			name = path_schematics.."default_town_farm.mts",
			layer = 0,
			count = 15,
			offset = -2,
			alignment = 0.5,
			floors_min = 0,
			floors_max = 0,
		},
		{
			name = path_schematics.."default_town_park.mts",
			layer = 0,
			count = 15,
			offset = 0,
			alignment = 0.5,
			floors_min = 0,
			floors_max = 0,
		},
		{
			name = path_schematics.."default_town_fountain.mts",
			layer = 0,
			count = 15,
			offset = 0,
			alignment = 0.5,
			floors_min = 0,
			floors_max = 0,
		},
		{
			name = path_schematics.."default_town_well.mts",
			layer = 0,
			count = 15,
			offset = -7,
			alignment = 0.5,
			floors_min = 0,
			floors_max = 0,
		},
	},
	roads = {
		{
			name_I = path_schematics.."default_town_road_I.mts",
			name_L = path_schematics.."default_town_road_L.mts",
			name_P = path_schematics.."default_town_road_P.mts",
			name_T = path_schematics.."default_town_road_T.mts",
			name_X = path_schematics.."default_town_road_X.mts",
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
