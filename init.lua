-- settings

CONNECT_DISTANCE = 50
EXPORT_IGNORE = {"ignore", "air", "fire:basic_flame", "structures:io_disabled", "structures:io_enabled", "structures:io_marker"}

-- import and export functions

local function distance (pos1, pos2)
	local size = { x = 0, y = 0, z = 0 }
	if pos1.x < pos2.x then size.x = pos2.x - pos1.x else size.x = pos1.x - pos2.x end
	if pos1.y < pos2.y then size.y = pos2.y - pos1.y else size.y = pos1.y - pos2.y end
	if pos1.z < pos2.z then size.z = pos2.z - pos1.z else size.z = pos1.z - pos2.z end

	return size
end

local function is_ignored (node)
	for i, v in ipairs(EXPORT_IGNORE) do
		if (node == v) then
			return true
		end
	end

	return false
end

local function make_formspec (file, angle, size, nodes)
		local formspec="size[6,4]"..
			"label[0,0;Size: X = "..size.x.." Y = "..size.y.." Z = "..size.z.." Nodes: "..nodes.."]"..
			"button_exit[4,0;2,1;unset;Remove markers]"..
			"field[0,1;4,2;file;File;"..file.."]"..
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

	local size = distance(pos, pos_markers)
	s = size.x..","..size.y..","..size.z.."\n"

	return size
end

local function make_formspec_nodes (pos)
	-- re-check markers and get their pos_markers
	local pos_markers = markers_get(pos)
	if (pos_markers.x == nil) or (pos_markers.y == nil) or (pos_markers.z == nil) then return nil end
	
	local nodes = 0

	-- write each node in the marked area to a line
	for loop_x = math.min(pos.x, pos_markers.x), math.max(pos.x, pos_markers.x) do
		for loop_y = math.min(pos.y, pos_markers.y), math.max(pos.y, pos_markers.y) do
			for loop_z = math.min(pos.z, pos_markers.z), math.max(pos.z, pos_markers.z) do
				local pos_here = {x = loop_x, y = loop_y, z = loop_z}

				if (is_ignored(minetest.env:get_node(pos_here).name) == false) then
					-- we want to save origins as distance from the main I/O node
					nodes = nodes + 1
				end
			end
		end
	end

	return nodes
end

local function area_clear (pos)
	-- clears import / export area of any objects which aren't ignored

	-- re-check markers and get their positions
	local pos_markers = markers_get(pos)
	if (pos_markers.x == nil) or (pos_markers.y == nil) or (pos_markers.z == nil) then return end
	local pos_start = { x = math.min(pos.x, pos_markers.x), y = math.min(pos.y, pos_markers.y), z = math.min(pos.z, pos_markers.z) }
	local pos_end = { x = math.max(pos.x, pos_markers.x), y = math.max(pos.y, pos_markers.y), z = math.max(pos.z, pos_markers.z) }

	-- erase each node in the marked area to a line
	for loop_x = pos_start.x, pos_end.x do
		for loop_y = pos_start.y, pos_end.y do
			for loop_z = pos_start.z, pos_end.z do
				local pos_here = {x = loop_x, y = loop_y, z = loop_z}

				if (is_ignored(minetest.env:get_node(pos_here).name) == false) then
					minetest.env:remove_node(pos_here)
				end
			end
		end
	end
end

local function area_export (pos, filename)
	-- exports structure to a text file

	-- re-check markers and get their positions
	local pos_markers = markers_get(pos)
	if (pos_markers.x == nil) or (pos_markers.y == nil) or (pos_markers.z == nil) then return end
	local pos_start = { x = math.min(pos.x, pos_markers.x), y = math.min(pos.y, pos_markers.y), z = math.min(pos.z, pos_markers.z) }
	local pos_end = { x = math.max(pos.x, pos_markers.x), y = math.max(pos.y, pos_markers.y), z = math.max(pos.z, pos_markers.z) }

	local file = io.open(filename, "w")
	if (file == nil) then return end

	-- write each node in the marked area to a line
	for loop_x = pos_start.x, pos_end.x do
		for loop_y = pos_start.y, pos_end.y do
			for loop_z = pos_start.z, pos_end.z do
				local pos_here = {x = loop_x, y = loop_y, z = loop_z}
				local node_name = minetest.env:get_node(pos_here).name
				local liquidtype = minetest.registered_nodes[node_name].liquidtype

				-- don't export flowing liquid nodes, just sources
				if (is_ignored(node_name) == false) and (liquidtype ~= "flowing") then
					-- we want to save origins as distance from the main I/O node
					local dist = distance(pos_start, pos_here)
					-- param2 must be persisted
					local node_param1 = minetest.env:get_node(pos_here).param1
					local node_param2 = minetest.env:get_node(pos_here).param2

					-- parameters: x position, y position, z position, node type, param1, param2
					s = dist.x.." "..dist.y.." "..dist.z.." "..
					minetest.env:get_node(pos_here).name.." "..
					node_param1.." "..node_param2.."\n"
					file:write(s)
				end
			end
		end
	end

	file:close()
end

local function area_import (pos, angle, filename)
	-- imports structure from a text file

	-- re-check markers and get their positions
	local pos_markers = markers_get(pos)
	if (pos_markers.x == nil) or (pos_markers.y == nil) or (pos_markers.z == nil) then return end
	local pos_start = { x = math.min(pos.x, pos_markers.x), y = math.min(pos.y, pos_markers.y), z = math.min(pos.z, pos_markers.z) }
	local pos_end = { x = math.max(pos.x, pos_markers.x), y = math.max(pos.y, pos_markers.y), z = math.max(pos.z, pos_markers.z) }

	local file = io.open(filename, "r")
	if (file == nil) then return end

	-- clear the area before we get started
	area_clear(pos)

	for line in io.lines(filename) do
		local parameters = {}
		for item in string.gmatch(line, "%S+") do
			table.insert(parameters, item)
		end

		-- parameters: x position [1], y position [2], z position [3], node type [4], param1 [5], param2 [6]
		local node_pos = { }
		local node_name = parameters[4]
		local node_param1 = parameters[5]
		local node_param2 = parameters[6]
		local node_paramtype2 = minetest.registered_nodes[node_name].paramtype2

		if (angle == 90) or (angle == -270) then
			node_pos = { x = pos_start.x + tonumber(parameters[3]), y = pos_start.y + tonumber(parameters[2]), z = pos_start.z + tonumber(parameters[1]) }

			-- clear and abort if a node is larger than the marked area
			if (node_pos.x > pos_end.x) or (node_pos.y > pos_end.y) or (node_pos.z > pos_end.z) then
				print("Structure I/O Error: Structure is larger than the marked area, clearing and aborting.")
				area_clear(pos)
				return
			end

			-- if param2 is facedir, rotate it accordingly
			-- 0 = y+ ; 1 = z+ ; 2 = z- ; 3 = x+ ; 4 = x- ; 5 = y-
			if (node_paramtype2 == "facedir") then
				if (node_param2 == "0") then node_param2 = "1"
				elseif (node_param2 == "1") then node_param2 = "0"
				elseif (node_param2 == "2") then node_param2 = "3"
				elseif (node_param2 == "3") then node_param2 = "2" end
			end
			-- if param2 is wallmounted, rotate it accordingly
			if (node_paramtype2 == "wallmounted") then
				if (node_param2 == "2") then node_param2 = "4"
				elseif (node_param2 == "3") then node_param2 = "5"
				elseif (node_param2 == "4") then node_param2 = "2"
				elseif (node_param2 == "5") then node_param2 = "3" end
			end
		elseif (angle == 180) then
			node_pos = { x = pos_end.x - tonumber(parameters[1]), y = pos_start.y + tonumber(parameters[2]), z = pos_end.z - tonumber(parameters[3]) }

			-- clear and abort if a node is larger than the marked area
			if (node_pos.x < pos_start.x) or (node_pos.y > pos_end.y) or (node_pos.z < pos_start.z) then
				print("Structure I/O Error: Structure is larger than the marked area, clearing and aborting.")
				area_clear(pos)
				return
			end

			-- if param2 is facedir, rotate it accordingly
			-- 0 = y+ ; 1 = z+ ; 2 = z- ; 3 = x+ ; 4 = x- ; 5 = y-
			if (node_paramtype2 == "facedir") then
				if (node_param2 == "0") then node_param2 = "2"
				elseif (node_param2 == "1") then node_param2 = "3"
				elseif (node_param2 == "2") then node_param2 = "0"
				elseif (node_param2 == "3") then node_param2 = "1" end
			end
			-- if param2 is wallmounted, rotate it accordingly
			if (node_paramtype2 == "wallmounted") then
				if (node_param2 == "2") then node_param2 = "3"
				elseif (node_param2 == "3") then node_param2 = "2"
				elseif (node_param2 == "4") then node_param2 = "5"
				elseif (node_param2 == "5") then node_param2 = "4" end
			end
		elseif (angle == 270) or (angle == -90) then
			node_pos = { x = pos_end.x - tonumber(parameters[3]), y = pos_start.y + tonumber(parameters[2]), z = pos_end.z - tonumber(parameters[1]) }

			-- clear and abort if a node is larger than the marked area
			if (node_pos.x < pos_start.x) or (node_pos.y > pos_end.y) or (node_pos.z < pos_start.z) then
				print("Structure I/O Error: Structure is larger than the marked area, clearing and aborting.")
				area_clear(pos)
				return
			end

			-- if param2 is facedir, rotate it accordingly
			-- 0 = y+ ; 1 = z+ ; 2 = z- ; 3 = x+ ; 4 = x- ; 5 = y-
			if (node_paramtype2 == "facedir") then
				if (node_param2 == "0") then node_param2 = "3"
				elseif (node_param2 == "1") then node_param2 = "2"
				elseif (node_param2 == "2") then node_param2 = "1"
				elseif (node_param2 == "3") then node_param2 = "0" end
			end
			-- if param2 is wallmounted, rotate it accordingly
			if (node_paramtype2 == "wallmounted") then
				if (node_param2 == "2") then node_param2 = "5"
				elseif (node_param2 == "3") then node_param2 = "4"
				elseif (node_param2 == "4") then node_param2 = "3"
				elseif (node_param2 == "5") then node_param2 = "2" end
			end
		else -- 0 degrees
			node_pos = { x = pos_start.x + tonumber(parameters[1]), y = pos_start.y + tonumber(parameters[2]), z = pos_start.z + tonumber(parameters[3]) }

			-- clear and abort if a node is larger than the marked area
			if (node_pos.x > pos_end.x) or (node_pos.y > pos_end.y) or (node_pos.z > pos_end.z) then
				print("Structure I/O Error: Structure is larger than the marked area, clearing and aborting.")
				area_clear(pos)
				return
			end
		end
		minetest.env:add_node(node_pos, { name = node_name, param1 = node_param1, param2 = node_param2 })
	end

	file:close()
end

-- functions

markers_remove = function (pos)
	-- removes all 3 markers so the player can set up new ones
	local pos_markers = markers_get(pos)
	local pos_here = {}

	-- remove X
	pos_here = { x = pos_markers.x, y = pos.y, z = pos.z }
	if (minetest.env:get_node(pos_here).name == "structures:io_marker") then
		minetest.env:remove_node(pos_here)
	end
	-- remove Y
	pos_here = { x = pos.x, y = pos_markers.y, z = pos.z }
	if (minetest.env:get_node(pos_here).name == "structures:io_marker") then
		minetest.env:remove_node(pos_here)
	end
	-- remove Z
	pos_here = { x = pos.x, y = pos.y, z = pos_markers.z }
	if (minetest.env:get_node(pos_here).name == "structures:io_marker") then
		minetest.env:remove_node(pos_here)
	end

	-- switch to disabled node
	minetest.env:add_node(pos, { name = "structures:io_disabled" })
end

markers_get = function (pos)
	-- search for in-line markers on the X / Y / Z axes within radius and return their pos_markers

	pos_markers = {x = nil, y = nil, z = nil}
	-- search X
	for search = pos.x - CONNECT_DISTANCE, pos.x + CONNECT_DISTANCE do
		pos_search = {x = search, y = pos.y, z = pos.z}
		if(minetest.env:get_node(pos_search).name == "structures:io_marker") then
			pos_markers.x = pos_search.x
			break
		end
	end
	-- search Y
	for search = pos.y - CONNECT_DISTANCE, pos.y + CONNECT_DISTANCE do
		pos_search = {x = pos.x, y = search, z = pos.z}
		if(minetest.env:get_node(pos_search).name == "structures:io_marker") then
			pos_markers.y = pos_search.y
			break
		end
	end
	-- search Z
	for search = pos.z - CONNECT_DISTANCE, pos.z + CONNECT_DISTANCE do
		pos_search = {x = pos.x, y = pos.y, z = search}
		if(minetest.env:get_node(pos_search).name == "structures:io_marker") then
			pos_markers.z = pos_search.z
			break
		end
	end

	return pos_markers
end

markers_transform = function (pos)
	-- check that the block is connected to 3 markers and change it accordingly

	local pos_markers = markers_get(pos)
	if (pos_markers.x ~= nil)
	and (pos_markers.y ~= nil)
	and (pos_markers.z ~= nil) then
		if(minetest.env:get_node(pos).name == "structures:io_disabled") then
			minetest.env:add_node(pos, { name = "structures:io_enabled" })
		end
	else
		if(minetest.env:get_node(pos).name == "structures:io_enabled") then
			minetest.env:add_node(pos, { name = "structures:io_disabled" })
		end
	end
end

-- item definitions

minetest.register_node("structures:io_disabled", {
	description = "Structure I/O",
	tiles = {"structure_io_disabled.png"},
	is_ground_content = true,
	groups = {cracky = 1,level = 2},
	drop = 'structures:io_disabled',
	sounds = default.node_sound_stone_defaults(),
})

minetest.register_node("structures:io_enabled", {
	description = "Structure I/O",
	tiles = {"structure_io_enabled.png"},
	is_ground_content = true,
	groups = {not_in_creative_inventory = 1, cracky = 1,level = 2},
	drop = 'structures:io_disabled',
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
			area_export(pos, fields.file)
		elseif (fields.import) then
			area_import(pos, tonumber(fields.angle), fields.file)
		elseif (fields.clear) then
			area_clear(pos)
		elseif (fields.unset) then
			markers_remove(pos)
		end
	end
})

minetest.register_node("structures:io_marker", {
	description = "Structure I/O marker",
	drawtype = "nodebox",
	tiles = {"structure_io_marker.png"},
	paramtype = "light",
	is_ground_content = true,
	groups = {cracky = 1,level = 2},
	drop = 'structures:io_marker',
	sounds = default.node_sound_stone_defaults(),

	node_box = {
		type = "fixed",
		fixed = {
			{-0.125, -0.5, -0.125, 0.125, 0.5, 0.125},
		},
	}
})

minetest.register_abm({
	nodenames = { "structures:io_disabled", "structures:io_enabled" },
	interval = 1,
	chance = 1,

	action = function(pos, node, active_object_count, active_object_count_wider)
		markers_transform(pos)
	end
})
