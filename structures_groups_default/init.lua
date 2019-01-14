-- Default town for the Structures mod

structures_groups_default = {}

local path_schematics = minetest.get_modpath("structures_groups_default").."/schematics/"

-- #1 - Settings

structures.mapgen_area_multiply = 1.5
structures.mapgen_structure_clear = 20

-- #2 - Functions

-- set the desired metadata for nodes in this area
local function set_metadata (name, number, minp, maxp, group_name)
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

-- if the Creatures mod and its default creatures are enabled, place some mobs in houses
local function set_creatures_races_default (name, number, minp, maxp, group_name)
	-- check if the mod exists
	if not creatures or not creatures_races_default then
		return
	end

	-- probability and number of mobs to spawn
	local count = math.random(-2, 2)
	if count <= 0 then
		return
	end
	-- find suitable nodes on which mobs may spawn
	local nodes = minetest.find_nodes_in_area_under_air(minp, maxp, {"group:crumbly", "group:cracky", "group:choppy"})
	if not nodes or #nodes == 0 then
		return
	end
	-- create a list of mobs that may spawn here
	local mobs = {
		"creatures_races_default:human_male",
		"creatures_races_default:human_female",
		"creatures_races_default:anthro_fox_male",
		"creatures_races_default:anthro_fox_female",
		"creatures_races_default:anthro_wolf_female",
		"creatures_races_default:anthro_wolf_male",
		"creatures_races_default:anthro_leopard_female",
		"creatures_races_default:anthro_leopard_male",
		"creatures_races_default:anthro_rabbit_female",
		"creatures_races_default:anthro_rabbit_male",
		"creatures_races_default:anthro_squirrel_female",
		"creatures_races_default:anthro_squirrel_male",
	}

	-- execute the spawn
	for i = 1, count do
		local mob = mobs[math.random(1, #mobs)]
		local node = nodes[math.random(1, #nodes)]
		node.y = node.y + 1
		creatures:spawn(mob, node)
	end
end

-- #3 - Towns

structures:register_group({
	name = "default_town",
	biomes = nil,
	height_min = 5,
	height_max = 50,
	tolerance = 0.75,
	elevation = 0.5,
	buildings = {
		{
			name = path_schematics.."default_town_house_tiny_1.mts",
			base = "default:dirt",
			replacements = {},
			force = true,
			layers = {1,},
			count = 10,
			offset = 0,
			floors_min = 0,
			floors_max = 0,
		},
		{
			name = path_schematics.."default_town_house_tiny_2.mts",
			base = "default:dirt",
			replacements = {},
			force = true,
			layers = {1,},
			count = 10,
			offset = 0,
			floors_min = 0,
			floors_max = 0,
		},
		{
			name = path_schematics.."default_town_house_tiny_3.mts",
			base = "default:dirt",
			replacements = {},
			force = true,
			layers = {1,},
			count = 10,
			offset = 0,
			floors_min = 0,
			floors_max = 0,
		},
		{
			name = path_schematics.."default_town_house_small.mts",
			base = "default:dirt",
			replacements = {},
			force = true,
			layers = {1,},
			count = 20,
			offset = -5,
			floors_min = 0,
			floors_max = 0,
		},
		{
			name = path_schematics.."default_town_house_medium.mts",
			base = "default:dirt",
			replacements = {},
			force = true,
			layers = {1,},
			count = 30,
			offset = -5,
			floors_min = 0,
			floors_max = 0,
		},
		{
			name = path_schematics.."default_town_house_large_1.mts",
			base = "default:dirt",
			replacements = {},
			force = true,
			layers = {1,},
			count = 40,
			offset = -5,
			floors_min = 0,
			floors_max = 0,
		},
		{
			name = path_schematics.."default_town_house_large_2.mts",
			base = "default:dirt",
			replacements = {},
			force = true,
			layers = {1,},
			count = 40,
			offset = -5,
			floors_min = 0,
			floors_max = 0,
		},
		{
			name = path_schematics.."default_town_hotel.mts",
			name_start = path_schematics.."default_town_hotel_start.mts",
			name_end = path_schematics.."default_town_hotel_end.mts",
			base = "default:dirt",
			replacements = {},
			force = true,
			layers = {1,},
			count = 50,
			offset = 0,
			floors_min = 1,
			floors_max = 5,
		},
		{
			name = path_schematics.."default_town_tower.mts",
			base = "default:dirt",
			replacements = {},
			force = true,
			layers = {1,},
			count = 10,
			offset = 0,
			floors_min = 0,
			floors_max = 0,
		},
		{
			name = path_schematics.."default_town_farm.mts",
			base = "default:dirt",
			replacements = {},
			force = true,
			layers = {1,},
			count = 15,
			offset = -2,
			floors_min = 0,
			floors_max = 0,
		},
		{
			name = path_schematics.."default_town_park.mts",
			base = "default:stone",
			replacements = {},
			force = true,
			layers = {1,},
			count = 25,
			offset = 0,
			floors_min = 0,
			floors_max = 0,
		},
		{
			name = path_schematics.."default_town_fountain.mts",
			base = "default:stone",
			replacements = {},
			force = true,
			layers = {1,},
			count = 20,
			offset = 0,
			floors_min = 0,
			floors_max = 0,
		},
		{
			name = path_schematics.."default_town_well.mts",
			base = "default:stone",
			replacements = {},
			force = true,
			layers = {1,},
			count = 5,
			offset = -7,
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
			base = "default:sandstone",
			replacements = {},
			force = true,
			layers = {1,},
			count = 100,
			offset = -8,
			flatness = 0.95,
			branch_count = 10,
			branch_min = 5,
			branch_max = 15,
		},
	},
	spawn_structure_post = function(name, number, minp, maxp, size, angle)
		set_metadata(name, number, minp, maxp, "default_town")
		set_creatures_races_default(name, number, minp, maxp, "default_town")
	end,
})
