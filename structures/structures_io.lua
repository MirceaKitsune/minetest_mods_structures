-- Structures: I/O functions
-- This file contains the input / output functions used to save and restore structures in and from text files

-- Settings

-- don't import the nodes listed here
structures.IO_ignore = {"ignore", "air", "structures:manager_disabled", "structures:manager_enabled", "structures:marker"}

-- Global functions - Import / export

-- gets the size of a structure file
function io_get_size (angle, filename)
	if not filename or filename == "" then return nil end
	-- obtain size from the serialized schematic in lua format
	-- since the table is returned as a string, use loadstring to activate it like a piece of lua code
	local file = minetest.serialize_schematic(filename, "lua", {})
	local func = nil
	local env = {}
	if setfenv then
		func = loadstring(file)
		setfenv(func, env)
	else
		func = load(file, nil, "t", env)
	end
	func()
	local size = env.schematic.size

	-- rotate box size with angle
	if angle == 90 or angle == 270 then
		local size_rotate = {x = size.z, y = size.y, z = size.x}
		size = size_rotate
	end

	return size
end

-- export structure to a schematic
function io_area_export (pos, ends, filename)
	if ends == nil or not filename or filename == "" then return end
	local pos_start = {x = math.min(pos.x, ends.x) + 1, y = math.min(pos.y, ends.y) + 1, z = math.min(pos.z, ends.z) + 1}
	local pos_end = {x = math.max(pos.x, ends.x) - 1, y = math.max(pos.y, ends.y) - 1, z = math.max(pos.z, ends.z) - 1}

	-- add ignored nodes with 0 probability
	local ignore = {}
	for loop_x = pos_start.x, pos_end.x do
		for loop_y = pos_start.y, pos_end.y do
			for loop_z = pos_start.z, pos_end.z do
				local pos_here = {x = loop_x, y = loop_y, z = loop_z}
				local node_here = minetest.env:get_node(pos_here).name
				local liquidtype = minetest.registered_nodes[node_here].liquidtype
				if calculate_node_in_table(node_here, structures.IO_ignore) == true or liquidtype == "flowing" then
					table.insert(ignore, {pos = {x = loop_x, y = loop_y, z = loop_z}, prob = -1} )
				end
			end
		end
	end

	minetest.create_schematic(pos_start, pos_end, ignore, filename)
end

-- import structure from a schematic
function io_area_import (pos, ends, angle, filename, replacements, force, check_bounds, vm)
	if ends == nil or not filename or filename == "" then return end
	local pos_start = {x = math.min(pos.x, ends.x) + 1, y = math.min(pos.y, ends.y) + 1, z = math.min(pos.z, ends.z) + 1}
	local pos_end = {x = math.max(pos.x, ends.x) - 1, y = math.max(pos.y, ends.y) - 1, z = math.max(pos.z, ends.z) - 1}

	-- check if the structure fits between the start and end positions if necessary
	if check_bounds == true then
		local size = io_get_size(angle, filename)
		if size == nil then return end

		-- abort if a node is larger than the marked area
		if pos_start.x + size.x - 1 > pos_end.x or pos_start.y + size.y - 1 > pos_end.y or pos_start.z + size.z - 1 > pos_end.z then
			print("Structure I/O Error: Structure is larger than the marked area, aborting.")
			return
		end
	end

	-- abort if file doesn't exist
	local file = io.open(filename, "r")
	if file == nil then return end
	file:close()

	-- place on vm if a voxelmanip is given, otherwise just place on the map
	if vm then
		minetest.place_schematic_on_vmanip(vm, pos_start, filename, angle, replacements, force)
	else
		minetest.place_schematic(pos_start, filename, angle, replacements, force)
	end
end
