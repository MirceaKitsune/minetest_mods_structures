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

-- runs the necessary updates on a vm after changes were made
function io_vm_update (voxelmanip)
	voxelmanip.vm:update_map()
	voxelmanip.vm:update_liquids()
	voxelmanip.vm:calc_lighting()
	voxelmanip.vm:write_to_map()
end

-- fills the marked area, ignored objects are not affected
function io_area_fill (pos, ends, node, force, voxelmanip)
	local pos_start = {x = math.min(pos.x, ends.x) + 1, y = math.min(pos.y, ends.y) + 1, z = math.min(pos.z, ends.z) + 1}
	local pos_end = {x = math.max(pos.x, ends.x) - 1, y = math.max(pos.y, ends.y) - 1, z = math.max(pos.z, ends.z) - 1}

	-- create a vm if none is given
	local voxelmanip_this = {}
	if voxelmanip then
		voxelmanip_this = {vm = voxelmanip.vm, emin = voxelmanip.emin, emax = voxelmanip.emax, minp = voxelmanip.minp, maxp = voxelmanip.maxp, update = false}
	else
		voxelmanip_this = {vm = VoxelManip(), emin = pos_start, emax = pos_end, minp = pos_start, maxp = pos_end, update = true}
	end

	local data = voxelmanip_this.vm:get_data()
	local area = VoxelArea:new{MinEdge = voxelmanip_this.emin, MaxEdge = voxelmanip_this.emax}
	local node_content = minetest.get_content_id(node)
	local node_air_content = minetest.get_content_id("air")

	-- set each node in the marked area
	for i in area:iterp(voxelmanip_this.minp, voxelmanip_this.maxp) do
		if data[i] == node_air_content or force == true then
			local pos_this = area:position(i)
			if pos_this.x >= pos_start.x and pos_this.x <= pos_end.x and
			pos_this.y >= pos_start.y and pos_this.y <= pos_end.y and
			pos_this.z >= pos_start.z and pos_this.z <= pos_end.z then
				data[i] = node_content
			end
		end
	end

	-- write new vm data, preform updates here if we used a local vm
	voxelmanip_this.vm:set_data(data)
	if voxelmanip_this.update == true then
		io_vm_update(voxelmanip_this)
	end
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
function io_area_import (pos, ends, angle, filename, replacements, force, check_bounds, voxelmanip)
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

	-- place on vmanip if a vm is given, otherwise just place on the map
	if voxelmanip then
		minetest.place_schematic_on_vmanip(voxelmanip.vm, pos_start, filename, angle, replacements, force)
	else
		minetest.place_schematic(pos_start, filename, angle, replacements, force)
	end

	-- we need to call on_construct for each node that has one, otherwise some nodes won't work correctly and even crash
	for search_x = pos_start.x, pos_end.x do
		for search_y = pos_start.y, pos_end.y do
			for search_z = pos_start.z, pos_end.z do
				local pos = {x = search_x, y = search_y, z = search_z}
				local node = minetest.get_node(pos).name
				if minetest.registered_nodes[node] and minetest.registered_nodes[node].on_construct then
					minetest.registered_nodes[node].on_construct(pos)
				end
			end
		end
	end
end
