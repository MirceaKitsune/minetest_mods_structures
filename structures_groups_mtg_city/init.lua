-- City for Minetest Game for the Structures mod

structures_groups_mtg_city = {}

local path_schematics = minetest.get_modpath("structures_groups_mtg_city").."/schematics/"

-- #1 - Settings

structures.mapgen_area_multiply = 1.5
structures.mapgen_structure_base_padding = 50

-- #2 - Functions

-- set the desired metadata for nodes in this area
local function set_metadata (name, number, minp, maxp, group_name)
	-- go through each node in the given area
	local nodes = minetest.find_nodes_in_area(minp, maxp, {"default:sign_wall",})
	for _, node in ipairs(nodes) do
		-- remove path from the name
		name = string.gsub(name, path_schematics.."mtg_city_", "")
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
	name = "mtg_city",
	biomes = nil,
	height_min = 10,
	height_max = 100,
	tolerance = 1,
	tolerance_link = 2,
	elevation = 0.5,
	buildings = {

	},
	roads = {
		{
			name_I = path_schematics.."road_small_I.mts",
			name_L = path_schematics.."road_small_L.mts",
			name_P = path_schematics.."road_small_P.mts",
			name_T = path_schematics.."road_small_T.mts",
			name_X = path_schematics.."road_small_X.mts",
			base = "default:stone",
			replacements = {},
			force = true,
			layers = {1,},
			count = 80,
			offset = -10,
			flatness = 1,
			branch_count = 20,
			branch_min = 4,
			branch_max = 8,
		},
		{
			name_I = path_schematics.."road_large_I.mts",
			name_L = path_schematics.."road_large_L.mts",
			name_P = path_schematics.."road_large_P.mts",
			name_T = path_schematics.."road_large_T.mts",
			name_X = path_schematics.."road_large_X.mts",
			base = "default:stone",
			replacements = {},
			force = true,
			layers = {1,},
			count = 100,
			offset = -10,
			flatness = 1,
			branch_count = 25,
			branch_min = 5,
			branch_max = 10,
		},
		{
			name_I = path_schematics.."road_tunnel_I.mts",
			name_L = path_schematics.."road_tunnel_L.mts",
			name_P = path_schematics.."road_tunnel_P.mts",
			name_T = path_schematics.."road_tunnel_T.mts",
			name_X = path_schematics.."road_tunnel_X.mts",
			base = "default:cobble",
			replacements = {},
			force = true,
			layers = {1,},
			count = 60,
			offset = -10,
			flatness = 1,
			branch_count = 25,
			branch_min = 6,
			branch_max = 12,
		},
		{
			name_I = path_schematics.."road_rail_I.mts",
			name_L = path_schematics.."road_rail_L.mts",
			name_P = path_schematics.."road_rail_P.mts",
			name_T = path_schematics.."road_rail_T.mts",
			name_X = path_schematics.."road_rail_X.mts",
			base = "default:cobble",
			replacements = {},
			force = true,
			layers = {1,},
			count = 40,
			offset = -2,
			flatness = 1,
			branch_count = 20,
			branch_min = 6,
			branch_max = 12,
		},
	},
	spawn_structure_post = function(name, number, minp, maxp, size, angle)
		set_metadata(name, number, minp, maxp, "mtg_city")
		set_creatures_races_default(name, number, minp, maxp, "mtg_city")
	end,
})
