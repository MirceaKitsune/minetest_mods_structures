-- Structures: I/O functions
-- This file contains the input / output functions used to save and restore structures in and from text files

-- Settings

IO_IGNORE = {"ignore", "air", "fire:basic_flame", "structures:manager_disabled", "structures:manager_enabled", "structures:marker"}
local IO_DIRECTORY = "structures"

-- Global functions - Import / export

-- clears marked area of any objects which aren't ignored
function io_area_clear (pos, ends)
	if (ends == nil) then return end
	local pos_start = { x = math.min(pos.x, ends.x), y = math.min(pos.y, ends.y), z = math.min(pos.z, ends.z) }
	local pos_end = { x = math.max(pos.x, ends.x), y = math.max(pos.y, ends.y), z = math.max(pos.z, ends.z) }

	-- erase each node in the marked area
	for loop_x = pos_start.x, pos_end.x do
		for loop_y = pos_start.y, pos_end.y do
			for loop_z = pos_start.z, pos_end.z do
				local pos_here = {x = loop_x, y = loop_y, z = loop_z}

				if (calculate_ignored(minetest.env:get_node(pos_here).name) == false) then
					minetest.env:remove_node(pos_here)
				end
			end
		end
	end
end

-- exports structure to a text file
function io_area_export (pos, ends, filename)
	if (ends == nil) then return end
	local pos_start = { x = math.min(pos.x, ends.x), y = math.min(pos.y, ends.y), z = math.min(pos.z, ends.z) }
	local pos_end = { x = math.max(pos.x, ends.x), y = math.max(pos.y, ends.y), z = math.max(pos.z, ends.z) }

	local path = minetest.get_modpath("structures").."/"..IO_DIRECTORY.."/"..filename
	local file = io.open(path, "w")
	if (file == nil) then return end

	-- write each node in the marked area to a line
	for loop_x = pos_start.x, pos_end.x do
		for loop_y = pos_start.y, pos_end.y do
			for loop_z = pos_start.z, pos_end.z do
				local pos_here = {x = loop_x, y = loop_y, z = loop_z}
				local node_name = minetest.env:get_node(pos_here).name
				local liquidtype = minetest.registered_nodes[node_name].liquidtype

				-- don't export flowing liquid nodes, just sources
				if (calculate_ignored(node_name) == false) and (liquidtype ~= "flowing") then
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

-- imports structure from a text file
function io_area_import (pos, ends, angle, filename)
	if (ends == nil) then return end
	local pos_start = { x = math.min(pos.x, ends.x), y = math.min(pos.y, ends.y), z = math.min(pos.z, ends.z) }
	local pos_end = { x = math.max(pos.x, ends.x), y = math.max(pos.y, ends.y), z = math.max(pos.z, ends.z) }

	local path = minetest.get_modpath("structures").."/"..IO_DIRECTORY.."/"..filename
	local file = io.open(path, "r")
	if (file == nil) then return end

	-- clear the area before we get started
	io_area_clear(pos_start, pos_end)

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

			-- clear and abort if a node is larger than the marked area
			if (node_pos.x < pos_start.x) or (node_pos.y > pos_end.y) or (node_pos.z > pos_end.z) then
				print("Structure I/O Error: Structure is larger than the marked area, clearing and aborting.")
				io_area_clear(pos)
				return
			end

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

			-- clear and abort if a node is larger than the marked area
			if (node_pos.x < pos_start.x) or (node_pos.y > pos_end.y) or (node_pos.z < pos_start.z) then
				print("Structure I/O Error: Structure is larger than the marked area, clearing and aborting.")
				io_area_clear(pos)
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
			node_pos = { x = pos_start.x + tonumber(parameters[3]), y = pos_start.y + tonumber(parameters[2]), z = pos_end.z - tonumber(parameters[1]) }

			-- clear and abort if a node is larger than the marked area
			if (node_pos.x > pos_end.x) or (node_pos.y > pos_end.y) or (node_pos.z < pos_start.z) then
				print("Structure I/O Error: Structure is larger than the marked area, clearing and aborting.")
				io_area_clear(pos)
				return
			end

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

			-- clear and abort if a node is larger than the marked area
			if (node_pos.x > pos_end.x) or (node_pos.y > pos_end.y) or (node_pos.z > pos_end.z) then
				print("Structure I/O Error: Structure is larger than the marked area, clearing and aborting.")
				io_area_clear(pos)
				return
			end
		end
		minetest.env:add_node(node_pos, { name = node_name, param1 = node_param1, param2 = node_param2 })
	end

	file:close()
end
