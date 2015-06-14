-- Structures: I/O functions
-- This file contains the input / output functions used to save and restore structures in and from text files

-- Settings

-- directory in which structure files are stored (inside the mod's own directory)
local IO_DIRECTORY = "structures"
-- don't import the nodes listed here
IO_IGNORE = {"ignore", "air", "fire:basic_flame", "structures:manager_disabled", "structures:manager_enabled", "structures:marker"}
-- use schematics instead of text files, faster and recommended
IO_SCHEMATICS = true

-- Global functions - Import / export

-- gets the size of a structure file
function io_get_size (angle, filename)
	local path = minetest.get_modpath("structures").."/"..IO_DIRECTORY.."/"..filename

	local size = { x = 0, y = 0, z = 0 }

	-- whether to use text files or schematics
	if (IO_SCHEMATICS == true) then
		path = path..".mts"
		local file = io.open(path, "r")
		if (file == nil) then return nil end

		-- thanks to sfan5 for this advanced code that reads the size from schematic files
		local read_s16 = function(fi)
			return string.byte(fi:read(1)) * 256 + string.byte(fi:read(1))
		end
		local function get_schematic_size(f)
			-- make sure those are the first 4 characters, otherwise this might be a corrupt file
			if f:read(4) ~= "MTSM" then return nil end
			-- advance 2 more characters
			f:read(2)
			-- the next characters here are our size, read them
			return read_s16(f), read_s16(f), read_s16(f)
		end

		size.x, size.y, size.z = get_schematic_size(file)
		file.close(file)
	else
		path = path..".txt"
		local file = io.open(path, "r")
		if (file == nil) then return nil end

		-- we must read the parameters of each node from the structure file
		for line in io.lines(path) do
			local parameters = {}
			for item in string.gmatch(line, "%S+") do
				table.insert(parameters, item)
			end

			-- the furthest node in any direction determines the overall size of the structure
			if (size.x < tonumber(parameters[1]) + 1) then
				size.x = tonumber(parameters[1]) + 1
			end
			if (size.y < tonumber(parameters[2]) + 1) then
				size.y = tonumber(parameters[2]) + 1
			end
			if (size.z < tonumber(parameters[3]) + 1) then
				size.z = tonumber(parameters[3]) + 1
			end
		end
		file:close()
	end

	-- rotate box size with angle
	if (angle == 90) or (angle == 270) then
		local size_rotate = { x = size.z, y = size.y, z = size.x }
		size = size_rotate
	end

	return size
end

-- fills the marked aream, ignored objects are not affected
function io_area_fill (pos, ends, node)
	local pos_start = { x = math.min(pos.x, ends.x) + 1, y = math.min(pos.y, ends.y) + 1, z = math.min(pos.z, ends.z) + 1 }
	local pos_end = { x = math.max(pos.x, ends.x) - 1, y = math.max(pos.y, ends.y) - 1, z = math.max(pos.z, ends.z) - 1 }

	-- no node specified means we clear the area
	if (node == nil) then
		node = "air"
	end

	-- erase each node in the marked area
	local vm = VoxelManip()
	local minp, maxp = vm:read_from_map(pos_start, pos_end)
	local data = vm:get_data()
	local va = VoxelArea:new{ MinEdge = minp, MaxEdge = maxp }
	for x = pos_start.x, pos_end.x do
		for y = pos_start.y, pos_end.y do
			for z = pos_start.z, pos_end.z do
				local i = va:index(x, y, z)
				data[i] = minetest.get_content_id(node)
			end
		end
	end
	vm:set_data(data)
	vm:write_to_map()
	vm:update_map()
	vm:calc_lighting()
	vm:update_liquids()
end

-- exports structure to a text file
function io_area_export (pos, ends, filename)
	if (ends == nil) then return end
	local pos_start = { x = math.min(pos.x, ends.x) + 1, y = math.min(pos.y, ends.y) + 1, z = math.min(pos.z, ends.z) + 1 }
	local pos_end = { x = math.max(pos.x, ends.x) - 1, y = math.max(pos.y, ends.y) - 1, z = math.max(pos.z, ends.z) - 1 }

	local path = minetest.get_modpath("structures").."/"..IO_DIRECTORY.."/"..filename

	-- whether to use text files or schematics
	if (IO_SCHEMATICS == true) then
		-- export to a schematic file
		path = path..".mts"

		-- add ignored nodes with 0 probability
		local ignore = { }
		for loop_x = pos_start.x, pos_end.x do
			for loop_y = pos_start.y, pos_end.y do
				for loop_z = pos_start.z, pos_end.z do
					local pos_here = {x = loop_x, y = loop_y, z = loop_z}
					local node_here = minetest.env:get_node(pos_here).name
					local liquidtype = minetest.registered_nodes[node_here].liquidtype
					if (calculate_node_in_table(node_here, IO_IGNORE) == true) or (liquidtype == "flowing") then
						table.insert(ignore, { pos = { x = loop_x, y = loop_y, z = loop_z }, prob = -1 } )
					end
				end
			end
		end

		minetest.create_schematic(pos_start, pos_end, ignore, path)
	else
		-- export to a text file
		path = path..".txt"
		local file = io.open(path, "w")
		if (file == nil) then return end

		-- write each node in the marked area to a line
		for loop_x = pos_start.x, pos_end.x do
			for loop_y = pos_start.y, pos_end.y do
				for loop_z = pos_start.z, pos_end.z do
					local pos_here = {x = loop_x, y = loop_y, z = loop_z}
					local node_here = minetest.env:get_node(pos_here).name
					local liquidtype = minetest.registered_nodes[node_here].liquidtype

					-- don't export flowing liquid nodes, just sources
					if (calculate_node_in_table(node_here, IO_IGNORE) == false) and (liquidtype ~= "flowing") then
						-- we want to save origins as distance from the main I/O node
						local dist = calculate_distance(pos_start, pos_here)
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
end

-- imports structure from a text file
function io_area_import (pos, ends, angle, filename, check_bounds)
	if (ends == nil) then return end
	local pos_start = { x = math.min(pos.x, ends.x) + 1, y = math.min(pos.y, ends.y) + 1, z = math.min(pos.z, ends.z) + 1 }
	local pos_end = { x = math.max(pos.x, ends.x) - 1, y = math.max(pos.y, ends.y) - 1, z = math.max(pos.z, ends.z) - 1 }

	-- check if the structure fits between the start and end positions if necessary
	if (check_bounds == true) then
		local size = io_get_size(angle, filename)
		if (size == nil) then return end

		-- abort if a node is larger than the marked area
		if (pos_start.x + size.x - 1 > pos_end.x) or (pos_start.y + size.y - 1 > pos_end.y) or (pos_start.z + size.z - 1 > pos_end.z) then
			print("Structure I/O Error: Structure is larger than the marked area, aborting.")
			return
		end
	end

	local path = minetest.get_modpath("structures").."/"..IO_DIRECTORY.."/"..filename

	-- whether to use text files or schematics
	if (IO_SCHEMATICS == true) then
		-- import from a schematic file
		path = path..".mts"

		-- abort if file doesn't exist
		local file = io.open(path, "r")
		if (file == nil) then return end
		file:close()

		minetest.place_schematic(pos_start, path, angle, _, true)

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
	else
		-- import from a text file
		path = path..".txt"
		local file = io.open(path, "r")
		if (file == nil) then return end

		for line in io.lines(path) do
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
				node_pos = { x = pos_end.x - tonumber(parameters[3]), y = pos_start.y + tonumber(parameters[2]), z = pos_start.z + tonumber(parameters[1]) }

				-- if param2 is facedir, rotate it accordingly
				-- 0 = y+ ; 1 = z+ ; 2 = z- ; 3 = x+ ; 4 = x- ; 5 = y-
				if (node_paramtype2 == "facedir") then
					if (node_param2 == "0") then node_param2 = "3"
					elseif (node_param2 == "1") then node_param2 = "0"
					elseif (node_param2 == "2") then node_param2 = "1"
					elseif (node_param2 == "3") then node_param2 = "2" end
				end
				-- if param2 is wallmounted, rotate it accordingly
				if (node_paramtype2 == "wallmounted") then
					if (node_param2 == "2") then node_param2 = "4"
					elseif (node_param2 == "3") then node_param2 = "5"
					elseif (node_param2 == "4") then node_param2 = "3"
					elseif (node_param2 == "5") then node_param2 = "2" end
				end
			elseif (angle == 180) then
				node_pos = { x = pos_end.x - tonumber(parameters[1]), y = pos_start.y + tonumber(parameters[2]), z = pos_end.z - tonumber(parameters[3]) }

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
				node_pos = { x = pos_start.x + tonumber(parameters[3]), y = pos_start.y + tonumber(parameters[2]), z = pos_end.z - tonumber(parameters[1]) }

				-- if param2 is facedir, rotate it accordingly
				-- 0 = y+ ; 1 = z+ ; 2 = z- ; 3 = x+ ; 4 = x- ; 5 = y-
				if (node_paramtype2 == "facedir") then
					if (node_param2 == "0") then node_param2 = "1"
					elseif (node_param2 == "1") then node_param2 = "2"
					elseif (node_param2 == "2") then node_param2 = "3"
					elseif (node_param2 == "3") then node_param2 = "0" end
				end
				-- if param2 is wallmounted, rotate it accordingly
				if (node_paramtype2 == "wallmounted") then
					if (node_param2 == "2") then node_param2 = "5"
					elseif (node_param2 == "3") then node_param2 = "4"
					elseif (node_param2 == "4") then node_param2 = "2"
					elseif (node_param2 == "5") then node_param2 = "3" end
				end
			else -- 0 degrees
				node_pos = { x = pos_start.x + tonumber(parameters[1]), y = pos_start.y + tonumber(parameters[2]), z = pos_start.z + tonumber(parameters[3]) }
			end
			minetest.env:set_node(node_pos, { name = node_name, param1 = node_param1, param2 = node_param2 })
		end

		file:close()
	end
end
