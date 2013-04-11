-- Structures: Item definitions
-- This file contains the item definitions and logics for the Manager and Markers

-- Settings

local CONNECT_DISTANCE = 50
local CONNECT_TIME = 1

-- Local functions - Formspec

local function make_formspec (file, angle, size, nodes)
		local formspec="size[6,4]"..
			"field[0,0;4,2;file;File;"..file.."]"..
			"button_exit[4,0;2,1;unset;Remove markers]"..
			"label[0,1;Size: X = "..size.x.." Y = "..size.y.." Z = "..size.z.." Nodes: "..nodes.."]"..
			"field[4,1;2,2;angle;Import angle;"..angle.."]"..
			"button[0,2;2,1;import;Import]"..
			"button[2,2;2,1;export;Export]"..
			"button[4,2;2,1;clear;Clear]"..
			"button_exit[0,3;6,1;exit;OK]"
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
		meta:set_float("angle", 0)
		meta:set_string("formspec", make_formspec("structure.txt", 0, make_formspec_size(pos), make_formspec_nodes(pos)))
		meta:set_string("infotext", "I/O ready")
	end,

	on_receive_fields = function(pos, formname, fields, sender)
		local meta = minetest.env:get_meta(pos)
		meta:set_string("file", fields.file)
		meta:set_float("angle", fields.angle)
		meta:set_string("formspec", make_formspec(fields.file, fields.angle, make_formspec_size(pos), make_formspec_nodes(pos)))

		if (fields.export) then
			io_area_export(pos, fields.file)
		elseif (fields.import) then
			io_area_import(pos, tonumber(fields.angle), fields.file)
		elseif (fields.clear) then
			io_area_clear(pos)
		elseif (fields.unset) then
			io_markers_remove(pos)
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
