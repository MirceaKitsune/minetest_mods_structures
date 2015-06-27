-- Structures: Item definitions
-- This file contains the item definitions and logics for the Manager and Markers

structures = {}

-- Settings

-- number of nodes in which a structure manager searches for markers
-- higher values allow for larger areas but cause a longer loop to execute
local CONNECT_DISTANCE = 100
-- how frequently a node manager detects if markers were added or removed in its range
-- high values cause slower updates, low values cause the check to be preformed more often which might be costly
local CONNECT_TIME = 1

-- Global functions - Calculate

-- checks if two tables contain a matching entry
function calculate_matching (table1, table2)
	for _, entry1 in ipairs(table1) do
		for _, entry2 in ipairs(table2) do
			if entry1 == entry2 then
				return true
			end
		end
	end
	return false
end

-- calculates the linear interpolation between two numbers
function calculate_lerp (value_start, value_end, control)
	return (1 - control) * value_start + control * value_end
end

-- returns the distance between two origins
function calculate_distance (pos1, pos2)
	local size = {x = 0, y = 0, z = 0}
	if pos1.x < pos2.x then size.x = pos2.x - pos1.x else size.x = pos1.x - pos2.x end
	if pos1.y < pos2.y then size.y = pos2.y - pos1.y else size.y = pos1.y - pos2.y end
	if pos1.z < pos2.z then size.z = pos2.z - pos1.z else size.z = pos1.z - pos2.z end

	return size
end

-- checks if the node is in the specified list
function calculate_node_in_table (node, list)
	for i, v in ipairs(list) do
		if node == v then
			return true
		end
	end

	return false
end

-- shuffle the entries of a table
function calculate_table_shuffle(list)
	local count = #list
	for i in ipairs(list) do
		-- obtain a random entry to swap this entry with
		local rand = math.random(count)

		-- swap the two entries
		local old = list[i]
		list[i] = list[rand]
		list[rand] = old
	end

	return list
end

-- returns a random entry if value is a table
function calculate_entry (value)
	if type(value) == "table" then
		return value[math.random(1, #value)]
	else
		return value
	end
end

-- returns the height based on height map
function calculate_heightmap_pos (heightmap, minp, maxp, pos_x, pos_z)
	local chunksize = maxp.x - minp.x + 1
	local index = (pos_z - minp.z) * chunksize + (pos_x - minp.x) + 1
	local height = heightmap[index]
	return height
end

-- Local functions - Formspec

local function make_formspec (file, io_angle, area_size, area_nodes)
		local formspec="size[6,4]"..
			default.gui_bg..
			default.gui_bg_img..
			default.gui_slots..
			"field[0,0;4,2;file;File;"..file.."]"..
			"field[4,0;2,2;io_angle;Import angle;"..io_angle.."]"..
			"label[0,1;Size: X = "..area_size.x.." Y = "..area_size.y.." Z = "..area_size.z.." Nodes: "..area_nodes.."]"..
			"button[0,2;2,1;io_import;Import]"..
			"button[2,2;2,1;io_export;Export]"..
			"button[4,2;2,1;io_clear;Clear]"..
			"button_exit[0,3;6,1;exit;OK]"
		return formspec
end

local function make_formspec_size (pos)
	local pos_markers = markers_get(pos)
	if pos_markers.x == nil or pos_markers.y == nil or pos_markers.z == nil then return nil end

	local size = calculate_distance(pos, pos_markers)
	-- remove edge from calculation
	size.x = size.x - 1
	size.y = size.y - 1
	size.z = size.z - 1
	s = size.x..","..size.y..","..size.z.."\n"

	return size
end

local function make_formspec_nodes (pos)
	local pos_markers = markers_get(pos)
	if pos_markers.x == nil or pos_markers.y == nil or pos_markers.z == nil then return nil end
	
	local nodes = 0

	for loop_x = math.min(pos.x, pos_markers.x) + 1, math.max(pos.x, pos_markers.x) - 1 do
		for loop_y = math.min(pos.y, pos_markers.y) + 1, math.max(pos.y, pos_markers.y) - 1 do
			for loop_z = math.min(pos.z, pos_markers.z) + 1, math.max(pos.z, pos_markers.z) - 1 do
				local pos_here = {x = loop_x, y = loop_y, z = loop_z}

				if calculate_node_in_table(minetest.env:get_node(pos_here).name, structures.IO_ignore) == false then
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
	pos_here = {x = pos_markers.x, y = pos.y, z = pos.z}
	if minetest.env:get_node(pos_here).name == "structures:marker" then
		minetest.env:remove_node(pos_here)
	end
	-- remove Y
	pos_here = {x = pos.x, y = pos_markers.y, z = pos.z}
	if minetest.env:get_node(pos_here).name == "structures:marker" then
		minetest.env:remove_node(pos_here)
	end
	-- remove Z
	pos_here = {x = pos.x, y = pos.y, z = pos_markers.z}
	if minetest.env:get_node(pos_here).name == "structures:marker" then
		minetest.env:remove_node(pos_here)
	end

	minetest.env:add_node(pos, {name = "structures:manager_disabled"})
end

-- search for in-line markers on the X / Y / Z axes within radius and return their positions
function markers_get (pos)
	pos_markers = {x = nil, y = nil, z = nil}
	-- search X
	for search = pos.x - CONNECT_DISTANCE, pos.x + CONNECT_DISTANCE do
		pos_search = {x = search, y = pos.y, z = pos.z}
		if minetest.env:get_node(pos_search).name == "structures:marker" then
			pos_markers.x = pos_search.x
			break
		end
	end
	-- search Y
	for search = pos.y - CONNECT_DISTANCE, pos.y + CONNECT_DISTANCE do
		pos_search = {x = pos.x, y = search, z = pos.z}
		if minetest.env:get_node(pos_search).name == "structures:marker" then
			pos_markers.y = pos_search.y
			break
		end
	end
	-- search Z
	for search = pos.z - CONNECT_DISTANCE, pos.z + CONNECT_DISTANCE do
		pos_search = {x = pos.x, y = pos.y, z = search}
		if minetest.env:get_node(pos_search).name == "structures:marker" then
			pos_markers.z = pos_search.z
			break
		end
	end

	return pos_markers
end

-- check that the block is connected to 3 markers and change it accordingly
function markers_transform (pos)
	local pos_markers = markers_get(pos)
	if pos_markers.x ~= nil and pos_markers.y ~= nil and pos_markers.z ~= nil then
		if minetest.env:get_node(pos).name == "structures:manager_disabled" then
			minetest.env:add_node(pos, {name = "structures:manager_enabled"})
		end
	else
		if minetest.env:get_node(pos).name == "structures:manager_enabled" then
			minetest.env:add_node(pos, {name = "structures:manager_disabled"})
		end
	end
end

-- Item definitions

minetest.register_privilege("structures", {
	description = "Import & Export structures",
	give_to_singleplayer = true
})

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
		meta:set_string("file", "structure")
		meta:set_float("io_angle", 0)
		meta:set_string("formspec", make_formspec("structure", 0, make_formspec_size(pos), make_formspec_nodes(pos)))
		meta:set_string("infotext", "I/O ready")
	end,

	on_receive_fields = function(pos, formname, fields, sender)
		local player = sender:get_player_name()
		if not minetest.check_player_privs(player, {structures=true}) then
			minetest.chat_send_player(player, "Error: You need the \"structures\" privilege to use the structure manager", false)
			return
		end

		local meta = minetest.env:get_meta(pos)
		meta:set_string("file", fields.file)
		meta:set_float("io_angle", fields.io_angle)
		meta:set_string("formspec", make_formspec(fields.file, fields.io_angle, make_formspec_size(pos), make_formspec_nodes(pos)))

		if fields.io_export then
			io_area_export(pos, markers_get(pos), fields.file)
		elseif fields.io_import then
			io_area_import(pos, markers_get(pos), tonumber(fields.io_angle), fields.file, {}, true, true)
		elseif fields.io_clear then
			io_area_fill(pos, markers_get(pos), nil)
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
	nodenames = {"structures:manager_disabled", "structures:manager_enabled"},
	interval = CONNECT_TIME,
	chance = 1,

	action = function(pos, node, active_object_count, active_object_count_wider)
		markers_transform(pos)
	end
})

-- Other scripts

dofile(minetest.get_modpath("structures").."/structures_io.lua")
dofile(minetest.get_modpath("structures").."/structures_mapgen.lua")
dofile(minetest.get_modpath("structures").."/structures_mapgen_roads.lua")
dofile(minetest.get_modpath("structures").."/structures_mapgen_buildings.lua")
