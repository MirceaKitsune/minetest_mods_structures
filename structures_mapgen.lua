-- Structures: Mapgen functions
-- This file contains the mapgen functions used to place saved structures in the world at generation time

-- Settings
local MAPGEN_FILE = "mapgen.txt"
local MAPGEN_PROBABILITY = 0.1
local MAPGEN_RANGE = 2.5
local MAPGEN_AVOID_STEPS = 5
local MAPGEN_FILL = true

-- Local functions - Table

-- the mapgen table and groups table
local mapgen_table = {}
local mapgen_groups = {}

-- updates the groups table with all mapgen groups
local function update_groups ()
	mapgen_groups = {}
	for i, v in ipairs(mapgen_table) do
		local found = false
		for ii, w in ipairs(mapgen_groups) do
			if (v[5] == w) then
				found = true
				break
			end
		end

		if (found == false) then
			table.insert(mapgen_groups, v[5])
		end
	end

	return false
end

-- writes the mapgen file into the mapgen table
local function file_to_table ()
	local path = minetest.get_modpath("structures").."/"..MAPGEN_FILE
	local file = io.open(path, "r")
	if (file == nil) then return end

	mapgen_table = {}
	-- loop through each line
	for line in io.lines(path) do
		local parameters = {}
		-- loop through each parameter in the line
		for item in string.gmatch(line, "%S+") do
			table.insert(parameters, item)
		end
		table.insert(mapgen_table, parameters)
	end

	file:close()
	update_groups()
end

-- writes the mapgen table into the mapgen file
local function table_to_file ()
	local path = minetest.get_modpath("structures").."/"..MAPGEN_FILE
	local file = io.open(path, "w")
	if (file == nil) then return end

	-- loop through each entry
	for i, entry1 in ipairs(mapgen_table) do
		s = ""
		-- loop through each parameter in the entry
		for w, entry2 in ipairs(entry1) do
			s = s..entry2.." "
		end
		s = s.."\n"
		file:write(s)
	end

	file:close()
	update_groups()
end

-- Local functions - Spawn

local function spawn_structure (filename, pos, size, distance, node, range, avoid)
	-- if too close to an avoid origin, move the location until we're far enough
	for i, org in ipairs(avoid) do
		local dist = calculate_distance(pos, org)
		while (dist.x < distance) or (dist.z < distance) do
			if (dist.x < distance) then
				pos.x = pos.x + MAPGEN_AVOID_STEPS
				dist.x = dist.x + MAPGEN_AVOID_STEPS
			end
			if (dist.z < distance) then
				pos.z = pos.z + MAPGEN_AVOID_STEPS
				dist.z = dist.z + MAPGEN_AVOID_STEPS
			end

			-- check that the origin is still in bounds, and fail the attempt if not
			if (pos.x < pos.x - range / 2) or (pos.x > pos.x + range / 2) or
			(pos.z < pos.z - range / 2) or (pos.z > pos.z + range / 2) then
				return nil
			end
		end
	end

	-- now scan downward until we find the specified node at surface level
	-- if we don't, this attempt to spawn the structure is lost
	local search_target = pos.y - range
	for search = pos.y, search_target, -1 do
		local pos_here = { x = pos.x, y = search, z = pos.z }
		local node_here = minetest.env:get_node(pos_here)
		local pos_down = { x = pos.x, y = search - 1, z = pos.z }
		local node_down = minetest.env:get_node(pos_down)

		if (node_here.name == "air") and (node_down.name == node) then
			-- create our structure
			local pos1 = { x = pos_here.x - size.x / 2, y = pos_here.y, z = pos_here.z - size.z / 2 }
			local pos2 = { x = pos_here.x + size.x / 2, y = pos_here.y + size.y, z = pos_here.z + size.z / 2 }
			io_area_import(pos1, pos2, 0 , filename)

			-- we spawned the structure on a suitable node, but what if it was the top of a peak?
			-- to avoid parts of the building left floating, cover everything until all 4 corners touch the ground
			if (MAPGEN_FILL == true) then
				for cover_y = pos_down.y, search_target, -1 do
					local c1 = { x = pos1.x, y = cover_y, z = pos1.z }
					local c2 = { x = pos1.x, y = cover_y, z = pos2.z }
					local c3 = { x = pos2.x, y = cover_y, z = pos1.z }
					local c4 = { x = pos2.x, y = cover_y, z = pos2.z }
					local n1 = minetest.env:get_node(c1)
					local n2 = minetest.env:get_node(c2)
					local n3 = minetest.env:get_node(c3)
					local n4 = minetest.env:get_node(c4)

					if (n1.name == "air") or (n2.name == "air") or (n3.name == "air") or (n4.name == "air") then
						for cover_x = pos1.x, pos2.x do
							for cover_z = pos1.z, pos2.z do
								pos_fill = { x = cover_x, y = cover_y, z = cover_z }
								node_fill = minetest.env:get_node(pos_fill)
								if (node_fill.name ~= node) then
									minetest.env:add_node(pos_fill, { name = node })
								end
							end
						end
					else
						break
					end
				end
			end

			-- return the position where our structure was spawned
			return pos_here
		end
	end

	return nil
end

local function spawn_group (minp, maxp)
	if(math.random() > MAPGEN_PROBABILITY) then return end

	-- randomly choose a mapgen group
	local group = math.random(1, table.getn(mapgen_groups))

	-- Add the origin of each spawned building to the avoidance list
	local avoid = {}

	-- choose middle location on the X and Z axes, top on Y
	local coords_x = minp.x + (maxp.x - minp.x) / 2
	local coords_y = maxp.y
	local coords_z = minp.z + (maxp.z - minp.z) / 2
	local pos = { x = coords_x, y = coords_y, z = coords_z }

	-- go through all entries in the mapgen table which belong to this group
	for i, entry in ipairs(mapgen_table) do
		if (entry[5] == mapgen_groups[group]) then
			local size = { x = entry[1], y = entry[2], z = entry[3] }
			local probability = tonumber(entry[7])
			local distance = tonumber(entry[10])

			-- decide on the distance this building can spawn in
			local range = (probability + distance) * MAPGEN_RANGE

			for x = 1, probability do
				-- randomize X and Z coordinates within range
				coords_x = pos.x + math.random(-range / 2, range / 2)
				coords_z = pos.z + math.random(-range / 2, range / 2)
				local coords = { x = coords_x, y = pos.y, z = coords_z }

				local org = spawn_structure(entry[4], coords, size, distance, entry[6], range, avoid)
				if (org ~= nil) then
					table.insert(avoid, org)
				end
			end
		end
	end
end

-- Global functions - Add / remove to / from file

function mapgen_add (pos, ends, filename, group, node, probability, height_min, height_max, spacing)
	-- remove the existing entry
	mapgen_remove (filename)

	-- we need to store the size of the structure
	local dist = calculate_distance(pos, ends)

	-- add file to the mapgen table
	entry = {dist.x, dist.y, dist.z, filename, group, node, probability, height_min, height_max, spacing }
	table.insert(mapgen_table, entry)

	table_to_file()
end

function mapgen_remove (filename)
	for i, entry in ipairs(mapgen_table) do
		if (entry[4] == filename) then
			table.remove(mapgen_table, i)
			break
		end
	end

	table_to_file()
end

-- Minetest functions

-- cache the mapgen file at startup
minetest.after(0, file_to_table)

minetest.register_on_generated(function(minp, maxp, seed)
	spawn_group (minp, maxp)
end)
