-- Default town for the Structures mod

local path_schematics = minetest.get_modpath("structures_groups_default").."/schematics/"

-- #1 - Settings

structures.mapgen_delay = 0.25
structures.mapgen_area_multiply = 1

-- #2 - Functions

-- set the desired metadata for nodes in this area
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

-- #3 - Towns

structures:register_group({
	name = "default_town",
	biomes = nil,
	height_min = 5,
	height_max = 50,
	buildings = {
		{
			name = path_schematics.."default_town_house_tiny_1.mts",
			layer = 0,
			count = 15,
			offset = 0,
			flatness = nil,
			floors_min = 0,
			floors_max = 0,
		},
		{
			name = path_schematics.."default_town_house_tiny_2.mts",
			layer = 0,
			count = 15,
			offset = 0,
			flatness = nil,
			floors_min = 0,
			floors_max = 0,
		},
		{
			name = path_schematics.."default_town_house_tiny_3.mts",
			layer = 0,
			count = 15,
			offset = 0,
			flatness = nil,
			floors_min = 0,
			floors_max = 0,
		},
		{
			name = path_schematics.."default_town_house_small.mts",
			layer = 0,
			count = 25,
			offset = -5,
			flatness = nil,
			floors_min = 0,
			floors_max = 0,
		},
		{
			name = path_schematics.."default_town_house_medium.mts",
			layer = 0,
			count = 50,
			offset = -5,
			flatness = nil,
			floors_min = 0,
			floors_max = 0,
		},
		{
			name = path_schematics.."default_town_house_large_1.mts",
			layer = 0,
			count = 25,
			offset = -5,
			flatness = nil,
			floors_min = 0,
			floors_max = 0,
		},
		{
			name = path_schematics.."default_town_house_large_2.mts",
			layer = 0,
			count = 25,
			offset = -5,
			flatness = nil,
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
			flatness = nil,
			floors_min = 1,
			floors_max = 3,
		},
		{
			name = path_schematics.."default_town_tower.mts",
			layer = 0,
			count = 15,
			offset = 0,
			flatness = nil,
			floors_min = 0,
			floors_max = 0,
		},
		{
			name = path_schematics.."default_town_farm.mts",
			layer = 0,
			count = 15,
			offset = -2,
			flatness = nil,
			floors_min = 0,
			floors_max = 0,
		},
		{
			name = path_schematics.."default_town_park.mts",
			layer = 0,
			count = 15,
			offset = 0,
			flatness = nil,
			floors_min = 0,
			floors_max = 0,
		},
		{
			name = path_schematics.."default_town_fountain.mts",
			layer = 0,
			count = 15,
			offset = 0,
			flatness = nil,
			floors_min = 0,
			floors_max = 0,
		},
		{
			name = path_schematics.."default_town_well.mts",
			layer = 0,
			count = 15,
			offset = -7,
			flatness = nil,
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
			flatness = 0.85,
			branch_min = 5,
		},
	},
	spawn_structure_post = function(name, number, minp, maxp, size, angle)
		set_signs (name, number, minp, maxp, "default_town")
	end,
})
