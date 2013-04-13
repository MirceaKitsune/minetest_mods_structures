-- Structures: Item definitions
-- This file contains the item definitions and logics for the Manager and Markers

-- Settings

local CONNECT_DISTANCE = 50
local CONNECT_TIME = 1

-- Local functions - Formspec

local function make_formspec (file, io_angle, area_size, area_nodes, mapgen_group, mapgen_node, mapgen_probability, mapgen_height_min, mapgen_height_max, mapgen_spacing)
		local formspec="size[6,8]"..
			"field[0,0;4,1;file;File;"..file.."]"..
			"button_exit[4,0;2,1;unset;Remove markers]"..
			"label[0,2;Size: X = "..area_size.x.." Y = "..area_size.y.." Z = "..area_size.z.." Nodes: "..area_nodes.."]"..
			"field[4,2;2,1;io_angle;Import angle;"..io_angle.."]"..
			"button[0,3;2,1;io_import;Import]"..
			"button[2,3;2,1;io_export;Export]"..
			"button[4,3;2,1;io_clear;Clear]"..
			"field[0,5;2,1;mapgen_node;Node type;"..mapgen_node.."]"..
			"field[2,5;1,1;mapgen_probability;Probability;"..mapgen_probability.."]"..
			"field[3,5;1,1;mapgen_height_min;Minimum height;"..mapgen_height_min.."]"..
			"field[4,5;1,1;mapgen_height_max;Maximum height;"..mapgen_height_max.."]"..
			"field[5,5;1,1;mapgen_spacing;Spacing;"..mapgen_spacing.."]"..
			"field[0,6;2,1;mapgen_group;Mapgen group;"..mapgen_group.."]"..
			"button[2,6;2,1;mapgen_add;Add file to mapgen]"..
			"button[4,6;2,1;mapgen_remove;Remove file from mapgen]"..
			"button_exit[0,7;6,1;exit;OK]"
		return formspec
end

local function make_formspec_size (pos)
	local pos_markers = markers_get(pos)
	if (pos_markers.x == nil) or (pos_markers.y == nil) or (pos_markers.z == nil) then return nil end

	local size = io_calculate_distance(pos, pos_markers)
	s = size.x..","..size.y..","..size.z.."\n"

	return size
end

local function make_formspec_nodes (pos)
	local pos_markers = markers_get(pos)
	if (pos_markers.x == nil) or (pos_markers.y == nil) or (pos_markers.z == nil) then return nil end
	
	local nodes = 0

	for loop_x = math.min(pos.x, pos_markers.x), math.max(pos.x, pos_markers.x) do
		for loop_y = math.min(pos.y, pos_markers.y), math.max(pos.y, pos_markers.y) do
			for loop_z = math.min(pos.z, pos_markers.z), math.max(pos.z, pos_markers.z) do
				local pos_here = {x = loop_x, y = loop_y, z = loop_z}

				if (io_calculate_ignored(minetest.env:get_node(pos_here).name) == false) then
					nodes = nodes + 1
				end
			end
		end
	end

	return nodes
end

-- Global functions - Item connections

-- removes all 3 markers and disables the manager node
function markers_remove (pos)
	local pos_markers = markers_get(pos)
	local pos_here = {}

	-- remove X
	pos_here = { x = pos_markers.x, y = pos.y, z = pos.z }
	if (minetest.env:get_node(pos_here).name == "structures:marker") then
		minetest.env:remove_node(pos_here)
	end
	-- remove Y
	pos_here = { x = pos.x, y = pos_markers.y, z = pos.z }
	if (minetest.env:get_node(pos_here).name == "structures:marker") then
		minetest.env:remove_node(pos_here)
	end
	-- remove Z
	pos_here = { x = pos.x, y = pos.y, z = pos_markers.z }
	if (minetest.env:get_node(pos_here).name == "structures:marker") then
		minetest.env:remove_node(pos_here)
	end

	minetest.env:add_node(pos, { name = "structures:manager_disabled" })
end

-- search for in-line markers on the X / Y / Z axes within radius and return their positions
function markers_get (pos)
	pos_markers = {x = nil, y = nil, z = nil}
	-- search X
	for search = pos.x - CONNECT_DISTANCE, pos.x + CONNECT_DISTANCE do
		pos_search = {x = search, y = pos.y, z = pos.z}
		if(minetest.env:get_node(pos_search).name == "structures:marker") then
			pos_markers.x = pos_search.x
			break
		end
	end
	-- search Y
	for search = pos.y - CONNECT_DISTANCE, pos.y + CONNECT_DISTANCE do
		pos_search = {x = pos.x, y = search, z = pos.z}
		if(minetest.env:get_node(pos_search).name == "structures:marker") then
			pos_markers.y = pos_search.y
			break
		end
	end
	-- search Z
	for search = pos.z - CONNECT_DISTANCE, pos.z + CONNECT_DISTANCE do
		pos_search = {x = pos.x, y = pos.y, z = search}
		if(minetest.env:get_node(pos_search).name == "structures:marker") then
			pos_markers.z = pos_search.z
			break
		end
	end

	return pos_markers
end

-- check that the block is connected to 3 markers and change it accordingly
function markers_transform (pos)
	local pos_markers = markers_get(pos)
	if (pos_markers.x ~= nil)
	and (pos_markers.y ~= nil)
	and (pos_markers.z ~= nil) then
		if(minetest.env:get_node(pos).name == "structures:manager_disabled") then
			minetest.env:add_node(pos, { name = "structures:manager_enabled" })
		end
	else
		if(minetest.env:get_node(pos).name == "structures:manager_enabled") then
			minetest.env:add_node(pos, { name = "structures:manager_disabled" })
		end
	end
end

-- Item definitions

minetest.register_node("structures:manager_disabled", {
	description = "Structure Manager",
	tiles = {"structure_io_disabled.png"},
	is_ground_content = true,
	groups = {cracky = 1,level = 2},
	drop = 'structures:manager_disabled',
	sounds = default.node_sound_stone_defaults(),
})

minetest.register_node("structures:manager_enabled", {
	description = "Structure Manager",
	tiles = {"structure_io_enabled.png"},
	is_ground_content = true,
	groups = {not_in_creative_inventory = 1, cracky = 1,level = 2},
	drop = 'structures:manager_disabled',
	sounds = default.node_sound_stone_defaults(),

	on_construct = function(pos)
		local meta = minetest.env:get_meta(pos)
		meta:set_string("file", "structure.txt")
		meta:set_float("io_angle", 0)
		meta:set_float("mapgen_group", "structures")
		meta:set_float("mapgen_node", "default:dirt_with_grass")
		meta:set_float("mapgen_probability", 1)
		meta:set_float("mapgen_height_min", -50)
		meta:set_float("mapgen_height_max", 50)
		meta:set_float("mapgen_height_spacing", 10)
		meta:set_string("formspec", make_formspec("structure.txt", 0, make_formspec_size(pos), make_formspec_nodes(pos), "structures", "default:dirt_with_grass", 1, -50, 50, 10))
		meta:set_string("infotext", "I/O ready")
	end,

	on_receive_fields = function(pos, formname, fields, sender)
		local meta = minetest.env:get_meta(pos)
		meta:set_string("file", fields.file)
		meta:set_float("io_angle", fields.io_angle)
		meta:set_float("mapgen_group", fields.mapgen_group)
		meta:set_string("formspec", make_formspec(fields.file, fields.io_angle, make_formspec_size(pos), make_formspec_nodes(pos), fields.mapgen_group, fields.mapgen_node, fields.mapgen_probability, fields.mapgen_height_min, fields.mapgen_height_max, fields.mapgen_spacing))

		if (fields.io_export) then
			io_area_export(pos, markers_get(pos), fields.file)
		elseif (fields.io_import) then
			io_area_import(pos, markers_get(pos), tonumber(fields.io_angle), fields.file)
		elseif (fields.io_clear) then
			io_area_clear(pos, markers_get(pos))
		elseif (fields.unset) then
			io_markers_remove(pos)
		elseif (fields.mapgen_add) then
			mapgen_add(fields.file, fields.mapgen_group, fields.mapgen_node, fields.mapgen_probability, fields.mapgen_height_min, fields.mapgen_height_max, fields.mapgen_spacing)
		elseif (fields.mapgen_remove) then
			mapgen_remove(fields.file)
		end
	end
})

minetest.register_node("structures:marker", {
	description = "Structure Marker",
	drawtype = "nodebox",
	tiles = {"structure_io_marker.png"},
	paramtype = "light",
	is_ground_content = true,
	groups = {cracky = 1,level = 2},
	drop = 'structures:marker',
	sounds = default.node_sound_stone_defaults(),

	node_box = {
		type = "fixed",
		fixed = {
			{-0.125, -0.5, -0.125, 0.125, 0.5, 0.125},
		},
	}
})

minetest.register_abm({
	nodenames = { "structures:manager_disabled", "structures:manager_enabled" },
	interval = CONNECT_TIME,
	chance = 1,

	action = function(pos, node, active_object_count, active_object_count_wider)
		markers_transform(pos)
	end
})

-- Other scripts

dofile(minetest.get_modpath("structures").."/structures_io.lua")
dofile(minetest.get_modpath("structures").."/structures_mapgen.lua")
